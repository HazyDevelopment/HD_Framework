-- ===================================================================
-- ukhs_job — ESX install
-- Run this if Config.Framework = "esx" in config.lua.
--
-- Includes: this resource's own on-duty tracker (ESX has no native
-- duty flag), plus example esx_jobs / esx_job_grades rows for all 7
-- UKHS ranks (0-9). If an "ambulance" job already exists in your
-- esx_jobs table, either drop the conflicting rows first or skip the
-- INSERTs below and just rename/re-grade your existing ambulance job
-- to match — the resource only cares that the grade numbers (0-9)
-- line up with config.lua.
-- ===================================================================

CREATE TABLE IF NOT EXISTS `ukhs_duty` (
  `identifier` VARCHAR(60) NOT NULL PRIMARY KEY,
  `on_duty` TINYINT(1) NOT NULL DEFAULT 0
);

-- -------------------------------------------------------------------
-- Job + grades. Skip this block if you already have an "ambulance" job.
-- -------------------------------------------------------------------
INSERT IGNORE INTO `jobs` (`name`, `label`) VALUES ('ambulance', 'United Kingdom Health Service');

INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) VALUES
('ambulance', 0, 'studentparamedic', 'Student Paramedic',           600,  '{}', '{}'),
('ambulance', 1, 'nqparamedic',      'Newly Qualified Paramedic',   800,  '{}', '{}'),
('ambulance', 2, 'paramedic',        'Paramedic',                   1000, '{}', '{}'),
('ambulance', 3, 'specparamedic',    'Specialist Paramedic',        1250, '{}', '{}'),
('ambulance', 4, 'advparamedic',     'Advanced Paramedic',          1500, '{}', '{}'),
('ambulance', 5, 'clinicalteamlead', 'Clinical Team Leader',        1800, '{}', '{}'),
('ambulance', 6, 'dutymanager',      'Duty Manager',                2100, '{}', '{}'),
('ambulance', 7, 'seniordutyman',    'Senior Duty Manager',         2400, '{}', '{}'),
('ambulance', 8, 'deputyopsmanager', 'Deputy Operations Manager',   2800, '{}', '{}'),
('ambulance', 9, 'opsmanager',       'Operations Manager',          3500, '{}', '{}');

-- If your ESX build's job_grades table doesn't have skin_male/skin_female
-- columns (older/newer forks vary), drop those two columns from the
-- INSERT above and the matching two `{}, {}` values per row.
