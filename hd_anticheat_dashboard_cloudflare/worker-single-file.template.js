// ═══════════════════════════════════════════════════════════════════
//  HD ANTICHEAT DASHBOARD — single-file Cloudflare Worker
//  Paste this ENTIRE file into the Cloudflare dashboard's Worker code
//  editor (Workers & Pages -> your worker -> Edit Code). No npm
//  install, no wrangler, no build step — everything (crypto, routing,
//  and the static frontend as base64) is self-contained in this one
//  file. This is a generated artifact for that manual-paste path only
//  — the real source of truth is the modular src/ + public/ files
//  alongside this one; regenerate this file from those instead of
//  hand-editing it directly if anything changes.
//
//  Required bindings — Settings -> Bindings on this Worker:
//    D1 database    binding name: DB           -> hd-anticheat-dashboard
//    R2 bucket      binding name: SCREENSHOTS  -> hd-anticheat-screenshots
//  Required variables/secrets — Settings -> Variables and Secrets:
//    APP_PUBLIC_URL      (plain text) e.g. https://fivem-panel.co.uk
//    AUTH_SESSION_SECRET (secret) long random string
//    UPLOAD_JWT_SECRET   (secret) long random string
//    ADMIN_SECRET        (secret, optional)
//  (Renamed from PUBLIC_URL/SESSION_JWT_SECRET after those two specific
//  names got stuck not binding correctly across several delete/re-add
//  cycles in the Cloudflare dashboard — UPLOAD_JWT_SECRET, added only
//  once, worked every time. New names sidestep whatever that was rather
//  than chase it further.)
// ═══════════════════════════════════════════════════════════════════

// ── Static frontend, base64-encoded to sidestep any quoting/escaping
// issues with the HTML/CSS/JS content (some of it uses backticks and
// ${...} itself, which would collide with embedding it in a template
// literal here). Decoded once per request via b64ToBytes below.
const ASSETS = {
    '/index.html': { b64: '__INDEX_HTML_B64__', type: 'text/html;charset=utf-8' },
    '/dashboard.html': { b64: '__DASHBOARD_HTML_B64__', type: 'text/html;charset=utf-8' },
    '/css/style.css': { b64: '__STYLE_CSS_B64__', type: 'text/css;charset=utf-8' },
    '/js/login.js': { b64: '__LOGIN_JS_B64__', type: 'application/javascript;charset=utf-8' },
    '/js/dashboard.js': { b64: '__DASHBOARD_JS_B64__', type: 'application/javascript;charset=utf-8' },
    '/favicon.png': { b64: '__FAVICON_PNG_B64__', type: 'image/png' },
    '/favicon.ico': { b64: '__FAVICON_ICO_B64__', type: 'image/x-icon' },
};

function b64ToBytes(b64) {
    const bin = atob(b64);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return bytes;
}

function json(data, status = 200) {
    // no-store on every API response — nothing here should ever be
    // cached by the browser or Cloudflare's edge, and the debug route's
    // identical output across multiple real backend changes strongly
    // suggests a stale cached copy was being served this whole time.
    return new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store, no-cache, must-revalidate' } });
}

// ── lib/crypto.js, inlined ──────────────────────────────────────────
const KEY_CHARSET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
// Cloudflare Workers' PBKDF2 implementation caps out at 100,000
// iterations — crypto.subtle.deriveBits throws above that here, unlike
// Node/browsers which allow much higher counts. This is the max this
// runtime actually supports, not an arbitrary choice.
const PBKDF2_ITERATIONS = 100000;

