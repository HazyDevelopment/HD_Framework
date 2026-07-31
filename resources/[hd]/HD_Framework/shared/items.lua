-- ═══════════════════════════════════════════════════════════════════
--  HD_FRAMEWORK | SHARED ITEMS
--  Starter item table — just enough for uk_policejob and hd_ems's
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
        -- Reusable tools (the mechanic tablet, in practice) set this to
        -- false so hd_inventory's useItem/useHotbar handlers don't
        -- delete them on use like a one-shot consumable — defaults to
        -- true so every existing item keeps its current behaviour.
        consumable = opts.consumable == nil and true or opts.consumable,
        shouldClose = opts.shouldClose or false,
        combinable = opts.combinable or nil,
        description = opts.description or '',
        -- Optional explicit ground-drop prop override, read by
        -- hd_inventory's server/drops.lua. Almost nothing needs to set
        -- this — most items are covered by Config.ItemDropProps'
        -- byName/byType fallback maps in hd_inventory/config.lua
        -- instead; this is only for the rare item that needs its own
        -- model regardless of what those maps say.
        model = opts.model or nil,
    }
end

-- ═══════════════════════════ IDENTIFICATION ═════════════════════════
item('id_card', 'ID Card', 0, { unique = true, description = 'UK national identity card' })
item('driver_license', "Driving Licence", 0, { unique = true, description = 'UK driving licence' })

-- ═══════════════════════════ POLICE LOADOUT ══════════════════════════
item('radio', 'Radio', 200, { useable = true, consumable = false, description = 'Communications radio' })
item('handcuffs', 'Handcuffs', 250, { useable = true, description = 'Restrains a suspect' })
item('armorplate', 'Armour Plate', 1000, { useable = true, image = 'armor.png', description = 'Protective ballistic plate' })

-- Weapon-type items: real, placeable/moveable/tradeable inventory items,
-- not auto-equipped straight to the ped. "Use" (hd_inventory's own
-- server/inventory.lua) toggles them in the ped's hand instead of
-- consuming them — the item `name` IS the weapon hash, lowercased, same
-- convention QBCore-ecosystem weapon items use (GetHashKey(name:upper())
-- in hd_inventory/client/main.lua). Firearms are issued with an `ammo`
-- metadata value by whichever armoury hands them out; melee/utility ones
-- don't need it.
item('weapon_nightstick',   'Baton',         1000, { type = 'weapon', unique = true, useable = true, description = 'Standard-issue police baton' })
item('weapon_flashlight',   'Torch',         400,  { type = 'weapon', unique = true, useable = true, description = 'Police-issue torch' })
item('weapon_stungun',      'Taser X2',      800,  { type = 'weapon', unique = true, useable = true, description = 'Conducted energy device' })
item('weapon_pistol',       'Glock 17',      1200, { type = 'weapon', unique = true, useable = true, description = 'ARV-issue sidearm' })
item('weapon_carbinerifle', 'Carbine Rifle', 3400, { type = 'weapon', unique = true, useable = true, description = 'ARV-issue carbine rifle' })
item('weapon_pumpshotgun',  'Pump Shotgun',  3200, { type = 'weapon', unique = true, useable = true, description = 'ARV-issue pump shotgun' })

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
item('trauma_kit', 'Trauma Kit', 2000, { useable = true, description = 'Advanced field trauma response, beyond a standard medical kit' })

-- ═══════════════════════════ MECHANIC / RECOVERY ═════════════════════
item('repairkit', 'Repair Kit', 1500, { useable = true, description = 'Repairs a damaged vehicle on-site' })
item('repairkit_advanced', 'Advanced Repair Kit', 2500, { useable = true, image = 'repairkit.png', description = "Field-fixes a vehicle in limp mode — brings the engine back to a driveable state, not a full repair" })
item('jump_cables', 'Jump Cables', 500, { useable = true, description = 'Jump-starts a dead vehicle battery' })
item('tow_hook', 'Tow Hook', 800, { description = 'Attaches a vehicle to the recovery truck' })

-- ═══════════════════════════ CIVILIAN ESSENTIALS ═════════════════════
item('phone', 'Mobile Phone', 200, { useable = true, unique = true, description = 'Opens your phone' })
item('water_bottle', 'Bottle of Water', 300, { useable = true, description = 'Quenches thirst' })
item('sandwich', 'Sandwich', 300, { useable = true, description = 'Fills you up a little' })
item('firstaid', 'First Aid Kit', 400, { useable = true, description = 'Basic first aid — weaker than a full Medical Kit' })
item('ifaks', 'IFAK', 300, { useable = true, description = 'Individual First Aid Kit — compact personal-carry trauma kit' })
item('lockpick', 'Lockpick', 150, { useable = true, image = 'lockpicks.png', description = 'Picks a basic lock' })

-- ═══════════════════════════════════════════════════════════════════
--  Everything below registers the rest of the pre-existing PNG icon
--  pack (html/images/ in hd_inventory) as real, usable inventory
--  items — every image now has a matching entry, so nothing in that
--  folder renders as an orphaned icon. Most of these are data-only for
--  now (a real label/weight/description, correctly flagged useable or
--  not) with no bespoke gameplay system behind them yet — that's
--  exactly the extension point this file's own header comment already
--  called out ("a later build phase adds full item icons/metadata/
--  crafting"). `useable = false` on purpose for anything that
--  shouldn't just vanish with a generic "Used X" message (raw
--  materials, attachments, camos, tints, vehicle parts, valuables,
--  gear you wear rather than consume) — hd_inventory's context menu
--  simply won't show a Use button for those. Weapon-type items all
--  need useable = true, since that's what makes the Use button (and
--  therefore the equip-toggle) appear at all.
-- ═══════════════════════════════════════════════════════════════════

