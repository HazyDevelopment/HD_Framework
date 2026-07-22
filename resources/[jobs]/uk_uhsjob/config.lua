Config = {}

-- ===================================================================
-- FRAMEWORK SELECTION
-- ===================================================================
Config.Framework = "qbcore" -- "qbcore" or "esx"

-- Job name to check against, per framework. QBCore's default EMS job
-- is "ambulance". Some ESX servers use "ambulance", others use "ems"
-- — change the one that matches your actual job name.
Config.AmbulanceJob = {
    qbcore = "ambulance",
    esx    = "ambulance",
}

-- Require on-duty (clocked in at a station) to use the garage,
-- armoury, and to be trackable on the GPS system.
Config.RequireOnDuty = true

Config.DepartmentName = "United Kingdom Health Service"
Config.ShortName      = "UHS"

-- ===================================================================
-- RANKS
-- Grade numbers match your job's grade field (QBCore: job.grade.level,
-- ESX: job grade). Grade 0 = Student Paramedic (basic UKHS
-- command-board read access), topping out at Operations Manager
-- (isBoss = true, gets the framework's boss/society menu access
-- where applicable).
--
-- Each rank's Loadout is what the armoury will let that rank draw.
-- This is a medical service — no weapons, just equipment. `items`
-- entries are { name = "item_name", count = number } and must already
-- exist as valid items in your inventory system (qb-core/shared/
-- items.lua, ESX items table, ox_inventory items, etc) — this
-- resource just calls the standard AddItem-style function, it doesn't
-- create item definitions.
-- ===================================================================
Config.Ranks = {
    [0] = {
        label = "Student Paramedic",
        isCommand = false,
        isBoss = false,
        loadout = {
            items = {
                { name = "bandage", count = 3 },
                { name = "painkillers", count = 2 },
                { name = "radio", count = 1 },
            },
        },
    },
    [1] = {
        label = "Newly Qualified Paramedic",
        isCommand = false,
        isBoss = false,
        loadout = {
            items = {
                { name = "bandage", count = 5 },
                { name = "painkillers", count = 3 },
                { name = "medkit", count = 1 },
                { name = "radio", count = 1 },
            },
        },
    },
    [2] = {
        label = "Paramedic",
        isCommand = false,
        isBoss = false,
        loadout = {
            items = {
                { name = "bandage", count = 5 },
                { name = "painkillers", count = 5 },
                { name = "medkit", count = 2 },
                { name = "splint", count = 2 },
                { name = "defibrillator", count = 1 },
                { name = "radio", count = 1 },
            },
        },
    },
    [3] = {
        label = "Specialist Paramedic",
        isCommand = false,
        isBoss = false,
        loadout = {
            items = {
                { name = "bandage", count = 6 },
                { name = "painkillers", count = 5 },
                { name = "medkit", count = 3 },
                { name = "splint", count = 3 },
                { name = "defibrillator", count = 1 },
                { name = "oxygen_mask", count = 1 },
                { name = "morphine", count = 1 },
                { name = "radio", count = 1 },
            },
        },
    },
    [4] = {
        label = "Advanced Paramedic",
        isCommand = false,
        isBoss = false,
        loadout = {
            items = {
                { name = "bandage", count = 6 },
                { name = "painkillers", count = 6 },
                { name = "medkit", count = 3 },
                { name = "splint", count = 3 },
                { name = "defibrillator", count = 2 },
                { name = "oxygen_mask", count = 2 },
                { name = "morphine", count = 2 },
                { name = "stretcher", count = 1 },
                { name = "radio", count = 1 },
            },
        },
    },
    [5] = {
        label = "Clinical Team Leader",
        isCommand = true, -- basic UKHS command tier begins here
        isBoss = false,
        loadout = {
            items = {
                { name = "bandage", count = 6 },
                { name = "painkillers", count = 6 },
                { name = "medkit", count = 4 },
                { name = "splint", count = 3 },
                { name = "defibrillator", count = 2 },
                { name = "oxygen_mask", count = 2 },
                { name = "morphine", count = 3 },
                { name = "stretcher", count = 1 },
                { name = "surgical_kit", count = 1 },
                { name = "radio", count = 1 },
            },
        },
    },
    [6] = {
        label = "Duty Manager",
        isCommand = true,
        isBoss = false,
        loadout = {
            items = {
                { name = "bandage", count = 7 },
                { name = "painkillers", count = 7 },
                { name = "medkit", count = 4 },
                { name = "splint", count = 4 },
                { name = "defibrillator", count = 3 },
                { name = "oxygen_mask", count = 3 },
                { name = "morphine", count = 3 },
                { name = "stretcher", count = 1 },
                { name = "surgical_kit", count = 2 },
                { name = "trauma_kit", count = 1 },
                { name = "radio", count = 1 },
            },
        },
    },
    [7] = {
        label = "Senior Duty Manager",
        isCommand = true,
        isBoss = false,
        loadout = {
            items = {
                { name = "bandage", count = 8 },
                { name = "painkillers", count = 8 },
                { name = "medkit", count = 5 },
                { name = "splint", count = 4 },
                { name = "defibrillator", count = 3 },
                { name = "oxygen_mask", count = 3 },
                { name = "morphine", count = 4 },
                { name = "stretcher", count = 1 },
                { name = "surgical_kit", count = 2 },
                { name = "trauma_kit", count = 2 },
                { name = "radio", count = 1 },
            },
        },
    },
    [8] = {
        label = "Deputy Operations Manager",
        isCommand = true,
        isBoss = false,
        loadout = {
            items = {
                { name = "bandage", count = 8 },
                { name = "painkillers", count = 8 },
                { name = "medkit", count = 5 },
                { name = "splint", count = 4 },
                { name = "defibrillator", count = 3 },
                { name = "oxygen_mask", count = 3 },
                { name = "morphine", count = 4 },
                { name = "stretcher", count = 1 },
                { name = "surgical_kit", count = 3 },
                { name = "trauma_kit", count = 3 },
                { name = "radio", count = 1 },
            },
        },
    },
    [9] = {
        label = "Operations Manager",
        isCommand = true,
        isBoss = true, -- top of the job — gets boss/society menu access where the framework supports it
        loadout = {
            items = {
                { name = "bandage", count = 8 },
                { name = "painkillers", count = 8 },
                { name = "medkit", count = 5 },
                { name = "splint", count = 4 },
                { name = "defibrillator", count = 3 },
                { name = "oxygen_mask", count = 3 },
                { name = "morphine", count = 4 },
                { name = "stretcher", count = 1 },
                { name = "surgical_kit", count = 3 },
                { name = "trauma_kit", count = 3 },
                { name = "radio", count = 1 },
            },
        },
    },
}

