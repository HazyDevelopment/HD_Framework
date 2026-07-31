Config = {}

-- ═══════════════════════════════════════════════════════════════════
-- hd_ems — the main UK Health Service ambulance job for HD_Framework.
-- This used to be split across two resources: hd_ems (the "built-in
-- death script" — downed/bleed-out state, in-person EMS revive) and
-- uk_uhsjob (duty/ranks/armoury/garage/GPS/staff revive). They're
-- merged here into one resource — hd_ems is now the whole ambulance
-- job, not just its death-handling half.
--
-- Without the deathscript half, resources/[gamemodes]/basic-gamemode
-- calls exports.spawnmanager:setAutoSpawn(true), which force-respawns
-- anyone 2 seconds after death — there's no time for EMS to matter.
-- This resource takes death over entirely: resurrect-in-place +
-- ragdoll lock (the standard ESX/QBCore "fake death" pattern — the ped
-- is technically alive from the game's perspective the whole time,
-- never fatally injured, so the native wasted screen/auto-respawn
-- never triggers), frozen in place until revived.
--
-- No self-service or timed respawn — a downed player stays exactly
-- where they fell until either an on-duty ambulance revives them in
-- person, or staff run /revive [id] (see Config.Revive below).
--
-- hd_dispatch already auto-opens an EMS call the moment a player goes
-- down (its own client hook on baseevents:onPlayerDied) — nothing to
-- change there, it already reads this resource's exact death moment.
-- ═══════════════════════════════════════════════════════════════════

Config.AmbulanceJob = 'ambulance'   -- must match the key in HD_Framework/shared/jobs.lua
Config.RequireOnDuty = true         -- must be on duty to use the armoury/garage/GPS, and to revive someone else in person

Config.DepartmentName = 'United Kingdom Health Service'
Config.ShortName = 'UHS'

-- Health (out of 200, GTA's max) restored on a proper in-person EMS revive.
Config.ReviveHealth = 120

-- EMS must be on duty, within this distance, and carrying this item
-- (not consumed — it's equipment, not a single-use consumable) to
-- revive. Hold E for RequiredHoldMs to complete it — not instant, so
-- it can't be spammed from a drive-by.
Config.ReviveDistance = 3.0
Config.ReviveItem = 'defibrillator'
Config.RequiredHoldMs = 5000

-- ═══════════════════════════ ANIMATIONS ══════════════════════════════════
-- Played on loop for as long as the player stays downed. Swap the
-- dict/clip here to re-skin it — client/main.lua just plays whatever's
-- configured, nothing else needs to change.
Config.DownedAnim = { dict = 'random@wipeblood', clip = 'wipe_blood_guard' }

-- Whether the revive transition (StandUp() in client/main.lua) plays
-- the game's own context-aware "lift yourself off the ground" get-up
-- animation (native TaskGetUp) before the player is unfrozen and
-- restored to their feet.
Config.PlayGetUpAnim = true

-- ═══════════════════════════════════════════════════════════════════
-- RANKS
-- Grade numbers match your job's grade field (HD_Framework:
-- job.grade.level). Grade 0 = Student Paramedic (basic UKHS
-- command-board read access), topping out at Operations Manager
-- (isBoss = true, gets the framework's boss/society menu access).
--
-- Each rank's Loadout is what the armoury will let that rank draw.
-- This is a medical service — no weapons, just equipment. `items`
-- entries are { name = "item_name", count = number } and must already
-- exist as valid items in HD_Framework/shared/items.lua — this
-- resource just calls hd_inventory's AddItem export, it doesn't create
-- item definitions.
-- ═══════════════════════════════════════════════════════════════════
Config.Ranks = {
    [0] = {
        label = 'Student Paramedic',
        isCommand = false,
        isBoss = false,
        loadout = {
            items = {
                { name = 'bandage', count = 3 },
                { name = 'painkillers', count = 2 },
                { name = 'radio', count = 1 },
            },
        },
    },
    [1] = {
        label = 'Newly Qualified Paramedic',
        isCommand = false,
        isBoss = false,
        loadout = {
            items = {
                { name = 'bandage', count = 5 },
                { name = 'painkillers', count = 3 },
                { name = 'medkit', count = 1 },
                { name = 'radio', count = 1 },
            },
        },
    },
    [2] = {
        label = 'Paramedic',
        isCommand = false,
        isBoss = false,
        loadout = {
            items = {
                { name = 'bandage', count = 5 },
                { name = 'painkillers', count = 5 },
                { name = 'medkit', count = 2 },
                { name = 'splint', count = 2 },
                { name = 'defibrillator', count = 1 },
                { name = 'radio', count = 1 },
            },
        },
    },
    [3] = {
        label = 'Specialist Paramedic',
        isCommand = false,
        isBoss = false,
        loadout = {
            items = {
                { name = 'bandage', count = 6 },
                { name = 'painkillers', count = 5 },
                { name = 'medkit', count = 3 },
                { name = 'splint', count = 3 },
                { name = 'defibrillator', count = 1 },
                { name = 'oxygen_mask', count = 1 },
                { name = 'morphine', count = 1 },
                { name = 'radio', count = 1 },
            },
        },
    },
    [4] = {
        label = 'Advanced Paramedic',
        isCommand = false,
        isBoss = false,
        loadout = {
            items = {
                { name = 'bandage', count = 6 },
                { name = 'painkillers', count = 6 },
                { name = 'medkit', count = 3 },
                { name = 'splint', count = 3 },
                { name = 'defibrillator', count = 2 },
                { name = 'oxygen_mask', count = 2 },
                { name = 'morphine', count = 2 },
                { name = 'stretcher', count = 1 },
                { name = 'radio', count = 1 },
            },
        },
    },
    [5] = {
        label = 'Clinical Team Leader',
        isCommand = true, -- basic UKHS command tier begins here
        isBoss = false,
        loadout = {
            items = {
                { name = 'bandage', count = 6 },
                { name = 'painkillers', count = 6 },
                { name = 'medkit', count = 4 },
                { name = 'splint', count = 3 },
                { name = 'defibrillator', count = 2 },
                { name = 'oxygen_mask', count = 2 },
                { name = 'morphine', count = 3 },
                { name = 'stretcher', count = 1 },
                { name = 'surgical_kit', count = 1 },
                { name = 'radio', count = 1 },
            },
        },
    },
    [6] = {
        label = 'Duty Manager',
        isCommand = true,
        isBoss = false,
        loadout = {
            items = {
                { name = 'bandage', count = 7 },
                { name = 'painkillers', count = 7 },
                { name = 'medkit', count = 4 },
                { name = 'splint', count = 4 },
                { name = 'defibrillator', count = 3 },
                { name = 'oxygen_mask', count = 3 },
                { name = 'morphine', count = 3 },
                { name = 'stretcher', count = 1 },
                { name = 'surgical_kit', count = 2 },
                { name = 'trauma_kit', count = 1 },
                { name = 'radio', count = 1 },
            },
        },
    },
    [7] = {
        label = 'Senior Duty Manager',
        isCommand = true,
        isBoss = false,
        loadout = {
            items = {
                { name = 'bandage', count = 8 },
                { name = 'painkillers', count = 8 },
                { name = 'medkit', count = 5 },
                { name = 'splint', count = 4 },
                { name = 'defibrillator', count = 3 },
                { name = 'oxygen_mask', count = 3 },
                { name = 'morphine', count = 4 },
                { name = 'stretcher', count = 1 },
                { name = 'surgical_kit', count = 2 },
                { name = 'trauma_kit', count = 2 },
                { name = 'radio', count = 1 },
            },
        },
    },
    [8] = {
        label = 'Deputy Operations Manager',
        isCommand = true,
        isBoss = false,
        loadout = {
            items = {
                { name = 'bandage', count = 8 },
                { name = 'painkillers', count = 8 },
                { name = 'medkit', count = 5 },
                { name = 'splint', count = 4 },
                { name = 'defibrillator', count = 3 },
                { name = 'oxygen_mask', count = 3 },
                { name = 'morphine', count = 4 },
                { name = 'stretcher', count = 1 },
                { name = 'surgical_kit', count = 3 },
                { name = 'trauma_kit', count = 3 },
                { name = 'radio', count = 1 },
            },
        },
    },
    [9] = {
        label = 'Operations Manager',
        isCommand = true,
        isBoss = true, -- top of the job — gets boss/society menu access where the framework supports it
        loadout = {
            items = {
                { name = 'bandage', count = 8 },
                { name = 'painkillers', count = 8 },
                { name = 'medkit', count = 5 },
                { name = 'splint', count = 4 },
                { name = 'defibrillator', count = 3 },
                { name = 'oxygen_mask', count = 3 },
                { name = 'morphine', count = 4 },
                { name = 'stretcher', count = 1 },
                { name = 'surgical_kit', count = 3 },
                { name = 'trauma_kit', count = 3 },
                { name = 'radio', count = 1 },
            },
        },
    },
}

-- ═══════════════════════════════════════════════════════════════════
-- STATIONS
-- Every vector below is exactly what you'll move to relocate a
-- station's garage/armoury/clock-in — just edit the coordinates,
-- nothing else needs touching. Add more entries to open additional
-- stations.
-- ═══════════════════════════════════════════════════════════════════
Config.Stations = {
    {
        label = 'Pillbox Hill Medical Center',

        ClockIn = vector4(298.6, -584.2, 43.3, 70.0),

        Armoury = vector4(309.1, -601.5, 43.2, 160.0),

        -- Garage: where the vehicle-selection menu opens, and the list
        -- of spawn points it'll try in order (so multiple vehicles
        -- pulled at once don't stack on each other).
        Garage = {
            Trigger = vector4(294.6, -604.6, 43.2, 250.0),
            SpawnPoints = {
                vector4(281.9, -604.5, 43.3, 251.0),
                vector4(288.0, -608.0, 43.3, 251.0),
                vector4(294.0, -611.5, 43.3, 251.0),
            },
        },
    },
}

Config.InteractDistance = 8.0
Config.InteractPressDistance = 1.6

-- ═══════════════════════════════════════════════════════════════════
-- GARAGE VEHICLES
-- The full fleet list. MinGrade gates who can pull it. `model` must
-- be a valid vehicle spawn name on your server.
-- ═══════════════════════════════════════════════════════════════════
Config.GarageVehicles = {
    { model = 'ambulance', label = 'Ambulance',             minGrade = 0 },
    { model = 'novak',     label = 'Rapid Response Vehicle', minGrade = 1 },
    { model = 'policeb',   label = 'Response Motorcycle',    minGrade = 3 },
    { model = 'polmav',    label = 'Air Ambulance',          minGrade = 5 },
    { model = 'fbi2',      label = 'Senior Command Saloon',  minGrade = 6 },
}

-- ═══════════════════════════════════════════════════════════════════
-- GPS TRACKING
-- Companion design with hd_policejob: this resource only ever tracks/
-- pushes ITS OWN job ("ambulance"). hd_policejob independently
-- registers "police" the same way — together the two give full mutual
-- visibility (each side's ViewerJobs includes both jobs) without
-- either resource double-registering the other's job. Running this
-- resource on its own still works fine; police simply won't have GPS
-- blips unless hd_policejob is also installed.
--
-- The event names used by client/gps.lua and server/gps.lua below are
-- kept as "ukhs:*" on purpose, not renamed to "hd_ems:*" — they used
-- to belong to uk_uhsjob before this merge, and hd_policejob's own
-- server/gps.lua still calls them literally
-- (TriggerClientEvent('ukhs:client:gpsUpdate', ...)) to piggyback on
-- this same client-side blip renderer. Renaming them here would also
-- require patching hd_policejob; keeping the old names means it needs
-- no changes at all.
-- ═══════════════════════════════════════════════════════════════════
Config.GPS = {
    -- Single true/false switch. When a different server has
    -- wasabi_gps installed, set this true and this resource will hand
    -- GPS tracking off to it automatically via its real, documented
    -- exports (docs.wasabiscripts.com/wasabi-scripts/free-releases/wasabi_gps/exports):
    --   exports.wasabi_gps:registerJob({ job, tracked, subscribers, blipSettings, item })
    --   exports.wasabi_gps:unregisterJob(job)
    -- Set this to false (or just don't install wasabi_gps) and this
    -- resource uses its own built-in ping + blip system instead —
    -- zero external dependencies. Safe to leave "true" even on
    -- servers that don't have wasabi_gps — it detects that and falls
    -- back automatically.
    UseWasabiGPS = true,
    WasabiResourceName = 'wasabi_gps',

    -- This resource's own job — the only one it tracks/pushes.
    TrackableJobs = { 'ambulance' },

    -- Jobs allowed to see ambulance units on the tracker/map.
    ViewerJobs = { 'police', 'ambulance' },

    -- Optional: require this item to be carried to be tracked
    -- (wasabi_gps's item-based GPS toggle). Leave nil to always track
    -- on-duty ambulance with no item requirement. Only takes effect
    -- when UseWasabiGPS is active.
    Item = nil,

    -- Optional per-job blip appearance, passed straight through to
    -- wasabi_gps's registerJob `blipSettings`. Ignored by the
    -- built-in fallback (which uses its own fixed blip style).
    BlipSettings = {
        ambulance = { color = 3, scale = 0.8, short = true, category = 7 },
    },

    -- How often (ms) the built-in fallback pushes position/polls.
    -- Not used while wasabi_gps is handling delivery.
    UpdateInterval = 5000,
}

-- ═══════════════════════════════════════════════════════════════════
-- STAFF REVIVE COMMAND
-- A text-chat command for SERVER STAFF (not the ambulance job) to
-- revive themselves or another player by server ID.
--
--   /revive        -> revives yourself
--   /revive [id]   -> revives the player with that server ID
-- ═══════════════════════════════════════════════════════════════════
Config.Revive = {
    Enabled = true,
    Command = 'revive',        -- the chat command name (/revive)
    RestoreArmor = false,      -- also set armour to 100 on revive
    ClearWanted = false,       -- clear the target's wanted level on revive
    Notify = true,             -- notify staff + revived player

    -- ── Who counts as "server staff" ────────────────────────────────
    -- A player may run the command if ANY of these pass.

    -- 1) ACE permission (framework-independent, recommended).
    --    Add to server.cfg, e.g.:
    --      add_ace group.admin ukhs.revive allow
    --    or grant per-identifier. Set to '' to disable this check.
    AcePermission = 'ukhs.revive',

    -- 2) Generic FiveM 'command' ace (RCON / most admin setups already
    --    have this). Set false to require the specific ace above.
    AllowGenericCommandAce = true,
}

-- ═══════════════════════════════════════════════════════════════════
-- PANIC BUTTON
-- /panic — the radio's emergency button, reachable as a command too.
-- Raises a top-priority hd_dispatch call visible to BOTH police and
-- ambulance (see hd_dispatch/config.lua's 'panic' call type) and plays
-- hd_radio's Panic.ogg for every eligible responder — see
-- client/panic.lua and server/panic.lua.
-- ═══════════════════════════════════════════════════════════════════
Config.Panic = {
    Command = 'panic',
    Cooldown = 30, -- seconds between presses per medic, stops spam
}
