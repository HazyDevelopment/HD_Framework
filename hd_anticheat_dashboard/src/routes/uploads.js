const express = require('express');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const multer = require('multer');
const db = require('../db');
const { verifyUploadToken } = require('../lib/jwt');

const router = express.Router();
const uploadsRoot = path.join(__dirname, '..', '..', 'uploads');

// screenshot-basic's client-side requestScreenshotUpload posts the
// image as multipart/form-data under a field name we choose — the
// FXServer resource is told to use 'file' (see hd_anticheat's
// client/main.lua). Held in memory only long enough to write it out
// under a name we control, never the client-supplied filename.
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 8 * 1024 * 1024 } });

const LICENSE_RE = /^HDAC-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/;
const TOKEN_RE = /^[a-f0-9]{24}$/;

// Public and unauthenticated-by-license-secret on purpose — this is the
// one endpoint a game CLIENT (not the trusted FXServer) ever talks to,
// so it's gated on the short-lived, single-purpose token minted by
// POST /api/server/uploads/session instead of any long-lived credential.
router.post('/:licenseKey/:banToken', upload.single('file'), (req, res) => {
    const { licenseKey, banToken } = req.params;
    const token = req.query.token;

    if (!LICENSE_RE.test(licenseKey) || !TOKEN_RE.test(banToken)) {
        return res.status(400).json({ error: 'Malformed license or ban token.' });
    }
    if (!token || !verifyUploadToken(token, licenseKey, banToken)) {
        return res.status(401).json({ error: 'Invalid or expired upload token.' });
    }
    if (!req.file) return res.status(400).json({ error: 'No file uploaded.' });

    const dir = path.join(uploadsRoot, licenseKey);
    fs.mkdirSync(dir, { recursive: true });
    const fileName = `${banToken}-${crypto.randomBytes(4).toString('hex')}.jpg`;
    fs.writeFileSync(path.join(dir, fileName), req.file.buffer);

    const url = `${process.env.PUBLIC_URL}/uploads/${licenseKey}/${fileName}`;
    db.prepare('INSERT INTO ban_screenshots (license_key, ban_token, url) VALUES (?, ?, ?)').run(licenseKey, banToken, url);

    res.json({ url });
});

module.exports = router;