-- ===================================================================
-- STATIONS
-- Every vector below is exactly what you'll move to relocate a
-- station's garage/armoury/clock-in — just edit the coordinates,
-- nothing else needs touching. Add more entries to open additional
-- stations.
-- ===================================================================
Config.Stations = {
    {
        label = "Pillbox Hill Medical Center",

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

-- ===================================================================
-- GARAGE VEHICLES
-- The full fleet list. MinGrade gates who can pull it. `model` must
-- be a valid vehicle spawn name on your server.
-- ===================================================================
Config.GarageVehicles = {
    { model = "ambulance", label = "Ambulance",              minGrade = 0 },
    { model = "novak",     label = "Rapid Response Vehicle",  minGrade = 1 },
    { model = "policeb",   label = "Response Motorcycle",     minGrade = 3 },
    { model = "polmav",    label = "Air Ambulance",           minGrade = 5 },
    { model = "fbi2",      label = "Senior Command Saloon",   minGrade = 6 },
}

-- ===================================================================
-- GPS TRACKING
-- Companion design: this resource only ever tracks/pushes ITS OWN
-- job ("ambulance"). If you're also running the police job resource
-- (uk_policejob), that one registers/pushes "police" — together the
-- two give full mutual visibility (each side's ViewerJobs includes
-- both jobs) without either resource double-registering the other's
-- job. Running this resource on its own still works fine; police
-- simply won't have GPS blips unless something else provides them.
-- ===================================================================
Config.GPS = {
    -- ===============================================================
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
    -- ===============================================================
    UseWasabiGPS = true,
    WasabiResourceName = "wasabi_gps",

    -- This resource's own job — the only one it tracks/pushes.
    TrackableJobs = { "ambulance" },

    -- Jobs allowed to see ambulance units on the tracker/map.
    ViewerJobs = { "police", "ambulance" },

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

-- ===================================================================
-- STAFF REVIVE COMMAND
-- A text-chat command for SERVER STAFF (not the ambulance job) to
-- revive themselves or another player by server ID. Works on both
-- QBCore and ESX. This file is escrow_ignore'd, so all of this stays
-- editable by server owners.
--
--   /revive        -> revives yourself
--   /revive [id]   -> revives the player with that server ID
-- ===================================================================
Config.Revive = {
    Enabled = true,
    Command = "revive",         -- the chat command name (/revive)
    RestoreArmor = false,       -- also set armour to 100 on revive
    ClearWanted = false,        -- clear the target's wanted level on revive
    Notify = true,              -- notify staff + revived player

    -- ── Who counts as "server staff" ────────────────────────────────
    -- A player may run the command if ANY of these pass. Add whichever
    -- fits how your server defines staff; leave the rest as-is.

    -- 1) ACE permission (framework-independent, recommended).
    --    Add to server.cfg, e.g.:
    --      add_ace group.admin ukhs.revive allow
    --    or grant per-identifier. Set to '' to disable this check.
    AcePermission = "ukhs.revive",

    -- 2) Generic FiveM 'command' ace (RCON / most admin setups already
    --    have this). Set false to require the specific ace above.
    AllowGenericCommandAce = true,

    -- 3) QBCore permission levels (uses QBCore.Functions.HasPermission).
    QBAdminPermissions = { "admin", "god" },

    -- 4) ESX admin groups (uses xPlayer group).
    ESXAdminGroups = { "admin", "superadmin", "mod" },

    -- Fire the framework's own ambulance revive events too, so any
    -- death/downed state managed by qb-ambulancejob / esx_ambulancejob
    -- is cleared in addition to the built-in native resurrect.
    FireFrameworkEvents = true,
}
