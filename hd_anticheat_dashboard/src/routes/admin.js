const express = require('express');
const db = require('../db');
const { requireAdmin } = require('../middleware/auth');
const { generateLicenseKey, generateSecret, hashSecret } = require('../lib/crypto');

const router = express.Router();

// Disabled entirely unless ADMIN_SECRET is set (see middleware/auth.js)
// — minting licenses over HTTP is a convenience for scripting a
// storefront webhook later; `npm run mint-license` needs no network
// exposure at all and is the recommended path for manual sales.
router.post('/licenses', requireAdmin, (req, res) => {
    const ownerLabel = String((req.body || {}).ownerLabel || '').slice(0, 200);

    let licenseKey;
    do {
        licenseKey = generateLicenseKey();
    } while (db.prepare('SELECT 1 FROM licenses WHERE license_key = ?').get(licenseKey));

    const secret = generateSecret();
    db.prepare('INSERT INTO licenses (license_key, secret_hash, owner_label) VALUES (?, ?, ?)')
        .run(licenseKey, hashSecret(secret), ownerLabel);

    // The only moment this secret ever exists in plaintext — hand it to
    // the buyer now, it cannot be recovered from the database after.
    res.json({ licenseKey, secret });
});

module.exports = router;
