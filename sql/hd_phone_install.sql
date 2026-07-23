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

-- ═══════════════════════════════════════════════════════════════════
--  v1.1.0 — Bank, Mail, Marketplace, Notes, Crypto, Gallery, Settings.
--  Bank itself needs no new balance table — it reads/writes
--  HD_Framework's existing `players.money` (cash/bank) via
--  Player.Functions.AddMoney/RemoveMoney, same as every other
--  money-touching resource in this ecosystem. These tables are just
--  the app-specific data each new app actually owns.
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `hd_phone_bank_log` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`  VARCHAR(50)  NOT NULL, -- whose statement this line appears on
    `type`       VARCHAR(20)  NOT NULL, -- 'deposit' | 'withdraw' | 'transfer_out' | 'transfer_in'
    `amount`     INT          NOT NULL,
    `other_party`VARCHAR(100) NULL,     -- display name/number of the other side, if any
    `created`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `citizenid_idx` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `hd_phone_mail` (
    `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`    VARCHAR(50)  NOT NULL, -- recipient
    `sender_label` VARCHAR(60)  NOT NULL, -- e.g. "HD Bank", "Marketplace", "Server Announcement"
    `subject`      VARCHAR(120) NOT NULL,
    `body`         TEXT         NOT NULL,
    `is_read`      TINYINT      NOT NULL DEFAULT 0,
    `created`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `citizenid_idx` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `hd_phone_marketplace` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`     VARCHAR(50)  NOT NULL,
    `seller_name`   VARCHAR(100) NOT NULL,
    `seller_number` VARCHAR(15)  NOT NULL,
    `title`         VARCHAR(80)  NOT NULL,
    `price`         INT          NOT NULL,
    `description`   TEXT         NULL,
    `image_url`     VARCHAR(255) NULL,
    `created`       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `hd_phone_notes` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`  VARCHAR(50)  NOT NULL,
    `content`    TEXT         NOT NULL,
    `created`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `citizenid_idx` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Single-coin ("HD Coin") simulated market. One singleton row —
-- price is server-authoritative, ticked by a random walk in
-- server/crypto.lua and persisted here so it survives a restart
-- instead of resetting.
CREATE TABLE IF NOT EXISTS `hd_phone_crypto_state` (
    `id`      TINYINT UNSIGNED NOT NULL,
    `price`   DECIMAL(10,2)    NOT NULL DEFAULT 100.00,
    `updated` TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT IGNORE INTO `hd_phone_crypto_state` (`id`, `price`) VALUES (1, 100.00);

CREATE TABLE IF NOT EXISTS `hd_phone_crypto_holdings` (
    `citizenid` VARCHAR(50)   NOT NULL,
    `amount`    DECIMAL(18,4) NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- A personal saved-image board, not a literal device camera (there's
-- no real screen-capture here — same "original, simplified take, not
-- a 1:1 reproduction" approach already used for Loopz not being real
-- video). Reuses Config.ImageHostWhitelist.
CREATE TABLE IF NOT EXISTS `hd_phone_gallery` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`  VARCHAR(50)  NOT NULL,
    `image_url`  VARCHAR(255) NOT NULL,
    `caption`    VARCHAR(150) NULL,
    `created`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `citizenid_idx` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `hd_phone_settings` (
    `citizenid` VARCHAR(50) NOT NULL,
    `wallpaper` VARCHAR(50) NOT NULL DEFAULT 'default',
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ═══════════════════════════════════════════════════════════════════
--  v1.2.0 — App Store. Phone/Messages/Contacts/App Store/Settings are
--  core apps and never touch this table; every other app only shows
--  on the home screen once a row exists here (see server/appstore.lua,
--  validated against Config.DownloadableApps).
-- ═══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS `hd_phone_installed_apps` (
    `citizenid` VARCHAR(50) NOT NULL,
    `app_id`    VARCHAR(30) NOT NULL,
    `installed` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `app_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ═══════════════════════════════════════════════════════════════════
--  v1.3.0 — No Caller ID + a custom (whitelisted-host) wallpaper URL,
--  both on the existing per-citizen settings row.
-- ═══════════════════════════════════════════════════════════════════
ALTER TABLE `hd_phone_settings`
    ADD COLUMN IF NOT EXISTS `no_caller_id` TINYINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `custom_wallpaper_url` VARCHAR(255) NULL;
