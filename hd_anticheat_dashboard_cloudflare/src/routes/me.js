import { Hono } from 'hono';
import { requireBrowserAuth } from '../middleware/auth.js';
import { PLANS, daysRemaining } from '../lib/license.js';

const router = new Hono();

// The dashboard's own "which plan am I on" read — requireBrowserAuth
// already loaded the row and set it on the context, so this is a plain
// reshape, no second query.
router.get('/me', requireBrowserAuth, (c) => {
    const license = c.get('license');
    return c.json({
        licenseKey: license.license_key,
        plan: license.plan,
        planLabel: PLANS[license.plan]?.label || license.plan,
        expiresAt: license.expires_at,
        daysRemaining: daysRemaining(license.expires_at),
        discordGuildId: license.discord_guild_id, // null until the FXServer's first successful sync binds it
    });
});

export default router;
