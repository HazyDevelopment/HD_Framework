-- ═══════════════════════════════════════════════════════════════════
--  HD FINES | INSTALL SQL | v1.1.0
--  A debt is what's left of a fine the target couldn't fully pay at
--  the time — `society` records which job's hd_society fund gets the
--  money once it's eventually paid off via /paydebt, since a citizen
--  can owe several different jobs at once.
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `hd_fines_debts` (
    `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50)  NOT NULL,
    `society`   VARCHAR(50)  NOT NULL,
    `amount`    INT UNSIGNED NOT NULL,
    `reason`    VARCHAR(255) NULL,
    `created`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `citizenid_idx` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
