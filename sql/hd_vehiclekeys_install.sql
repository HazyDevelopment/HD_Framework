-- ═══════════════════════════════════════════════════════════════════
--  HD VEHICLEKEYS | INSTALL SQL | v1.0.0
--  Ownership itself is read straight from `player_vehicles.citizenid`
--  (already created by hd_framework_install.sql) — this table only
--  tracks EXTRA keyholders the owner has shared a copy with. Lock
--  state itself isn't persisted (in-memory, resets to unlocked on
--  restart) — see the main README for why.
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `hd_vehicle_keys` (
    `plate`     VARCHAR(15) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`plate`, `citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
