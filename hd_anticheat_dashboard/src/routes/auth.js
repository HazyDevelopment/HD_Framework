const express = require('express');
const db = require('../db');
const { verifySecret } = require('../lib/crypto');
const { signSession } = require('../lib/jwt');

const router = express.Router();

router.post('/login', (req, res) => {
    const { licenseKey, secret } = req.body || {};
    if (!licenseKey || !secret) return res.status(400).json({ error: 'License key and secret are required.' });

    const license = db.prepare('SELECT * FROM licenses WHERE license_key = ?').get(licenseKey.trim().toUpperCase());
    if (!license || !license.active || !verifySecret(secret, license.secret_hash)) {
        return res.status(401).json({ error: 'Invalid license key or secret.' });
    }

    res.json({ token: signSession(license.license_key) });
});

module.exports = router;
