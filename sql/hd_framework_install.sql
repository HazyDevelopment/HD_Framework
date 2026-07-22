-- ═══════════════════════════════════════════════════════════════════
--  HD_FRAMEWORK | INSTALL SQL | v1.0.0
--  Import this BEFORE starting HD_Framework. Schema intentionally
--  matches stock QBCore's `players` / `player_vehicles` shape
--  (citizenid, charinfo JSON, metadata JSON, job JSON, money JSON) so
--  uk_policejob, uk_uhsjob, hazy_mdt and any off-the-shelf QBCore
--  resource work against it with zero changes via the qb-core bridge
--  resource.
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `players` (
    `citizenid`     VARCHAR(50)  NOT NULL,
    `license`       VARCHAR(80)  NOT NULL,
    `name`          VARCHAR(100) NOT NULL DEFAULT '',
    `money`         LONGTEXT     NOT NULL,
    `job`           LONGTEXT     NOT NULL,
    `gang`          LONGTEXT     NULL DEFAULT NULL,
    `charinfo`      LONGTEXT     NOT NULL,
    `metadata`      LONGTEXT     NOT NULL,
    `position`      LONGTEXT     NULL DEFAULT NULL,
    `last_updated`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`),
    UNIQUE KEY `license_unique` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `player_vehicles` (
    `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `license`           VARCHAR(80)  NOT NULL,
    `citizenid`         VARCHAR(50)  NOT NULL,
    `vehicle`           VARCHAR(60)  NOT NULL,
    `hash`              VARCHAR(80)  NULL DEFAULT NULL,
    `mods`              LONGTEXT     NULL DEFAULT NULL,
    `plate`             VARCHAR(15)  NOT NULL,
    `garage`            VARCHAR(50)  NULL DEFAULT NULL,
    `state`             TINYINT      NOT NULL DEFAULT 1,
    `depotprice`        INT          NOT NULL DEFAULT 0,
    `drivingdistance`   INT          NULL DEFAULT 0,
    `status`            LONGTEXT     NULL DEFAULT NULL,
    `glovebox`          LONGTEXT     NULL DEFAULT NULL,
    `trunk`             LONGTEXT     NULL DEFAULT NULL,
    `fuel`              INT          NOT NULL DEFAULT 100,
    `engine`            FLOAT        NOT NULL DEFAULT 1000,
    `body`              FLOAT        NOT NULL DEFAULT 1000,
    PRIMARY KEY (`id`),
    UNIQUE KEY `plate_unique` (`plate`),
    KEY `citizenid_idx` (`citizenid`),
    CONSTRAINT `fk_player_vehicles_citizenid` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Fingerprint table expected by uk_policejob's scanner feature.
CREATE TABLE IF NOT EXISTS `ukp_fingerprints` (
    `identifier`    VARCHAR(80) NOT NULL,
    `fingerprint`   VARCHAR(20) NOT NULL,
    PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
