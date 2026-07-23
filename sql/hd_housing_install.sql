-- ═══════════════════════════════════════════════════════════════════
--  HD HOUSING | INSTALL SQL | v1.0.0
--  One row per property, whether it's a free starter flat claimed at
--  character creation or a house the real estate job registered.
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `hd_properties` (
    `id`            VARCHAR(50)   NOT NULL,        -- Config.StarterFlats id, or 're_<n>' for real-estate ones
    `label`         VARCHAR(100)  NOT NULL,
    `citizenid`     VARCHAR(50)   NULL DEFAULT NULL, -- NULL = unowned/available
    `type`          VARCHAR(20)   NOT NULL,          -- 'starter' | 'realestate'
    `price`         INT           NOT NULL DEFAULT 0,
    `exterior_x`    FLOAT         NOT NULL,
    `exterior_y`    FLOAT         NOT NULL,
    `exterior_z`    FLOAT         NOT NULL,
    `exterior_w`    FLOAT         NOT NULL DEFAULT 0,
    `pocket_x`      FLOAT         NOT NULL,
    `pocket_y`      FLOAT         NOT NULL,
    `pocket_z`      FLOAT         NOT NULL,
    `created`       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `citizenid_idx` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
