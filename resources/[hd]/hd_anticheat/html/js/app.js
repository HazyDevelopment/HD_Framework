// ═══════════════════════════════════════════════════════════════════
//  HD ANTICHEAT | NUI
//  Pure display + a couple of manual actions — every real decision
//  (who's flagged, who's banned) happens server-side in
//  server/detection.lua and server/main.lua, never here.
// ═══════════════════════════════════════════════════════════════════

const app = document.getElementById('app');
let selectedPlayer = null;
let flagsCache = [];

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

// ═══════════════════════════ OPEN / CLOSE ═════════════════════════════
function openPanel() { app.classList.remove('hidden'); }
function closePanel() { app.classList.add('hidden'); post('close'); }

document.getElementById('closeBtn').addEventListener('click', closePanel);
document.addEventListener('keyup', (e) => {
    if (e.key === 'Escape' && !app.classList.contains('hidden')) closePanel();
});

// ═══════════════════════════ TABS ═════════════════════════════════════
document.querySelectorAll('.tab-btn[data-tab]').forEach((btn) => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.tab-btn[data-tab]').forEach((b) => b.classList.remove('active'));
        document.querySelectorAll('.tab-panel').forEach((p) => p.classList.remove('active'));
        btn.classList.add('active');
        document.getElementById(`tab-${btn.dataset.tab}`).classList.add('active');
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
