-- ═══════════════════════════════════════════════════════════════════
--  HD HOUSING | INSTALL SQL | v1.1.0
--  One row per property, whether it's a free starter flat claimed at
--  character creation or a house the real estate job sold. `id` is
--  always the owned Config.ApartmentShells entry's own id — real
--  interior shells are a fixed pool now (see config.lua), not
--  something generated at an arbitrary coordinate, so there's no
--  separate generated id like the old 're_<n>' real-estate rows had.
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `hd_properties` (
    `id`            VARCHAR(50)   NOT NULL,        -- Config.ApartmentShells id
    `label`         VARCHAR(100)  NOT NULL,
    `citizenid`     VARCHAR(50)   NULL DEFAULT NULL, -- NULL = unowned/available
    `type`          VARCHAR(20)   NOT NULL,          -- 'starter' | 'realestate'
    `price`         INT           NOT NULL DEFAULT 0,
    `exterior_x`    FLOAT         NOT NULL,
    `exterior_y`    FLOAT         NOT NULL,
    `exterior_z`    FLOAT         NOT NULL,
    `exterior_w`    FLOAT         NOT NULL DEFAULT 0,
    `pocket_x`      FLOAT         NOT NULL,          -- interior spawn coords (name kept from the old sky-pocket system)
    `pocket_y`      FLOAT         NOT NULL,
    `pocket_z`      FLOAT         NOT NULL,
    `ipl`           VARCHAR(50)   NULL DEFAULT NULL, -- v1.1.0 — set only for high-end shells that need RequestIpl before entry
    `created`       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `citizenid_idx` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `hd_properties` ADD COLUMN IF NOT EXISTS `ipl` VARCHAR(50) NULL DEFAULT NULL AFTER `pocket_z`;

-- v1.2.0 — placeable wardrobe/stash. JSON blob rather than a fixed set
-- of x/y/z/h columns per item, same shape as hd_phone_settings.home_order
-- elsewhere in this build: { wardrobe = {x,y,z,h}, stash = {x,y,z,h} },
-- either key absent until the owner actually places that piece.
ALTER TABLE `hd_properties` ADD COLUMN IF NOT EXISTS `furniture` TEXT NULL DEFAULT NULL;
