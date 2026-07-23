Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | HAZY DEVELOPMENT | v1.0.0
--  Smartphone: Contacts, Messages, Calls, three social apps (renamed
--  from the real-world apps they're inspired by so this stays clear
--  of any trademark — original names/UI, not reproductions), and
--  Garages. Talks to the framework the same way every other resource
--  in this ecosystem does — exports['HD_Framework']:GetCoreObject().
-- ═══════════════════════════════════════════════════════════════════

-- ═══════════════════════════ ITEM / OPEN ════════════════════════════
Config.Item = 'phone'   -- item key, see shared/items.lua in HD_Framework
Config.RequireItem = true -- hd_inventory now exists and seeds every new
                           -- citizen with a 'phone' item (Config.StarterItems
                           -- in hd_inventory/config.lua), so this check has
                           -- something real to gate against. See
                           -- client/main.lua's HasPhone() for the export call.
Config.Keybind = 'M'   -- rebindable in FiveM settings

-- ═══════════════════════════ SOCIAL APPS ════════════════════════════
-- Original names, not reproductions of any real platform's branding.
-- 'wire' is a short-text public feed, 'picta' is a photo feed, 'loopz'
-- is a caption-led "moments" feed — deliberately NOT real embedded
-- video (arbitrary video embedding in an NUI is a real security/
-- reliability rabbit hole), just simplified to text+optional image
-- like picta, framed differently. Upgrade it to real clips later if
-- you wire up a trusted video host.
Config.SocialApps = {
    wire = {
        label = 'Wire',
        maxLength = 280,
        allowImage = false,
    },
    picta = {
        label = 'Picta',
        maxLength = 150,
        allowImage = true,
    },
    loopz = {
        label = 'Loopz',
        maxLength = 150,
        allowImage = true,
    },
}

-- Allowed image hosts for Picta/Loopz posts ({} = allow all). Matches
-- hazy_mdt's Config.MugshotWhitelist convention.
Config.ImageHostWhitelist = {
    'i.imgur.com', 'imgur.com', 'cdn.discordapp.com', 'media.discordapp.net', 'i.postimg.cc'
}

-- ═══════════════════════════ MESSAGES / CONTACTS ════════════════════
Config.MaxMessageLength = 300
Config.MessageHistoryLimit = 100 -- per-conversation, oldest just don't load further back

-- ═══════════════════════════ CALLS ══════════════════════════════════
-- Ring/accept/decline/hang-up, linked to real pma-voice audio in
-- server/calls.lua (exports['pma-voice']:setPlayerCall). HD Phone
-- doesn't ship pma-voice itself — get it separately (see the main
-- README) — and degrades gracefully to a silent call UI if it isn't
-- running, rather than erroring.
Config.Calls = {
    RingTimeoutSeconds = 25,
}

-- ═══════════════════════════ GARAGES ════════════════════════════════
-- Move/add entries freely — the app lists whichever garage each
-- vehicle's `garage` column points at, and store/retrieve is gated on
-- standing inside one of these radii.
Config.Garages = {
    {
        key = 'legion',
        label = 'Legion Square Garage',
        coords = vector3(-247.2, -958.9, 31.2),
        radius = 15.0,
        spawn = vector4(-235.6, -947.1, 30.6, 205.0),
    },
    {
        key = 'davis',
        label = 'Davis Ave Garage',
        coords = vector3(114.4, -1954.6, 21.1),
        radius = 15.0,
        spawn = vector4(103.9, -1966.8, 21.1, 210.0),
    },
}

-- ═══════════════════════════ BANK ═══════════════════════════════════
-- Transfers only reach an ONLINE recipient (resolved by phone number,
-- same as Calls already require) — same scope discipline this
-- resource already applies elsewhere rather than reaching into an
-- offline player's saved row directly.
Config.Bank = {
    MinTransfer = 1,
    MaxTransfer = 500000,
}

-- ═══════════════════════════ MARKETPLACE ════════════════════════════
Config.Marketplace = {
    MaxTitleLength = 80,
    MaxDescriptionLength = 300,
    MaxPrice = 10000000,
    ListingLimitPerPlayer = 10,
}

-- ═══════════════════════════ NOTES ══════════════════════════════════
Config.Notes = {
    MaxLength = 2000,
    MaxPerPlayer = 30,
}

-- ═══════════════════════════ CRYPTO ═════════════════════════════════
-- One simulated coin, server-authoritative random-walk price. Not
-- tied to any real exchange/API — a self-contained economy toy.
Config.Crypto = {
    CoinName = 'HD Coin',
    CoinTicker = 'HDC',
    TickIntervalMs = 30000,   -- how often the price moves
    VolatilityPercent = 3.5,  -- max %% swing per tick, either direction
    MinPrice = 5.00,
    MaxPrice = 5000.00,
    PriceHistoryLength = 30,  -- how many past ticks the client-side sparkline keeps
}

-- ═══════════════════════════ GALLERY ════════════════════════════════
-- A personal saved-image board, not a literal device camera — same
-- "original, simplified take" approach already used for Loopz not
-- being real video. Reuses Config.ImageHostWhitelist above.
Config.Gallery = {
    MaxCaptionLength = 150,
    MaxPerPlayer = 40,
}

-- ═══════════════════════════ MAIL ═══════════════════════════════════
Config.Mail = {
    MaxPerPlayer = 100, -- oldest trimmed past this on send
}

-- ═══════════════════════════ SETTINGS / WALLPAPERS ══════════════════
-- Applied as the home screen background — key must match a CSS rule
-- in html/css/style.css's "WALLPAPERS" section.
Config.Wallpapers = {
    { key = 'default',  label = 'Default' },
    { key = 'sunset',   label = 'Sunset' },
    { key = 'ocean',    label = 'Ocean' },
    { key = 'midnight', label = 'Midnight' },
    { key = 'mono',     label = 'Mono' },
}

-- ═══════════════════════════ AIRDROP ════════════════════════════════
-- Broadcasts your number + character name to every other online phone
-- within Radius meters; each nearby player gets an accept/decline
-- prompt, and accepting just runs the normal saveContact flow on
-- their end — no separate contact-storage code needed.
Config.Airdrop = {
    Radius = 10.0,
}

-- ═══════════════════════════ APP STORE ══════════════════════════════
-- Phone, Messages, Contacts, App Store and Settings are core apps —
-- always on the home screen, can't be removed (mirrors iOS system
-- apps). Everything else starts uninstalled and only shows up once a
-- citizen has "downloaded" it here — this is the authoritative id
-- list server/appstore.lua validates installApp/uninstallApp against,
-- kept in sync with the `core: false` entries in html/js/app.js's
-- APPS array.
Config.DownloadableApps = {
    'wire', 'picta', 'loopz', 'garages', 'bank', 'mail', 'marketplace', 'notes', 'crypto', 'gallery',
    'airdrop', 'facetime',
}

-- ═══════════════════════════ NOTIFY ══════════════════════════════════
Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
