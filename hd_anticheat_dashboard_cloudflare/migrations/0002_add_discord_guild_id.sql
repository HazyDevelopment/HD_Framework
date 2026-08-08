-- ═══════════════════════════════════════════════════════════════════
--  HD ANTICHEAT DASHBOARD | MIGRATION 0002 | Add Discord guild binding
--  Only needed if you already ran schema.sql before discord_guild_id
--  existed on `licenses` — a brand new database created from the
--  current schema.sql already has this column and does NOT need this
--  file. Run once (npm run d1:migrate2 / d1:migrate2:local). Every
--  existing row becomes discord_guild_id = NULL ("not yet bound"), so
--  no currently-active license is locked out — it just binds to
--  whatever guild ID its FXServer next reports, same as a brand new one.
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE licenses ADD COLUMN discord_guild_id TEXT;
