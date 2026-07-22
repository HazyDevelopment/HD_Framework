-- ═══════════════════════════════════════════════════════════════════
--  HAZY DEVELOPMENT | ADVANCED MDT | v2.1.0 — QBCORE INSTALL SQL
--
--  Player & vehicle data is read live from your existing QBCore tables:
--    • `players`          → citizenid, charinfo (name/DOB/phone), metadata (licences)
--    • `player_vehicles`  → plate, vehicle model, owner (joined to `players`)
--  Nothing is copied or duplicated — the MDT queries them directly.
--
--  This file creates every MDT table (both departments) and adds
--  indexes to the QBCore tables so civilian & plate searches stay fast.
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

-- ───────────── QBCORE TABLE READ OPTIMISATION (optional) ───────────
-- The MDT searches `players.charinfo` (JSON) by name and
-- `player_vehicles.plate` by plate. Generated columns + indexes below
-- make those lookups fast on large databases. Safe to skip if your
-- MySQL/MariaDB version doesn't support generated columns.

ALTER TABLE `players`
    ADD COLUMN IF NOT EXISTS `mdt_firstname` VARCHAR(60)
        GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(`charinfo`, '$.firstname'))) STORED,
    ADD COLUMN IF NOT EXISTS `mdt_lastname` VARCHAR(60)
        GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(`charinfo`, '$.lastname'))) STORED;

ALTER TABLE `players`
    ADD INDEX IF NOT EXISTS `idx_mdt_firstname` (`mdt_firstname`),
    ADD INDEX IF NOT EXISTS `idx_mdt_lastname` (`mdt_lastname`);

ALTER TABLE `player_vehicles`
    ADD INDEX IF NOT EXISTS `idx_mdt_plate` (`plate`),
    ADD INDEX IF NOT EXISTS `idx_mdt_citizenid` (`citizenid`);
