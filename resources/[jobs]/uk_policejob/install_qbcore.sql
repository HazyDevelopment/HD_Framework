-- ===================================================================
-- ukp_job — QBCore install
-- Run this if Config.Framework = "qbcore" in config.lua.
--
-- QBCore doesn't take job/grade definitions from SQL — those live in
-- qb-core/shared/jobs.lua. See qbcore_job_snippet.lua in this resource
-- for the "police" job entry with all 16 UKP ranks (0-15) already
-- filled in to paste into that file. This SQL file only creates the
-- tables this resource manages itself (evidence + fingerprints).
-- `ukp_duty` is NOT needed under QBCore — duty is tracked natively via
-- Player.Functions.SetJobDuty, this resource just calls that.
-- ===================================================================

CREATE TABLE IF NOT EXISTS `ukp_evidence` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `case_number` VARCHAR(50) NOT NULL,
  `item_name` VARCHAR(255) NOT NULL,
  `description` TEXT NULL,
  `logged_by` VARCHAR(100) NULL,
  `logged_by_identifier` VARCHAR(50) NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `ukp_fingerprints` (
  `identifier` VARCHAR(50) NOT NULL PRIMARY KEY,
  `fingerprint_id` VARCHAR(20) NOT NULL UNIQUE
);
