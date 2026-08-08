Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD ANTICHEAT | v1.0.0
--  What this can and can't actually do, honestly:
--  - It CAN reliably catch impossible movement (speed/teleport hacks)
--    and a player taking real hits without losing health (godmode).
--    Both are checked against ground truth this server already owns
--    (GetEntityCoords/GetEntityHealth), not anything the client claims.
--  - It CANNOT directly detect noclip as a concept — FiveM has no
--    server-side "is collision off" native. What it catches instead is
--    the *consequence* of noclip: moving somewhere no legitimate
--    on-foot movement could reach. A real admin's own noclip is exempt
--    (see server/detection.lua's IsAdmin check), so this doesn't get in
--    a legitimate staff member's way.
-- ═══════════════════════════════════════════════════════════════════

Config.Command = 'anticheat' -- opens the NUI panel (admin-only)

-- ═══════════════════════════ MOVEMENT ══════════════════════════════════
Config.CheckIntervalMs = 1500  -- how often each player's position is sampled
Config.SpawnGraceMs = 6000     -- no movement checks for this long after a player's character loads — streaming/collision settling, plus every legitimate "you just got placed somewhere" moment (spawn, apartment enter/exit, admin teleport) shares this same grace window
Config.MaxOnFootSpeed = 12.0   -- metres/second, on foot only (vehicle movement is never checked — too many legitimate high-speed vectors: tuned cars, ziptires, ramps). Real sprint tops out around 6-7 m/s; this already has a large margin built in
Config.TeleportDistance = 60.0 -- a single check-interval jump bigger than this can't be legitimate movement, on foot or in a vehicle

-- ═══════════════════════════ DAMAGE / INVINCIBILITY ═══════════════════
Config.DamageCheckDelayMs = 350 -- how long after a weapon-damage event to compare health before/after

-- ═══════════════════════════ SUSPICION SCORING ═════════════════════════
-- Every detection adds points instead of banning on the first hit —
-- catches sustained cheating reliably while giving a one-off false
-- positive (e.g. a legitimate teleport landing right as a check fires)
-- room to decay away instead of ending someone's career over it.
Config.BanThreshold = 100
Config.ScoreDecayPerMinute = 20
Config.Points = {
    speedHack = 40,
    teleportHack = 55,
    invincibility = 60,
}

Config.BanMessage = 'Banned by HD AntiCheat.\nReason: %s\nAppeal on our Discord if you believe this is a mistake.'

-- How many recent flags the NUI's Detections tab keeps in view.
Config.LogLimit = 200

-- ═══════════════════════════ ADMIN DUTY / CHAT ═════════════════════════
-- '/acduty' toggles a verified admin's on-duty flag (same IsExemptAdmin
-- check as everything else — a non-admin typing this does nothing). The
-- NUI's Chat tab, and every admin-chat broadcast, is scoped to whoever
-- currently has this flag set — an admin who never runs the command
-- never sees or sends admin chat, on purpose (keeps it to staff who are
-- actually working right now, not everyone who happens to qualify).
Config.DutyCommand = 'acduty'
Config.ChatCommand = 'a' -- '/a <message>' — only sends if the caller is an on-duty admin

-- '/acreport <message>' — any player, not just admins, so someone who
-- just watched a modder do something impossible has a direct line to
-- staff instead of hoping one happens to be watching. Goes straight to
-- the Reports tab plus a toast for any on-duty admin, even one who
-- doesn't have the panel open right now.
Config.ReportCommand = 'acreport'
Config.ReportCooldownMs = 30000 -- minimum gap between one player's own reports — stops the Reports tab being flooded, doesn't limit different players reporting the same incident

