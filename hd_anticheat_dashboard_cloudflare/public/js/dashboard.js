const token = localStorage.getItem('hdac_token');
if (!token) window.location.href = 'index.html';

document.getElementById('licenseBadge').textContent = localStorage.getItem('hdac_license') || '';

// ── Plan / expiry badge ──────────────────────────────────────────────
async function loadMe() {
    const me = await api('/api/me');
    const el = document.getElementById('planBadge');
    if (me.daysRemaining === null) {
        el.textContent = `${me.planLabel} — never expires`;
        el.classList.remove('plan-warning');
    } else {
        el.textContent = `${me.planLabel} — ${me.daysRemaining} day${me.daysRemaining === 1 ? '' : 's'} left`;
        el.classList.toggle('plan-warning', me.daysRemaining <= 7);
    }

    const guildEl = document.getElementById('guildBadge');
    // Bound on the FXServer's first successful sync (server/dashboard.lua) —
    // still null the very first time a fresh license is opened here, before
    // that resource has ever started with this key/secret configured.
    guildEl.textContent = me.discordGuildId ? `Discord: ${me.discordGuildId}` : 'Discord: not linked yet';
}

const CONFIG_FIELDS = [
    'check_interval_ms', 'spawn_grace_ms', 'max_on_foot_speed', 'teleport_distance',
    'damage_check_delay_ms', 'ban_threshold', 'score_decay_per_minute',
    'points_speed_hack', 'points_teleport_hack', 'points_invincibility', 'ban_message',
];

function toast(msg) {
    const el = document.getElementById('toast');
    el.textContent = msg;
    el.classList.remove('hidden');
    setTimeout(() => el.classList.add('hidden'), 2600);
}

async function api(path, opts = {}) {
    const res = await fetch(path, {
        ...opts,
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, ...(opts.headers || {}) },
    });
    if (res.status === 401) {
        localStorage.removeItem('hdac_token');
        window.location.href = 'index.html';
        throw new Error('Session expired.');
    }
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.error || `Request failed (${res.status})`);
    return data;
}

// ── Nav ──────────────────────────────────────────────────────────────
document.querySelectorAll('.nav-btn[data-page]').forEach((btn) => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.nav-btn[data-page]').forEach((b) => b.classList.remove('active'));
        document.querySelectorAll('.page').forEach((p) => p.classList.remove('active'));
        btn.classList.add('active');
        document.getElementById(`page-${btn.dataset.page}`).classList.add('active');
    });
});

document.getElementById('logoutBtn').addEventListener('click', () => {
    localStorage.removeItem('hdac_token');
    localStorage.removeItem('hdac_license');
    window.location.href = 'index.html';
});

// ── Server Config ────────────────────────────────────────────────────
async function loadConfig() {
    const cfg = await api('/api/config');
    for (const f of CONFIG_FIELDS) {
        const el = document.getElementById(f);
        if (el && cfg[f] !== null && cfg[f] !== undefined) el.value = cfg[f];
    }
}

document.getElementById('saveConfigBtn').addEventListener('click', async () => {
    const body = {};
    for (const f of CONFIG_FIELDS) body[f] = document.getElementById(f).value;
    try {
        await api('/api/config', { method: 'PUT', body: JSON.stringify(body) });
        const msg = document.getElementById('configMsg');
        msg.textContent = 'Saved.';
        setTimeout(() => (msg.textContent = ''), 2500);
    } catch (err) {
        toast(err.message);
    }
});

// ── Webhook ──────────────────────────────────────────────────────────
function hexToDecimal(hex) {
    const clean = (hex || '').replace('#', '');
    const n = parseInt(clean, 16);
    return Number.isFinite(n) ? n : 15548997;
}
function decimalToHex(n) {
    return '#' + (Number(n) || 15548997).toString(16).padStart(6, '0');
}

async function loadWebhook() {
    const w = await api('/api/webhook');
    document.getElementById('discord_webhook_url').value = w.discord_webhook_url || '';
    document.getElementById('embed_color_hex').value = decimalToHex(w.embed_color);
    document.getElementById('include_steam').checked = !!w.include_steam;
    document.getElementById('include_discord').checked = !!w.include_discord;
    document.getElementById('include_cfx').checked = !!w.include_cfx;
    document.getElementById('include_screenshots').checked = !!w.include_screenshots;
}

function readWebhookForm() {
    return {
        discord_webhook_url: document.getElementById('discord_webhook_url').value.trim(),
        embed_color: hexToDecimal(document.getElementById('embed_color_hex').value),
        include_steam: document.getElementById('include_steam').checked,
        include_discord: document.getElementById('include_discord').checked,
        include_cfx: document.getElementById('include_cfx').checked,
        include_screenshots: document.getElementById('include_screenshots').checked,
    };
}

document.getElementById('saveWebhookBtn').addEventListener('click', async () => {
    try {
        await api('/api/webhook', { method: 'PUT', body: JSON.stringify(readWebhookForm()) });
        const msg = document.getElementById('webhookMsg');
        msg.textContent = 'Saved.';
        setTimeout(() => (msg.textContent = ''), 2500);
    } catch (err) {
        toast(err.message);
    }
});

document.getElementById('testWebhookBtn').addEventListener('click', async () => {
    try {
        await api('/api/webhook/test', { method: 'POST', body: JSON.stringify(readWebhookForm()) });
        toast('Test embed sent — check your Discord channel.');
    } catch (err) {
        toast(err.message);
    }
});

// ── Ban Log ──────────────────────────────────────────────────────────
function escapeHtml(s) {
    return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

async function loadBans() {
    const tbody = document.querySelector('#bansTable tbody');
    const bans = await api('/api/bans');
    if (!bans.length) {
        tbody.innerHTML = '<tr class="empty-row"><td colspan="5">No bans reported yet.</td></tr>';
        return;
    }
    tbody.innerHTML = bans.map((b) => {
        const identity = [
            b.cfx_name ? `Cfx: ${escapeHtml(b.cfx_name)}` : null,
            b.steam_id ? `Steam: ${escapeHtml(b.steam_id)}` : null,
            b.discord_name ? `Discord: ${escapeHtml(b.discord_name)}` : (b.discord_id ? `Discord ID: ${escapeHtml(b.discord_id)}` : null),
        ].filter(Boolean).join('<br>') || '—';
        const shots = (b.screenshots || []).length
            ? `<div class="shot-thumbs">${b.screenshots.map((u) => `<a href="${u}" target="_blank" rel="noopener"><img src="${u}" loading="lazy"></a>`).join('')}</div>`
            : '';
        const kindClass = b.kind === 'injection' ? 'kind-injection' : '';
        return `<tr>
            <td>${escapeHtml(new Date(b.created_at + 'Z').toLocaleString())}</td>
            <td>${escapeHtml(b.player_name)}</td>
            <td class="${kindClass}">${escapeHtml(b.kind)}</td>
            <td>${escapeHtml(b.reason)}${shots}</td>
            <td>${identity}</td>
        </tr>`;
    }).join('');
}

document.getElementById('refreshBansBtn').addEventListener('click', () => loadBans().catch((e) => toast(e.message)));

// ── Init ─────────────────────────────────────────────────────────────
Promise.all([loadConfig(), loadWebhook(), loadBans(), loadMe()]).catch((err) => toast(err.message));