-- ─────────────────────────── DOCUMENTS & IDs ──────────────────────────
item('bank_card', 'Bank Card', 10, { unique = true, description = 'A personal bank card' })
item('certificate', 'Certificate', 20, { description = 'An official certificate' })
item('evidence', 'Evidence Bag', 100, { description = 'A sealed bag of evidence from a scene' })
item('lawyerpass', "Solicitor's Pass", 20, { unique = true, description = 'Grants access to legal/court areas' })
item('markedbills', 'Marked Banknotes', 200, { description = 'Banknotes marked for tracking — best not spent' })
item('printerdocument', 'Printed Document', 5, { description = 'A printed page' })
item('security_card_01', 'Security Keycard (Blue)', 10, { unique = true, description = 'Grants access to a restricted area' })
item('security_card_02', 'Security Keycard (Red)', 10, { unique = true, description = 'Grants access to a restricted area' })
item('stickynote', 'Sticky Note', 5, { description = 'A handwritten note' })
item('weapon_license', 'Firearms Licence', 10, { unique = true, description = 'Certifies the holder to legally carry a firearm' })

-- ─────────────────────────── ELECTRONICS ──────────────────────────────
item('cryptostick', 'Crypto USB Stick', 100, { unique = true, description = 'Holds a cryptocurrency wallet' })
item('electronickit', 'Electronics Kit', 800, { useable = true, description = 'Tools for repairing or bypassing electronics' })
item('fitbit', 'Fitness Tracker', 100, { unique = true, description = 'Tracks steps and heart rate' })
item('iphone', 'iPhone', 200, { useable = true, unique = true, description = 'Opens your phone' })
item('samsungphone', 'Android Phone', 200, { useable = true, unique = true, description = 'Opens your phone' })
item('laptop', 'Laptop', 1200, { useable = true, unique = true, description = 'A portable computer' })
item('tablet', 'Tablet', 500, { useable = true, unique = true, description = 'A touchscreen tablet' })
item('usb_device', 'USB Drive', 20, { description = 'A USB storage device' })
item('radioscanner', 'Police Scanner', 400, { useable = true, description = 'Listens in on emergency service radio chatter' })
item('newsbmic', 'Boom Mic', 800, { description = 'A broadcast boom microphone' })
item('newscam', 'News Camera', 1500, { description = 'A broadcast television camera' })
item('newsmic', 'Handheld Mic', 300, { description = 'A handheld broadcast microphone' })
item('binoculars', 'Binoculars', 400, { useable = true, description = 'For observing from a distance' })
item('pinger', 'GPS Tracker', 150, { useable = true, description = 'A covert GPS tracking device' })

-- ─────────────────────────── TOOLS & KITS ─────────────────────────────
item('advancedkit', 'Advanced Tool Kit', 1500, { useable = true, description = 'A comprehensive set of tools' })
item('advancedlockpick', 'Advanced Lockpick', 200, { useable = true, description = 'Picks a reinforced lock' })
item('attworkbench', 'Attachment Workbench', 5000, { description = 'A workbench for fitting weapon attachments' })
item('cleaningkit', 'Cleaning Kit', 500, { useable = true, description = 'Cleans and maintains equipment' })
item('drill', 'Power Drill', 1200, { useable = true, description = 'A cordless power drill' })
item('harness', 'Climbing Harness', 600, { description = 'Safety harness for climbing or rappelling' })
item('labkey', 'Lab Key', 20, { unique = true, description = 'Opens a laboratory' })
item('police_stormram', 'Enforcer Ram', 4000, { useable = true, description = 'Breaches a locked door' })
item('screwdriverset', 'Screwdriver Set', 400, { useable = true, description = 'A set of screwdrivers' })
item('tirerepairkit', 'Tyre Repair Kit', 600, { useable = true, description = 'Repairs a punctured tyre' })
item('tunerchip', 'Tuner Chip', 300, { description = 'An ECU tuning chip for a vehicle' })
-- Reusable — see resources/[mechanic]/hd_mechanic. On-duty mechanics
-- get one automatically the first time they clock on; use it from the
-- driver's seat of any vehicle to view damage, issue MOT/insurance,
-- and order parts. consumable = false so it stays in the inventory
-- after use instead of being deleted like a one-shot kit.
item('mechanic_tablet', 'Mechanic Tablet', 500, { useable = true, unique = true, consumable = false, image = 'tablet.png', description = 'Vehicle diagnostics, MOT/insurance, and parts ordering' })
item('walkstick', 'Walking Stick', 500, { description = 'A wooden walking stick' })
item('workbench', 'Workbench', 5000, { description = 'A general-purpose crafting workbench' })

-- ─────────────────────────── JEWELLERY & VALUABLES ────────────────────
item('10kgoldchain', '10K Gold Chain', 100, { description = 'A 10-karat gold chain' })
item('casinochips', 'Casino Chips', 20, { description = 'Chips redeemable at a casino' })
item('diamond_ring', 'Diamond Ring', 20, { description = 'A ring set with a diamond' })
item('goldbar', 'Gold Bar', 1000, { description = 'A solid gold bar' })
item('goldchain', 'Gold Chain', 80, { description = 'A gold chain' })
item('moneybag', 'Bag of Cash', 2000, { description = 'A bag stuffed with cash' })
item('rolex', 'Luxury Watch', 100, { description = 'An expensive wristwatch' })

