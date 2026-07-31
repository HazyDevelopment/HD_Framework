Config = {}

-- ═══════════════════════════════════════════════════════════════════
-- hd_policejob — hand-written UK police job for the real, standalone
-- HD_Framework (exports['HD_Framework']:GetCoreObject()). Fills the
-- gap left by uk_policejob, which is escrow-encrypted and cannot run
-- on this server (see this server's top-level README).
--
-- Same shape as hd_ems (the ambulance job): ranks/loadout config,
-- armoury, GPS. GPS deliberately reuses hd_ems's existing client-side
-- blip renderer (event names ukhs:client:gpsUpdate / ukhs:client:
-- gpsRemove — kept under their old uk_uhsjob-era names, see
-- hd_ems/config.lua's GPS section) instead of building a parallel one
-- — that renderer already color-codes police blips blue, it just
-- never had anything pushing "police" units into it before now.
-- ═══════════════════════════════════════════════════════════════════

Config.JobName = 'police'          -- must match the key in HD_Framework/shared/jobs.lua
Config.RequireOnDuty = true        -- must be on duty to use the armoury / show on GPS

Config.DepartmentName = 'United Kingdom Police'
Config.ShortName = 'UKP'

-- ═══════════════════════════════════════════════════════════════════
-- WEAPON AMMO
-- Weapons are real hd_inventory items now (see HD_Framework/shared/
-- items.lua's "Weapon-type items" section) — placeable/moveable/
-- tradeable/droppable like any other item, not auto-equipped the
-- moment they're drawn. "Use" on one toggles it in the ped's hand
-- (hd_inventory's own client/main.lua). This table just says how much
-- ammo to stamp into an issued firearm's metadata; melee/utility
-- items (baton/torch/taser) don't need an entry, they default to 0.
-- ═══════════════════════════════════════════════════════════════════
Config.WeaponAmmo = {
    weapon_pistol       = 60,
    weapon_carbinerifle = 150,
    weapon_pumpshotgun  = 32,
}

-- Short icon-file names for this resource's own armoury NUI
-- (html/images/*.svg) — independent of the real hd_inventory item
-- name, which any catalog entry not listed here just falls back to.
Config.IconNames = {
    weapon_nightstick   = 'baton',
    weapon_flashlight   = 'torch',
    weapon_stungun      = 'taser',
    weapon_pistol       = 'pistol',
    weapon_carbinerifle = 'carbine',
    weapon_pumpshotgun  = 'shotgun',
}

-- ═══════════════════════════════════════════════════════════════════
-- RANKS
-- Grade numbers/labels match HD_Framework/shared/jobs.lua's `police`
-- entry exactly — that file is the source of truth for the officer's
-- actual grade/label, this table only adds armoury behaviour on top.
--
-- loadout.items entries are { name = "item_name", count = number },
-- real hd_inventory items (must exist in HD_Framework/shared/items.lua)
-- — includes both ordinary equipment and weapon-type items alike.
-- ═══════════════════════════════════════════════════════════════════
Config.Ranks = {
    [0] = { -- PCSO
        label = 'PCSO', isArmedResponse = false, isCommand = false, isBoss = false,
        loadout = { items = {
            { name = 'weapon_nightstick', count = 1 },
            { name = 'weapon_flashlight', count = 1 },
            { name = 'handcuffs', count = 1 },
            { name = 'radio', count = 1 },
        } },
    },
    [1] = { -- Police Constable — PCSO loadout + taser
        label = 'Police Constable', isArmedResponse = false, isCommand = false, isBoss = false,
        loadout = { items = {
            { name = 'weapon_nightstick', count = 1 },
            { name = 'weapon_flashlight', count = 1 },
            { name = 'weapon_stungun', count = 1 },
            { name = 'handcuffs', count = 2 },
            { name = 'radio', count = 1 },
        } },
    },
    [2] = { -- Sergeant
        label = 'Sergeant', isArmedResponse = false, isCommand = false, isBoss = false,
        loadout = { items = {
            { name = 'weapon_nightstick', count = 1 },
            { name = 'weapon_flashlight', count = 1 },
            { name = 'weapon_stungun', count = 1 },
            { name = 'handcuffs', count = 2 },
            { name = 'radio', count = 1 },
        } },
    },
    [3] = { -- Inspector
        label = 'Inspector', isArmedResponse = false, isCommand = false, isBoss = false,
        loadout = { items = {
            { name = 'weapon_nightstick', count = 1 },
            { name = 'weapon_flashlight', count = 1 },
            { name = 'weapon_stungun', count = 1 },
            { name = 'handcuffs', count = 2 },
            { name = 'radio', count = 1 },
        } },
    },
    [4] = { -- Chief Inspector
        label = 'Chief Inspector', isArmedResponse = false, isCommand = true, isBoss = false,
        loadout = { items = {
            { name = 'weapon_nightstick', count = 1 },
            { name = 'weapon_flashlight', count = 1 },
            { name = 'weapon_stungun', count = 1 },
            { name = 'handcuffs', count = 2 },
            { name = 'radio', count = 1 },
        } },
    },

    -- ─────────────────────────────────────────────────────────────
    -- Armed Response Vehicle tier — the only ranks issued firearms.
    -- ─────────────────────────────────────────────────────────────
    [5] = { -- Armed Response Officer
        label = 'Armed Response Officer', isArmedResponse = true, isCommand = false, isBoss = false,
        loadout = { items = {
            { name = 'weapon_nightstick', count = 1 },
            { name = 'weapon_flashlight', count = 1 },
            { name = 'weapon_stungun', count = 1 },
            { name = 'weapon_pistol', count = 1 },
            { name = 'weapon_carbinerifle', count = 1 },
            { name = 'weapon_pumpshotgun', count = 1 },
            { name = 'handcuffs', count = 4 },
            { name = 'radio', count = 1 },
            { name = 'armorplate', count = 2 },
        } },
    },
    [6] = { -- ARV Sergeant
        label = 'ARV Sergeant', isArmedResponse = true, isCommand = false, isBoss = false,
        loadout = { items = {
            { name = 'weapon_nightstick', count = 1 },
            { name = 'weapon_flashlight', count = 1 },
            { name = 'weapon_stungun', count = 1 },
            { name = 'weapon_pistol', count = 1 },
            { name = 'weapon_carbinerifle', count = 1 },
            { name = 'weapon_pumpshotgun', count = 1 },
            { name = 'handcuffs', count = 4 },
            { name = 'radio', count = 1 },
            { name = 'armorplate', count = 3 },
        } },
    },
    [7] = { -- ARV Inspector
        label = 'ARV Inspector', isArmedResponse = true, isCommand = true, isBoss = false,
        loadout = { items = {
            { name = 'weapon_nightstick', count = 1 },
            { name = 'weapon_flashlight', count = 1 },
            { name = 'weapon_stungun', count = 1 },
            { name = 'weapon_pistol', count = 1 },
            { name = 'weapon_carbinerifle', count = 1 },
            { name = 'weapon_pumpshotgun', count = 1 },
            { name = 'handcuffs', count = 6 },
            { name = 'radio', count = 1 },
            { name = 'armorplate', count = 3 },
        } },
    },
    [8] = { -- ARV Commander
        label = 'ARV Commander', isArmedResponse = true, isCommand = true, isBoss = false,
        loadout = { items = {
            { name = 'weapon_nightstick', count = 1 },
            { name = 'weapon_flashlight', count = 1 },
            { name = 'weapon_stungun', count = 1 },
            { name = 'weapon_pistol', count = 1 },
            { name = 'weapon_carbinerifle', count = 1 },
            { name = 'weapon_pumpshotgun', count = 1 },
            { name = 'handcuffs', count = 6 },
            { name = 'radio', count = 1 },
            { name = 'armorplate', count = 4 },
        } },
    },

    -- ─────────────────────────────────────────────────────────────
    -- Senior command — Superintendent up to Commissioner. Plain
    -- clothes / office rank: no firearms unless also ARV-tagged.
    -- ─────────────────────────────────────────────────────────────
    [9]  = { label = 'Superintendent',               isArmedResponse = false, isCommand = true, isBoss = false,
        loadout = { items = {
            { name = 'weapon_nightstick', count = 1 }, { name = 'weapon_flashlight', count = 1 }, { name = 'weapon_stungun', count = 1 },
            { name = 'handcuffs', count = 2 }, { name = 'radio', count = 1 },
        } } },
    [10] = { label = 'Chief Superintendent',         isArmedResponse = false, isCommand = true, isBoss = false,
        loadout = { items = {
            { name = 'weapon_nightstick', count = 1 }, { name = 'weapon_flashlight', count = 1 }, { name = 'weapon_stungun', count = 1 },
            { name = 'handcuffs', count = 2 }, { name = 'radio', count = 1 },
        } } },
    [11] = { label = 'Commander',                    isArmedResponse = false, isCommand = true, isBoss = false,
        loadout = { items = {
            { name = 'weapon_nightstick', count = 1 }, { name = 'weapon_flashlight', count = 1 }, { name = 'weapon_stungun', count = 1 },
            { name = 'handcuffs', count = 2 }, { name = 'radio', count = 1 },
        } } },
    [12] = { label = 'Deputy Assistant Commissioner', isArmedResponse = false, isCommand = true, isBoss = false,
        loadout = { items = {
            { name = 'weapon_nightstick', count = 1 }, { name = 'weapon_flashlight', count = 1 }, { name = 'weapon_stungun', count = 1 },
            { name = 'handcuffs', count = 2 }, { name = 'radio', count = 1 },
        } } },
    [13] = { label = 'Assistant Commissioner',        isArmedResponse = false, isCommand = true, isBoss = false,
        loadout = { items = {
            { name = 'weapon_nightstick', count = 1 }, { name = 'weapon_flashlight', count = 1 }, { name = 'weapon_stungun', count = 1 },
            { name = 'handcuffs', count = 2 }, { name = 'radio', count = 1 },
        } } },
    [14] = { label = 'Deputy Commissioner',           isArmedResponse = false, isCommand = true, isBoss = false,
        loadout = { items = {
            { name = 'weapon_nightstick', count = 1 }, { name = 'weapon_flashlight', count = 1 }, { name = 'weapon_stungun', count = 1 },
            { name = 'handcuffs', count = 2 }, { name = 'radio', count = 1 },
        } } },
    [15] = { -- Commissioner — boss of the job
        label = 'Commissioner', isArmedResponse = false, isCommand = true, isBoss = true,
        loadout = { items = {
            { name = 'weapon_nightstick', count = 1 }, { name = 'weapon_flashlight', count = 1 }, { name = 'weapon_stungun', count = 1 },
            { name = 'handcuffs', count = 2 }, { name = 'radio', count = 1 },
        } } },
}

-- ═══════════════════════════════════════════════════════════════════
-- STATIONS
-- ═══════════════════════════════════════════════════════════════════
Config.Stations = {
    {
        label = 'New Scotland Yard',
        ClockIn = vector4(441.8, -981.9, 30.68, 90.0),
        Armoury = vector4(452.6, -980.4, 30.68, 90.0),
    },
}

Config.InteractDistance = 10.0
Config.InteractPressDistance = 1.5

-- ═══════════════════════════════════════════════════════════════════
-- DETAIN ON WARRANT
-- The actual enforcement mechanic hd_fines' auto-warrant was missing —
-- see the top-level README's "Where to go from here". An on-duty
-- officer standing next to a citizen with an active hazy_mdt warrant
-- can run /detain [server id]: it verifies the warrant server-side via
-- hazy_mdt's GetActiveWarrants/ClearWarrantsForCitizen exports, clears
-- it, and holds the citizen (frozen, in a cell) for HoldSeconds. Soft
-- dependency on hazy_mdt — with it not running, /detain just refuses
-- with "MDT is not running" rather than erroring.
-- ═══════════════════════════════════════════════════════════════════
Config.Detain = {
    Distance = 3.0,                              -- must be this close to the target to detain them
    HoldSeconds = 300,                            -- 5 minutes in the holding cell
    Cell = vector4(459.8, -993.9, 24.9, 160.0),   -- New Scotland Yard holding cell, below the ClockIn floor
}

-- ═══════════════════════════════════════════════════════════════════
-- PANIC BUTTON
-- /panic — the radio's emergency button, reachable as a command too
-- for whoever doesn't have Hold-key muscle memory for it. Raises a
-- top-priority hd_dispatch call visible to BOTH police and ambulance
-- (see hd_dispatch/config.lua's 'panic' call type) and plays hd_radio's
-- Panic.ogg for every eligible responder, same as the radio's own
-- panic button — see client/panic.lua and server/panic.lua.
-- ═══════════════════════════════════════════════════════════════════
Config.Panic = {
    Command = 'panic',
    Cooldown = 30, -- seconds between presses per officer, stops spam
}

-- ═══════════════════════════════════════════════════════════════════
-- GPS TRACKING
-- Companion design, mirrors uk_uhsjob/config.lua's own GPS section:
-- this resource only ever tracks/pushes ITS OWN job ("police"). Reuses
-- uk_uhsjob's existing client-side event names on purpose (see the
-- header note above) so both jobs' officers render on the exact same
-- blip system, already running on every connected client.
-- ═══════════════════════════════════════════════════════════════════
Config.GPS = {
    TrackableJobs = { 'police' },
    ViewerJobs    = { 'police', 'ambulance' },
    UpdateInterval = 5000, -- ms, matches uk_uhsjob's own default
}
