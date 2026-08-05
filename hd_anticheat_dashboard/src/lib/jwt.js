const jwt = require('jsonwebtoken');

const SESSION_SECRET = process.env.SESSION_JWT_SECRET;
const UPLOAD_SECRET = process.env.UPLOAD_JWT_SECRET;

if (!SESSION_SECRET || !UPLOAD_SECRET) {
    throw new Error('SESSION_JWT_SECRET and UPLOAD_JWT_SECRET must be set in .env — see .env.example');
}

function signSession(licenseKey) {
    return jwt.sign({ lk: licenseKey }, SESSION_SECRET, { expiresIn: '12h' });
}

function verifySession(token) {
    try {
        const payload = jwt.verify(token, SESSION_SECRET);
        return payload.lk;
    } catch {
        return null;
    }
}

// Scoped to exactly one license + one ban-capture event, short-lived —
// this is the token handed to a game CLIENT (via the FXServer resource)
// so it can upload screenshots directly to us. It is deliberately NOT
// the buyer's real license secret: the client process is the one thing
// in this whole flow that might be running a cheat, so it never sees
// anything long-lived or reusable beyond this one burst.
function signUploadToken(licenseKey, banToken) {
    return jwt.sign({ lk: licenseKey, bt: banToken }, UPLOAD_SECRET, { expiresIn: '90s' });
}

function verifyUploadToken(token, licenseKey, banToken) {
    try {
        const payload = jwt.verify(token, UPLOAD_SECRET);
        return payload.lk === licenseKey && payload.bt === banToken;
    } catch {
        return false;
    }
}

module.exports = { signSession, verifySession, signUploadToken, verifyUploadToken };
