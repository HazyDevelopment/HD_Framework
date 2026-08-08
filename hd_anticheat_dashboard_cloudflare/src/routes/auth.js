import { Hono } from 'hono';
import { verifySecret } from '../lib/crypto.js';
import { signSession } from '../lib/jwt.js';
import { isExpired, EXPIRED_MESSAGE } from '../lib/license.js';

const router = new Hono();

router.post('/login', async (c) => {
    const body = await c.req.json().catch(() => ({}));
    const { licenseKey, secret } = body;
    if (!licenseKey || !secret) return c.json({ error: 'License key and secret are required.' }, 400);

    const license = await c.env.DB.prepare('SELECT * FROM licenses WHERE license_key = ?').bind(licenseKey.trim().toUpperCase()).first();
    if (!license || !license.active || !(await verifySecret(secret, license.secret_hash))) {
        return c.json({ error: 'Invalid license key or secret.' }, 401);
    }
    // Checked here too, not just by requireBrowserAuth on later calls —
    // otherwise an expired buyer would successfully log in and only find
    // out something's wrong once every page underneath fails to load.
    if (isExpired(license.expires_at)) return c.json({ error: EXPIRED_MESSAGE, expired: true }, 401);

    return c.json({ token: await signSession(license.license_key, c.env.SESSION_JWT_SECRET) });
});

export default router;