function randomSegment(len) {
    const bytes = crypto.getRandomValues(new Uint8Array(len));
    let out = '';
    for (let i = 0; i < len; i++) out += KEY_CHARSET[bytes[i] % KEY_CHARSET.length];
    return out;
}
function generateLicenseKey() {
    return `HDAC-${randomSegment(4)}-${randomSegment(4)}-${randomSegment(4)}-${randomSegment(4)}`;
}
function generateSecret() {
    return base64UrlEncode(crypto.getRandomValues(new Uint8Array(24)));
}
function base64UrlEncode(bytes) {
    let bin = '';
    for (const b of bytes) bin += String.fromCharCode(b);
    return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function base64UrlDecode(str) {
    str = str.replace(/-/g, '+').replace(/_/g, '/');
    while (str.length % 4) str += '=';
    const bin = atob(str);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return bytes;
}
async function pbkdf2(secret, salt, iterations) {
    const keyMaterial = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), 'PBKDF2', false, ['deriveBits']);
    const bits = await crypto.subtle.deriveBits({ name: 'PBKDF2', salt, iterations, hash: 'SHA-256' }, keyMaterial, 256);
    return new Uint8Array(bits);
}
async function hashSecret(secret) {
    const salt = crypto.getRandomValues(new Uint8Array(16));
    const hash = await pbkdf2(secret, salt, PBKDF2_ITERATIONS);
    return `pbkdf2$${PBKDF2_ITERATIONS}$${base64UrlEncode(salt)}$${base64UrlEncode(hash)}`;
}
async function verifySecret(secret, stored) {
    const parts = (stored || '').split('$');
    if (parts.length !== 4 || parts[0] !== 'pbkdf2') return false;
    const iterations = parseInt(parts[1], 10);
    const salt = base64UrlDecode(parts[2]);
    const expected = base64UrlDecode(parts[3]);
    const actual = await pbkdf2(secret, salt, iterations);
    if (actual.length !== expected.length) return false;
    let diff = 0;
    for (let i = 0; i < actual.length; i++) diff |= actual[i] ^ expected[i];
    return diff === 0;
}

// ── lib/jwt.js, inlined ─────────────────────────────────────────────
function b64urlFromBytes(bytes) { return base64UrlEncode(bytes); }
function b64urlToBytes(str) { return base64UrlDecode(str); }
function b64urlFromString(str) { return b64urlFromBytes(new TextEncoder().encode(str)); }
function b64urlToString(str) { return new TextDecoder().decode(b64urlToBytes(str)); }

async function hmacKey(secret) {
    return crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']);
}
async function jwtSign(payload, secret, expiresInSeconds) {
    const header = { alg: 'HS256', typ: 'JWT' };
    const now = Math.floor(Date.now() / 1000);
    const body = { ...payload, iat: now, exp: now + expiresInSeconds };
    const signingInput = `${b64urlFromString(JSON.stringify(header))}.${b64urlFromString(JSON.stringify(body))}`;
    const key = await hmacKey(secret);
    const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(signingInput));
    return `${signingInput}.${b64urlFromBytes(new Uint8Array(sig))}`;
}
async function jwtVerify(token, secret) {
    const parts = (token || '').split('.');
    if (parts.length !== 3) return null;
    const [h, p, s] = parts;
    const key = await hmacKey(secret);
    const valid = await crypto.subtle.verify('HMAC', key, b64urlToBytes(s), new TextEncoder().encode(`${h}.${p}`));
    if (!valid) return null;
    let payload;
    try { payload = JSON.parse(b64urlToString(p)); } catch { return null; }
    if (payload.exp && Math.floor(Date.now() / 1000) > payload.exp) return null;
    return payload;
}
async function signSession(licenseKey, secret) { return jwtSign({ lk: licenseKey }, secret, 12 * 3600); }
async function verifySession(token, secret) { const p = await jwtVerify(token, secret); return p ? p.lk : null; }
async function signUploadToken(licenseKey, banToken, secret) { return jwtSign({ lk: licenseKey, bt: banToken }, secret, 90); }
async function verifyUploadToken(token, licenseKey, banToken, secret) {
    const p = await jwtVerify(token, secret);
    return !!p && p.lk === licenseKey && p.bt === banToken;
}

