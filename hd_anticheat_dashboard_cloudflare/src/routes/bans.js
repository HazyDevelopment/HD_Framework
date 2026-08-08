import { Hono } from 'hono';
import { requireBrowserAuth, requireServerAuth } from '../middleware/auth.js';
import { signUploadToken } from '../lib/jwt.js';
import { postBanToDiscord } from '../lib/discord.js';

const router = new Hono();

function randomHex(n) {
    const bytes = crypto.getRandomValues(new Uint8Array(n));
    return Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join('');
}

// ── Browser (dashboard ban log) ─────────────────────────────────────
router.get('/bans', requireBrowserAuth, async (c) => {
    const licenseKey = c.get('licenseKey');
    const { results: rows } = await c.env.DB.prepare(
        'SELECT id, player_name, kind, reason, steam_id, discord_id, discord_name, cfx_id, cfx_name, ban_token, created_at FROM bans WHERE license_key = ? ORDER BY id DESC LIMIT 100'
    ).bind(licenseKey).all();

    for (const row of rows) {
        if (row.ban_token) {
            const { results: shots } = await c.env.DB.prepare(
                'SELECT url FROM ban_screenshots WHERE license_key = ? AND ban_token = ? ORDER BY id'
            ).bind(licenseKey, row.ban_token).all();
            row.screenshots = shots.map((s) => s.url);
        } else {
            row.screenshots = [];
        }
    }
    return c.json(rows);
});

// ── Server: mint a one-time, scoped token before asking the client to
// upload a screenshot burst. Called once per injection-tripwire event,
// BEFORE the FXServer triggers the client-side capture.
router.post('/server/uploads/session', requireServerAuth, async (c) => {
    const licenseKey = c.get('licenseKey');
    const banToken = randomHex(12);
    const token = await signUploadToken(licenseKey, banToken, c.env.UPLOAD_JWT_SECRET);
    const uploadUrl = `${c.env.PUBLIC_URL}/api/uploads/${licenseKey}/${banToken}?token=${token}`;
    return c.json({ banToken, uploadUrl });
});

// ── Server: report a ban. If banToken is supplied and screenshots were
// uploaded for it, they're pulled in and forwarded to Discord alongside
// the identity fields. Discord posting failures don't fail the request.
router.post('/server/bans', requireServerAuth, async (c) => {
    const licenseKey = c.get('licenseKey');
    const b = await c.req.json().catch(() => ({}));

    const info = await c.env.DB.prepare(
        `INSERT INTO bans (license_key, player_name, kind, reason, steam_id, discord_id, discord_name, cfx_id, cfx_name, ban_token)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(
        licenseKey,
        String(b.playerName || '').slice(0, 100),
        String(b.kind || '').slice(0, 40),
        String(b.reason || '').slice(0, 500),
        b.steamId || null,
        b.discordId || null,
        b.discordName || null,
        b.cfxId || null,
        b.cfxName || null,
        b.banToken || null
    ).run();

    const banId = info.meta.last_row_id;
    const ban = await c.env.DB.prepare('SELECT * FROM bans WHERE id = ?').bind(banId).first();
    const webhookCfg = await c.env.DB.prepare('SELECT * FROM webhooks WHERE license_key = ?').bind(licenseKey).first();

    let screenshots = [];
    if (ban.ban_token) {
        const { results } = await c.env.DB.prepare(
            'SELECT url FROM ban_screenshots WHERE license_key = ? AND ban_token = ? ORDER BY id'
        ).bind(licenseKey, ban.ban_token).all();
        screenshots = results.map((s) => s.url);
    }

    let discordResult = { skipped: true };
    try {
        discordResult = await postBanToDiscord(ban, webhookCfg, screenshots);
    } catch (err) {
        console.error(`[hd_anticheat_dashboard] Discord webhook failed for ${licenseKey}:`, err.message);
    }

    return c.json({ ok: true, banId, discordPosted: !discordResult.skipped });
});

export default router;
