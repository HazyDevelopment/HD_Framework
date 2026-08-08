import { Hono } from 'hono';
import { requireBrowserAuth, requireServerAuth } from '../middleware/auth.js';
import { postBanToDiscord } from '../lib/discord.js';

const router = new Hono();

async function getWebhook(db, licenseKey) {
    const row = await db.prepare('SELECT * FROM webhooks WHERE license_key = ?').bind(licenseKey).first();
    return row || {
        license_key: licenseKey,
        discord_webhook_url: '',
        embed_color: 15548997,
        include_steam: 1,
        include_discord: 1,
        include_cfx: 1,
        include_screenshots: 1,
    };
}

router.get('/webhook', requireBrowserAuth, async (c) => {
    return c.json(await getWebhook(c.env.DB, c.get('licenseKey')));
});

router.put('/webhook', requireBrowserAuth, async (c) => {
    const licenseKey = c.get('licenseKey');
    const b = await c.req.json().catch(() => ({}));
    const url = (b.discord_webhook_url || '').trim();
    if (url && !/^https:\/\/(discord|discordapp)\.com\/api\/webhooks\//.test(url)) {
        return c.json({ error: "That doesn't look like a Discord webhook URL (expected https://discord.com/api/webhooks/...)." }, 400);
    }

    const existing = await c.env.DB.prepare('SELECT license_key FROM webhooks WHERE license_key = ?').bind(licenseKey).first();
    const params = [
        url,
        Number.isFinite(+b.embed_color) ? +b.embed_color : 15548997,
        b.include_steam ? 1 : 0,
        b.include_discord ? 1 : 0,
        b.include_cfx ? 1 : 0,
        b.include_screenshots ? 1 : 0,
    ];

    if (existing) {
        await c.env.DB.prepare(
            `UPDATE webhooks SET discord_webhook_url = ?, embed_color = ?, include_steam = ?, include_discord = ?, include_cfx = ?, include_screenshots = ?, updated_at = datetime('now') WHERE license_key = ?`
        ).bind(...params, licenseKey).run();
    } else {
        await c.env.DB.prepare(
            `INSERT INTO webhooks (license_key, discord_webhook_url, embed_color, include_steam, include_discord, include_cfx, include_screenshots) VALUES (?, ?, ?, ?, ?, ?, ?)`
        ).bind(licenseKey, ...params).run();
    }
    return c.json(await getWebhook(c.env.DB, licenseKey));
});

// Tests whatever is currently in the form, not what's saved.
router.post('/webhook/test', requireBrowserAuth, async (c) => {
    const b = await c.req.json().catch(() => ({}));
    const url = (b.discord_webhook_url || '').trim();
    if (!url) return c.json({ error: 'Enter a webhook URL first.' }, 400);

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
        return c.json({ ok: true });
    } catch (err) {
        return c.json({ error: err.message }, 400);
    }
});

// The one webhook-related thing FXServer does need to know before a
// ban: whether it's worth spending the screenshot-burst delay at all.
// The webhook URL itself is never included in this response — posting
// to Discord always happens from here, never from the game server.
router.get('/server/webhook-flags', requireServerAuth, async (c) => {
    const w = await getWebhook(c.env.DB, c.get('licenseKey'));
    return c.json({ include_screenshots: !!w.include_screenshots, configured: !!w.discord_webhook_url });
});

export default router;