// ── lib/discord.js, inlined ─────────────────────────────────────────
const KIND_LABELS = {
    speedHack: 'Speed Hack', teleportHack: 'Teleport Hack', invincibility: 'Invincibility',
    injection: 'Injection / Mod Menu', manual: 'Manual Ban',
};
function buildEmbeds(ban, webhookCfg, screenshotUrls) {
    const fields = [];
    if (ban.reason) fields.push({ name: 'Reason', value: ban.reason.slice(0, 1024) });
    if (webhookCfg.include_cfx && (ban.cfx_name || ban.cfx_id)) {
        fields.push({ name: 'Cfx.re Account', value: [ban.cfx_name, ban.cfx_id ? `ID: ${ban.cfx_id}` : null].filter(Boolean).join('\n') || 'Unknown', inline: true });
    }
    if (webhookCfg.include_steam) fields.push({ name: 'Steam ID', value: ban.steam_id || 'Steam not running', inline: true });
    if (webhookCfg.include_discord) {
        fields.push({ name: 'Discord', value: ban.discord_name ? `${ban.discord_name} (${ban.discord_id})` : (ban.discord_id ? `ID: ${ban.discord_id}` : 'Discord not running'), inline: true });
    }
    const groupAnchor = `https://hd-anticheat.invalid/bans/${ban.id || Date.now()}`;
    const main = {
        title: `Player Banned — ${KIND_LABELS[ban.kind] || ban.kind || 'Unknown'}`,
        url: groupAnchor,
        description: `**${ban.player_name || 'Unknown player'}**`,
        color: webhookCfg.embed_color,
        fields,
        timestamp: new Date().toISOString(),
        footer: { text: 'HD AntiCheat' },
    };
    const embeds = [main];
    const shots = webhookCfg.include_screenshots ? (screenshotUrls || []) : [];
    for (const url of shots.slice(0, 4)) embeds.push({ url: groupAnchor, image: { url } });
    return embeds;
}
async function postBanToDiscord(ban, webhookCfg, screenshotUrls) {
    if (!webhookCfg || !webhookCfg.discord_webhook_url) return { skipped: true };
    const embeds = buildEmbeds(ban, webhookCfg, screenshotUrls);
    const res = await fetch(webhookCfg.discord_webhook_url, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ embeds }),
    });
    if (!res.ok) {
        const text = await res.text().catch(() => '');
        throw new Error(`Discord webhook returned ${res.status}: ${text.slice(0, 300)}`);
    }
    return { skipped: false };
}

