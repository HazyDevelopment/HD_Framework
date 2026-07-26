Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD SHOPS | HAZY DEVELOPMENT | v1.0.0
--  24/7-style convenience stores dotted across the map — every
--  location sells the same Config.Stock, same as real 24/7/LTD
--  Gasoline branches. Walk up, press E, buy with cash, item lands
--  straight in the inventory via hd_inventory's AddItem export.
--
--  Coordinates are real 24/7/Rob's Liquor/LTD Gasoline store fronts,
--  but placed from memory rather than verified live in-game this
--  session — if a particular ped ends up slightly inside a wall or
--  facing the wrong way at your build, it's a one-line coords/heading
--  tweak here, not a script change.
-- ═══════════════════════════════════════════════════════════════════

Config.InteractDistance = 8.0
Config.InteractPressDistance = 1.5
Config.PedModel = 'mp_m_shopkeep_01'
Config.Account = 'cash'

Config.Locations = {
    { label = '24/7 — Strawberry',        coords = vector4(25.7, -1347.3, 29.49, 0.0) },
    { label = "Rob's Liquor — Vinewood",  coords = vector4(-1222.14, -906.71, 12.34, 260.0) },
    { label = '24/7 — Rockford Hills',    coords = vector4(-1487.55, -378.19, 40.16, 0.0) },
    { label = 'LTD Gasoline — Route 68',  coords = vector4(1961.68, 3740.85, 32.34, 325.0) },
    { label = '24/7 — Sandy Shores',      coords = vector4(1698.79, 4924.36, 42.06, 45.0) },
    { label = '24/7 — Grapeseed',         coords = vector4(1729.78, 6414.16, 35.04, 137.0) },
    { label = '24/7 — Paleto Bay',        coords = vector4(-111.05, 6469.63, 31.63, 265.0) },
    { label = 'LTD Gasoline — Chumash',   coords = vector4(-3241.87, 1001.75, 12.83, 15.0) },
    { label = '24/7 — Banham Canyon',     coords = vector4(-3037.85, 585.86, 7.9, 40.0) },
    { label = '24/7 — Harmony',           coords = vector4(547.53, 2671.97, 42.15, 0.0) },
    { label = '24/7 — Portola Drive',     coords = vector4(373.79, 325.4, 103.57, 250.0) },
    { label = '24/7 — Davis',             coords = vector4(-47.4, -1757.4, 29.42, 135.0) },
    { label = '24/7 — Alta Street',       coords = vector4(-707.5, -913.1, 19.2, 0.0) },
    { label = "Rob's Liquor — Vespucci",  coords = vector4(-1392.9, -606.4, 30.32, 45.0) },
}

-- Shared stock, same range at every branch — a standard British
-- convenience-shop line-up. `item` must match a name in
-- HD_Framework/shared/items.lua. Prices in £.
Config.Stock = {
    { item = 'water_bottle',  price = 2 },
    { item = 'cola',          price = 2 },
    { item = 'coffee',        price = 3 },
    { item = 'sandwich',      price = 4 },
    { item = 'tosti',         price = 4 },
    { item = 'snikkel_candy', price = 1 },
    { item = 'twerks_candy',  price = 1 },
    { item = 'lighter',       price = 2 },
    { item = 'beer',          price = 3 },
    { item = 'wine',          price = 9 },
    { item = 'vodka',         price = 15 },
    { item = 'whiskey',       price = 18 },
    { item = 'firstaid',      price = 15 },
    { item = 'bandage',       price = 8 },
    { item = 'painkillers',   price = 6 },
    { item = 'lockpick',      price = 20 },
    { item = 'jerry_can',     price = 25 },

    -- Takeaway food, hardware, and branded/canned drinks — see
    -- shared/items.lua's "TAKEAWAY & BRANDED DRINKS" section.
    { item = 'repairkit',           price = 45 },
    { item = 'hamburger',           price = 3 },
    { item = 'cheeseburger',        price = 4 },
    { item = 'baconburger',         price = 5 },
    { item = 'baconcheeseburger',   price = 5 },
    { item = 'doublecheeseburger',  price = 6 },
    { item = 'fullburger',          price = 7 },
    { item = 'chickennuggets',      price = 4 },
    { item = 'chips',               price = 3 },
    { item = 'kebab',               price = 7 },
    { item = 'large_kebab',         price = 9 },
    { item = 'hotchocolate',        price = 3 },
    { item = 'takeaway_coffee',     price = 3 },
    { item = 'mcdonalds_drink',     price = 2 },
    { item = '7up',                 price = 1 },
    { item = 'cocacola',            price = 1 },
    { item = 'dietcoke',            price = 1 },
    { item = 'fanta',               price = 1 },
    { item = 'sprite',              price = 1 },
    { item = 'pepsi',               price = 1 },
    { item = 'pepsi_max',           price = 1 },
    { item = 'irnbru',              price = 1 },
    { item = 'tango_apple',         price = 1 },
    { item = 'caprisun',            price = 1 },
    { item = 'lucozade',            price = 2 },
    { item = 'monster',             price = 2 },
    { item = 'ocb_papers',          price = 2 },
    { item = 'ocb_black',           price = 2 },
    { item = 'raw_papers',          price = 2 },
    { item = 'rizla_silver',        price = 2 },
}

Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
