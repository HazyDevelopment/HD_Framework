Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD INVENTORY | HAZY DEVELOPMENT | v1.0.0
--  Custom grid inventory — UX modelled on modern drag-and-drop store-
--  style inventories (Quasar Store and similar), built from scratch:
--  no third-party code or assets. Player inventory, shared stashes,
--  vehicle glovebox/trunk and ground drops all share one container
--  abstraction (see server/containers.lua) so every one of them
--  drag-drops into every other one for free.
-- ═══════════════════════════════════════════════════════════════════

-- ═══════════════════════════ PLAYER INVENTORY ═══════════════════════
Config.MaxSlots = 30
Config.MaxWeight = 30000   -- grams (30kg) — shared/items.lua weights are already gram-scale
Config.HotbarSlots = 5     -- slots 1-5 of the main grid double as the hotbar; keys 1-5 use them

-- Seeded into a citizen's inventory the very first time hd_inventory
-- ever loads it (i.e. their `players.inventory` column is still
-- NULL) — this is what makes hd_phone's Config.RequireItem check
-- actually pass for a brand-new character.
Config.StarterItems = {
    { name = 'phone', amount = 1 },
    { name = 'id_card', amount = 1 },
}

-- ═══════════════════════════ VEHICLE STORAGE ════════════════════════
-- Keyed by GetVehicleClass() (0-21, standard GTA vehicle classes) —
-- a van holds more than a sports car. `glovebox`/`trunk` set to `nil`
-- (i.e. just omitted) means that vehicle class has no storage of that
-- kind at all — a motorcycle has no glovebox — server/containers.lua
-- denies access outright rather than showing an empty 0-slot panel.
-- Anything not listed here (boats, aircraft, trains, and any class
-- Rockstar adds later) falls back to Config.DefaultCapacity.
Config.VehicleClassCapacity = {
    [0]  = { glovebox = { slots = 3, weight = 3000 },  trunk = { slots = 8,  weight = 8000 } },  -- Compacts
    [1]  = { glovebox = { slots = 5, weight = 5000 },  trunk = { slots = 15, weight = 15000 } }, -- Sedans
    [2]  = { glovebox = { slots = 5, weight = 5000 },  trunk = { slots = 20, weight = 20000 } }, -- SUVs
    [3]  = { glovebox = { slots = 4, weight = 4000 },  trunk = { slots = 10, weight = 10000 } }, -- Coupes
    [4]  = { glovebox = { slots = 4, weight = 4000 },  trunk = { slots = 12, weight = 12000 } }, -- Muscle
    [5]  = { glovebox = { slots = 3, weight = 3000 },  trunk = { slots = 6,  weight = 6000 } },  -- Sports Classics
    [6]  = { glovebox = { slots = 3, weight = 3000 },  trunk = { slots = 6,  weight = 6000 } },  -- Sports
    [7]  = { glovebox = { slots = 2, weight = 2000 },  trunk = { slots = 4,  weight = 4000 } },  -- Super
    [8]  = { trunk = { slots = 2, weight = 2000 } },                                             -- Motorcycles — no glovebox
    [9]  = { glovebox = { slots = 5, weight = 5000 },  trunk = { slots = 18, weight = 18000 } }, -- Off-road
    [10] = { glovebox = { slots = 6, weight = 6000 },  trunk = { slots = 40, weight = 40000 } }, -- Industrial
    [11] = { glovebox = { slots = 5, weight = 5000 },  trunk = { slots = 30, weight = 30000 } }, -- Utility
    [12] = { glovebox = { slots = 6, weight = 6000 },  trunk = { slots = 35, weight = 35000 } }, -- Vans
    [13] = {},                                                                                    -- Cycles — no storage at all
    [17] = { glovebox = { slots = 5, weight = 5000 },  trunk = { slots = 20, weight = 20000 } }, -- Service
    [18] = { glovebox = { slots = 6, weight = 6000 },  trunk = { slots = 25, weight = 25000 } }, -- Emergency
    [19] = { glovebox = { slots = 6, weight = 6000 },  trunk = { slots = 40, weight = 40000 } }, -- Military
    [20] = { glovebox = { slots = 8, weight = 8000 },  trunk = { slots = 50, weight = 50000 } }, -- Commercial
}
Config.DefaultCapacity = { glovebox = { slots = 5, weight = 5000 }, trunk = { slots = 15, weight = 15000 } }
Config.VehicleInteractDistance = 3.0

-- ═══════════════════════════ STASHES ═════════════════════════════════
-- Any other resource can open one via
-- exports['hd_inventory']:OpenStash(id, label, slots, weight) — it's
-- auto-created in the DB on first open with whatever size is passed
-- (or the defaults below if omitted). Same id always returns the same
-- shared contents to everyone who opens it.
Config.StashDefaults = { slots = 30, weight = 30000 }

-- ═══════════════════════════ GROUND DROPS ════════════════════════════
-- Persisted in `hd_inventory_drops` — a drop survives a restart and is
-- reloaded into memory (server/drops.lua) the moment the server comes
-- back up. Renders as a real world prop now too (client/drops.lua) —
-- one generic model for every drop rather than one accurate prop per
-- item, same trade-off ox_inventory itself makes with its own default.
Config.DropRadius = 2.0
Config.DropProp = 'prop_med_bag_01b'

-- ═══════════════════════════ KEYBINDS ════════════════════════════════
Config.Keybind = 'TAB' -- opens the player's own inventory

-- ═══════════════════════════ NOTIFY ══════════════════════════════════
Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