-- ─────────────────────────── CRAFTING MATERIALS ───────────────────────
-- aluminum/iron/metalscrap/steel/rubber double as field-repair items —
-- see resources/[mechanic]/hd_mechanic's Config.FieldRepair. Used from
-- the driver's seat of a damaged vehicle: the four metals patch up
-- bodywork damage (each a different amount — steel > aluminium > iron
-- > scrap, roughly by how refined it is), rubber fixes one burst tyre.
-- Still perfectly ordinary crafting materials otherwise.
item('aluminum', 'Aluminium', 300, { useable = true, description = 'Raw aluminium — patches vehicle bodywork in a pinch' })
item('aluminumoxide', 'Aluminium Oxide', 300, { description = 'Refined aluminium oxide' })
item('copper', 'Copper', 300, { description = 'Raw copper' })
item('glass', 'Glass', 200, { description = 'A sheet of glass' })
item('iron', 'Iron', 300, { useable = true, description = 'Raw iron — patches vehicle bodywork in a pinch' })
item('ironoxide', 'Iron Oxide', 300, { description = 'Refined iron oxide' })
item('metalscrap', 'Scrap Metal', 400, { useable = true, description = 'Scrap metal — patches vehicle bodywork in a pinch' })
item('plastic', 'Plastic', 200, { description = 'A block of raw plastic' })
item('rubber', 'Rubber', 200, { useable = true, description = 'A block of raw rubber — can fix a burst tyre' })
item('steel', 'Steel', 400, { useable = true, description = 'Refined steel — patches vehicle bodywork in a pinch' })
item('thermite', 'Thermite', 400, { description = 'A thermite charge — burns through metal' })

-- ─────────────────────────── CHEMICALS ────────────────────────────────
item('acetone', 'Acetone', 400, { description = 'A volatile solvent' })
item('ephedrine', 'Ephedrine', 200, { description = 'A chemical precursor' })
item('hydrochloricacid', 'Hydrochloric Acid', 400, { description = 'A corrosive acid' })

-- ─────────────────────────── DRUGS & CONTRABAND ───────────────────────
item('cocaine_baggy', 'Bag of Cocaine', 50, { useable = true, description = 'A small bag of cocaine' })
item('cocaineleaf', 'Coca Leaf', 50, { description = 'A raw coca leaf' })
item('coke_brick', 'Brick of Cocaine', 1000, { description = 'A compressed brick of cocaine' })
item('coke_small_brick', 'Small Brick of Cocaine', 500, { description = 'A small compressed brick of cocaine' })
item('crack_baggy', 'Bag of Crack', 50, { useable = true, description = 'A small bag of crack cocaine' })
item('joint', 'Joint', 20, { useable = true, description = 'A rolled joint' })
item('meth_baggy', 'Bag of Meth', 50, { useable = true, description = 'A small bag of methamphetamine' })
item('meth_tray', 'Tray of Meth', 500, { description = 'A tray of raw methamphetamine' })
item('oxy', 'Oxycodone', 30, { useable = true, description = 'A prescription-strength painkiller, illicitly obtained' })
item('rolling_paper', 'Rolling Papers', 10, { description = 'Papers for rolling a joint' })
item('ocb_papers', 'OCB Rolling Papers', 10, { image = 'ocb.png', description = 'A pack of OCB rolling papers' })
item('ocb_black', 'OCB Black Rolling Papers', 10, { description = 'A pack of OCB Black rolling papers' })
item('raw_papers', 'RAW Rolling Papers', 10, { image = 'raw.png', description = 'A pack of RAW rolling papers' })
item('rizla_silver', 'Rizla Silver Rolling Papers', 10, { image = 'rizzla_silver.png', description = 'A pack of Rizla Silver rolling papers' })
item('snikkel_candy', 'Snikkel Bar', 100, { useable = true, description = 'A chocolate bar' })
item('twerks_candy', 'Twerks Bar', 100, { useable = true, description = 'A chocolate bar' })
item('weed_baggy', 'Bag of Weed', 50, { useable = true, description = 'A small bag of cannabis' })
item('weed_baggy_empty', 'Empty Bag', 5, { description = 'An empty resealable bag' })
item('weed_brick', 'Brick of Weed', 1000, { description = 'A compressed brick of cannabis' })
item('weed_nutrition', 'Plant Nutrients', 300, { description = 'Nutrients for growing cannabis' })
item('weed_seed', 'Cannabis Seed', 5, { description = 'A cannabis seed' })
item('xtc_baggy', 'Bag of Ecstasy', 50, { useable = true, description = 'A small bag of ecstasy pills' })
item('nitrous', 'Nitrous Oxide Canister', 800, { description = 'A pressurised nitrous oxide canister' })

-- ─────────────────────────── FOOD & DRINK ─────────────────────────────
item('beer', 'Beer', 350, { useable = true, description = 'A bottle of beer' })
item('coffee', 'Coffee', 250, { useable = true, description = 'A hot cup of coffee' })
item('cola', 'Cola', 350, { useable = true, description = 'A can of cola' })
item('grape', 'Grapes', 150, { useable = true, description = 'A bunch of grapes' })
item('grapejuice', 'Grape Juice', 300, { useable = true, description = 'A glass of grape juice' })
item('snowball', 'Snowball', 50, { useable = true, description = 'A packed snowball' })
item('tosti', 'Toastie', 250, { useable = true, description = 'A toasted sandwich' })
item('vodka', 'Vodka', 400, { useable = true, description = 'A bottle of vodka' })
item('whiskey', 'Whiskey', 400, { useable = true, description = 'A bottle of whiskey' })
item('wine', 'Wine', 450, { useable = true, description = 'A bottle of wine' })

