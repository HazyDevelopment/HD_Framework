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

-- ═══════════════════════════ DISCORD ROLE ADMIN ══════════════════════
-- hd_admin is gated entirely on a Discord role, not an ACE permission
-- — no `add_principal` line to hand-maintain in server.cfg per staff
-- member, add or remove the role in Discord and it takes effect on
-- that person's next /admin (checked fresh each time, cached for
-- Config.DiscordCacheSeconds so it isn't hammering Discord's API on
-- every single button click in the panel).
--
-- Checking a Discord user's guild roles requires Discord's own Bot
-- API — there is no anonymous/tokenless way to look this up, that's a
-- constraint of Discord's API, not a choice made here. Setup (about
-- two minutes):
--   1. https://discord.com/developers/applications -> New Application.
--   2. Bot tab -> Reset Token -> copy it into Config.DiscordBotToken
--      below. On the same tab, enable "SERVER MEMBERS INTENT" — the
--      role lookup silently fails without it.
--   3. OAuth2 -> URL Generator -> tick the "bot" scope -> open the
--      generated URL and invite the bot into your Discord server.
--   4. In Discord: User Settings -> Advanced -> turn on Developer Mode.
--   5. Right-click your Discord server's icon -> Copy Server ID ->
--      paste into Config.DiscordGuildId below.
--   6. Server Settings -> Roles -> right-click the role that should
--      count as admin -> Copy Role ID -> add it to
--      Config.DiscordAdminRoleIds below (add more than one id if
--      several different roles should all count as admin).
-- Without all three filled in, /admin refuses everyone, console
-- included — there's no ACE fallback left to fall back to on purpose.
Config.DiscordBotToken = ''    -- from step 2 above — paste the bot token exactly as Discord shows it, nothing else
Config.DiscordGuildId = '1528109596424536125'     -- from step 5 above
Config.DiscordAdminRoleIds = { -- from step 6 above, one string per qualifying role
     '1528133940312014998',
}
Config.DiscordCacheSeconds = 30 -- how long a player's checked admin status is trusted before re-querying Discord

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
