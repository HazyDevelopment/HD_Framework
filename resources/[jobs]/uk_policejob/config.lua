Config = {}

-- ===================================================================
-- FRAMEWORK SELECTION
-- ===================================================================
Config.Framework = "qbcore" -- "qbcore" or "esx"

-- Job name to check against, per framework. Both default to "police"
-- — change the one that matches your actual job name if it differs
-- (this is the name used in qb-core/shared/jobs.lua or your ESX
-- esx_jobs table).
Config.PoliceJob = {
    qbcore = "police",
    esx    = "police",
}

-- Require on-duty (clocked in at a station) to use the garage,
-- armoury, evidence locker, fingerprint scanner, and to be trackable
-- on the GPS system.
Config.RequireOnDuty = true

Config.DepartmentName = "United Kingdom Police"
Config.ShortName      = "UKP"

-- ===================================================================
-- RANKS
-- Grade numbers match your job's grade field (QBCore: job.grade.level,
-- ESX: job grade). Grade 0 = PCSO. 5-8 = Armed Response Unit tier.
-- 9+ = senior command, topping out at Commissioner (isBoss = true,
-- gets the framework's boss/society menu access where applicable).
--
-- Each rank's Loadout is what the armoury will let that rank draw.
-- `weapons` entries are { name = "WEAPON_X", ammo = number }.
-- `items` entries are { name = "item_name", count = number } — these
-- must already exist as valid items in your inventory system
-- (qb-core/shared/items.lua, ESX items table, ox_inventory items, etc)
-- — this resource just calls the standard AddItem-style function for
-- whichever framework you're on, it doesn't create item definitions.
-- ===================================================================
Config.Ranks = {
    [0] = {
        label = "PCSO",
        isArmedResponse = false,
        isCommand = false,
        isBoss = false,
        loadout = {
            weapons = {{ name = "WEAPON_NIGHTSTICK", ammo = 1 },},
            items = { { name = "radio", count = 1 },
                      { name = "handcuffs", count = 1 },
                      },
            armor = 25,
        },
    },
    [1] = {
        label = "Police Constable",
        isArmedResponse = false,
        isCommand = false,
        isBoss = false,
        loadout = {
            weapons = {
                { name = "WEAPON_STUNGUN", ammo = 1 },
                { name = "WEAPON_NIGHTSTICK", ammo = 1 },
            },
            items = { { name = "handcuffs", count = 2 }, { name = "radio", count = 1 } },
            armor = 25,
        },
    },
    [2] = {
        label = "Sergeant",
        isArmedResponse = false,
        isCommand = false,
        isBoss = false,
        loadout = {
            weapons = {
                { name = "WEAPON_STUNGUN", ammo = 1 },
                { name = "WEAPON_NIGHTSTICK", ammo = 1 },
                { name = "WEAPON_FLASHLIGHT", ammo = 1 },
            },
            items = { { name = "handcuffs", count = 2 }, { name = "radio", count = 1 } },
            armor = 25,
        },
    },
    [3] = {
        label = "Inspector",
        isArmedResponse = false,
        isCommand = false,
        isBoss = false,
        loadout = {
            weapons = {
                { name = "WEAPON_STUNGUN", ammo = 1 },
                { name = "WEAPON_NIGHTSTICK", ammo = 1 },
                { name = "WEAPON_FLASHLIGHT", ammo = 1 },
            },
            items = { { name = "handcuffs", count = 2 }, { name = "radio", count = 1 } },
            armor = 25,
        },
    },
    [4] = {
        label = "Chief Inspector",
        isArmedResponse = false,
        isCommand = true, -- basic police command, per spec
        isBoss = false,
        loadout = {
            weapons = {
                { name = "WEAPON_STUNGUN", ammo = 1 },
                { name = "WEAPON_NIGHTSTICK", ammo = 1 },
                { name = "WEAPON_FLASHLIGHT", ammo = 1 },
                { name = "WEAPON_PISTOL", ammo = 60 },
            },
            items = { { name = "handcuffs", count = 2 }, { name = "radio", count = 1 } },
            armor = 25,
        },
    },

    -- -----------------------------------------------------------
    -- Armed Response tier (5-8)
    -- -----------------------------------------------------------
    [5] = {
        label = "Armed Response Officer",
        isArmedResponse = true,
        isCommand = false,
        isBoss = false,
        loadout = {
            weapons = {
                { name = "WEAPON_STUNGUN", ammo = 1 },
                { name = "WEAPON_NIGHTSTICK", ammo = 1 },
                { name = "WEAPON_COMBATPISTOL", ammo = 90 },
                { name = "WEAPON_CARBINERIFLE", ammo = 150 },
            },
            items = { { name = "handcuffs", count = 4 }, { name = "radio", count = 1 }, { name = "armorplate", count = 2 } },
            armor = 50,
        },
    },
    [6] = {
        label = "ARV Sergeant",
        isArmedResponse = true,
        isCommand = false,
        isBoss = false,
        loadout = {
            weapons = {
                { name = "WEAPON_STUNGUN", ammo = 1 },
                { name = "WEAPON_NIGHTSTICK", ammo = 1 },
                { name = "WEAPON_COMBATPISTOL", ammo = 90 },
                { name = "WEAPON_CARBINERIFLE", ammo = 150 },
                { name = "WEAPON_PUMPSHOTGUN", ammo = 40 },
            },
            items = { { name = "handcuffs", count = 4 }, { name = "radio", count = 1 }, { name = "armorplate", count = 2 } },
            armor = 50,
        },
    },
    [7] = {
        label = "ARV Inspector",
        isArmedResponse = true,
        isCommand = true,
        isBoss = false,
        loadout = {
            weapons = {
                { name = "WEAPON_STUNGUN", ammo = 1 },
                { name = "WEAPON_NIGHTSTICK", ammo = 1 },
                { name = "WEAPON_COMBATPISTOL", ammo = 90 },
                { name = "WEAPON_CARBINERIFLE", ammo = 150 },
                { name = "WEAPON_PUMPSHOTGUN", ammo = 40 },
                { name = "WEAPON_SPECIALCARBINE", ammo = 150 },
            },
            items = { { name = "handcuffs", count = 4 }, { name = "radio", count = 1 }, { name = "armorplate", count = 3 } },
            armor = 75,
        },
    },
    [8] = {
        label = "ARV Commander",
        isArmedResponse = true,
        isCommand = true,
        isBoss = false,
        loadout = {
            weapons = {
                { name = "WEAPON_STUNGUN", ammo = 1 },
                { name = "WEAPON_NIGHTSTICK", ammo = 1 },
                { name = "WEAPON_COMBATPISTOL", ammo = 90 },
                { name = "WEAPON_CARBINERIFLE", ammo = 150 },
                { name = "WEAPON_PUMPSHOTGUN", ammo = 40 },
                { name = "WEAPON_SPECIALCARBINE", ammo = 150 },
                { name = "WEAPON_MARKSMANRIFLE", ammo = 60 },
            },
            items = { { name = "handcuffs", count = 6 }, { name = "radio", count = 1 }, { name = "armorplate", count = 4 } },
            armor = 100,
        },
    },

    -- -----------------------------------------------------------
    -- Senior command (9+) — Superintendent up through Commissioner
    -- -----------------------------------------------------------
    [9] = {
        label = "Superintendent",
        isArmedResponse = false,
        isCommand = true,
        isBoss = false,
        loadout = {
            weapons = {
                { name = "WEAPON_STUNGUN", ammo = 1 },
                { name = "WEAPON_NIGHTSTICK", ammo = 1 },
                { name = "WEAPON_PISTOL", ammo = 60 },
            },
            items = { { name = "handcuffs", count = 2 }, { name = "radio", count = 1 } },
            armor = 50,
        },
    },
    [10] = {
        label = "Chief Superintendent",
        isArmedResponse = false,
        isCommand = true,
        isBoss = false,
        loadout = {
            weapons = {
                { name = "WEAPON_STUNGUN", ammo = 1 },
                { name = "WEAPON_NIGHTSTICK", ammo = 1 },
                { name = "WEAPON_PISTOL", ammo = 60 },
            },
            items = { { name = "handcuffs", count = 2 }, { name = "radio", count = 1 } },
            armor = 50,
        },
    },
    [11] = {
        label = "Commander",
        isArmedResponse = false,
        isCommand = true,
        isBoss = false,
        loadout = {
            weapons = {
                { name = "WEAPON_STUNGUN", ammo = 1 },
                { name = "WEAPON_NIGHTSTICK", ammo = 1 },
                { name = "WEAPON_PISTOL", ammo = 60 },
            },
            items = { { name = "handcuffs", count = 2 }, { name = "radio", count = 1 } },
            armor = 50,
        },
    },
    [12] = {
        label = "Deputy Assistant Commissioner",
        isArmedResponse = false,
        isCommand = true,
        isBoss = false,
        loadout = {
            weapons = {
                { name = "WEAPON_STUNGUN", ammo = 1 },
                { name = "WEAPON_PISTOL", ammo = 60 },
            },
            items = { { name = "handcuffs", count = 2 }, { name = "radio", count = 1 } },
            armor = 50,
        },
    },
    [13] = {
        label = "Assistant Commissioner",
        isArmedResponse = false,
        isCommand = true,
        isBoss = false,
        loadout = {
            weapons = {
                { name = "WEAPON_STUNGUN", ammo = 1 },
                { name = "WEAPON_PISTOL", ammo = 60 },
            },
            items = { { name = "handcuffs", count = 2 }, { name = "radio", count = 1 } },
            armor = 50,
        },
    },
    [14] = {
        label = "Deputy Commissioner",
        isArmedResponse = false,
        isCommand = true,
        isBoss = false,
        loadout = {
            weapons = {
                { name = "WEAPON_STUNGUN", ammo = 1 },
                { name = "WEAPON_PISTOL", ammo = 60 },
            },
            items = { { name = "handcuffs", count = 2 }, { name = "radio", count = 1 } },
            armor = 50,
        },
    },
    [15] = {
        label = "Commissioner",
        isArmedResponse = false,
        isCommand = true,
        isBoss = true, -- top of the job — gets boss/society menu access where the framework supports it
        loadout = {
            weapons = {
                { name = "WEAPON_STUNGUN", ammo = 1 },
                { name = "WEAPON_PISTOL", ammo = 60 },
            },
            items = { { name = "handcuffs", count = 2 }, { name = "radio", count = 1 } },
            armor = 100,
        },
    },
}

-- ===================================================================
-- STATIONS
-- Every vector below is exactly what you'll move to relocate a
-- station's garage/armoury/clock-in/evidence locker/fingerprint
-- scanner — just edit the coordinates, nothing else needs touching.
-- Add more entries to open additional stations.
-- ===================================================================
Config.Stations = {
    {
        label = "New Scotland Yard",

        ClockIn = vector4(441.0, -981.0, 30.7, 90.0),

        Armoury = vector4(452.6, -980.0, 30.7, 90.0),

        -- Garage: where the vehicle-selection menu opens, and the list
        -- of spawn points it'll try in order (so multiple vehicles
        -- pulled at once don't stack on each other).
        Garage = {
            Trigger = vector4(454.6, -1017.0, 28.4, 0.0),
            SpawnPoints = {
                vector4(441.6, -1018.0, 28.4, 320.0),
                vector4(446.0, -1022.0, 28.4, 320.0),
                vector4(450.4, -1026.0, 28.4, 320.0),
            },
        },

        EvidenceLocker = vector4(459.6, -993.0, 30.7, 180.0),

        FingerprintScanner = vector4(459.9, -984.7, 30.7, 180.0),
    },
}

-- ===================================================================
-- GARAGE VEHICLES
-- The full fleet list. MinGrade gates who can pull it — e.g. ARV
-- vehicles only show up for rank 5+ (Armed Response tier and up).
-- `model` must be a valid vehicle spawn name on your server.
-- ===================================================================
Config.GarageVehicles = {
    { model = "police",    label = "Vauxhall Interceptor (Marked)", minGrade = 0 },
    { model = "police2",   label = "Ford Focus (Marked)",           minGrade = 0 },
    { model = "police3",   label = "Dodge Charger (Unmarked)",      minGrade = 2 },
    { model = "police4",   label = "Unmarked Sedan",                minGrade = 4 },
    { model = "riot",      label = "ARV Response Van",              minGrade = 5 },
    { model = "policeb",   label = "Response Motorcycle",           minGrade = 1 },
    { model = "fbi",       label = "Command SUV",                   minGrade = 9 },
    { model = "fbi2",      label = "Senior Command Saloon",         minGrade = 12 },
}

-- ===================================================================
-- GPS TRACKING
-- Lets police (and optionally ambulance) see live blips for anyone
-- carrying/assigned a tracker, on-duty units in the same job, or both
-- — configurable below. Integrates with wasabi_gps if it's running;
-- otherwise falls back to this resource's own lightweight blip system.
-- ===================================================================
Config.GPS = {
    -- ===============================================================
    -- Single true/false switch. When a different server has
    -- wasabi_gps installed, set this true and this resource will hand
    -- GPS tracking off to it automatically via its real, documented
    -- exports (docs.wasabiscripts.com/wasabi-scripts/free-releases/wasabi_gps/exports):
    --   exports.wasabi_gps:registerJob({ job, tracked, subscribers, blipSettings, item })
    --   exports.wasabi_gps:unregisterJob(job)
    -- Once registered, wasabi_gps owns tracking/subscriptions/blips
    -- for that job entirely.
    --
    -- Set this to false (or just don't install wasabi_gps) and this
    -- resource uses its own built-in ping + blip system instead —
    -- zero external dependencies, same TrackableJobs/ViewerJobs rules
    -- apply either way. If wasabi_gps is enabled here but isn't
    -- actually installed/running on a given server, this resource
    -- detects that automatically and falls back to the built-in
    -- system too — so this is safe to leave "true" even on servers
    -- that don't have wasabi_gps.
    -- ===============================================================
    UseWasabiGPS = true,
    WasabiResourceName = "wasabi_gps",

    -- Jobs whose on-duty members are trackable.
    TrackableJobs = { "police", "ambulance" },

    -- Jobs allowed to see tracked units — passed to wasabi_gps as its
    -- `subscribers` list when UseWasabiGPS is active, and used to
    -- gate the built-in fallback's blips/NUI list the same way.
    ViewerJobs = { "police", "ambulance" },

    -- Optional: require this item to be carried to be tracked
    -- (wasabi_gps's item-based GPS toggle). Leave nil to always track
    -- on-duty members of TrackableJobs with no item requirement. Only
    -- takes effect when UseWasabiGPS is active — the built-in
    -- fallback doesn't have an item-gate.
    Item = nil,

    -- Optional per-job blip appearance, passed straight through to
    -- wasabi_gps's registerJob `blipSettings`. Ignored by the
    -- built-in fallback (which uses its own fixed blip style).
    BlipSettings = {
        police    = { color = 38, scale = 0.8, short = true, category = 7 },
        ambulance = { color = 3,  scale = 0.8, short = true, category = 7 },
    },

    -- How often (ms) the built-in fallback pushes position/polls.
    -- Not used while wasabi_gps is handling delivery.
    UpdateInterval = 5000,
}
