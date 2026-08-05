const express = require('express');
const crypto = require('crypto');
const db = require('../db');
const { requireBrowserAuth, requireServerAuth } = require('../middleware/auth');
const { signUploadToken } = require('../lib/jwt');
const { postBanToDiscord } = require('../lib/discord');

const router = express.Router();

// ── Browser (dashboard ban log) ─────────────────────────────────────
router.get('/bans', requireBrowserAuth, (req, res) => {
    const rows = db.prepare(
        'SELECT id, player_name, kind, reason, steam_id, discord_id, discord_name, cfx_id, cfx_name, ban_token, created_at FROM bans WHERE license_key = ? ORDER BY id DESC LIMIT 100'
    ).all(req.licenseKey);

    const shotStmt = db.prepare('SELECT url FROM ban_screenshots WHERE license_key = ? AND ban_token = ? ORDER BY id');
    for (const row of rows) {
        row.screenshots = row.ban_token ? shotStmt.all(req.licenseKey, row.ban_token).map((s) => s.url) : [];
    }
    res.json(rows);
});

// ── Server: mint a one-time, scoped token before asking the client to
// upload a screenshot burst. Called once per injection-tripwire event,
// BEFORE the FXServer triggers the client-side capture.
router.post('/server/uploads/session', requireServerAuth, (req, res) => {
    const banToken = crypto.randomBytes(12).toString('hex');
    const token = signUploadToken(req.licenseKey, banToken);
    const uploadUrl = `${process.env.PUBLIC_URL}/api/uploads/${req.licenseKey}/${banToken}?token=${token}`;
    res.json({ banToken, uploadUrl });
});

// ── Server: report a ban. If banToken is supplied and screenshots were
// uploaded for it, they're pulled in and forwarded to Discord alongside
// the identity fields. Discord posting failures don't fail the request
// — the ban itself (already applied by the FXServer/hd_admin ban table)
// isn't undone by a webhook hiccup.
router.post('/server/bans', requireServerAuth, async (req, res) => {
    const b = req.body || {};
    const info = db.prepare(
        `INSERT INTO bans (license_key, player_name, kind, reason, steam_id, discord_id, discord_name, cfx_id, cfx_name, ban_token)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(
        req.licenseKey,
        String(b.playerName || '').slice(0, 100),
        String(b.kind || '').slice(0, 40),
        String(b.reason || '').slice(0, 500),
        b.steamId || null,
        b.discordId || null,
        b.discordName || null,
        b.cfxId || null,
        b.cfxName || null,
        b.banToken || null
    );

    const ban = db.prepare('SELECT * FROM bans WHERE id = ?').get(info.lastInsertRowid);
    const webhookCfg = db.prepare('SELECT * FROM webhooks WHERE license_key = ?').get(req.licenseKey);
    const screenshots = ban.ban_token
        ? db.prepare('SELECT url FROM ban_screenshots WHERE license_key = ? AND ban_token = ? ORDER BY id').all(req.licenseKey, ban.ban_token).map((s) => s.url)
        : [];

    let discordResult = { skipped: true };
    try {
        discordResult = await postBanToDiscord(ban, webhookCfg, screenshots);
    } catch (err) {
        console.error(`[hd_anticheat_dashboard] Discord webhook failed for ${req.licenseKey}:`, err.message);
    }

    res.json({ ok: true, banId: ban.id, discordPosted: !discordResult.skipped });
});

module.exports = router;
