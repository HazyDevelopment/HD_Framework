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

-- v1.1.0 — every deposit/withdrawal used to just mutate `balance` in
-- place with no record left behind. One row per AddFunds/RemoveFunds
-- call now (see server/main.lua's LogTransaction), so a boss or admin
-- can actually review where a society's money came from and went —
-- see the top-level README's "Where to go from here".
CREATE TABLE IF NOT EXISTS `hd_society_transactions` (
    `id`      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `society` VARCHAR(50)  NOT NULL,
    `type`    VARCHAR(10)  NOT NULL,          -- 'credit' | 'debit'
    `amount`  INT UNSIGNED NOT NULL,
    `actor`   VARCHAR(50)  NULL,              -- citizenid, when known
    `reason`  VARCHAR(50)  NULL,              -- short tag: 'boss-deposit', 'fine', 'salary', etc.
    `created` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `society_idx` (`society`, `created`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
