Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | HAZY DEVELOPMENT | v1.0.0
--  Smartphone: Contacts, Messages, Calls, three social apps (renamed
--  from the real-world apps they're inspired by so this stays clear
--  of any trademark — original names/UI, not reproductions), and
--  Garages. Talks to the framework the same way every other resource
--  in this ecosystem does — exports['qb-core']:GetCoreObject().
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

-- ═══════════════════════════ NOTIFY ══════════════════════════════════
Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
