const crypto = require('crypto');
const bcrypt = require('bcryptjs');

// HDAC-XXXX-XXXX-XXXX-XXXX — easy to read over Discord/email to a buyer,
// unambiguous charset (no 0/O/1/I) so a mistyped key fails fast instead
// of silently landing on someone else's license.
const KEY_CHARSET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function randomSegment(len) {
    let out = '';
    const bytes = crypto.randomBytes(len);
    for (let i = 0; i < len; i++) out += KEY_CHARSET[bytes[i] % KEY_CHARSET.length];
    return out;
}

function generateLicenseKey() {
    return `HDAC-${randomSegment(4)}-${randomSegment(4)}-${randomSegment(4)}-${randomSegment(4)}`;
}

// The secret is shown to the buyer exactly once at mint time — only its
// bcrypt hash is ever persisted, same trust model as a password.
function generateSecret() {
    return crypto.randomBytes(24).toString('base64url');
}

function hashSecret(secret) {
    return bcrypt.hashSync(secret, 12);
}

function verifySecret(secret, hash) {
    return bcrypt.compareSync(secret, hash);
}

module.exports = { generateLicenseKey, generateSecret, hashSecret, verifySecret };
