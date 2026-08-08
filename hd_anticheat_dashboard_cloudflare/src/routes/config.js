import { Hono } from 'hono';
import { requireBrowserAuth, requireServerAuth } from '../middleware/auth.js';
import { daysRemaining } from '../lib/license.js';

const router = new Hono();

const FIELDS = [
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
    const values = FIELDS.map((f) => (body[f] === undefined || body[f] === '' ? null : body[f]));

    if (existing) {
        const sets = FIELDS.map((f) => `${f} = ?`).join(', ');
        await db.prepare(`UPDATE configs SET ${sets}, updated_at = datetime('now') WHERE license_key = ?`)
            .bind(...values, licenseKey).run();
    } else {
        await db.prepare(
            `INSERT INTO configs (license_key, ${FIELDS.join(', ')}) VALUES (?, ${FIELDS.map(() => '?').join(', ')})`
        ).bind(licenseKey, ...values).run();
    }
    return getConfig(db, licenseKey);
}

// ── Browser (dashboard UI) ──────────────────────────────────────────
router.get('/config', requireBrowserAuth, async (c) => {
    return c.json(await getConfig(c.env.DB, c.get('licenseKey')));
});

router.put('/config', requireBrowserAuth, async (c) => {
    const body = await c.req.json().catch(() => ({}));
    return c.json(await saveConfig(c.env.DB, c.get('licenseKey'), body));
});

// ── Server (FXServer boot / periodic refresh) ───────────────────────
// Read-only from this side on purpose — a buyer's game server pulls
// its config, it never pushes one. `license` is included so
// hd_anticheat/server/dashboard.lua can print a days-remaining warning
// as a plan approaches expiry, without a second request just for that.
router.get('/server/config', requireServerAuth, async (c) => {
    const config = await getConfig(c.env.DB, c.get('licenseKey'));
    const license = c.get('license');
    return c.json({
        ...config,
        license: {
            plan: license.plan,
            expiresAt: license.expires_at,
            daysRemaining: daysRemaining(license.expires_at),
        },
    });
});

export default router;
