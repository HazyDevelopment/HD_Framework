-- ═══════════════════════════════════════════════════════════════════
--  HAZY DEVELOPMENT | ADVANCED MDT | v2.1.0 — ESX INSTALL SQL
--
--  Player & vehicle data is read live from your existing ESX tables:
--    • `users`           → identifier, firstname, lastname, dateofbirth
--    • `user_licenses`   → licence types per identifier
--    • `owned_vehicles`  → plate, vehicle JSON, owner (joined to `users`)
--  Nothing is copied or duplicated — the MDT queries them directly.
--
--  This file creates every MDT table (both departments) and adds
--  indexes to the ESX tables so civilian & plate searches stay fast.
--  Importing this file is REQUIRED — the resource does not create
--  its tables automatically. It only verifies they exist on startup.
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────── POLICE (mdtpolice_) ───────────────────

CREATE TABLE IF NOT EXISTS `mdtpolice_updates` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `kind` VARCHAR(20) NOT NULL DEFAULT 'update',
    `title` VARCHAR(120) NOT NULL,
    `message` TEXT NOT NULL,
    `author` VARCHAR(80) NOT NULL,
    `callsign` VARCHAR(20) DEFAULT '',
    `created` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `mdtpolice_settings` (
    `identifier` VARCHAR(60) NOT NULL,
    `callsign` VARCHAR(20) DEFAULT '',
    `theme` TEXT,
    PRIMARY KEY (`identifier`)
);

CREATE TABLE IF NOT EXISTS `mdtpolice_reports` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `rtype` VARCHAR(40) NOT NULL,
    `title` VARCHAR(120) NOT NULL,
    `content` TEXT NOT NULL,
    `involved` TEXT,
    `author` VARCHAR(80) NOT NULL,
    `author_callsign` VARCHAR(20) DEFAULT '',
    `created` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `mdtpolice_warrants` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(60) NOT NULL,
    `name` VARCHAR(80) NOT NULL,
    `reason` TEXT NOT NULL,
    `issued_by` VARCHAR(80) NOT NULL,
    `active` TINYINT(1) DEFAULT 1,
    `created` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_warrant_citizen` (`citizenid`, `active`)
);

CREATE TABLE IF NOT EXISTS `mdtpolice_vehicle_markers` (
    `plate` VARCHAR(12) NOT NULL,
    `marker` VARCHAR(30) NOT NULL,
    `notes` TEXT,
    `set_by` VARCHAR(80) NOT NULL,
    `created` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`plate`)
);

CREATE TABLE IF NOT EXISTS `mdtpolice_mugshots` (
    `citizenid` VARCHAR(60) NOT NULL,
    `url` VARCHAR(255) NOT NULL,
    `set_by` VARCHAR(80) NOT NULL,
    `updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
);

-- ─────────────────────────── UHS (mdtuhs_) ─────────────────────────

CREATE TABLE IF NOT EXISTS `mdtuhs_updates` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `kind` VARCHAR(20) NOT NULL DEFAULT 'update',
    `title` VARCHAR(120) NOT NULL,
    `message` TEXT NOT NULL,
    `author` VARCHAR(80) NOT NULL,
    `callsign` VARCHAR(20) DEFAULT '',
    `created` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `mdtuhs_settings` (
    `identifier` VARCHAR(60) NOT NULL,
    `callsign` VARCHAR(20) DEFAULT '',
    `theme` TEXT,
    PRIMARY KEY (`identifier`)
);

CREATE TABLE IF NOT EXISTS `mdtuhs_reports` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `rtype` VARCHAR(40) NOT NULL,
    `title` VARCHAR(120) NOT NULL,
    `content` TEXT NOT NULL,
    `involved` TEXT,
    `author` VARCHAR(80) NOT NULL,
    `author_callsign` VARCHAR(20) DEFAULT '',
    `created` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `mdtuhs_patients` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(60) NOT NULL,
    `name` VARCHAR(80) NOT NULL,
    `blood_type` VARCHAR(5) DEFAULT '',
    `medications` TEXT,
    `staff` TEXT,
    `treatment` TEXT,
    `notes` TEXT,
    `author` VARCHAR(80) NOT NULL,
    `created` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_patient_citizen` (`citizenid`)
);

-- ───────────── ESX TABLE READ OPTIMISATION (optional) ──────────────
-- The MDT searches `users` by first/last name, `user_licenses` by
-- owner, and `owned_vehicles` by plate. These indexes keep those
-- lookups fast on large databases.

ALTER TABLE `users`
    ADD INDEX IF NOT EXISTS `idx_mdt_firstname` (`firstname`),
    ADD INDEX IF NOT EXISTS `idx_mdt_lastname` (`lastname`);

ALTER TABLE `user_licenses`
    ADD INDEX IF NOT EXISTS `idx_mdt_owner` (`owner`);

ALTER TABLE `owned_vehicles`
    ADD INDEX IF NOT EXISTS `idx_mdt_plate` (`plate`),
    ADD INDEX IF NOT EXISTS `idx_mdt_owner` (`owner`);
