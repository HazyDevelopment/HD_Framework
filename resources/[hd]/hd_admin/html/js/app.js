// ═══════════════════════════════════════════════════════════════════
//  HD ADMIN | NUI
//  Every button here just relays to a server event that re-checks
//  IsAdmin itself — this UI has no authority of its own, it's just a
//  thin front end for hd_admin/server/*.lua.
// ═══════════════════════════════════════════════════════════════════

const app = document.getElementById('app');
let options = { jobs: [], items: [], weather: [] };
let selectedPlayer = null;
let noclipOn = false;
let godmodeOn = false;

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

// ═══════════════════════════ OPEN / CLOSE ═════════════════════════════
function openPanel() {
    app.classList.remove('hidden');
}

function closePanel() {
    app.classList.add('hidden');
    post('close');
}

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
        if (btn.dataset.tab === 'bans') post('getBans');
    });
});

// ═══════════════════════════ MESSAGES FROM CLIENT ═════════════════════
window.addEventListener('message', (event) => {
    const data = event.data;
    switch (data.action) {
        case 'open': openPanel(); break;
        case 'players': renderPlayers(data.list); break;
        case 'options': cacheOptions(data.opts); break;
        case 'bans': renderBans(data.list); break;
        case 'announce': toast(`[Announcement] ${data.message}`); break;
    }
});

// ═══════════════════════════ PLAYERS ═══════════════════════════════════
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
            <td>${escapeHtml(p.name)}</td>
            <td>${escapeHtml(p.citizenid || '')}</td>
            <td>${escapeHtml(p.job || '')}</td>
            <td>${p.ping}</td>
            <td><button class="btn btn-sm manage-btn">Manage</button></td>
        `;
        tr.querySelector('.manage-btn').addEventListener('click', () => selectPlayer(p));
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

document.getElementById('refreshPlayers').addEventListener('click', () => post('getPlayers'));

document.querySelectorAll('#playerActions [data-act]').forEach((btn) => {
    btn.addEventListener('click', () => {
        if (!selectedPlayer) return;
        const id = selectedPlayer.id;
        const act = btn.dataset.act;

        if (act === 'kick') {
            const reason = document.getElementById('kickReason').value || 'No reason given';
            post('kick', { args: [id, reason] });
        } else if (act === 'ban') {
            const reason = document.getElementById('banReason').value || 'No reason given';
            const hoursVal = document.getElementById('banDuration').value;
            post('ban', { args: [id, reason, hoursVal === '' ? null : Number(hoursVal)] });
        } else if (act === 'giveMoney') {
            const account = document.getElementById('moneyAccount').value;
            const amount = Number(document.getElementById('moneyAmount').value);
            if (!amount || amount <= 0) { toast('Enter a valid amount.'); return; }
            post('giveMoney', { args: [id, account, amount] });
        } else if (act === 'setJob') {
            const jobName = document.getElementById('jobSelect').value;
            const grade = Number(document.getElementById('jobGrade').value || 0);
            post('setJob', { args: [id, jobName, grade] });
        } else if (act === 'giveItem') {
            const itemName = document.getElementById('itemSelect').value;
            const amount = Number(document.getElementById('itemAmount').value || 1);
            post('giveItem', { args: [id, itemName, amount] });
        } else {
            // teleportTo / bringHere / heal / toggleFreeze — all take just the target id
            post(act, { args: [id] });
        }
    });
});

// ═══════════════════════════ OPTIONS (jobs/items/weather) ══════════════
function cacheOptions(opts) {
    options = opts || { jobs: [], items: [], weather: [] };

    const jobSelect = document.getElementById('jobSelect');
    jobSelect.innerHTML = options.jobs.map((j) => `<option value="${j.name}">${escapeHtml(j.label)}</option>`).join('');
    jobSelect.addEventListener('change', populateGrades);
    populateGrades();

    const itemSelect = document.getElementById('itemSelect');
    itemSelect.innerHTML = options.items.map((i) => `<option value="${i.name}">${escapeHtml(i.label)}</option>`).join('');

    const weatherSelect = document.getElementById('weatherSelect');
    weatherSelect.innerHTML = options.weather.map((w) => `<option value="${w}">${w}</option>`).join('');
}

function populateGrades() {
    const jobName = document.getElementById('jobSelect').value;
    const job = options.jobs.find((j) => j.name === jobName);
    const gradeSelect = document.getElementById('jobGrade');
    if (!job || !job.grades) { gradeSelect.innerHTML = '<option value="0">0</option>'; return; }
    gradeSelect.innerHTML = Object.keys(job.grades)
        .map((g) => `<option value="${g}">${escapeHtml(job.grades[g].name || g)}</option>`)
        .join('');
}

// ═══════════════════════════ WORLD ═════════════════════════════════════
document.getElementById('applyWeather').addEventListener('click', () => {
    post('setWeather', { args: [document.getElementById('weatherSelect').value] });
});

document.getElementById('applyTime').addEventListener('click', () => {
    const hour = Number(document.getElementById('timeHour').value);
    if (Number.isNaN(hour) || hour < 0 || hour > 23) { toast('Hour must be 0-23.'); return; }
    post('setTime', { args: [hour] });
});

document.getElementById('sendAnnounce').addEventListener('click', () => {
    const input = document.getElementById('announceMsg');
    const msg = input.value.trim();
    if (!msg) return;
    post('announce', { args: [msg] });
    input.value = '';
});

// ═══════════════════════════ BANS ══════════════════════════════════════
function renderBans(list) {
    const tbody = document.querySelector('#bansTable tbody');
    tbody.innerHTML = '';

    if (!list || list.length === 0) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="5">No active bans.</td></tr>';
        return;
    }

    list.forEach((b) => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${escapeHtml(b.name)}</td>
            <td>${escapeHtml(b.reason)}</td>
            <td>${escapeHtml(b.banned_by)}</td>
            <td>${b.expires ? escapeHtml(b.expires) : 'Permanent'}</td>
            <td><button class="btn btn-sm btn-danger unban-btn">Unban</button></td>
        `;
        tr.querySelector('.unban-btn').addEventListener('click', () => post('unban', { args: [b.id] }));
        tbody.appendChild(tr);
    });
}

document.getElementById('refreshBans').addEventListener('click', () => post('getBans'));

// ═══════════════════════════ SELF ═══════════════════════════════════════
document.getElementById('btnNoclip').addEventListener('click', async () => {
    const res = await post('toggleNoclip');
    noclipOn = !!res.enabled;
    document.getElementById('btnNoclip').textContent = `Noclip: ${noclipOn ? 'ON' : 'OFF'}`;
    document.getElementById('btnNoclip').classList.toggle('active-state', noclipOn);
});

document.getElementById('btnGodmode').addEventListener('click', async () => {
    const res = await post('toggleGodmode');
    godmodeOn = !!res.enabled;
    document.getElementById('btnGodmode').textContent = `God Mode: ${godmodeOn ? 'ON' : 'OFF'}`;
    document.getElementById('btnGodmode').classList.toggle('active-state', godmodeOn);
});

document.getElementById('btnWaypoint').addEventListener('click', () => post('teleportWaypoint'));

document.getElementById('spawnVeh').addEventListener('click', () => {
    const model = document.getElementById('vehModel').value.trim();
    if (!model) return;
    post('spawnVehicle', { model });
});

// ═══════════════════════════ UTIL ══════════════════════════════════════
function escapeHtml(str) {
    return String(str ?? '').replace(/[&<>"']/g, (c) => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
}