-- ─────────────────────────── TAKEAWAY & BRANDED DRINKS ─────────────────
-- More hd_shops stock — see resources/[hd]/hd_shops/config.lua
-- Config.Stock. Real raster PNG icons (hd_inventory/html/images), not
-- the hand-drawn SVG set above.
item('fullburger', 'Deluxe Burger', 500, { useable = true, description = 'A fully-loaded takeaway burger' })
item('baconburger', 'Bacon Burger', 450, { useable = true, description = 'A burger topped with bacon' })
item('baconcheeseburger', 'Bacon Cheeseburger', 500, { useable = true, description = 'A burger topped with bacon and cheese' })
item('cheeseburger', 'Cheeseburger', 350, { useable = true, description = 'A burger topped with cheese' })
item('doublecheeseburger', 'Double Cheeseburger', 550, { useable = true, description = 'A double-patty cheeseburger' })
item('hamburger', 'Hamburger', 300, { useable = true, description = 'A plain takeaway burger' })
item('chickennuggets', 'Chicken Nuggets', 250, { useable = true, description = 'A box of chicken nuggets' })
item('chips', 'Chips', 300, { useable = true, description = 'A portion of chips' })
item('kebab', 'Kebab', 500, { useable = true, description = 'A takeaway kebab' })
item('large_kebab', 'Large Kebab', 750, { useable = true, description = 'A large takeaway kebab' })
item('hotchocolate', 'Hot Chocolate', 300, { useable = true, description = 'A hot chocolate' })
item('takeaway_coffee', 'Takeaway Coffee', 300, { useable = true, description = 'A takeaway cup of coffee' })
item('mcdonalds_drink', 'Fountain Drink', 400, { useable = true, description = 'A takeaway fountain drink' })
item('7up', '7 Up', 350, { useable = true, description = 'A can of 7 Up' })
item('cocacola', 'Coca-Cola', 350, { useable = true, description = 'A can of Coca-Cola' })
item('dietcoke', 'Diet Coke', 350, { useable = true, description = 'A can of Diet Coke' })
item('fanta', 'Fanta', 350, { useable = true, description = 'A can of Fanta' })
item('sprite', 'Sprite', 350, { useable = true, description = 'A can of Sprite' })
item('pepsi', 'Pepsi', 350, { useable = true, description = 'A can of Pepsi' })
item('pepsi_max', 'Pepsi Max', 350, { useable = true, description = 'A can of Pepsi Max' })
item('irnbru', 'Irn-Bru', 350, { useable = true, description = 'A can of Irn-Bru' })
item('lucozade', 'Lucozade', 400, { useable = true, description = 'A bottle of Lucozade' })
item('monster', 'Monster Energy', 500, { useable = true, description = 'A can of Monster Energy' })
item('caprisun', 'Capri-Sun', 200, { useable = true, description = 'A pouch of Capri-Sun' })
item('tango_apple', 'Tango Apple', 350, { useable = true, description = 'A can of Tango Apple' })

-- ─────────────────────────── FISHING & DIVING ─────────────────────────
item('fish', 'Fish', 300, { useable = true, description = 'A freshly caught fish' })
item('fishbait', 'Fishing Bait', 50, { description = 'Bait for fishing' })
item('fishingrod', 'Fishing Rod', 800, { description = 'A rod for fishing' })
item('antipatharia_coral', 'Black Coral', 100, { description = 'A rare piece of black coral' })
item('dendrogyra_coral', 'Pillar Coral', 100, { description = 'A rare piece of pillar coral' })
item('diving_gear', 'Diving Gear', 3000, { description = 'A full scuba diving set' })
item('diving_tube', 'Oxygen Tank', 2000, { description = 'A scuba oxygen tank' })

-- ─────────────────────────── FIREWORKS ────────────────────────────────
item('firework1', 'Firework (Red)', 300, { useable = true, description = 'A firework rocket' })
item('firework2', 'Firework (Blue)', 300, { useable = true, description = 'A firework rocket' })
item('firework3', 'Firework (Green)', 300, { useable = true, description = 'A firework rocket' })
item('firework4', 'Firework (Gold)', 300, { useable = true, description = 'A firework rocket' })

-- ─────────────────────────── MISC ─────────────────────────────────────
item('jerry_can', 'Jerry Can', 3000, { useable = true, description = 'A can of petrol' })
item('lighter', 'Lighter', 50, { useable = true, description = 'A cigarette lighter' })
item('parachute', 'Parachute', 4000, { description = 'A packed parachute' })

-- ─────────────────────────── VEHICLE PARTS ────────────────────────────
item('veh_armor', 'Vehicle Armour Kit', 4000, { description = 'An armour upgrade kit for a vehicle' })
item('veh_brakes', 'Brake Upgrade Kit', 3000, { description = 'A brake upgrade kit' })
item('veh_engine', 'Engine Upgrade Kit', 5000, { description = 'An engine upgrade kit' })
item('veh_exterior', 'Body Kit', 5000, { description = 'An exterior body kit' })
item('veh_interior', 'Interior Trim Kit', 3000, { description = 'An interior trim upgrade' })
item('veh_neons', 'Neon Kit', 1500, { description = 'A set of underglow neon lights' })
item('veh_plates', 'Number Plate', 200, { description = 'A vehicle number plate' })
item('veh_suspension', 'Suspension Kit', 3500, { description = 'A suspension upgrade kit' })
item('veh_tint', 'Window Tint Kit', 500, { description = 'A window tint kit' })
item('veh_toolbox', 'Vehicle Toolbox', 4000, { description = 'A toolbox of vehicle mod parts' })
item('veh_transmission', 'Transmission Upgrade Kit', 4000, { description = 'A transmission upgrade kit' })
item('veh_turbo', 'Turbo Kit', 3000, { description = 'A turbocharger upgrade kit' })
item('veh_wheels', 'Wheel Set', 4000, { description = 'A set of aftermarket wheels' })
item('veh_xenons', 'Xenon Headlight Kit', 800, { description = 'A xenon headlight upgrade kit' })

