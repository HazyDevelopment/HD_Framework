-- ═══════════════════════════════════════════════════════════════════
--  HD INVENTORY | INSTALL SQL | v1.1.0
--  Import after hd_framework_install.sql. Adds the `inventory` column
--  to the existing `players` table and creates the shared-stash
--  table. Vehicle storage needs no new table — `player_vehicles`
--  already has `glovebox`/`trunk` LONGTEXT columns from
--  hd_framework_install.sql; hd_inventory just reads/writes them.
--  Ground drops ARE now persisted (v1.1.0) — see hd_inventory_drops.
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE `players` ADD COLUMN IF NOT EXISTS `inventory` LONGTEXT NULL AFTER `metadata`;

CREATE TABLE IF NOT EXISTS `hd_inventory_stashes` (
    `id`        VARCHAR(50)  NOT NULL,
    `label`     VARCHAR(60)  NOT NULL DEFAULT 'Stash',
    `slots`     INT UNSIGNED NOT NULL DEFAULT 30,
    `weight`    INT UNSIGNED NOT NULL DEFAULT 30000,
    `data`      LONGTEXT     NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- A row exists for exactly as long as the drop does — created the
-- moment an item hits the ground, deleted the moment it's emptied
-- (see server/drops.lua). Surviving a restart is the whole point, so
-- unlike the in-memory v1.0.0 version this needs real coordinates.
CREATE TABLE IF NOT EXISTS `hd_inventory_drops` (
    `id`      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `x`       FLOAT        NOT NULL,
    `y`       FLOAT        NOT NULL,
    `z`       FLOAT        NOT NULL,
    `data`    LONGTEXT     NOT NULL,
    `created` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