// ── auth helpers ─────────────────────────────────────────────────────
function randomHex(n) {
    const bytes = crypto.getRandomValues(new Uint8Array(n));
    return Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function requireBrowserAuth(request, env) {
    const header = request.headers.get('Authorization') || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    const licenseKey = token && (await verifySession(token, env.AUTH_SESSION_SECRET));
    if (!licenseKey) return { error: json({ error: 'Not logged in.' }, 401) };
    const license = await env.DB.prepare('SELECT * FROM licenses WHERE license_key = ? AND active = 1').bind(licenseKey).first();
    if (!license) return { error: json({ error: 'License no longer active.' }, 401) };
    return { licenseKey };
}
async function requireServerAuth(request, env) {
    const licenseKey = request.headers.get('X-License-Key');
    const secret = request.headers.get('X-License-Secret');
    if (!licenseKey || !secret) return { error: json({ error: 'Missing license credentials.' }, 401) };
    const license = await env.DB.prepare('SELECT * FROM licenses WHERE license_key = ? AND active = 1').bind(licenseKey).first();
    if (!license || !(await verifySecret(secret, license.secret_hash))) return { error: json({ error: 'Invalid license credentials.' }, 401) };
    return { licenseKey };
}

// ── config ────────────────────────────────────────────────────────────
const CONFIG_FIELDS = [
    'check_interval_ms', 'spawn_grace_ms', 'max_on_foot_speed', 'teleport_distance',
    'damage_check_delay_ms', 'ban_threshold', 'score_decay_per_minute',
    'points_speed_hack', 'points_teleport_hack', 'points_invincibility', 'ban_message',
];
async function getConfig(db, licenseKey) {
    const row = await db.prepare('SELECT * FROM configs WHERE license_key = ?').bind(licenseKey).first();
    return row || { license_key: licenseKey };
}
async function saveConfig(db, licenseKey, body) {
    const existing = await db.prepare('SELECT license_key FROM configs WHERE license_key = ?').bind(licenseKey).first();
    const values = CONFIG_FIELDS.map((f) => (body[f] === undefined || body[f] === '' ? null : body[f]));
    if (existing) {
        const sets = CONFIG_FIELDS.map((f) => `${f} = ?`).join(', ');
        await db.prepare(`UPDATE configs SET ${sets}, updated_at = datetime('now') WHERE license_key = ?`).bind(...values, licenseKey).run();
    } else {
        await db.prepare(`INSERT INTO configs (license_key, ${CONFIG_FIELDS.join(', ')}) VALUES (?, ${CONFIG_FIELDS.map(() => '?').join(', ')})`).bind(licenseKey, ...values).run();
    }
    return getConfig(db, licenseKey);
}

// ── webhook ───────────────────────────────────────────────────────────
async function getWebhook(db, licenseKey) {
    const row = await db.prepare('SELECT * FROM webhooks WHERE license_key = ?').bind(licenseKey).first();
    return row || { license_key: licenseKey, discord_webhook_url: '', embed_color: 15548997, include_steam: 1, include_discord: 1, include_cfx: 1, include_screenshots: 1 };
}
async function saveWebhook(db, licenseKey, b) {
    const existing = await db.prepare('SELECT license_key FROM webhooks WHERE license_key = ?').bind(licenseKey).first();
    const params = [
        (b.discord_webhook_url || '').trim(),
        Number.isFinite(+b.embed_color) ? +b.embed_color : 15548997,
        b.include_steam ? 1 : 0, b.include_discord ? 1 : 0, b.include_cfx ? 1 : 0, b.include_screenshots ? 1 : 0,
    ];
    if (existing) {
        await db.prepare(`UPDATE webhooks SET discord_webhook_url = ?, embed_color = ?, include_steam = ?, include_discord = ?, include_cfx = ?, include_screenshots = ?, updated_at = datetime('now') WHERE license_key = ?`).bind(...params, licenseKey).run();
    } else {
        await db.prepare(`INSERT INTO webhooks (license_key, discord_webhook_url, embed_color, include_steam, include_discord, include_cfx, include_screenshots) VALUES (?, ?, ?, ?, ?, ?, ?)`).bind(licenseKey, ...params).run();
    }
    return getWebhook(db, licenseKey);
}

// ── main dispatcher ──────────────────────────────────────────────────
export default {
    async fetch(request, env, ctx) {
        const url = new URL(request.url);
        const path = url.pathname;
        const method = request.method;

        try {
            // ═══ /api/auth/login ═══
            if (path === '/api/auth/login' && method === 'POST') {
                const body = await request.json().catch(() => ({}));
                const { licenseKey, secret } = body;
                if (!licenseKey || !secret) return json({ error: 'License key and secret are required.' }, 400);
                const license = await env.DB.prepare('SELECT * FROM licenses WHERE license_key = ?').bind(licenseKey.trim().toUpperCase()).first();
                if (!license || !license.active || !(await verifySecret(secret, license.secret_hash))) return json({ error: 'Invalid license key or secret.' }, 401);
                return json({ token: await signSession(license.license_key, env.AUTH_SESSION_SECRET) });
            }

            // ═══ /api/config ═══
            if (path === '/api/config' && method === 'GET') {
                const auth = await requireBrowserAuth(request, env); if (auth.error) return auth.error;
                return json(await getConfig(env.DB, auth.licenseKey));
            }
            if (path === '/api/config' && method === 'PUT') {
                const auth = await requireBrowserAuth(request, env); if (auth.error) return auth.error;
                const body = await request.json().catch(() => ({}));
                return json(await saveConfig(env.DB, auth.licenseKey, body));
            }
            if (path === '/api/server/config' && method === 'GET') {
                const auth = await requireServerAuth(request, env); if (auth.error) return auth.error;
                return json(await getConfig(env.DB, auth.licenseKey));
            }

            // ═══ /api/webhook ═══
            if (path === '/api/webhook' && method === 'GET') {
                const auth = await requireBrowserAuth(request, env); if (auth.error) return auth.error;
                return json(await getWebhook(env.DB, auth.licenseKey));
            }
            if (path === '/api/webhook' && method === 'PUT') {
                const auth = await requireBrowserAuth(request, env); if (auth.error) return auth.error;
                const b = await request.json().catch(() => ({}));
                const url2 = (b.discord_webhook_url || '').trim();
                if (url2 && !/^https:\/\/(discord|discordapp)\.com\/api\/webhooks\//.test(url2)) {
                    return json({ error: "That doesn't look like a Discord webhook URL (expected https://discord.com/api/webhooks/...)." }, 400);
                }
                return json(await saveWebhook(env.DB, auth.licenseKey, b));
            }
            if (path === '/api/webhook/test' && method === 'POST') {
                const auth = await requireBrowserAuth(request, env); if (auth.error) return auth.error;
                const b = await request.json().catch(() => ({}));
                const testUrl = (b.discord_webhook_url || '').trim();
                if (!testUrl) return json({ error: 'Enter a webhook URL first.' }, 400);
                const fakeBan = {
                    id: 0, player_name: 'Test Player', kind: 'injection',
                    reason: 'This is a test post from the HD AntiCheat dashboard — no real ban occurred.',
                    steam_id: '76561198000000000', discord_id: '123456789012345678', discord_name: 'testuser',
                    cfx_id: '1234567', cfx_name: 'TestPlayer',
                };
                try {
                    await postBanToDiscord(fakeBan, {
                        discord_webhook_url: testUrl,
                        embed_color: Number.isFinite(+b.embed_color) ? +b.embed_color : 15548997,
                        include_steam: b.include_steam ? 1 : 0, include_discord: b.include_discord ? 1 : 0,
                        include_cfx: b.include_cfx ? 1 : 0, include_screenshots: false,
                    }, []);
                    return json({ ok: true });
                } catch (err) {
                    return json({ error: err.message }, 400);
                }
            }
            if (path === '/api/server/webhook-flags' && method === 'GET') {
                const auth = await requireServerAuth(request, env); if (auth.error) return auth.error;
                const w = await getWebhook(env.DB, auth.licenseKey);
                return json({ include_screenshots: !!w.include_screenshots, configured: !!w.discord_webhook_url });
            }

            // ═══ /api/bans ═══
            if (path === '/api/bans' && method === 'GET') {
                const auth = await requireBrowserAuth(request, env); if (auth.error) return auth.error;
                const { results: rows } = await env.DB.prepare(
                    'SELECT id, player_name, kind, reason, steam_id, discord_id, discord_name, cfx_id, cfx_name, ban_token, created_at FROM bans WHERE license_key = ? ORDER BY id DESC LIMIT 100'
                ).bind(auth.licenseKey).all();
                for (const row of rows) {
                    if (row.ban_token) {
                        const { results: shots } = await env.DB.prepare('SELECT url FROM ban_screenshots WHERE license_key = ? AND ban_token = ? ORDER BY id').bind(auth.licenseKey, row.ban_token).all();
                        row.screenshots = shots.map((s) => s.url);
                    } else row.screenshots = [];
                }
                return json(rows);
            }
            if (path === '/api/server/uploads/session' && method === 'POST') {
                const auth = await requireServerAuth(request, env); if (auth.error) return auth.error;
                const banToken = randomHex(12);
                const token = await signUploadToken(auth.licenseKey, banToken, env.UPLOAD_JWT_SECRET);
                const uploadUrl = `${env.APP_PUBLIC_URL}/api/uploads/${auth.licenseKey}/${banToken}?token=${token}`;
                return json({ banToken, uploadUrl });
            }
            if (path === '/api/server/bans' && method === 'POST') {
                const auth = await requireServerAuth(request, env); if (auth.error) return auth.error;
                const b = await request.json().catch(() => ({}));
                const info = await env.DB.prepare(
                    `INSERT INTO bans (license_key, player_name, kind, reason, steam_id, discord_id, discord_name, cfx_id, cfx_name, ban_token) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
                ).bind(
                    auth.licenseKey, String(b.playerName || '').slice(0, 100), String(b.kind || '').slice(0, 40), String(b.reason || '').slice(0, 500),
                    b.steamId || null, b.discordId || null, b.discordName || null, b.cfxId || null, b.cfxName || null, b.banToken || null
                ).run();
                const banId = info.meta.last_row_id;
                const ban = await env.DB.prepare('SELECT * FROM bans WHERE id = ?').bind(banId).first();
                const webhookCfg = await env.DB.prepare('SELECT * FROM webhooks WHERE license_key = ?').bind(auth.licenseKey).first();
                let screenshots = [];
                if (ban.ban_token) {
                    const { results } = await env.DB.prepare('SELECT url FROM ban_screenshots WHERE license_key = ? AND ban_token = ? ORDER BY id').bind(auth.licenseKey, ban.ban_token).all();
                    screenshots = results.map((s) => s.url);
                }
                let discordResult = { skipped: true };
                try { discordResult = await postBanToDiscord(ban, webhookCfg, screenshots); } catch (err) { console.error('Discord webhook failed:', err.message); }
                return json({ ok: true, banId, discordPosted: !discordResult.skipped });
            }

            // ═══ /api/uploads/:licenseKey/:banToken ═══ (screenshot-basic uploads here)
            const uploadMatch = path.match(/^\/api\/uploads\/([^/]+)\/([^/]+)$/);
            if (uploadMatch && method === 'POST') {
                const [, licenseKey, banToken] = uploadMatch;
                const token = url.searchParams.get('token');
                if (!/^HDAC-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/.test(licenseKey) || !/^[a-f0-9]{24}$/.test(banToken)) {
                    return json({ error: 'Malformed license or ban token.' }, 400);
                }
                if (!token || !(await verifyUploadToken(token, licenseKey, banToken, env.UPLOAD_JWT_SECRET))) return json({ error: 'Invalid or expired upload token.' }, 401);
                const formData = await request.formData();
                const file = formData.get('file');
                if (!file || typeof file === 'string') return json({ error: 'No file uploaded.' }, 400);
                if (file.size > 8 * 1024 * 1024) return json({ error: 'File too large.' }, 400);
                const key = `${licenseKey}/${banToken}-${randomHex(4)}.jpg`;
                await env.SCREENSHOTS.put(key, await file.arrayBuffer(), { httpMetadata: { contentType: 'image/jpeg' } });
                const fileUrl = `${env.APP_PUBLIC_URL}/uploads/${key}`;
                await env.DB.prepare('INSERT INTO ban_screenshots (license_key, ban_token, url) VALUES (?, ?, ?)').bind(licenseKey, banToken, fileUrl).run();
                return json({ url: fileUrl });
            }

            // ═══ /api/admin/licenses ═══ (only reachable if ADMIN_SECRET is set)
            if (path === '/api/admin/licenses' && method === 'POST') {
                const configured = env.ADMIN_SECRET;
                if (!configured) return new Response('Not found', { status: 404 });
                if (request.headers.get('X-Admin-Secret') !== configured) return json({ error: 'Unauthorized.' }, 401);
                const body = await request.json().catch(() => ({}));
                const ownerLabel = String(body.ownerLabel || '').slice(0, 200);
                let licenseKey, attempts = 0;
                do { licenseKey = generateLicenseKey(); attempts++; }
                while (attempts < 5 && await env.DB.prepare('SELECT 1 FROM licenses WHERE license_key = ?').bind(licenseKey).first());
                const secret = generateSecret();
                await env.DB.prepare('INSERT INTO licenses (license_key, secret_hash, owner_label) VALUES (?, ?, ?)').bind(licenseKey, await hashSecret(secret), ownerLabel).run();
                return json({ licenseKey, secret });
            }

            // ═══ /uploads/* — serves ban-evidence screenshots out of R2 ═══
            if (path.startsWith('/uploads/')) {
                const key = path.replace(/^\/uploads\//, '');
                const obj = await env.SCREENSHOTS.get(key);
                if (!obj) return new Response('Not found', { status: 404 });
                return new Response(obj.body, { headers: { 'Content-Type': obj.httpMetadata?.contentType || 'image/jpeg', 'Cache-Control': 'public, max-age=31536000, immutable' } });
            }

            // ═══ static frontend ═══
            const assetPath = path === '/' ? '/index.html' : path;
            const asset = ASSETS[assetPath];
            if (asset) return new Response(b64ToBytes(asset.b64), { headers: { 'Content-Type': asset.type } });

            return new Response('Not found', { status: 404 });
        } catch (err) {
            return json({ error: 'Internal error: ' + err.message }, 500);
        }
    },
};
