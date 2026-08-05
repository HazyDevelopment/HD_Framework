const db = require('../db');
const { verifySecret } = require('../lib/crypto');
const { verifySession } = require('../lib/jwt');

// Browser sessions: dashboard.html sends `Authorization: Bearer <jwt>`
// after a successful /api/auth/login. Attaches req.licenseKey.
function requireBrowserAuth(req, res, next) {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    const licenseKey = token && verifySession(token);
    if (!licenseKey) return res.status(401).json({ error: 'Not logged in.' });

    const license = db.prepare('SELECT * FROM licenses WHERE license_key = ? AND active = 1').get(licenseKey);
    if (!license) return res.status(401).json({ error: 'License no longer active.' });

    req.licenseKey = licenseKey;
    next();
}

// Machine-to-machine: the buyer's FXServer authenticates with its raw
// license key + secret on every call (headers, never a query string —
// this can carry the actual long-lived credential, unlike the upload
// flow). No session/JWT on this side; Lua has no reason to manage
// token refresh for a request it makes once at boot and every so often
// after that.
function requireServerAuth(req, res, next) {
    const licenseKey = req.headers['x-license-key'];
    const secret = req.headers['x-license-secret'];
    if (!licenseKey || !secret) return res.status(401).json({ error: 'Missing license credentials.' });

    const license = db.prepare('SELECT * FROM licenses WHERE license_key = ? AND active = 1').get(licenseKey);
    if (!license || !verifySecret(secret, license.secret_hash)) {
        return res.status(401).json({ error: 'Invalid license credentials.' });
    }

    req.licenseKey = licenseKey;
    next();
}

function requireAdmin(req, res, next) {
    const configured = process.env.ADMIN_SECRET;
    if (!configured) return res.status(404).end(); // route doesn't exist unless explicitly enabled
    if (req.headers['x-admin-secret'] !== configured) return res.status(401).json({ error: 'Unauthorized.' });
    next();
}

module.exports = { requireBrowserAuth, requireServerAuth, requireAdmin };
