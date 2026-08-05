const express = require('express');
const db = require('../db');
const { requireBrowserAuth, requireServerAuth } = require('../middleware/auth');
const { postBanToDiscord } = require('../lib/discord');

const router = express.Router();

function getWebhook(licenseKey) {
    return db.prepare('SELECT * FROM webhooks WHERE license_key = ?').get(licenseKey) || {
        license_key: licenseKey,
        discord_webhook_url: '',
        embed_color: 15548997,
        include_steam: 1,
        include_discord: 1,
        include_cfx: 1,
        include_screenshots: 1,
    };
}

router.get('/webhook', requireBrowserAuth, (req, res) => {
    res.json(getWebhook(req.licenseKey));
});

router.put('/webhook', requireBrowserAuth, (req, res) => {
    const b = req.body || {};
    const url = (b.discord_webhook_url || '').trim();
    if (url && !/^https:\/\/(discord|discordapp)\.com\/api\/webhooks\//.test(url)) {
        return res.status(400).json({ error: 'That doesn\'t look like a Discord webhook URL (expected https://discord.com/api/webhooks/...).' });
    }

    const existing = db.prepare('SELECT license_key FROM webhooks WHERE license_key = ?').get(req.licenseKey);
    const params = [
        url,
        Number.isFinite(+b.embed_color) ? +b.embed_color : 15548997,
        b.include_steam ? 1 : 0,
        b.include_discord ? 1 : 0,
        b.include_cfx ? 1 : 0,
        b.include_screenshots ? 1 : 0,
    ];

    if (existing) {
        db.prepare(
            `UPDATE webhooks SET discord_webhook_url = ?, embed_color = ?, include_steam = ?, include_discord = ?, include_cfx = ?, include_screenshots = ?, updated_at = datetime('now') WHERE license_key = ?`
        ).run(...params, req.licenseKey);
    } else {
        db.prepare(
            `INSERT INTO webhooks (license_key, discord_webhook_url, embed_color, include_steam, include_discord, include_cfx, include_screenshots) VALUES (?, ?, ?, ?, ?, ?, ?)`
        ).run(req.licenseKey, ...params);
    }
    res.json(getWebhook(req.licenseKey));
});

// Tests whatever is currently in the form, not what's saved — lets a
// buyer confirm their webhook URL works before hitting Save.
router.post('/webhook/test', requireBrowserAuth, async (req, res) => {
    const b = req.body || {};
    const url = (b.discord_webhook_url || '').trim();
    if (!url) return res.status(400).json({ error: 'Enter a webhook URL first.' });

    const fakeBan = {
        id: 0,
        player_name: 'Test Player',
        kind: 'injection',
        reason: 'This is a test post from the HD AntiCheat dashboard — no real ban occurred.',
        steam_id: '76561198000000000',
        discord_id: '123456789012345678',
        discord_name: 'testuser',
        cfx_id: '1234567',
        cfx_name: 'TestPlayer',
    };
    try {
        await postBanToDiscord(fakeBan, {
            discord_webhook_url: url,
            embed_color: Number.isFinite(+b.embed_color) ? +b.embed_color : 15548997,
            include_steam: b.include_steam ? 1 : 0,
            include_discord: b.include_discord ? 1 : 0,
            include_cfx: b.include_cfx ? 1 : 0,
            include_screenshots: false,
        }, []);
        res.json({ ok: true });
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

// The one webhook-related thing FXServer does need to know before a
// ban: whether it's worth spending the screenshot-burst delay at all.
// The webhook URL itself is never included in this response — posting
// to Discord always happens from here, never from the game server.
router.get('/server/webhook-flags', requireServerAuth, (req, res) => {
    const w = getWebhook(req.licenseKey);
    res.json({ include_screenshots: !!w.include_screenshots, configured: !!w.discord_webhook_url });
});

module.exports = router;