-- ═══════════════════════════ MONITOR TAB ═══════════════════════════════
-- How often live telemetry (position/heading, not video — see the
-- Monitor tab's own header text in html/index.html for why) refreshes
-- for admins who currently have the tab open. Nothing is sent at all
-- while no admin is watching.
Config.MonitorIntervalMs = 1000

-- ═══════════════════════════ WORLD ══════════════════════════════════════
-- FiveM has no native that resets "the whole map" — a World Reset asks
-- every connected client to run ClearAreaOfObjects around their OWN
-- position, which is the real, documented way to force stray/broken
-- dynamic props (a knocked-over streetlight, a dropped bin) back to
-- their default streamed-in state near wherever players actually are.
Config.WorldResetRadius = 200.0

-- How long the on-screen announcement banner stays visible for. The
-- announcement also always goes to every player's chat (including the
-- sending admin's own), so it isn't lost even if their panel isn't open
-- to see the banner.
Config.AnnouncementBannerMs = 8000

-- ═══════════════════════════ INJECTION / MOD-MENU TRIPWIRE ════════════
-- Be clear about what this actually is: FiveM gives a server ZERO
-- visibility into what's running inside a client's game process — there
-- is no native that reports "this player has a menu injected", and
-- nothing here can literally identify "RedEngine" or any other specific
-- product by name. What every public mod menu DOES have to do to
-- actually cheat is talk to the server over the network — usually by
-- firing server events, often ones borrowed from other frameworks
-- (ESX/QBCore-style names are extremely common, since menus are built
-- to work across many servers). HD_Framework is deliberately standalone
-- (see the repo's own "remove qb-core bridge" history) and registers
-- NONE of these — so a real player or a legitimate resource here will
-- NEVER trigger one, which makes any occurrence at all an unusually
-- clean signal. Add more prefixes/exact names below as new menus'
-- public documentation/leaks surface them; this list can only ever grow
-- from specific, known evidence, not guesswork.
-- IMPORTANT technical limitation, not a style choice: FiveM's event
-- system has no wildcard/prefix listener in the Lua API — a
-- RegisterNetEvent only ever catches the EXACT name given to it, and
-- an event nothing has registered that exact name for is silently
-- dropped before any script ever sees it. So this can only ever be a
-- curated list of exact names, never a true prefix/pattern catch-all —
-- anything claiming otherwise about a FiveM server-side script isn't
-- being accurate about what the platform actually allows. Grow this
-- list from specific, known evidence (leaked menu source, documented
-- exploit write-ups) as it surfaces, not guesswork.
Config.InjectionTripwireEvents = {
    'esx:getSharedObject', 'esx_menu_default:openMenu', 'esx_menu_list:openMenu',
    'esx_ambulancejob:revive', 'esx_policejob:handcuff', 'esx:onPlayerSpawn',
    'QBCore:Client:OnPlayerLoaded', 'QBCore:Server:OnPlayerLoaded', 'QBCore:ToggleDuty',
    'QBCore:Server:SetDuty', 'QBCore:Server:AddMoney', 'QBCore:Server:RemoveMoney',
    'qb-admin:server:GetPlayers', 'qb-adminmenu:server:noclip', 'qb-weapons:server:GetWeaponFromID',
    'vRP:updatePlayer', 'Deluxe_Menu:MainMenu', 'wf-mods:server:spawnVehicle',
}

-- ═══════════════════════════ ON SELLING THIS AS A LICENSED ASSET ═══════
-- Two different, honest answers to two different questions, so neither
-- gets overclaimed as covering the other:
--
-- "Can a buyer's server (or a cheat running on it) abuse THIS
--  resource's own network surface?" — every RegisterNetEvent/NUI
--  callback this resource exposes re-checks IsExemptAdmin server-side
--  regardless of what the client claims (see server/main.lua's header),
--  and the one event a non-admin client can legitimately fire on its
--  own — 'hd_anticheat:server:playerLoaded' — is replay-guarded
--  (server/main.lua's LastPlayerLoadedAt) specifically because an
--  injected script firing it repeatedly would otherwise buy permanent
--  immunity from the movement checks in detection.lua. That's a real,
--  original fix for a real gap in THIS codebase, not a borrowed one.
--
-- "Can a buyer (or someone who isn't a buyer at all) read or reuse this
--  resource's actual Lua source?" — that's not a problem this resource
--  can solve from inside its own Lua, on this or any FiveM asset,
--  because by the time any of this code is running, the client/server
--  Lua has already been delivered. The real, platform-level answer is
--  Keymaster escrow: package and sell this through Cfx.re's Keymaster +
--  a Tebex store, and the encrypted resource is only ever decrypted
--  transiently inside a legitimate, entitled FXServer process — a buyer
--  never has plaintext Lua to extract in the first place. `config.lua`
--  is deliberately the one file left OUT of escrow (see
--  fxmanifest.lua's `escrow_ignore`) so buyers can still tune their own
--  settings; every other file in this resource should go through
--  Keymaster escrow as part of packaging for sale, which is a Cfx.re
--  portal/build step, not something to hand-implement here.

-- ═══════════════════════════ WEB DASHBOARD (OPTIONAL) ══════════════════
-- Lets whoever bought this copy manage its settings and Discord ban
-- webhook from a browser instead of hand-editing this file — see
-- hd_anticheat_dashboard/ in this repo for the service itself (a
-- separate Node app you or the vendor deploys once, not a FiveM
-- resource). Leave Key blank (the default) to do nothing at all: this
-- resource then behaves exactly as if the dashboard didn't exist,
-- reading only the local values in this file, same as always.
--
-- Key/Secret come from whoever sold you this license (or, if you're
-- running the dashboard yourself, from `npm run mint-license` in
-- hd_anticheat_dashboard/). DashboardUrl is wherever that service is
-- reachable at. When set, every setting in the "MOVEMENT",
-- "DAMAGE / INVINCIBILITY", "SUSPICION SCORING", and "BAN MESSAGE"
-- sections above is re-checked against the dashboard roughly every ten
-- minutes and overridden if you've changed it there — a field you've
-- never touched on the dashboard just keeps using this file's value,
-- nothing here is silently reset to some other default.
-- DiscordGuildId is required alongside Key/Secret, not optional — it's
-- what ties this specific license to ONE specific Discord community
-- rather than just a key+secret pair that could otherwise be handed to
-- a totally different server. The dashboard binds a license to whatever
-- guild ID it sees on that license's FIRST successful sync (see
-- hd_anticheat_dashboard_cloudflare/src/middleware/auth.js) and rejects
-- every later sync from a different one — so this can't be changed
-- later to "move" a license onto a different community; a genuine
-- migration needs the vendor to unlink it dashboard-side first. Same
-- Discord server ID hd_admin/config.lua's Config.DiscordGuildId already
-- uses for this framework — right-click your Discord server's icon
-- (Developer Mode on) -> Copy Server ID if you ever need to fill this
-- in for a different community.
Config.License = {
    Key = 'HDAC-VZQ6-UAP3-87NL-4RRV',                                     -- e.g. 'HDAC-XXXX-XXXX-XXXX-XXXX'
    Secret = 'Qbicigeam4bGJ03V48okNMkkE7vxtR3V',
    DiscordGuildId = '1528109596424536125',
    DashboardUrl = 'https://fivem-panel.co.uk/dashboard',
}

-- Only relevant once Config.License.Key is set above AND screenshot
-- evidence is switched on for this license in the dashboard's Discord
-- Webhook page. Requires the community `screenshot-basic` resource
-- started alongside this one (`ensure screenshot-basic` in server.cfg,
-- above `ensure hd_anticheat`) — if it isn't running, this is skipped
-- silently, bans still work exactly the same either way.
--
-- Be clear about what this actually is: FiveM gives a script no way to
-- record real video from a client. What this does instead is ask
-- screenshot-basic for a quick burst of still frames the moment the
-- injection tripwire fires, and post them together as a Discord embed
-- gallery — genuinely useful evidence, just not literally "video".
Config.ScreenshotBurstCount = 3    -- how many stills to capture
Config.ScreenshotBurstDelayMs = 450 -- gap between each capture

-- Not a service this resource runs or connects to anywhere by default
-- — a real cross-server shared ban list means hosting a live, always-on
-- API that every buyer's server calls, and taking on real responsibility
-- for handling other people's Discord/Cfx.re identity data at scale.
-- That's an infrastructure and data-handling decision for whoever
-- operates this framework commercially to make deliberately, not
-- something to wire up silently. Leave this blank to do nothing; point
-- it at a URL you control and every permanent injection-menu ban POSTs
-- a JSON body there (see server/main.lua's BanPlayer) so you can feed
-- your own centralized system if you build one.
Config.GlobalBanWebhookUrl = ''
