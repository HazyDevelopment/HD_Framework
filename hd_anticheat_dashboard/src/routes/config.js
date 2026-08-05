const express = require('express');
const db = require('../db');
const { requireBrowserAuth, requireServerAuth } = require('../middleware/auth');

const router = express.Router();

const FIELDS = [
    'check_interval_ms', 'spawn_grace_ms', 'max_on_foot_speed', 'teleport_distance',
    'damage_check_delay_ms', 'ban_threshold', 'score_decay_per_minute',
    'points_speed_hack', 'points_teleport_hack', 'points_invincibility', 'ban_message',
];

function getConfig(licenseKey) {
    return db.prepare('SELECT * FROM configs WHERE license_key = ?').get(licenseKey) || { license_key: licenseKey };
}

function saveConfig(licenseKey, body) {
    const existing = db.prepare('SELECT license_key FROM configs WHERE license_key = ?').get(licenseKey);
    const values = FIELDS.map((f) => (body[f] === undefined || body[f] === '' ? null : body[f]));

    if (existing) {
        const sets = FIELDS.map((f) => `${f} = ?`).join(', ');
        db.prepare(`UPDATE configs SET ${sets}, updated_at = datetime('now') WHERE license_key = ?`)
            .run(...values, licenseKey);
    } else {
        db.prepare(
            `INSERT INTO configs (license_key, ${FIELDS.join(', ')}) VALUES (?, ${FIELDS.map(() => '?').join(', ')})`
        ).run(licenseKey, ...values);
    }
    return getConfig(licenseKey);
}

// ── Browser (dashboard UI) ──────────────────────────────────────────
router.get('/config', requireBrowserAuth, (req, res) => {
    res.json(getConfig(req.licenseKey));
});

router.put('/config', requireBrowserAuth, (req, res) => {
    res.json(saveConfig(req.licenseKey, req.body || {}));
});

// ── Server (FXServer boot / periodic refresh) ───────────────────────
// Read-only from this side on purpose — a buyer's game server pulls
// its config, it never pushes one. The dashboard is the single source
// of truth so a setting can't drift between "what config.lua says" and
// "what the dashboard shows" on two different machines.
router.get('/server/config', requireServerAuth, (req, res) => {
    res.json(getConfig(req.licenseKey));
});

module.exports = router;
