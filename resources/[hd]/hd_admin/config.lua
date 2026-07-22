Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD ADMIN | HAZY DEVELOPMENT | v1.0.0
--  /admin opens the panel for staff only — gated on the same
--  `hd.admin` ACE permission every other admin command in this
--  framework already uses (HD_Framework's /addmoney, /setjob,
--  /givevehicle, hd_society's /addfunds). One permission to grant in
--  server.cfg, not a separate staff system to maintain.
--
--  The NUI only ever opening for admins is a UX nicety, not the real
--  gate — every single action re-checks IsPlayerAceAllowed(src,
--  Config.Permission) server-side on its own, same as everywhere else
--  in this build. A player who somehow forces the NUI open without
--  the ACE grant still can't actually do anything through it.
-- ═══════════════════════════════════════════════════════════════════

Config.Command = 'admin'
Config.Permission = 'hd.admin'

-- ═══════════════════════════ WORLD CONTROLS ═══════════════════════════
-- The real, documented SetWeatherTypeNow string constants — not a
-- guessed list.
Config.WeatherTypes = {
    'EXTRASUNNY', 'CLEAR', 'CLOUDS', 'OVERCAST', 'RAIN', 'THUNDER',
    'CLEARING', 'FOGGY', 'SMOG', 'SNOW', 'SNOWLIGHT', 'BLIZZARD', 'XMAS',
}

-- ═══════════════════════════ BANS ═════════════════════════════════════
Config.BanDurations = {
    { label = '1 Hour', hours = 1 },
    { label = '1 Day', hours = 24 },
    { label = '7 Days', hours = 168 },
    { label = '30 Days', hours = 720 },
    { label = 'Permanent', hours = nil },
}
Config.BanMessage = 'You are banned from this server.\nReason: %s\n%s' -- %s = reason, %s = "Expires: ..." or "Permanent"

-- ═══════════════════════════ TELEPORT ═════════════════════════════════
Config.TeleportZOffset = 1.0 -- small lift so you don't spawn inside the ground

Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
