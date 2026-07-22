-- ===================================================================
-- ukp_job — ESX install
-- Run this if Config.Framework = "esx" in config.lua.
--
-- Includes: this resource's own tables (evidence, fingerprints, and
-- the ESX on-duty tracker, since ESX has no native duty flag), plus
-- example esx_jobs / esx_job_grades rows for all 16 UKP ranks (0-15).
-- If a "police" job already exists in your esx_jobs table, either
-- drop the conflicting rows first or skip the INSERTs below and just
-- rename/re-grade your existing police job to match — the resource
-- only cares that the grade numbers (0-15) line up with config.lua.
-- ===================================================================

CREATE TABLE IF NOT EXISTS `ukp_duty` (
  `identifier` VARCHAR(60) NOT NULL PRIMARY KEY,
  `on_duty` TINYINT(1) NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS `ukp_evidence` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `case_number` VARCHAR(50) NOT NULL,
  `item_name` VARCHAR(255) NOT NULL,
  `description` TEXT NULL,
  `logged_by` VARCHAR(100) NULL,
  `logged_by_identifier` VARCHAR(60) NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `ukp_fingerprints` (
  `identifier` VARCHAR(60) NOT NULL PRIMARY KEY,
  `fingerprint_id` VARCHAR(20) NOT NULL UNIQUE
);

-- -------------------------------------------------------------------
-- Job + grades. Skip this block if you already have a "police" job.
-- -------------------------------------------------------------------
INSERT IGNORE INTO `jobs` (`name`, `label`) VALUES ('police', 'United Kingdom Police');

INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) VALUES
('police', 0,  'pcso',         'PCSO',                             600,  '{}', '{}'),
('police', 1,  'constable',    'Police Constable',                 900,  '{}', '{}'),
('police', 2,  'sergeant',     'Sergeant',                         1100, '{}', '{}'),
('police', 3,  'inspector',    'Inspector',                        1300, '{}', '{}'),
('police', 4,  'chiefinsp',    'Chief Inspector',                  1500, '{}', '{}'),
('police', 5,  'aro',          'Armed Response Officer',           1600, '{}', '{}'),
('police', 6,  'arvsergeant',  'ARV Sergeant',                     1800, '{}', '{}'),
('police', 7,  'arvinspector', 'ARV Inspector',                    2000, '{}', '{}'),
('police', 8,  'arvcommander', 'ARV Commander',                    2200, '{}', '{}'),
('police', 9,  'superintendent','Superintendent',                  2400, '{}', '{}'),
('police', 10, 'chiefsuper',   'Chief Superintendent',             2600, '{}', '{}'),
('police', 11, 'commander',    'Commander',                        2800, '{}', '{}'),
('police', 12, 'depacomm',     'Deputy Assistant Commissioner',    3000, '{}', '{}'),
('police', 13, 'asstcomm',     'Assistant Commissioner',           3200, '{}', '{}'),
('police', 14, 'deputycomm',   'Deputy Commissioner',              3400, '{}', '{}'),
('police', 15, 'commissioner', 'Commissioner',                     4000, '{}', '{}');

-- If your ESX build's job_grades table doesn't have skin_male/skin_female
-- columns (older/newer forks vary), drop those two columns from the
-- INSERT above and the matching two `{}, {}` values per row.
