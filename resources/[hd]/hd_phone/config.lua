Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | HAZY DEVELOPMENT
--  Original iOS-inspired smartphone NUI — own branding/app catalog
--  throughout (HD ID account system, HD Phone name), not a reskin of
--  any specific commercial phone script. Real per-character data for
--  everything below, not mocked.
-- ═══════════════════════════════════════════════════════════════════

Config.OpenKey = 'M'                    -- RegisterKeyMapping default, rebindable in FiveM's own keybind settings
Config.RequireItem = true               -- must be carrying a phone-type item to open
Config.PhoneItems = { 'phone', 'iphone', 'samsungphone' }

-- Any image URL used anywhere in the phone (wallpapers, posts, profile
-- photos) must come from one of these hosts.
Config.ImageHostWhitelist = {
    'i.imgur.com', 'imgur.com',
    'cdn.discordapp.com', 'media.discordapp.net',
    'i.ibb.co',
}

Config.Wallpapers = {
    { id = 'aurora',   label = 'Aurora',   preview = 'wallpaper_aurora.svg' },
    { id = 'sunset',   label = 'Sunset',   preview = 'wallpaper_sunset.svg' },
    { id = 'midnight', label = 'Midnight', preview = 'wallpaper_midnight.svg' },
    { id = 'mono',     label = 'Mono',     preview = 'wallpaper_mono.svg' },
}

-- ═══════════════════════════ APP REGISTRY ════════════════════════════
-- `core = true` apps are always on the home screen/dock and can't be
-- removed. Everything else starts uninstalled — open the App Store and
-- hit Get. `builtin = false` marks an app this build doesn't implement
-- yet (shows a friendly "coming soon" screen instead of erroring).
Config.Apps = {
    { id = 'phone',     label = 'Phone',     icon = 'phone',     core = true,  dock = true },
    { id = 'messages',  label = 'Messages',  icon = 'messages',  core = true,  dock = true },
    { id = 'contacts',  label = 'Contacts',  icon = 'contacts',  core = true },
    { id = 'settings',  label = 'Settings',  icon = 'settings',  core = true },

    { id = 'camera',    label = 'Camera',    icon = 'camera',    category = 'Utilities' },
    { id = 'photos',    label = 'Photos',    icon = 'photos',    category = 'Utilities' },
    { id = 'facetime',  label = 'FaceTime',  icon = 'facetime',  category = 'Social' },
    { id = 'wire',      label = 'Wire',      icon = 'wire',      category = 'Social' },
    { id = 'picta',     label = 'Picta',     icon = 'picta',     category = 'Social' },
    { id = 'loopz',     label = 'Loopz',     icon = 'loopz',     category = 'Social' },
    { id = 'matchup',   label = 'Matchup',   icon = 'matchup',   category = 'Social' },
    { id = 'darkchat',  label = 'Dark Chat', icon = 'darkchat',  category = 'Social' },

    { id = 'bank',      label = 'Bank',      icon = 'bank',      category = 'Finance' },
    { id = 'crypto',    label = 'Crypto',    icon = 'crypto',    category = 'Finance' },
    { id = 'marketplace', label = 'Marketplace', icon = 'marketplace', category = 'Finance' },

    { id = 'mail',      label = 'Mail',      icon = 'mail',      category = 'Utilities' },
    { id = 'notes',     label = 'Notes',     icon = 'notes',     category = 'Utilities' },
    { id = 'clock',     label = 'Clock',     icon = 'clock',     category = 'Utilities' },
    { id = 'maps',      label = 'Maps',      icon = 'maps',      category = 'Utilities' },
    { id = 'music',     label = 'Music',     icon = 'music',     category = 'Utilities' },
    { id = 'voicememo', label = 'Voice Memo',icon = 'voicememo', category = 'Utilities' },
    { id = 'garages',   label = 'Garages',   icon = 'garages',   category = 'Utilities' },
    { id = 'appstore',  label = 'App Store', icon = 'appstore',  core = true },
}

-- ═══════════════════════════ CAMERA ══════════════════════════════════
-- Needs the community 'screenshot-basic' resource (not included) to
-- actually capture a frame — degrades to a clear "not installed"
-- notice otherwise, never fakes a photo.
Config.Camera = {
    WebhookUrl = '', -- Discord webhook the captured image gets uploaded to
}

-- ═══════════════════════════ MAIL / MARKETPLACE / NOTES ══════════════
Config.Mail = { MaxPerPlayer = 100 }
Config.Marketplace = { ListingLimitPerPlayer = 10 }
Config.Notes = { MaxPerPlayer = 50 }

-- ═══════════════════════════ CRYPTO ══════════════════════════════════
Config.Crypto = {
    CoinName = 'HDCoin',
    CoinTicker = 'HDC',
    StartPrice = 500,
    MinPrice = 50,
    MaxPrice = 5000,
    TickSeconds = 60,
    MaxSwingPercent = 4,
}

-- ═══════════════════════════ VOICE MEMO ══════════════════════════════
Config.VoiceMemo = { MaxDurationSeconds = 30, MaxPerPlayer = 20 }

-- ═══════════════════════════ AIRDROP ═════════════════════════════════
Config.Airdrop = { Radius = 15.0 }

-- ═══════════════════════════ GARAGES ═════════════════════════════════
Config.Garages = {
    { key = 'legion',   label = 'Legion Square Garage', coords = vector4(215.0, -810.0, 30.7, 70.0) },
    { key = 'vespucci', label = 'Vespucci Garage',      coords = vector4(-1183.0, -1509.0, 4.4, 30.0) },
}
Config.GarageInteractDistance = 10.0

-- ═══════════════════════════ DARK CHAT ═══════════════════════════════
Config.DarkChat = { AliasPrefix = 'Ghost' }

-- ═══════════════════════════ MAPS ════════════════════════════════════
Config.Maps = {
    Pins = {
        { label = 'Legion Square Garage', coords = vector3(215.0, -810.0, 30.7), category = 'garage' },
        { label = 'Pillbox Hospital',      coords = vector3(298.0, -584.0, 43.2), category = 'hospital' },
        { label = 'Mission Row PD',        coords = vector3(428.2, -984.5, 30.7), category = 'police' },
    },
}

Config.MessageHistoryLimit = 100
Config.MaxMessageLength = 500
