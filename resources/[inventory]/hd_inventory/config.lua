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
    { name = 'water_bottle', amount = 15 },
    { name = 'sandwich', amount = 15 },
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
-- back up. Renders as a real world prop (client/drops.lua).
Config.DropRadius = 2.0
Config.DropProp = 'prop_med_bag_01b' -- final fallback when nothing below matches

-- Per-item ground-drop props — every drop used to render as this same
-- generic Config.DropProp regardless of contents (see top-level
-- README's "Where to go from here"). server/drops.lua's
-- ResolveDropProp(data) picks a drop's first item and checks, in
-- order: that item's own shared/items.lua `model` field (explicit,
-- rare) → byName below → byType below (keyed on the item's `type`,
-- e.g. every weapon-type item at once) → Config.DropProp. A drop that
-- gains a second, different item afterward keeps the prop it was
-- created with — same "pick a tie-break rule, don't chase every
-- possible mixed pile" trade-off as the single generic model before
-- it. Add to either table freely; anything unmatched still falls back
-- to Config.DropProp exactly like before, nothing breaks.
Config.ItemDropProps = {
    byType = {
        weapon = 'prop_box_ammo04a',
    },
    byName = {
        -- cash / valuables
        moneybag = 'prop_cash_pile_01', goldbar = 'prop_cash_pile_01', goldchain = 'prop_cash_pile_01',
        ['10kgoldchain'] = 'prop_cash_pile_01', diamond_ring = 'prop_cash_pile_01', rolex = 'prop_cash_pile_01',
        casinochips = 'prop_cash_pile_01', markedbills = 'prop_cash_pile_01',

        -- phones / computers
        phone = 'prop_laptop_02b', iphone = 'prop_laptop_02b', samsungphone = 'prop_laptop_02b',
        laptop = 'prop_laptop_02b', tablet = 'prop_laptop_02b',

        -- documents / cards
        id_card = 'prop_cs_letter', driver_license = 'prop_cs_letter', bank_card = 'prop_cs_letter',
        weapon_license = 'prop_cs_letter', security_card_01 = 'prop_cs_letter', security_card_02 = 'prop_cs_letter',
        certificate = 'prop_cs_letter', lawyerpass = 'prop_cs_letter',

        -- tools / repair kits
        repairkit = 'prop_tool_box_04', repairkit_advanced = 'prop_tool_box_04', jump_cables = 'prop_tool_box_04',
        drill = 'prop_tool_box_04', cleaningkit = 'prop_tool_box_04', screwdriverset = 'prop_tool_box_04',
        advancedkit = 'prop_tool_box_04', electronickit = 'prop_tool_box_04', tirerepairkit = 'prop_tool_box_04',

        -- ammo (issued separately from the weapon-type items above)
        mg_ammo = 'prop_box_ammo04a', pistol_ammo = 'prop_box_ammo04a', rifle_ammo = 'prop_box_ammo04a',
        shotgun_ammo = 'prop_box_ammo04a', smg_ammo = 'prop_box_ammo04a',

        -- baggable contraband
        weed_baggy = 'prop_paper_bag_01', cocaine_baggy = 'prop_paper_bag_01', meth_baggy = 'prop_paper_bag_01',
        crack_baggy = 'prop_paper_bag_01', xtc_baggy = 'prop_paper_bag_01', oxy = 'prop_paper_bag_01',

        -- medical (matches Config.DropProp's own model, now explicit rather than an accidental global default)
        medkit = 'prop_med_bag_01b', bandage = 'prop_med_bag_01b', defibrillator = 'prop_med_bag_01b',
        trauma_kit = 'prop_med_bag_01b', splint = 'prop_med_bag_01b', morphine = 'prop_med_bag_01b',
        surgical_kit = 'prop_med_bag_01b', firstaid = 'prop_med_bag_01b', ifaks = 'prop_med_bag_01b',
    },
}

-- ═══════════════════════════ KEYBINDS ════════════════════════════════
Config.Keybind = 'TAB' -- opens the player's own inventory
Config.HotbarToggleKey = 'Z' -- hold to show the hotbar HUD; hidden by default, hides again on release

-- ═══════════════════════════ NOTIFY ══════════════════════════════════
Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
