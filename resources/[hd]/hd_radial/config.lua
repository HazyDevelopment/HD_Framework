Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD RADIAL | HAZY DEVELOPMENT | v1.0.0
--  A qb-radial-style F1 wheel: a hub of six categories, each opening
--  its own ring of real actions — not placeholders. Every entry below
--  maps to a genuine native/anim/scenario/event, see client/main.lua's
--  RunAction dispatcher for exactly what each `type` does.
-- ═══════════════════════════════════════════════════════════════════

Config.OpenKey = 'F1'

-- Six categories around the hub, in the exact clock position the NUI
-- lays them out (see html/js/app.js — it reads this order and places
-- them at 60° apart starting from the top). 'work' has no fixed
-- `items` here — it's built client-side per the player's current job,
-- see BuildWorkItems in client/main.lua.
Config.Categories = {
    { id = 'gps',          label = 'GPS',          icon = 'gps' },
    { id = 'interactions', label = 'Interactions', icon = 'interactions' },
    { id = 'walkstyle',    label = 'Walkstyle',    icon = 'walkstyle' },
    { id = 'general',      label = 'General',      icon = 'general' },
    { id = 'work',         label = 'Work',         icon = 'work' },
    { id = 'emotes',       label = 'Emotes',       icon = 'emotes' },
}

-- ═══════════════════════════ EMOTES ══════════════════════════════════
-- Ambient scenarios (TaskStartScenarioInPlace) rather than one-off
-- anim dict/clip pairs — real, stable Rockstar scenario names that
-- loop naturally and cancel cleanly the moment the player moves,
-- rather than a hand-picked anim that could clash with movement.
Config.Emotes = {
    { label = 'Dance',        scenario = 'WORLD_HUMAN_PARTYING' },
    { label = 'Crossed Arms', scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
    { label = 'Lean',         scenario = 'WORLD_HUMAN_HANG_OUT_STREET' },
    { label = 'Sunbathe',     scenario = 'WORLD_HUMAN_SUNBATHE' },
    { label = 'Coffee',       scenario = 'WORLD_HUMAN_AA_COFFEE' },
    { label = 'Smoke',        scenario = 'WORLD_HUMAN_SMOKING' },
}

-- ═══════════════════════════ INTERACTIONS ════════════════════════════
-- 'handsup' calls the shared exports['HD_Framework']:ToggleHandsUp() —
-- the exact same toggle the X keybind fires, defined once in
-- HD_Framework/client/main.lua so there's only one implementation.
Config.Interactions = {
    { label = 'Hands Up',  type = 'handsup' },
    { label = 'Crouch',    type = 'crouch' },
}

-- ═══════════════════════════ WALKSTYLES ══════════════════════════════
-- Real movement clipsets — 'Normal' resets to the default. Applied via
-- RequestClipSet/SetPedMovementClipset, persists until reset or
-- relog (native game behaviour, not something this resource re-applies).
Config.Walkstyles = {
    { label = 'Normal',    clipset = nil },
    { label = 'Confident', clipset = 'move_m@confident' },
    { label = 'Business',  clipset = 'move_m@business@a' },
    { label = 'Injured',   clipset = 'move_m@injured' },
    { label = 'Drunk',     clipset = 'move_m@drunk@moderatedrunk' },
    { label = 'Gangster',  clipset = 'move_m@ballistic' },
}

-- ═══════════════════════════ GENERAL ═════════════════════════════════
-- Vehicle actions no-op with a clear notice if you're not in one —
-- see client/main.lua's RunAction 'vehicle' branch.
Config.General = {
    { label = 'Seatbelt',      type = 'command',  command = 'hd_seatbelt' },
    { label = 'Engine',        type = 'engine' },
    { label = 'Lock Vehicle',  type = 'lockvehicle' },
    { label = 'Hood',          type = 'vehicledoor', door = 4 },
    { label = 'Trunk',         type = 'vehicledoor', door = 5 },
}

-- ═══════════════════════════ GPS ═════════════════════════════════════
-- Real, hand-picked coordinates already used elsewhere in this build
-- (hd_ems's Pillbox Hill station, hd_policejob's New Scotland Yard,
-- hd_mechanic's first shop) — not invented ones.
Config.GPS = {
    { label = 'Hospital',   coords = vector3(298.6, -584.2, 43.3) },
    { label = 'Police HQ',  coords = vector3(441.8, -981.9, 30.68) },
    { label = 'Mechanic',   coords = vector3(-207.0, -1330.0, 30.9) },
    { label = 'Clear',      type = 'clearwaypoint' },
}

-- ═══════════════════════════ WORK ════════════════════════════════════
-- Keyed by job name — the duty-toggle event each job resource already
-- registers. Any job not listed here just shows "Job Info" only (no
-- generic duty event to guess at) rather than silently failing.
Config.WorkDutyEvents = {
    police = 'hdpolice:server:toggleDuty',
    ambulance = 'hd_ems:server:toggleDuty',
}

Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
