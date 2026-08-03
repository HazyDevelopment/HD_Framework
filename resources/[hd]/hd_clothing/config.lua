Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD CLOTHING | HAZY DEVELOPMENT | v1.0.0
--  The wardrobe system this framework was missing — stands in for
--  qb-clothing. Component/prop counts are read live from the ped
--  model via GetNumberOfPedDrawableVariations and friends, not
--  hand-listed per item, so this works against any ped model without
--  a maintained catalog. Two ways in:
--    • Config.OpenCommand — free wardrobe, browse/save/wear any of
--      your saved outfits, no cost.
--    • Config.Stores — walk up, press E, same menu but "Save" is
--      "Buy" instead: charges Config.Stores[].OutfitPrice from bank
--      and saves the result as a new named outfit.
--  Either way, whatever's actually being worn when you save/buy/wear
--  is also persisted as your character's "last worn" look
--  (players.clothing) and re-applied automatically on spawn — see
--  server/main.lua.
-- ═══════════════════════════════════════════════════════════════════

Config.OpenCommand = 'outfits'

-- ═══════════════════════════ CATEGORIES ══════════════════════════════
-- kind = 'component' uses SetPedComponentVariation/component ids;
-- kind = 'prop' uses SetPedPropIndex/prop ids and supports "None"
-- (index -1, i.e. ClearPedProp) since not every prop should be worn.
Config.Categories = {
    { id = 'mask',       label = 'Mask',        kind = 'component', index = 1 },
    { id = 'hair',       label = 'Hair',        kind = 'component', index = 2 },
    { id = 'torso',      label = 'Top',         kind = 'component', index = 11 },
    { id = 'undershirt', label = 'Undershirt',  kind = 'component', index = 8 },
    { id = 'arms',       label = 'Arms',        kind = 'component', index = 3 },
    { id = 'legs',       label = 'Legs',        kind = 'component', index = 4 },
    { id = 'shoes',      label = 'Shoes',       kind = 'component', index = 6 },
    { id = 'bags',       label = 'Bags',        kind = 'component', index = 5 },
    { id = 'accessory',  label = 'Accessory',   kind = 'component', index = 7 },
    { id = 'armor',      label = 'Body Armour', kind = 'component', index = 9 },
    { id = 'hats',       label = 'Hats',        kind = 'prop', index = 0, canRemove = true },
    { id = 'glasses',    label = 'Glasses',     kind = 'prop', index = 1, canRemove = true },
    { id = 'ears',       label = 'Ears',        kind = 'prop', index = 2, canRemove = true },
    { id = 'watches',    label = 'Watches',     kind = 'prop', index = 6, canRemove = true },
    { id = 'bracelets',  label = 'Bracelets',   kind = 'prop', index = 7, canRemove = true },
}

-- ═══════════════════════════ CLOTHING CATALOG ═══════════════════════
-- Optional, per category (keyed by the `id` from Config.Categories
-- above). When a category has entries here, the wardrobe shows THIS
-- curated, labelled list instead of raw numbered cycling through every
-- drawable the game ships — real "custom clothing provided by the
-- server" rather than exposing literally every raw variation (plenty
-- of which look broken on the base freemode model). A category with
-- no entries here just falls back to the old raw native cycling
-- automatically, so this is safe to fill in gradually, one category
-- at a time.
--
-- Add entries as { label = 'Name', drawable = N, texture = N }. Find
-- real numbers by cycling the raw wardrobe yourself first (leave a
-- category's catalog empty, note down the drawable/texture pairs that
-- actually look good on mp_m_freemode_01/mp_f_freemode_01 — see
-- HD_Framework's player-model change, below), then paste them in here
-- with a real label. The single entry per category below is just a
-- safe, always-valid placeholder (drawable 0, the base variant every
-- ped model has) proving the catalog system works out of the box —
-- replace/expand it with your own.
Config.ClothingCatalog = {
    torso = { { label = 'Default Top', drawable = 0, texture = 0 } },
    legs = { { label = 'Default Trousers', drawable = 0, texture = 0 } },
    shoes = { { label = 'Default Shoes', drawable = 0, texture = 0 } },
    -- add more categories (see Config.Categories above for the full
    -- list of ids) the same way
}

-- ═══════════════════════════ WARDROBE ═════════════════════════════════
Config.MaxOutfits = 15         -- named outfits a citizen can have saved at once
Config.PreviewCamOffset = vector3(0.0, 2.1, 0.35) -- relative to the ped, looking back at it

-- ═══════════════════════════ STORES ═══════════════════════════════════
-- Each is a real, walk-up-and-press-E ped. Buying here works exactly
-- like the free wardrobe except it charges OutfitPrice and requires
-- hd_society (the sale deposits into the 'clothingstore' fund) —
-- Config.Societies in hd_society/config.lua needs a matching entry if
-- you want that revenue somewhere; otherwise it's just not banked.
--
-- One of every real in-game clothing store location, city and county
-- both — Binco is the budget brand (cheapest), Suburban mid-range,
-- Ponsonbys the high-end Rockford Hills/Del Perro boutiques (priciest).
-- Coordinates are the standard vanilla store doorways; nudge any of
-- them if a ped ends up slightly off in your install.
Config.Stores = {
    -- ── Los Santos ──────────────────────────────────────────────────
    {
        label = 'Suburban — Vinewood',
        coords = vector4(127.9, -223.4, 54.6, 70.0),
        pedModel = 'a_f_y_business_04',
        OutfitPrice = 150,
    },
    {
        label = 'Ponsonbys — Rockford Hills',
        coords = vector4(-708.7, -152.1, 37.4, 0.0),
        pedModel = 'a_m_y_business_03',
        OutfitPrice = 250,
    },
    {
        label = 'Ponsonbys — Del Perro',
        coords = vector4(-1447.7, -239.9, 46.9, 30.0),
        pedModel = 'a_f_y_business_02',
        OutfitPrice = 220,
    },
    {
        label = 'Ponsonbys — Great Ocean Highway',
        coords = vector4(-829.7, -1073.6, 11.3, 0.0),
        pedModel = 'a_m_y_business_02',
        OutfitPrice = 200,
    },
    {
        label = 'Binco — Strawberry',
        coords = vector4(72.3, -1399.1, 29.4, 0.0),
        pedModel = 'a_f_y_hipster_03',
        OutfitPrice = 60,
    },
    {
        label = 'Binco — Davis',
        coords = vector4(425.5, -800.2, 29.5, 0.0),
        pedModel = 'a_m_y_hipster_01',
        OutfitPrice = 60,
    },
    {
        label = 'Binco — Vespucci',
        coords = vector4(-167.9, -299.1, 39.7, 250.0),
        pedModel = 'a_f_y_hipster_01',
        OutfitPrice = 60,
    },

    -- ── Blaine County ───────────────────────────────────────────────
    {
        label = 'Suburban — Sandy Shores',
        coords = vector4(1961.6, 3740.6, 32.3, 210.0),
        pedModel = 'a_f_y_business_04',
        OutfitPrice = 80,
    },
    {
        label = 'Binco — Grapeseed',
        coords = vector4(1696.1, 4829.3, 42.1, 0.0),
        pedModel = 'a_m_y_hipster_01',
        OutfitPrice = 50,
    },
    {
        label = 'Binco — Paleto Bay',
        coords = vector4(1195.9, 2696.9, 38.2, 0.0),
        pedModel = 'a_f_y_hipster_03',
        OutfitPrice = 50,
    },
}
Config.InteractDistance = 8.0
Config.InteractPressDistance = 1.5

Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
