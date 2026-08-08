import { Hono } from 'hono';
import { requireAdmin } from '../middleware/auth.js';
import { generateLicenseKey, generateSecret, hashSecret } from '../lib/crypto.js';
import { PLANS, isValidPlan, computeExpiresAt, daysRemaining } from '../lib/license.js';

const router = new Hono();

// Disabled entirely unless ADMIN_SECRET is set (see middleware/auth.js)
// — minting licenses over HTTP is a convenience for scripting a
// storefront webhook later (e.g. a Tebex purchase-complete callback
// hitting this route directly); `npm run mint-license` needs no network
// exposure at all and is the recommended path for manual sales.
router.post('/licenses', requireAdmin, async (c) => {
    const body = await c.req.json().catch(() => ({}));
    const ownerLabel = String(body.ownerLabel || '').slice(0, 200);
    const plan = isValidPlan(body.plan) ? body.plan : 'lifetime';

    let licenseKey;
    let attempts = 0;
    do {
        licenseKey = generateLicenseKey();
        attempts++;
    } while (attempts < 5 && await c.env.DB.prepare('SELECT 1 FROM licenses WHERE license_key = ?').bind(licenseKey).first());

    const secret = generateSecret();
    const expiresAt = computeExpiresAt(plan);
    await c.env.DB.prepare('INSERT INTO licenses (license_key, secret_hash, owner_label, plan, expires_at) VALUES (?, ?, ?, ?, ?)')
        .bind(licenseKey, await hashSecret(secret), ownerLabel, plan, expiresAt).run();

    // The only moment this secret ever exists in plaintext — hand it to
    // the buyer now, it cannot be recovered from the database after.
    return c.json({ licenseKey, secret, plan, expiresAt });
});

// Read-only visibility for the vendor (you) over the whole license
// book — which plan each buyer is on and how long they have left, so
// you can see who's about to lapse without hand-querying D1. Same
// requireAdmin gate as minting; not shown to buyers.
router.get('/licenses', requireAdmin, async (c) => {
    const { results } = await c.env.DB.prepare(
        'SELECT license_key, owner_label, active, plan, expires_at, discord_guild_id, created_at FROM licenses ORDER BY created_at DESC LIMIT 500'
    ).all();

    return c.json(results.map((row) => ({
        licenseKey: row.license_key,
        ownerLabel: row.owner_label,
        active: row.active === 1,
        plan: row.plan,
        planLabel: PLANS[row.plan]?.label || row.plan,
        expiresAt: row.expires_at,
        daysRemaining: daysRemaining(row.expires_at),
        discordGuildId: row.discord_guild_id,
        createdAt: row.created_at,
    })));
});

// Support route for a legitimate migration (buyer moving to a new
// Discord server, or the wrong guild ID got bound on first activation)
// — clears the binding so the NEXT requireServerAuth call locks onto
// whatever guild ID it sees then. Same requireAdmin gate as everything
// else here; a buyer can't do this themselves, on purpose — self-serve
// unlinking would defeat the entire point of binding it in the first
// place.
router.post('/licenses/:key/unlink-guild', requireAdmin, async (c) => {
    const licenseKey = c.req.param('key');
    const result = await c.env.DB.prepare('UPDATE licenses SET discord_guild_id = NULL WHERE license_key = ?').bind(licenseKey).run();
    if (!result.meta || result.meta.changes === 0) return c.json({ error: 'License not found.' }, 404);
    return c.json({ ok: true });
});

export default router;
