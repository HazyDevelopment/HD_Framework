-- ═══════════════════════════════════════════════════════════════════
--  HD ANTICHEAT DASHBOARD | MIGRATION 0001 | Add license plans/expiry
--  Only needed if you already ran the old schema.sql against a real
--  database before `plan`/`expires_at` existed on `licenses` — a brand
--  new database created from the current schema.sql already has both
--  columns and does NOT need this file. Run once
--  (`npm run d1:migrate` / `d1:migrate:local`); SQLite's ALTER TABLE has
--  no "ADD COLUMN IF NOT EXISTS", so running it twice against the same
--  database errors on the second attempt — that's expected, not a bug.
--  Every existing row becomes `plan = 'lifetime'`, `expires_at = NULL`
--  (never expires) — the same behaviour every license already had
--  before this column existed, so no currently-active buyer is
--  suddenly locked out by applying this.
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE licenses ADD COLUMN plan TEXT NOT NULL DEFAULT 'lifetime';
ALTER TABLE licenses ADD COLUMN expires_at TEXT;
