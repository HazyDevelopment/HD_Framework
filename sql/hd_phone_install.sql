-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | INSTALL SQL | v1.0.0
--  Import this alongside hd_framework_install.sql. The Garages app
--  needs no new table — it reads/writes the `player_vehicles` table
--  that HD_Framework already created (`garage` + `state` columns).
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `hd_phone_messages` (
    `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `sender`    VARCHAR(15)  NOT NULL,
    `recipient` VARCHAR(15)  NOT NULL,
    `message`   TEXT         NOT NULL,
    `is_read`   TINYINT      NOT NULL DEFAULT 0,
    `created`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `sender_idx` (`sender`),
    KEY `recipient_idx` (`recipient`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `hd_phone_contacts` (
    `id`     INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `owner`  VARCHAR(50)  NOT NULL, -- citizenid of the contact list owner
    `name`   VARCHAR(60)  NOT NULL,
    `number` VARCHAR(15)  NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `owner_number_unique` (`owner`, `number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `hd_phone_posts` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `app`         VARCHAR(10)  NOT NULL, -- 'wire' | 'picta' | 'loopz'
    `citizenid`   VARCHAR(50)  NOT NULL,
    `author_name` VARCHAR(100) NOT NULL,
    `content`     TEXT         NULL,
    `image_url`   VARCHAR(255) NULL,
    `created`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `app_idx` (`app`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `hd_phone_post_likes` (
    `post_id`   INT UNSIGNED NOT NULL,
    `citizenid` VARCHAR(50)  NOT NULL,
    PRIMARY KEY (`post_id`, `citizenid`),
    CONSTRAINT `fk_hd_phone_post_likes_post` FOREIGN KEY (`post_id`) REFERENCES `hd_phone_posts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
