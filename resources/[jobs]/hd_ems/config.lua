Config = {}

-- ═══════════════════════════════════════════════════════════════════
-- hd_ems — the "built-in death script" the ambulance job was missing.
-- Without this, resources/[gamemodes]/basic-gamemode calls
-- exports.spawnmanager:setAutoSpawn(true), which force-respawns anyone
-- 2 seconds after death — there's no time for EMS to matter. This
-- resource takes death over entirely: resurrect-in-place + ragdoll
-- lock (the standard ESX/QBCore "fake death" pattern — the ped is
-- technically alive from the game's perspective the whole time, never
-- fatally injured, so the native wasted screen/auto-respawn never
-- triggers), frozen in place until revived.
--
-- No self-service or timed respawn — a downed player stays exactly
-- where they fell until either an on-duty ambulance revives them in
-- person, or staff run uk_uhsjob's /revive [id].
--
-- hd_dispatch already auto-opens an EMS call the moment a player goes
-- down (its own client hook on baseevents:onPlayerDied) — nothing to
-- change there, it already reads this resource's exact death moment.
-- ═══════════════════════════════════════════════════════════════════

Config.AmbulanceJob = 'ambulance'          -- must match the key in HD_Framework/shared/jobs.lua
Config.RequireOnDutyToRevive = true

-- Health (out of 200, GTA's max) restored on a proper EMS revive.
Config.ReviveHealth = 120

-- EMS must be on duty, within this distance, and carrying this item
-- (not consumed — it's equipment, not a single-use consumable) to
-- revive. Hold E for RequiredHoldMs to complete it — not instant, so
-- it can't be spammed from a drive-by.
Config.ReviveDistance = 3.0
Config.ReviveItem = 'defibrillator'
Config.RequiredHoldMs = 5000
