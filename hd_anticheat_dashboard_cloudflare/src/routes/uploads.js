import { Hono } from 'hono';
import { verifyUploadToken } from '../lib/jwt.js';

const router = new Hono();

const LICENSE_RE = /^HDAC-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/;
const TOKEN_RE = /^[a-f0-9]{24}$/;
const MAX_BYTES = 8 * 1024 * 1024;

function randomHex(n) {
    const bytes = crypto.getRandomValues(new Uint8Array(n));
    return Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join('');
}

// Public and unauthenticated-by-license-secret on purpose — this is the
// one endpoint a game CLIENT (not the trusted FXServer) ever talks to,
// so it's gated on the short-lived, single-purpose token minted by
// POST /api/server/uploads/session instead of any long-lived credential.
// screenshot-basic's client-side requestScreenshotUpload posts the
// image as multipart/form-data under the field name 'file' (see
// hd_anticheat's client/main.lua).
router.post('/:licenseKey/:banToken', async (c) => {
    const licenseKey = c.req.param('licenseKey');
    const banToken = c.req.param('banToken');
    const token = c.req.query('token');

    if (!LICENSE_RE.test(licenseKey) || !TOKEN_RE.test(banToken)) {
        return c.json({ error: 'Malformed license or ban token.' }, 400);
    }
    if (!token || !(await verifyUploadToken(token, licenseKey, banToken, c.env.UPLOAD_JWT_SECRET))) {
        return c.json({ error: 'Invalid or expired upload token.' }, 401);
    }

    const formData = await c.req.formData();
    const file = formData.get('file');
    if (!file || typeof file === 'string') return c.json({ error: 'No file uploaded.' }, 400);
    if (file.size > MAX_BYTES) return c.json({ error: 'File too large.' }, 400);

    const key = `${licenseKey}/${banToken}-${randomHex(4)}.jpg`;
    await c.env.SCREENSHOTS.put(key, await file.arrayBuffer(), { httpMetadata: { contentType: 'image/jpeg' } });

    const url = `${c.env.PUBLIC_URL}/uploads/${key}`;
    await c.env.DB.prepare('INSERT INTO ban_screenshots (license_key, ban_token, url) VALUES (?, ?, ?)').bind(licenseKey, banToken, url).run();

    return c.json({ url });
});

export default router;