-- ─────────────────────────── WEAPON ATTACHMENTS ───────────────────────
item('advscope_attachment', 'Advanced Scope', 300, { description = 'Weapon attachment: advanced scope' })
item('barrel_attachment', 'Heavy Barrel', 400, { description = 'Weapon attachment: heavy barrel' })
item('bellend_muzzle_brake', 'Muzzle Brake', 200, { description = 'Weapon attachment: muzzle brake' })
item('clip_attachment', 'Extended Clip', 300, { description = 'Weapon attachment: extended clip' })
item('comp_attachment', 'Compensator', 250, { description = 'Weapon attachment: compensator' })
item('drum_attachment', 'Drum Magazine', 500, { description = 'Weapon attachment: drum magazine' })
item('fat_end_muzzle_brake', 'Muzzle Brake', 200, { description = 'Weapon attachment: muzzle brake' })
item('flashlight_attachment', 'Weapon Flashlight', 200, { description = 'Weapon attachment: flashlight' })
item('flat_muzzle_brake', 'Muzzle Brake', 200, { description = 'Weapon attachment: muzzle brake' })
item('grip_attachment', 'Grip', 200, { description = 'Weapon attachment: grip' })
item('heavy_duty_muzzle_brake', 'Muzzle Brake', 200, { description = 'Weapon attachment: muzzle brake' })
item('holoscope_attachment', 'Holographic Sight', 300, { description = 'Weapon attachment: holographic sight' })
item('largescope_attachment', 'Large Scope', 350, { description = 'Weapon attachment: large scope' })
item('medscope_attachment', 'Medium Scope', 300, { description = 'Weapon attachment: medium scope' })
item('nvscope_attachment', 'Night Vision Scope', 400, { description = 'Weapon attachment: night vision scope' })
item('precision_muzzle_brake', 'Muzzle Brake', 200, { description = 'Weapon attachment: muzzle brake' })
item('slanted_muzzle_brake', 'Muzzle Brake', 200, { description = 'Weapon attachment: muzzle brake' })
item('smallscope_attachment', 'Small Scope', 250, { description = 'Weapon attachment: small scope' })
item('split_end_muzzle_brake', 'Muzzle Brake', 200, { description = 'Weapon attachment: muzzle brake' })
item('squared_muzzle_brake', 'Muzzle Brake', 200, { description = 'Weapon attachment: muzzle brake' })
item('suppressor_attachment', 'Suppressor', 300, { description = 'Weapon attachment: suppressor' })
item('tactical_muzzle_brake', 'Muzzle Brake', 200, { description = 'Weapon attachment: muzzle brake' })
item('thermalscope_attachment', 'Thermal Scope', 400, { description = 'Weapon attachment: thermal scope' })

-- ─────────────────────────── WEAPON CAMOS ─────────────────────────────
item('boomcamo_attachment', 'Weapon Camo: Boom', 100, { description = 'Weapon skin' })
item('brushcamo_attachment', 'Weapon Camo: Brush', 100, { description = 'Weapon skin' })
item('digicamo_attachment', 'Weapon Camo: Digital', 100, { description = 'Weapon skin' })
item('geocamo_attachment', 'Weapon Camo: Geometric', 100, { description = 'Weapon skin' })
item('leopardcamo_attachment', 'Weapon Camo: Leopard', 100, { description = 'Weapon skin' })
item('patriotcamo_attachment', 'Weapon Camo: Patriot', 100, { description = 'Weapon skin' })
item('perseuscamo_attachment', 'Weapon Camo: Perseus', 100, { description = 'Weapon skin' })
item('sessantacamo_attachment', 'Weapon Camo: Sessanta', 100, { description = 'Weapon skin' })
item('skullcamo_attachment', 'Weapon Camo: Skull', 100, { description = 'Weapon skin' })
item('woodcamo_attachment', 'Weapon Camo: Wood', 100, { description = 'Weapon skin' })
item('zebracamo_attachment', 'Weapon Camo: Zebra', 100, { description = 'Weapon skin' })

-- ─────────────────────────── WEAPON TINTS ──────────────────────────────
item('weapontint_army', 'Weapon Tint: Army', 50, { description = 'Weapon finish' })
item('weapontint_black', 'Weapon Tint: Black', 50, { description = 'Weapon finish' })
item('weapontint_gold', 'Weapon Tint: Gold', 50, { description = 'Weapon finish' })
item('weapontint_green', 'Weapon Tint: Green', 50, { description = 'Weapon finish' })
item('weapontint_lspd', 'Weapon Tint: LSPD', 50, { description = 'Weapon finish' })
item('weapontint_orange', 'Weapon Tint: Orange', 50, { description = 'Weapon finish' })
item('weapontint_pink', 'Weapon Tint: Pink', 50, { description = 'Weapon finish' })
item('weapontint_plat', 'Weapon Tint: Platinum', 50, { description = 'Weapon finish' })

-- ─────────────────────────── AMMO ──────────────────────────────────────
item('mg_ammo', 'MG Ammo', 400, { useable = true, description = 'Ammunition for machine guns' })
item('pistol_ammo', 'Pistol Ammo', 200, { useable = true, description = 'Ammunition for pistols' })
item('rifle_ammo', 'Rifle Ammo', 300, { useable = true, description = 'Ammunition for rifles' })
item('shotgun_ammo', 'Shotgun Shells', 300, { useable = true, description = 'Ammunition for shotguns' })
item('smg_ammo', 'SMG Ammo', 250, { useable = true, description = 'Ammunition for submachine guns' })

