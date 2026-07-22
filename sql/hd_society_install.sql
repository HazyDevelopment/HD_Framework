-- ═══════════════════════════════════════════════════════════════════
--  HD SOCIETY | INSTALL SQL | v1.0.0
--  One row per job that has a business fund. Rows are created lazily
--  (balance 0) the first time any hd_society export touches that
--  society name — no need to pre-seed this table.
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `hd_society_funds` (
    `society` VARCHAR(50) NOT NULL,
    `balance` INT         NOT NULL DEFAULT 0,
    PRIMARY KEY (`society`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
