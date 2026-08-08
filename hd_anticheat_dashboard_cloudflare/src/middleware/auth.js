import { verifySession } from '../lib/jwt.js';
import { verifySecret } from '../lib/crypto.js';
import { isExpired, EXPIRED_MESSAGE, GUILD_MISMATCH_MESSAGE } from '../lib/license.js';

// Browser sessions: dashboard.html sends `Authorization: Bearer <jwt>`
// after a successful /api/auth/login. Sets c.get('licenseKey') for
// downstream handlers, same shape as the Node version's req.licenseKey.
export async function requireBrowserAuth(c, next) {
    const header = c.req.header('Authorization') || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    const licenseKey = token && (await verifySession(token, c.env.SESSION_JWT_SECRET));
    if (!licenseKey) return c.json({ error: 'Not logged in.' }, 401);

    const license = await c.env.DB.prepare('SELECT * FROM licenses WHERE license_key = ? AND active = 1').bind(licenseKey).first();
    if (!license) return c.json({ error: 'License no longer active.' }, 401);
    if (isExpired(license.expires_at)) return c.json({ error: EXPIRED_MESSAGE, expired: true }, 401);

    c.set('licenseKey', licenseKey);
    c.set('license', license);
    await next();
}

// Machine-to-machine: the buyer's FXServer authenticates with its raw
// license key + secret on every call (headers, never a query string).
// No session/JWT on this side — Lua has no reason to manage token
// refresh for a request it makes once at boot and every so often after.
//
// Also where the Discord-guild binding lives (config.lua's
// Config.License.DiscordGuildId header, sent as X-Discord-Guild-Id by
// hd_anticheat/server/dashboard.lua's AuthHeaders): a license with no
// bound guild yet locks onto whatever guild ID this FIRST successful
// call reports; every later call from a different guild ID is rejected.
// This is what stops a key+secret pair being handed off to an
// unrelated server — the key alone was never enough to authenticate
// somewhere else, it also has to be presenting the same Discord
// community's guild ID the license first activated on.
export async function requireServerAuth(c, next) {
    const licenseKey = c.req.header('X-License-Key');
    const secret = c.req.header('X-License-Secret');
    const guildId = c.req.header('X-Discord-Guild-Id');
    if (!licenseKey || !secret) return c.json({ error: 'Missing license credentials.' }, 401);
    if (!guildId) return c.json({ error: 'Missing Discord guild ID — update to a version of hd_anticheat/config.lua that sets Config.License.DiscordGuildId.' }, 401);

    const license = await c.env.DB.prepare('SELECT * FROM licenses WHERE license_key = ? AND active = 1').bind(licenseKey).first();
    if (!license || !(await verifySecret(secret, license.secret_hash))) {
        return c.json({ error: 'Invalid license credentials.' }, 401);
    }
    if (isExpired(license.expires_at)) return c.json({ error: EXPIRED_MESSAGE, expired: true }, 401);

    if (!license.discord_guild_id) {
        await c.env.DB.prepare('UPDATE licenses SET discord_guild_id = ? WHERE license_key = ?').bind(guildId, licenseKey).run();
        license.discord_guild_id = guildId;
    } else if (license.discord_guild_id !== guildId) {
        return c.json({ error: GUILD_MISMATCH_MESSAGE, guildMismatch: true }, 401);
    }

    c.set('licenseKey', licenseKey);
    c.set('license', license);
    await next();
}

export function requireAdmin(c, next) {
    const configured = c.env.ADMIN_SECRET;
    if (!configured) return c.notFound(); // route doesn't exist unless explicitly enabled
    if (c.req.header('X-Admin-Secret') !== configured) return c.json({ error: 'Unauthorized.' }, 401);
    return next();
}
