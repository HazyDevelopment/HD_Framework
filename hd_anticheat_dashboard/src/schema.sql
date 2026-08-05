-- ═══════════════════════════════════════════════════════════════════
--  HD ANTICHEAT DASHBOARD | SCHEMA | v1.0.0
--  One row per purchased license in `licenses`; everything else hangs
--  off `license_key` (not the numeric id) since that's the value the
--  buyer's FXServer actually presents on every request.  `configs` and
--  `webhooks` are 1:1 with a license — a buyer has exactly one server
--  configuration and one Discord webhook setup at a time, so these are
--  UPSERT targets, not append-only logs. `bans` and `ban_screenshots`
--  ARE append-only — a running history of what this license's server
--  has reported.
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS licenses (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    license_key TEXT NOT NULL UNIQUE,
    secret_hash TEXT NOT NULL,
    owner_label TEXT NOT NULL DEFAULT '', -- vendor's own note: buyer name/server, not shown to the buyer
    active      INTEGER NOT NULL DEFAULT 1,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Mirrors resources/[hd]/hd_anticheat/config.lua's tunables. Any column
-- left NULL means "buyer hasn't overridden this" — the FXServer resource
-- falls back to its own local config.lua default for that field instead
-- of receiving a NULL and breaking.
CREATE TABLE IF NOT EXISTS configs (
    license_key            TEXT PRIMARY KEY REFERENCES licenses(license_key) ON DELETE CASCADE,
    check_interval_ms      INTEGER,
    spawn_grace_ms         INTEGER,
    max_on_foot_speed      REAL,
    teleport_distance      REAL,
    damage_check_delay_ms  INTEGER,
    ban_threshold          INTEGER,
    score_decay_per_minute REAL,
    points_speed_hack      INTEGER,
    points_teleport_hack   INTEGER,
    points_invincibility   INTEGER,
    ban_message            TEXT,
    updated_at             TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS webhooks (
    license_key         TEXT PRIMARY KEY REFERENCES licenses(license_key) ON DELETE CASCADE,
    discord_webhook_url TEXT NOT NULL DEFAULT '',
    embed_color         INTEGER NOT NULL DEFAULT 15548997, -- Discord "red", decimal
    include_steam       INTEGER NOT NULL DEFAULT 1,
    include_discord      INTEGER NOT NULL DEFAULT 1,
    include_cfx          INTEGER NOT NULL DEFAULT 1,
    include_screenshots  INTEGER NOT NULL DEFAULT 1,
    updated_at            TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS bans (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    license_key   TEXT NOT NULL REFERENCES licenses(license_key) ON DELETE CASCADE,
    player_name   TEXT NOT NULL DEFAULT '',
    kind          TEXT NOT NULL DEFAULT '', -- speedHack | teleportHack | invincibility | injection | manual
    reason        TEXT NOT NULL DEFAULT '',
    steam_id      TEXT,
    discord_id    TEXT,
    discord_name  TEXT,
    cfx_id        TEXT,
    cfx_name      TEXT,
    ban_token     TEXT, -- links to ban_screenshots captured for this same event, if any
    created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS bans_license_idx ON bans(license_key, created_at DESC);

-- One row per screenshot captured for an injection-tripwire burst.
-- ban_token is minted server-side by the FXServer resource before it
-- asks the client to upload, then handed back on the /api/bans call so
-- this table's rows can be matched to the ban they belong to.
CREATE TABLE IF NOT EXISTS ban_screenshots (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    license_key TEXT NOT NULL REFERENCES licenses(license_key) ON DELETE CASCADE,
    ban_token   TEXT NOT NULL,
    url         TEXT NOT NULL,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS ban_screenshots_token_idx ON ban_screenshots(license_key, ban_token);
