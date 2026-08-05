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
