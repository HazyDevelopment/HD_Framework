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
Config.License = {
    Key = '',                                     -- e.g. 'HDAC-XXXX-XXXX-XXXX-XXXX'
    Secret = '',
    DashboardUrl = 'https://your-dashboard.example.com',
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
