-- ═══════════════════════════════════════════════════════════════════
--  HD ANTICHEAT | INSTALL SQL | v1.0.0
--  One row per detection event, kept even after the player's dropped
--  or banned — this is the audit trail the NUI's Detections tab reads,
--  not live state (that's all in memory server-side, gone on restart
--  by design, same as hd_inventory's ground drops).
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `hd_anticheat_flags` (
    `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50)  NULL DEFAULT NULL,
    `name`      VARCHAR(100) NOT NULL,
    `type`      VARCHAR(30)  NOT NULL,             -- 'speedHack' | 'teleportHack' | 'invincibility'
    `detail`    VARCHAR(255) NOT NULL DEFAULT '',
    `score`     INT          NOT NULL DEFAULT 0,   -- running suspicion score at the moment of this flag
    `banned`    TINYINT(1)   NOT NULL DEFAULT 0,   -- did this specific flag cross the ban threshold
    `created`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `citizenid_idx` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- One row per `/acreport` submission — the Reports tab's source of
-- truth, kept after the reporter disconnects so staff can still work
-- the queue. Position is captured at submit time so an admin can jump
-- straight to where the reporter actually was.
CREATE TABLE IF NOT EXISTS `hd_anticheat_reports` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`     VARCHAR(50)  NULL DEFAULT NULL,
    `reporter_name` VARCHAR(100) NOT NULL,
    `title`         VARCHAR(100) NOT NULL DEFAULT '',
    `message`       VARCHAR(500) NOT NULL,
    `x`             FLOAT        NOT NULL DEFAULT 0,
    `y`             FLOAT        NOT NULL DEFAULT 0,
    `z`             FLOAT        NOT NULL DEFAULT 0,
    `status`        VARCHAR(20)  NOT NULL DEFAULT 'open', -- 'open' | 'resolved'
    `created`       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `status_idx` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
