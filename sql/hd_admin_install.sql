-- ═══════════════════════════════════════════════════════════════════
--  HD ADMIN | INSTALL SQL | v1.0.0
--  Bans key off `license` (the one identifier every connecting player
--  always has — see HD_Framework's own GetLicense pattern) so a ban
--  survives a name change or a fresh character. `expires` NULL means
--  permanent.
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `hd_admin_bans` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `license`    VARCHAR(80)  NOT NULL,
    `name`       VARCHAR(100) NOT NULL DEFAULT '',
    `reason`     VARCHAR(255) NOT NULL DEFAULT '',
    `banned_by`  VARCHAR(100) NOT NULL DEFAULT '',
    `expires`    TIMESTAMP    NULL DEFAULT NULL,
    `created`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `active`     TINYINT      NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    KEY `license_idx` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- v1.1.0 — raw platform identifiers captured at ban time (not looked up
-- later, since a banned player's identifiers obviously can't be
-- re-queried after they're gone). discord_name is a best-effort Discord
-- bot API resolution done once at ban time when Config.DiscordBotToken
-- is set; NULL just means it wasn't available, never a blocker.
ALTER TABLE `hd_admin_bans` ADD COLUMN IF NOT EXISTS `discord_id`   VARCHAR(32)  NULL DEFAULT NULL AFTER `license`;
ALTER TABLE `hd_admin_bans` ADD COLUMN IF NOT EXISTS `discord_name` VARCHAR(100) NULL DEFAULT NULL AFTER `discord_id`;
ALTER TABLE `hd_admin_bans` ADD COLUMN IF NOT EXISTS `cfx_id`       VARCHAR(64)  NULL DEFAULT NULL AFTER `discord_name`;
