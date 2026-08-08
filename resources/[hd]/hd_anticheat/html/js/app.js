// ═══════════════════════════════════════════════════════════════════
//  HD ANTICHEAT | NUI
//  Pure display + a couple of manual actions — every real decision
//  (who's flagged, who's banned) happens server-side in
//  server/detection.lua and server/main.lua, never here.
// ═══════════════════════════════════════════════════════════════════

const app = document.getElementById('app');
let selectedPlayer = null;
let flagsCache = [];
let rosterCache = [];
let selectedRosterPlayer = null;
let reportsCache = [];
let chatCache = [];
let onDuty = false;
let monitorCache = [];
let bigScreenId = null;
const monitorHistory = {}; // [id] -> recent [{x,y}] samples, oldest first
const MONITOR_HISTORY_LEN = 12;
const MONITOR_RADIUS_M = 40; // metres from center to tile edge — controls how "zoomed in" the radar looks

function post(name, body = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body),
    }).then((r) => r.json()).catch(() => ({}));
}

function toast(msg) {
    const el = document.getElementById('toast');
    el.textContent = msg;
    el.classList.remove('hidden');
    clearTimeout(toast._t);
    toast._t = setTimeout(() => el.classList.add('hidden'), 2500);
}

function escapeHtml(str) {
    return String(str ?? '').replace(/[&<>"']/g, (c) => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
}

// Reports loaded at resource start come back with a MySQL TIMESTAMP
// string (`created`); ones that arrive live are a plain os.time()
// number — handle both rather than assuming one shape.
function formatTime(at) {
    if (at == null) return '';
    if (typeof at === 'number') return new Date(at * 1000).toLocaleTimeString();
    return String(at);
}

// ═══════════════════════════ OPEN / CLOSE ═════════════════════════════
function openPanel() { app.classList.remove('hidden'); }
function closePanel() {
    app.classList.add('hidden');
    // The server side of 'close' already tears down spectate/monitor
    // (client/main.lua) — this just resets the NUI's own view state so
    // the panel doesn't reopen stuck on the big screen next time.
    bigScreenId = null;
    document.body.classList.remove('big-screen-active');
    document.getElementById('monitorBigScreen').classList.add('hidden');
    document.getElementById('monitorGrid').classList.remove('hidden');
    post('close');
}

document.getElementById('closeBtn').addEventListener('click', closePanel);

// ═══════════════════════════ /acreport FORM ═══════════════════════════
// Own tiny overlay, independent of #app — reachable by every player via
// /acreport (client/main.lua), not gated behind the admin panel above.
const reportFormOverlay = document.getElementById('reportFormOverlay');

function openReportForm() {
    document.getElementById('reportTitleInput').value = '';
    document.getElementById('reportMessageInput').value = '';
    reportFormOverlay.classList.remove('hidden');
    document.getElementById('reportTitleInput').focus();
}

function closeReportForm() {
    reportFormOverlay.classList.add('hidden');
    post('closeReportForm');
}

document.getElementById('reportCancelBtn').addEventListener('click', closeReportForm);

document.getElementById('reportSubmitBtn').addEventListener('click', () => {
    const title = document.getElementById('reportTitleInput').value.trim();
    const message = document.getElementById('reportMessageInput').value.trim();
    if (!title || !message) { toast('Enter both a title and details.'); return; }
    post('submitReport', { title, message });
    // Closes via the same path Cancel uses (releases NUI focus too) —
    // submitReport can silently reject server-side (the per-player
    // cooldown), so this can't assume success and skip the focus
    // release, or a rejected submit would leave the mouse trapped with
    // no visible form left to explain why. Notify() (game toast) is
    // what actually reports success/failure, independent of this.
    closeReportForm();
});

document.addEventListener('keyup', (e) => {
    if (e.key !== 'Escape') return;
    if (!reportFormOverlay.classList.contains('hidden')) { closeReportForm(); return; }
    if (!app.classList.contains('hidden')) closePanel();
});

// ═══════════════════════════ TABS ═════════════════════════════════════
document.querySelectorAll('.tab-btn[data-tab]').forEach((btn) => {
    btn.addEventListener('click', () => {
        const tab = btn.dataset.tab;
        if (tab === 'chat' && !onDuty) return; // defensive — the button is CSS-hidden off duty anyway

        const activeBtn = document.querySelector('.tab-btn[data-tab].active');
        const leavingMonitor = activeBtn && activeBtn.dataset.tab === 'monitor' && tab !== 'monitor';

        document.querySelectorAll('.tab-btn[data-tab]').forEach((b) => b.classList.remove('active'));
        document.querySelectorAll('.tab-panel').forEach((p) => p.classList.remove('active'));
        btn.classList.add('active');
        document.getElementById(`tab-${tab}`).classList.add('active');

        if (tab === 'monitor') {
            post('monitorStart');
        } else if (leavingMonitor) {
            exitBigScreen();
            post('monitorStop');
        }
    });
});

// ═══════════════════════════ MESSAGES FROM CLIENT ═════════════════════
window.addEventListener('message', (event) => {
    const d = event.data;
    switch (d.action) {
        case 'open': openPanel(); break;
        case 'players': renderPlayers(d.data); break;
        case 'flags': flagsCache = d.data || []; renderFlags(); break;
        case 'flag':
            flagsCache.unshift(d.data);
            renderFlags();
            toast(`${d.data.banned ? 'BANNED' : 'Flagged'}: ${d.data.name} — ${d.data.type}`);
            break;

        case 'roster': renderRoster(d.data); break;

        case 'monitor': handleMonitorUpdate(d.data); break;

        case 'reports': reportsCache = d.data || []; renderReports(); break;
        case 'report':
            reportsCache.unshift(d.data);
            renderReports();
            toast(`New report from ${d.data.name}`);
            break;

        case 'chatHistory': chatCache = d.data || []; renderChat(); break;
        case 'chat': {
            chatCache.unshift(d.data);
            if (chatCache.length > 100) chatCache.pop();
            renderChat();
            const chatTabActive = document.getElementById('tab-chat').classList.contains('active');
            if (!chatTabActive) toast(`[Admin Chat] ${d.data.name}: ${d.data.message}`);
            break;
        }

        case 'dutyState': applyDutyState(d.onDuty); break;

        case 'announce': showAnnounceBanner(d.message, d.admin, d.ms); break;

        case 'license': renderLicenseStatus(d.data); break;

        case 'openReportForm': openReportForm(); break;
        case 'reportNotify': showReportNotify(d.data); break;
    }
});

// ═══════════════════════════ OVERVIEW ═══════════════════════════════════
function renderPlayers(list) {
    const tbody = document.querySelector('#playersTable tbody');
    tbody.innerHTML = '';

    if (!list || list.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="6">No players online.</td></tr>';
        return;
    }

    list.forEach((p) => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${p.id}</td>
            <td>${escapeHtml(p.name)}${p.admin ? '<span class="admin-badge">ADMIN (exempt)</span>' : ''}</td>
            <td>${escapeHtml(p.citizenid || '')}</td>
            <td>${p.ping}</td>
            <td class="${p.score >= 60 ? 'score-hot' : ''}">${p.score}</td>
            <td><button class="btn btn-sm manage-btn" ${p.admin ? 'disabled' : ''}>Manage</button></td>
        `;
        if (!p.admin) tr.querySelector('.manage-btn').addEventListener('click', () => selectPlayer(p));
        tbody.appendChild(tr);
    });
}

function selectPlayer(p) {
    selectedPlayer = p;
    document.getElementById('paName').textContent = `${p.name} (${p.id})`;
    document.getElementById('playerActions').classList.remove('hidden');
}

document.getElementById('paClose').addEventListener('click', () => {
    selectedPlayer = null;
    document.getElementById('playerActions').classList.add('hidden');
});

document.getElementById('refreshBtn').addEventListener('click', () => post('refresh'));

document.getElementById('btnClearScore').addEventListener('click', () => {
    if (!selectedPlayer) return;
    post('clearScore', { targetId: selectedPlayer.id });
});

document.getElementById('btnManualBan').addEventListener('click', () => {
    if (!selectedPlayer) return;
    const reason = document.getElementById('banReason').value.trim();
    if (!reason) { toast('Enter a ban reason.'); return; }
    post('manualBan', { targetId: selectedPlayer.id, reason });
    document.getElementById('banReason').value = '';
    selectedPlayer = null;
    document.getElementById('playerActions').classList.add('hidden');
});

// ═══════════════════════════ DETECTIONS ═════════════════════════════════
function renderFlags() {
    const tbody = document.querySelector('#flagsTable tbody');
    tbody.innerHTML = '';

    if (!flagsCache || flagsCache.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="6">No detections yet.</td></tr>';
        return;
    }

    flagsCache.forEach((f) => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${escapeHtml(f.name)}</td>
            <td>${escapeHtml(f.citizenid || '')}</td>
            <td>${escapeHtml(f.type)}</td>
            <td>${escapeHtml(f.detail)}</td>
            <td>${f.score}</td>
            <td class="${f.banned ? 'result-banned' : 'result-flagged'}">${f.banned ? 'Banned' : 'Flagged'}</td>
        `;
        tbody.appendChild(tr);
    });
}

// ═══════════════════════════ LICENSE STATUS ══════════════════════════════
// Purely informational — mirrors the same plan/expiry data the web
// dashboard shows (hd_anticheat_dashboard_cloudflare/public/js/dashboard.js).
// `data` is null whenever Config.License.Key is blank (self-hosted/local
// use, never gated on this) or the first sync hasn't landed yet.
function renderLicenseStatus(data) {
    const el = document.getElementById('licenseStatus');
    if (!data) { el.classList.add('hidden'); return; }

    el.classList.remove('hidden');
    if (data.expired) {
        el.textContent = 'License expired — renew to restore dashboard sync';
        el.classList.add('license-warning');
        return;
    }
    if (data.guildMismatch) {
        el.textContent = 'License bound to a different Discord server';
        el.classList.add('license-warning');
        return;
    }

    el.classList.remove('license-warning');
    if (data.daysRemaining == null) {
        el.textContent = 'Lifetime license';
    } else {
        el.textContent = `License: ${data.daysRemaining} day${data.daysRemaining === 1 ? '' : 's'} left`;
        el.classList.toggle('license-warning', data.daysRemaining <= 7);
    }
}

// ═══════════════════════════ PLAYERS (roster) ═══════════════════════════
function renderRoster(list) {
    rosterCache = list || [];
    const tbody = document.querySelector('#rosterTable tbody');
    tbody.innerHTML = '';

    if (rosterCache.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="5">No players online.</td></tr>';
        return;
    }

    rosterCache.forEach((p) => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${p.id}</td>
            <td>${escapeHtml(p.steamName)}${p.admin ? '<span class="admin-badge">ADMIN</span>' : ''}</td>
            <td>${escapeHtml(p.charName || '')}</td>
            <td>${p.ping}</td>
            <td><button class="btn btn-sm roster-manage-btn">Manage</button></td>
        `;
        tr.querySelector('.roster-manage-btn').addEventListener('click', () => selectRosterPlayer(p));
        tbody.appendChild(tr);
    });
}

function selectRosterPlayer(p) {
    selectedRosterPlayer = p;
    document.getElementById('raName').textContent = `${p.steamName} (${p.id})`;
    document.getElementById('rosterActions').classList.remove('hidden');
}

document.getElementById('raClose').addEventListener('click', () => {
    selectedRosterPlayer = null;
    document.getElementById('rosterActions').classList.add('hidden');
});

document.getElementById('rosterRefreshBtn').addEventListener('click', () => post('getRoster'));

document.getElementById('btnRaTeleport').addEventListener('click', () => {
    if (!selectedRosterPlayer) return;
    post('teleportTo', { args: [selectedRosterPlayer.id] });
});

document.getElementById('btnRaKick').addEventListener('click', () => {
    if (!selectedRosterPlayer) return;
    const reason = document.getElementById('kickReason').value.trim() || 'No reason given';
    post('kick', { args: [selectedRosterPlayer.id, reason] });
    document.getElementById('kickReason').value = '';
});

document.getElementById('btnRaBan').addEventListener('click', () => {
    if (!selectedRosterPlayer) return;
    const reason = document.getElementById('raBanReason').value.trim();
    if (!reason) { toast('Enter a ban reason.'); return; }
    post('manualBan', { targetId: selectedRosterPlayer.id, reason });
    document.getElementById('raBanReason').value = '';
});

// ═══════════════════════════ WORLD ═══════════════════════════════════════
document.getElementById('btnWorldReset').addEventListener('click', () => {
    post('worldReset');
    toast('World reset dispatched.');
});

document.getElementById('btnAnnounce').addEventListener('click', () => {
    const input = document.getElementById('announceInput');
    const msg = input.value.trim();
    if (!msg) { toast('Enter a message.'); return; }
    post('announce', { args: [msg] });
    input.value = '';
});

function showAnnounceBanner(message, admin, ms) {
    const el = document.getElementById('announceBanner');
    el.innerHTML = `
        <div class="announce-title">SERVER ANNOUNCEMENT</div>
        <div class="announce-msg">${escapeHtml(message)}</div>
        <div class="announce-admin">— ${escapeHtml(admin || '')}</div>
    `;
    el.classList.remove('hidden');
    clearTimeout(showAnnounceBanner._t);
    showAnnounceBanner._t = setTimeout(() => el.classList.add('hidden'), ms || 8000);
}

// Every on-duty admin gets this regardless of whether the panel is even
// open (server/reports.lua broadcasts to all of OnDuty, not just
// OpenPanels) — deliberately just the report number, not the content,
// so it's a quick heads-up rather than a wall of text popping up
// mid-gameplay. Clicking it jumps straight to the Reports tab.
function showReportNotify(data) {
    const el = document.getElementById('reportNotify');
    el.innerHTML = `<div class="report-notify-title">New Report</div>Report #${data.id}`;
    el.classList.remove('hidden');
    el.onclick = () => {
        el.classList.add('hidden');
        if (app.classList.contains('hidden')) return; // panel isn't open — nothing to switch tabs on
        document.querySelector('.tab-btn[data-tab="reports"]').click();
    };
    clearTimeout(showReportNotify._t);
    showReportNotify._t = setTimeout(() => el.classList.add('hidden'), 8000);
}

// ═══════════════════════════ MONITOR ═════════════════════════════════════
// The small tiles are live position/heading telemetry — a genuine,
// continuously-updating radar plotted from real server-side coordinates
// (see server/monitor.lua's header for why it's this and not a video
// thumbnail). The big screen is real live video: it drives hd_admin's
// own spectate camera and shows it through a transparent cutout this
// panel opens up around it (see style.css's .big-screen-active rules).
function updateHistory(p) {
    const hist = monitorHistory[p.id] || (monitorHistory[p.id] = []);
    hist.push({ x: p.x, y: p.y });
    if (hist.length > MONITOR_HISTORY_LEN) hist.shift();
}

function drawRadar(canvas, entry, history) {
    const ctx = canvas.getContext('2d');
    const w = canvas.width, h = canvas.height;
    ctx.clearRect(0, 0, w, h);

    ctx.fillStyle = 'rgba(59, 7, 100, 0.4)';
    ctx.fillRect(0, 0, w, h);

    const cx = w / 2, cy = h / 2;
    const scale = (Math.min(w, h) / 2 - 6) / MONITOR_RADIUS_M;

    ctx.strokeStyle = 'rgba(216, 180, 254, 0.22)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(cx, 0); ctx.lineTo(cx, h);
    ctx.moveTo(0, cy); ctx.lineTo(w, cy);
    ctx.arc(cx, cy, Math.min(w, h) / 2 - 4, 0, Math.PI * 2);
    ctx.stroke();

    if (history && history.length > 1) {
        ctx.strokeStyle = 'rgba(192, 132, 252, 0.75)';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        history.forEach((pt, i) => {
            const px = cx + (pt.x - entry.x) * scale;
            const py = cy - (pt.y - entry.y) * scale;
            if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
        });
        ctx.stroke();
    }

    if (entry.heading != null) {
        const rad = (entry.heading * Math.PI) / 180;
        ctx.strokeStyle = '#fde68a';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(cx, cy);
        ctx.lineTo(cx + Math.sin(rad) * 13, cy - Math.cos(rad) * 13);
        ctx.stroke();
    }

    ctx.fillStyle = entry.admin ? '#86efac' : '#f3e8ff';
    ctx.beginPath();
    ctx.arc(cx, cy, 4, 0, Math.PI * 2);
    ctx.fill();
}

function renderMonitorGrid(list) {
    const grid = document.getElementById('monitorGrid');
    const currentIds = new Set(list.map((p) => String(p.id)));
    grid.querySelectorAll('.mon-tile').forEach((t) => { if (!currentIds.has(t.dataset.id)) t.remove(); });

    if (list.length === 0) {
        grid.innerHTML = '<div class="empty-row">No players online.</div>';
        return;
    }

    list.forEach((p) => {
        let tile = grid.querySelector(`.mon-tile[data-id="${p.id}"]`);
        if (!tile) {
            tile = document.createElement('div');
            tile.className = 'mon-tile';
            tile.dataset.id = p.id;
            tile.innerHTML = `<div class="mon-tile-head"></div><canvas width="150" height="100"></canvas><div class="mon-tile-stats"></div>`;
            tile.addEventListener('click', () => enterBigScreen(p.id));
            grid.appendChild(tile);
        }
        tile.querySelector('.mon-tile-head').innerHTML = `${escapeHtml(p.name)} <span class="mon-id">#${p.id}</span>`;
        drawRadar(tile.querySelector('canvas'), p, monitorHistory[p.id]);
        tile.querySelector('.mon-tile-stats').innerHTML = telemetryLine(p);
    });
}

// Same telemetry fields the big screen's toolbar has available (name/id)
// plus everything else the server actually sends (server/monitor.lua) —
// no Kick/Ban/Teleport controls here on purpose, those stay exclusive to
// the big screen (see enterBigScreen) so a tile is look-only until an
// admin deliberately selects it.
function telemetryLine(p) {
    const moveIcon = p.inVehicle ? '🚗' : '🚶';
    const speed = (p.speed ?? 0).toFixed(1);
    const ping = p.ping != null ? `${p.ping}ms` : '—';
    return `${moveIcon} ${speed} m/s <span class="mon-stat-sep">•</span> ${ping} ping`;
}

function updateBigScreenName() {
    const p = monitorCache.find((pl) => String(pl.id) === String(bigScreenId));
    document.getElementById('bigName').textContent = p ? `${p.name} (#${p.id})` : `#${bigScreenId}`;
}

function renderBigThumbs() {
    const wrap = document.getElementById('bigThumbs');
    const others = monitorCache.filter((p) => String(p.id) !== String(bigScreenId));
    const currentIds = new Set(others.map((p) => String(p.id)));
    wrap.querySelectorAll('.mon-thumb').forEach((t) => { if (!currentIds.has(t.dataset.id)) t.remove(); });

    others.forEach((p) => {
        let thumb = wrap.querySelector(`.mon-thumb[data-id="${p.id}"]`);
        if (!thumb) {
            thumb = document.createElement('div');
            thumb.className = 'mon-thumb';
            thumb.dataset.id = p.id;
            thumb.innerHTML = `<canvas width="90" height="60"></canvas><div class="mon-thumb-label"></div>`;
            thumb.addEventListener('click', () => switchBigScreen(p.id));
            wrap.appendChild(thumb);
        }
        thumb.querySelector('.mon-thumb-label').textContent = `${p.name} #${p.id}`;
        drawRadar(thumb.querySelector('canvas'), p, monitorHistory[p.id]);
    });
}

function handleMonitorUpdate(list) {
    monitorCache = list || [];
    monitorCache.forEach(updateHistory);

    if (bigScreenId != null) {
        const stillThere = monitorCache.some((p) => String(p.id) === String(bigScreenId));
        if (!stillThere) {
            toast('Target disconnected — returning to grid.');
            exitBigScreen();
            return;
        }
        updateBigScreenName();
        renderBigThumbs();
    } else {
        renderMonitorGrid(monitorCache);
    }
}

function enterBigScreen(id) {
    bigScreenId = id;
    document.getElementById('monitorGrid').classList.add('hidden');
    document.getElementById('monitorBigScreen').classList.remove('hidden');
    document.body.classList.add('big-screen-active');
    updateBigScreenName();
    renderBigThumbs();
    post('startBigScreen', { targetId: id });
}

function switchBigScreen(id) {
    bigScreenId = id;
    updateBigScreenName();
    renderBigThumbs();
    post('startBigScreen', { targetId: id }); // hd_admin's own spectate handler ends the previous target before starting this one
}

function exitBigScreen() {
    if (bigScreenId == null) return;
    post('stopBigScreen');
    bigScreenId = null;
    document.body.classList.remove('big-screen-active');
    document.getElementById('monitorBigScreen').classList.add('hidden');
    document.getElementById('monitorGrid').classList.remove('hidden');
}

document.getElementById('bigBack').addEventListener('click', exitBigScreen);

document.getElementById('bigTeleport').addEventListener('click', () => {
    if (bigScreenId != null) post('teleportTo', { args: [bigScreenId] });
});

document.getElementById('bigKick').addEventListener('click', () => {
    if (bigScreenId == null) return;
    const reason = document.getElementById('bigReason').value.trim() || 'No reason given';
    post('kick', { args: [bigScreenId, reason] });
});

document.getElementById('bigBan').addEventListener('click', () => {
    if (bigScreenId == null) return;
    const reason = document.getElementById('bigReason').value.trim();
    if (!reason) { toast('Enter a ban reason.'); return; }
    post('manualBan', { targetId: bigScreenId, reason });
});

// ═══════════════════════════ REPORTS ═════════════════════════════════════
function renderReports() {
    const tbody = document.querySelector('#reportsTable tbody');
    tbody.innerHTML = '';

    if (reportsCache.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="6">No reports.</td></tr>';
        return;
    }

    reportsCache.forEach((r) => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${escapeHtml(r.name)}</td>
            <td>${escapeHtml(r.title || '')}</td>
            <td>${escapeHtml(r.message)}</td>
            <td class="${r.status === 'open' ? 'result-flagged' : ''}">${escapeHtml(r.status)}</td>
            <td>${formatTime(r.at)}</td>
            <td class="report-actions"></td>
        `;
        const actionsTd = tr.querySelector('.report-actions');

        const tpBtn = document.createElement('button');
        tpBtn.className = 'btn btn-sm';
        tpBtn.textContent = 'Teleport';
        tpBtn.addEventListener('click', () => post('teleportToCoords', { args: [r.x, r.y, r.z] }));
        actionsTd.appendChild(tpBtn);

        if (r.status === 'open') {
            const resBtn = document.createElement('button');
            resBtn.className = 'btn btn-sm';
            resBtn.textContent = 'Resolve';
            resBtn.addEventListener('click', () => post('resolveReport', { args: [r.id] }));
            actionsTd.appendChild(resBtn);
        }

        tbody.appendChild(tr);
    });
}

// ═══════════════════════════ DUTY + ADMIN CHAT ═══════════════════════════
function applyDutyState(state) {
    onDuty = state === true;
    const btn = document.getElementById('dutyToggle');
    btn.textContent = onDuty ? 'Duty: ON' : 'Duty: OFF';
    btn.classList.toggle('duty-on', onDuty);
    btn.classList.toggle('duty-off', !onDuty);

    document.querySelectorAll('.duty-only').forEach((el) => el.classList.toggle('hidden', !onDuty));
    document.getElementById('chatOffNotice').classList.toggle('hidden', onDuty);
    document.getElementById('chatBody').classList.toggle('hidden', !onDuty);

    if (onDuty) {
        post('getChat');
    } else {
        const chatBtn = document.querySelector('.tab-btn[data-tab="chat"]');
        if (chatBtn.classList.contains('active')) document.querySelector('.tab-btn[data-tab="overview"]').click();
    }
}

document.getElementById('dutyToggle').addEventListener('click', () => post('toggleDuty'));

function renderChat() {
    const log = document.getElementById('chatLog');
    if (chatCache.length === 0) {
        log.innerHTML = '<div class="empty-row">No messages yet.</div>';
        return;
    }
    log.innerHTML = chatCache.slice().reverse().map((m) => `
        <div class="chat-msg">
            <span class="chat-name">${escapeHtml(m.name)}</span>
            <span class="chat-time">${formatTime(m.at)}</span>
            <div class="chat-text">${escapeHtml(m.message)}</div>
        </div>
    `).join('');
    log.scrollTop = log.scrollHeight;
}

function sendChat() {
    const input = document.getElementById('chatInput');
    const msg = input.value.trim();
    if (!msg) return;
    post('sendChat', { args: [msg] });
    input.value = '';
}

document.getElementById('btnChatSend').addEventListener('click', sendChat);
document.getElementById('chatInput').addEventListener('keyup', (e) => {
    if (e.key === 'Enter') sendChat();
});
