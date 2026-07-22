-- ═══════════════════════════════════════════════════════════════════
--  HD_FRAMEWORK | SHARED ITEMS
--  Starter item table — just enough for uk_policejob and uk_uhsjob's
--  rank loadouts (server/player.lua AddItem checks names against this
--  table) plus basic civilian essentials, so nothing errors before
--  the custom Quasar-style inventory resource (a later build phase)
--  adds full item icons/metadata/crafting. Add items here freely —
--  the inventory resource reads this same global `Items` table.
-- ═══════════════════════════════════════════════════════════════════

Items = {}

local function item(name, label, weight, opts)
    opts = opts or {}
    Items[name] = {
        name = name,
        label = label,
        weight = weight or 0,
        type = opts.type or 'item',
        image = opts.image or (name .. '.png'),
        unique = opts.unique or false,
        useable = opts.useable or false,
        shouldClose = opts.shouldClose or false,
        combinable = opts.combinable or nil,
        description = opts.description or '',
    }
end

-- ═══════════════════════════ IDENTIFICATION ═════════════════════════
item('id_card', 'ID Card', 0, { unique = true, description = 'UK national identity card' })
item('driver_license', "Driving Licence", 0, { unique = true, description = 'UK driving licence' })

-- ═══════════════════════════ POLICE LOADOUT ══════════════════════════
item('radio', 'Police Radio', 200, { useable = true, description = 'Departmental communications radio' })
item('handcuffs', 'Handcuffs', 250, { useable = true, description = 'Restrains a suspect' })
item('armorplate', 'Armour Plate', 1000, { useable = true, description = 'Protective ballistic plate' })

-- ═══════════════════════════ UHS / MEDICAL LOADOUT ═══════════════════
item('bandage', 'Bandage', 100, { useable = true, description = 'Stops light bleeding' })
item('painkillers', 'Painkillers', 100, { useable = true, description = 'Eases pain from injury' })
item('medkit', 'Medical Kit', 500, { useable = true, description = 'Treats moderate injuries' })
item('splint', 'Splint', 300, { useable = true, description = 'Stabilises a fracture' })
item('defibrillator', 'Defibrillator', 2000, { useable = true, description = 'Restarts the heart in cardiac arrest' })
item('oxygen_mask', 'Oxygen Mask', 800, { useable = true, description = 'Restores breathing capacity' })
item('morphine', 'Morphine', 150, { useable = true, description = 'Strong pain relief for critical injuries' })
item('stretcher', 'Stretcher', 3000, { description = 'Carries an incapacitated patient' })
item('surgical_kit', 'Surgical Kit', 2500, { useable = true, description = 'Field surgery for critical trauma' })

-- ═══════════════════════════ MECHANIC / RECOVERY ═════════════════════
item('repairkit', 'Repair Kit', 1500, { useable = true, description = 'Repairs a damaged vehicle on-site' })
item('repairkit_advanced', 'Advanced Repair Kit', 2500, { useable = true, description = "Field-fixes a vehicle in limp mode — brings the engine back to a driveable state, not a full repair" })
item('jump_cables', 'Jump Cables', 500, { useable = true, description = 'Jump-starts a dead vehicle battery' })
item('tow_hook', 'Tow Hook', 800, { description = 'Attaches a vehicle to the recovery truck' })

-- ═══════════════════════════ CIVILIAN ESSENTIALS ═════════════════════
item('phone', 'Mobile Phone', 200, { useable = true, unique = true, description = 'Opens your phone' })
item('water_bottle', 'Bottle of Water', 300, { useable = true, description = 'Quenches thirst' })
item('sandwich', 'Sandwich', 300, { useable = true, description = 'Fills you up a little' })