-- ═══════════════════════════ WEAPONS (the rest of the GTA set) ════════
-- Same convention as the police loadout weapons above: real,
-- placeable/moveable/tradeable items, "Use" toggles them into the
-- ped's hand. Registered here so every remaining weapon_*.png in the
-- icon pack has a matching item — nothing hands these out by default,
-- this just makes them valid AddItem targets for whatever gives them
-- out later (a gun store, a heist reward, an admin command).
item('weapon_acidpackage',          'Acid Package',              500,  { type = 'weapon', unique = true, useable = true, description = 'A package of corrosive acid' })
item('weapon_advancedrifle',        'Advanced Rifle',            3200, { type = 'weapon', unique = true, useable = true, description = 'A rifle with an advanced firing system' })
item('weapon_appistol',             'AP Pistol',                 1200, { type = 'weapon', unique = true, useable = true, description = 'A rapid-fire pistol' })
item('weapon_assaultrifle',         'Assault Rifle',             3400, { type = 'weapon', unique = true, useable = true, description = 'A fully automatic assault rifle' })
item('weapon_assaultrifle_mk2',     'Assault Rifle Mk II',       3400, { type = 'weapon', unique = true, useable = true, description = 'An improved assault rifle' })
item('weapon_assaultshotgun',       'Assault Shotgun',           3400, { type = 'weapon', unique = true, useable = true, description = 'A fully automatic shotgun' })
item('weapon_assaultsmg',           'Assault SMG',               2200, { type = 'weapon', unique = true, useable = true, description = 'A high rate-of-fire SMG' })
item('weapon_autoshotgun',          'Auto Shotgun',              3400, { type = 'weapon', unique = true, useable = true, description = 'An automatic shotgun' })
item('weapon_ball',                 'Ball',                      300,  { type = 'weapon', unique = true, useable = true, description = 'A throwable ball' })
item('weapon_bat',                  'Baseball Bat',              900,  { type = 'weapon', unique = true, useable = true, description = 'A wooden baseball bat' })
item('weapon_battleaxe',            'Battle Axe',                1800, { type = 'weapon', unique = true, useable = true, description = 'A heavy battle axe' })
item('weapon_bottle',               'Bottle',                    500,  { type = 'weapon', unique = true, useable = true, description = 'A broken bottle' })
item('weapon_bread',                'Baguette',                  200,  { type = 'weapon', unique = true, useable = true, description = 'A loaf of bread' })
item('weapon_briefcase',            'Briefcase',                 1000, { type = 'weapon', unique = true, useable = true, description = 'A locked briefcase' })
item('weapon_briefcase_02',         'Briefcase (Full)',          2000, { type = 'weapon', unique = true, useable = true, description = 'A briefcase full of cash' })
item('weapon_bullpuprifle',         'Bullpup Rifle',             3000, { type = 'weapon', unique = true, useable = true, description = 'A compact bullpup rifle' })
item('weapon_bullpuprifle_mk2',     'Bullpup Rifle Mk II',       3000, { type = 'weapon', unique = true, useable = true, description = 'An improved bullpup rifle' })
item('weapon_bullpupshotgun',       'Bullpup Shotgun',           3000, { type = 'weapon', unique = true, useable = true, description = 'A compact bullpup shotgun' })
item('weapon_bzgas',                'BZ Gas',                    300,  { type = 'weapon', unique = true, useable = true, description = 'An incapacitating gas canister' })
item('weapon_candycane',            'Candy Cane', 400, { type = 'weapon', unique = true, useable = true, description = 'A festive candy cane' })
item('weapon_carbinerifle_mk2',     'Carbine Rifle Mk II',       3400, { type = 'weapon', unique = true, useable = true, description = 'An improved carbine rifle' })
item('weapon_ceramicpistol',        'Ceramic Pistol',            1000, { type = 'weapon', unique = true, useable = true, description = 'A pistol built with ceramic components' })
item('weapon_combatmg',             'Combat MG',                 4000, { type = 'weapon', unique = true, useable = true, description = 'A belt-fed machine gun' })
item('weapon_combatmg_mk2',         'Combat MG Mk II',           4000, { type = 'weapon', unique = true, useable = true, description = 'An improved combat machine gun' })
item('weapon_combatpdw',            'Combat PDW',                2200, { type = 'weapon', unique = true, useable = true, description = 'A compact personal defence weapon' })
item('weapon_combatpistol',         'Combat Pistol',             1200, { type = 'weapon', unique = true, useable = true, description = 'A military-style combat pistol' })
item('weapon_combatshotgun',        'Combat Shotgun',            3400, { type = 'weapon', unique = true, useable = true, description = 'A military combat shotgun' })
item('weapon_compactlauncher',      'Compact Grenade Launcher',  4000, { type = 'weapon', unique = true, useable = true, description = 'A compact grenade launcher' })
item('weapon_compactrifle',         'Compact Rifle',             2800, { type = 'weapon', unique = true, useable = true, description = 'A compact carbine rifle' })
item('weapon_crowbar',              'Crowbar',                   1000, { type = 'weapon', unique = true, useable = true, description = 'A steel crowbar' })
item('weapon_dagger',               'Dagger',                    500,  { type = 'weapon', unique = true, useable = true, description = 'A ceremonial dagger' })
item('weapon_dbshotgun',            'Double-Barrel Shotgun',     3000, { type = 'weapon', unique = true, useable = true, description = 'A break-action double-barrel shotgun' })
item('weapon_digiscanner',          'Digital Scanner',           500,  { type = 'weapon', unique = true, useable = true, description = 'A digital scanning device' })
item('weapon_doubleaction',         'Double Action Revolver',    1200, { type = 'weapon', unique = true, useable = true, description = 'A double-action revolver' })
item('weapon_emplauncher',          'EMP Launcher',              4000, { type = 'weapon', unique = true, useable = true, description = 'Fires an electromagnetic pulse charge' })
item('weapon_fertilizercan',        'Fertiliser Can',            2000, { type = 'weapon', unique = true, useable = true, description = 'A can of chemical fertiliser' })
item('weapon_fireextinguisher',     'Fire Extinguisher',         2500, { type = 'weapon', unique = true, useable = true, description = 'A pressurised fire extinguisher' })
item('weapon_firework',             'Firework Launcher',         2000, { type = 'weapon', unique = true, useable = true, description = 'Launches firework rockets' })
item('weapon_flare',                'Flare',                     200,  { type = 'weapon', unique = true, useable = true, description = 'A handheld emergency flare' })
item('weapon_flaregun',             'Flare Gun',                 1000, { type = 'weapon', unique = true, useable = true, description = 'Fires an emergency flare' })
item('weapon_gadgetpistol',         'Gadget Pistol',             1200, { type = 'weapon', unique = true, useable = true, description = 'A modified novelty pistol' })
item('weapon_garbagebag',           'Garbage Bag',               500,  { type = 'weapon', unique = true, useable = true, description = 'A bag of rubbish' })
item('weapon_gas',                  'Gas Grenade',               300,  { type = 'weapon', unique = true, useable = true, description = 'A tear gas grenade' })
item('weapon_golfclub',             'Golf Club',                 900,  { type = 'weapon', unique = true, useable = true, description = 'A golf club' })
item('weapon_grenade',              'Grenade',                   400,  { type = 'weapon', unique = true, useable = true, description = 'A fragmentation grenade' })
item('weapon_grenadelauncher',      'Grenade Launcher',          4000, { type = 'weapon', unique = true, useable = true, description = 'Launches explosive grenades' })
item('weapon_grenadelauncher_smoke','Grenade Launcher (Smoke)',  4000, { type = 'weapon', unique = true, useable = true, description = 'Launches smoke grenades' })
item('weapon_gusenberg',            'Gusenberg Sweeper',         2500, { type = 'weapon', unique = true, useable = true, description = 'A vintage tommy gun' })
item('weapon_hammer',               'Hammer',                    800,  { type = 'weapon', unique = true, useable = true, description = 'A claw hammer' })
item('weapon_handcuffs',            'Handcuffs (Restraint)',     250,  { type = 'weapon', unique = true, useable = true, description = 'Restrains a suspect' })
item('weapon_hatchet',              'Hatchet',                   900,  { type = 'weapon', unique = true, useable = true, description = 'A hand hatchet' })
item('weapon_hazardcan',            'Hazardous Materials Can',   2000, { type = 'weapon', unique = true, useable = true, description = 'A can of hazardous chemicals' })
item('weapon_heavypistol',          'Heavy Pistol',              1300, { type = 'weapon', unique = true, useable = true, description = 'A large-calibre pistol' })
item('weapon_heavyrifle',           'Heavy Rifle',               3600, { type = 'weapon', unique = true, useable = true, description = 'A high-calibre battle rifle' })
item('weapon_heavyshotgun',         'Heavy Shotgun',             3400, { type = 'weapon', unique = true, useable = true, description = 'A heavy-duty shotgun' })
item('weapon_heavysniper',          'Heavy Sniper',              4200, { type = 'weapon', unique = true, useable = true, description = 'A high-calibre sniper rifle' })
item('weapon_heavysniper_mk2',      'Heavy Sniper Mk II',        4200, { type = 'weapon', unique = true, useable = true, description = 'An improved heavy sniper rifle' })
item('weapon_hominglauncher',       'Homing Launcher',           9000, { type = 'weapon', unique = true, useable = true, description = 'A guided missile launcher' })
item('weapon_knife',                'Knife',                     400,  { type = 'weapon', unique = true, useable = true, description = 'A combat knife' })
item('weapon_knuckle',              'Brass Knuckles',            300,  { type = 'weapon', unique = true, useable = true, description = 'A set of brass knuckles' })
item('weapon_machete',              'Machete',                   900,  { type = 'weapon', unique = true, useable = true, description = 'A large machete' })
item('weapon_machinepistol',        'Machine Pistol',            1200, { type = 'weapon', unique = true, useable = true, description = 'A fully automatic pistol' })
item('weapon_marksmanpistol',       'Marksman Pistol',           1300, { type = 'weapon', unique = true, useable = true, description = 'A precision single-shot pistol' })
item('weapon_marksmanrifle',        'Marksman Rifle',            3600, { type = 'weapon', unique = true, useable = true, description = 'A precision marksman rifle' })
item('weapon_marksmanrifle_mk2',    'Marksman Rifle Mk II',      3600, { type = 'weapon', unique = true, useable = true, description = 'An improved marksman rifle' })
item('weapon_metaldetector',        'Metal Detector',            1500, { type = 'weapon', unique = true, useable = true, description = 'A handheld metal detector' })
item('weapon_mg',                   'Machine Gun',               3800, { type = 'weapon', unique = true, useable = true, description = 'A general-purpose machine gun' })
item('weapon_microsmg',             'Micro SMG', 1800, { type = 'weapon', unique = true, useable = true, description = 'A compact submachine gun' })
item('weapon_militaryrifle',        'Military Rifle',            3400, { type = 'weapon', unique = true, useable = true, description = 'A military-issue rifle' })
item('weapon_minigun',              'Minigun',                   18000,{ type = 'weapon', unique = true, useable = true, description = 'A rotary-barrel machine gun' })
item('weapon_minismg',              'Mini SMG',                  1600, { type = 'weapon', unique = true, useable = true, description = 'A small, concealable SMG' })
item('weapon_molotov',              'Molotov Cocktail',          400,  { type = 'weapon', unique = true, useable = true, description = 'An improvised incendiary bottle' })
item('weapon_musket',               'Musket',                    2500, { type = 'weapon', unique = true, useable = true, description = 'A muzzle-loaded musket' })
item('weapon_navyrevolver',         'Navy Revolver',             1200, { type = 'weapon', unique = true, useable = true, description = 'A vintage naval revolver' })
item('weapon_petrolcan',            'Petrol Can',                3000, { type = 'weapon', unique = true, useable = true, description = 'A can of petrol' })
item('weapon_pipebomb',             'Pipe Bomb',                 400,  { type = 'weapon', unique = true, useable = true, description = 'An improvised explosive device' })
item('weapon_pistol50',             'Pistol .50',                1400, { type = 'weapon', unique = true, useable = true, description = 'A large-calibre pistol' })
item('weapon_pistol_mk2',           'Pistol Mk II',              1200, { type = 'weapon', unique = true, useable = true, description = 'An improved sidearm' })
item('weapon_pistolxm3',            'Pistol XM3',                1200, { type = 'weapon', unique = true, useable = true, description = 'A modernised sidearm' })
item('weapon_poolcue',              'Pool Cue',                  600,  { type = 'weapon', unique = true, useable = true, description = 'A wooden pool cue' })
item('weapon_precisionrifle',       'Precision Rifle',           3600, { type = 'weapon', unique = true, useable = true, description = 'A high-precision rifle' })
item('weapon_proxmine',             'Proximity Mine',            500,  { type = 'weapon', unique = true, useable = true, description = 'A remote-triggered proximity mine' })
item('weapon_pumpshotgun_mk2',      'Pump Shotgun Mk II',        3200, { type = 'weapon', unique = true, useable = true, description = 'An improved pump-action shotgun' })
item('weapon_railgun',              'Railgun',                   10000,{ type = 'weapon', unique = true, useable = true, description = 'An experimental electromagnetic rifle' })
item('weapon_railgunxm3',           'Railgun XM3',               10000,{ type = 'weapon', unique = true, useable = true, description = 'A modernised railgun' })
item('weapon_raycarbine',           'Unholy Hellbringer',        3400, { type = 'weapon', unique = true, useable = true, description = 'An experimental energy carbine' })
item('weapon_rayminigun',           'Widowmaker',                18000,{ type = 'weapon', unique = true, useable = true, description = 'An experimental energy minigun' })
item('weapon_raypistol',            'Up-n-Atomizer',             1200, { type = 'weapon', unique = true, useable = true, description = 'An experimental energy pistol' })
item('weapon_revolver',             'Heavy Revolver',            1300, { type = 'weapon', unique = true, useable = true, description = 'A large-calibre revolver' })
item('weapon_revolver_mk2',         'Heavy Revolver Mk II',      1300, { type = 'weapon', unique = true, useable = true, description = 'An improved heavy revolver' })
item('weapon_rpg',                  'RPG', 9000, { type = 'weapon', unique = true, useable = true, description = 'A rocket-propelled grenade launcher' })
item('weapon_sawnoffshotgun',       'Sawn-Off Shotgun',          2200, { type = 'weapon', unique = true, useable = true, description = 'A concealable sawn-off shotgun' })
item('weapon_smg',                  'SMG',                       2000, { type = 'weapon', unique = true, useable = true, description = 'A submachine gun' })
item('weapon_smg_mk2',              'SMG Mk II',                 2000, { type = 'weapon', unique = true, useable = true, description = 'An improved submachine gun' })
item('weapon_smokegrenade',         'Smoke Grenade',             300,  { type = 'weapon', unique = true, useable = true, description = 'A smoke grenade' })
item('weapon_sniperrifle',          'Sniper Rifle',              4200, { type = 'weapon', unique = true, useable = true, description = 'A bolt-action sniper rifle' })
item('weapon_snowball',             'Snowball (Throwable)',      50,   { type = 'weapon', unique = true, useable = true, description = 'A packed snowball' })
item('weapon_snspistol',            'SNS Pistol',                1000, { type = 'weapon', unique = true, useable = true, description = 'A small concealable pistol' })
item('weapon_snspistol_mk2',        'SNS Pistol Mk II',          1000, { type = 'weapon', unique = true, useable = true, description = 'An improved concealable pistol' })
item('weapon_specialcarbine',       'Special Carbine',           3400, { type = 'weapon', unique = true, useable = true, description = 'A tactical carbine rifle' })
item('weapon_specialcarbine_mk2',   'Special Carbine Mk II',     3400, { type = 'weapon', unique = true, useable = true, description = 'An improved special carbine' })
item('weapon_stickybomb',           'Sticky Bomb',               400,  { type = 'weapon', unique = true, useable = true, description = 'A remote-detonated explosive charge' })
item('weapon_stone_hatchet',        'Stone Hatchet',             900,  { type = 'weapon', unique = true, useable = true, description = 'A primitive stone hatchet' })
item('weapon_switchblade',          'Switchblade',               200,  { type = 'weapon', unique = true, useable = true, description = 'A folding switchblade knife' })
item('weapon_tecpistol',            'Tec-9 Pistol',              1200, { type = 'weapon', unique = true, useable = true, description = 'A compact machine pistol' })
item('weapon_vintagepistol',        'Vintage Pistol',            1100, { type = 'weapon', unique = true, useable = true, description = 'A classic semi-automatic pistol' })
item('weapon_wrench',               'Wrench',                    900,  { type = 'weapon', unique = true, useable = true, description = 'A heavy wrench' })
