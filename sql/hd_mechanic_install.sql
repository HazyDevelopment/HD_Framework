CREATE TABLE IF NOT EXISTS `hd_vehicle_compliance` (
    `plate`            VARCHAR(15) NOT NULL,
    `mot_expiry`       TIMESTAMP   NULL DEFAULT NULL,
    `insurance_expiry` TIMESTAMP   NULL DEFAULT NULL,
    `limp_mode`        TINYINT     NOT NULL DEFAULT 0,
    `updated`          TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
