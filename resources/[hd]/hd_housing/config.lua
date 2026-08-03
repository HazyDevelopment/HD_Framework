Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD HOUSING
--  Every owned property — a starter flat picked at character creation,
--  or one the real estate job sells later — is one row in
--  `hd_properties`, sharing the same "walk to the door, press E, get
--  moved inside" flow either way.
--
--  Interiors are now real, game-shipped ("gamebuild") apartment
--  interiors — the same MP Apartment shells GTA Online itself uses,
--  not custom MLO assets (importing custom map interiors still isn't
--  achievable here) and not the empty sky-pocket placeholder this used
--  to be. Two flavours, both in Config.ApartmentShells below:
--    • `ipl` set — one of the high-end Eclipse Towers interior designs
--      (apa_v_mp_h_0X). Requires RequestIpl before teleporting in.
--    • `ipl` omitted — an ordinary mid-range house/flat that's just
--      part of the base map already, no IPL request needed, teleport
--      straight there.
--  Coordinates are the well-documented, widely-used native interior
--  entry points for these shells (the same ones qb-apartments-style
--  scripts have used for years) — verified against a public reference
--  list, not guessed.
-- ═══════════════════════════════════════════════════════════════════

Config.InteractDistance = 2.0 -- how close to the door before the [E] prompt shows
Config.IplWaitMs = 3000       -- how long to wait for a high-end shell's IPL to stream in before giving up and teleporting anyway

-- ═══════════════════════════ APARTMENT SHELLS ═════════════════════════
-- A fixed pool — real interiors are real, finite assets, not something
-- that can be generated at an arbitrary coordinate like the old pocket
-- system could. `startsAsFlat = true` entries are what
-- Config.StarterFlatIds below offers for free at character creation;
-- everything else is exclusively real-estate-job inventory (see
-- server/realestate.lua) — a genuine reason to buy rather than wait for
-- a free slot to open up.
-- `size` is shown on the brochure (see hd_housing:client "BROCHURE"
-- section) — a flavour classification, not a mechanically-enforced
-- capacity of anything.
Config.ApartmentShells = {
    -- Ordinary houses/flats, already part of the base map — no IPL needed.
    { id = 'flat_integrity28', label = '4 Integrity Way, Apt 28',   size = 'Studio',    coords = vector4(-18.08, -583.67, 79.47, 160.0) },
    { id = 'flat_integrity30', label = '4 Integrity Way, Apt 30',   size = 'Studio',    coords = vector4(-35.31, -580.42, 88.71, 160.0) },
    { id = 'flat_delperro4',   label = 'Del Perro Heights, Apt 4',  size = '1 Bedroom', coords = vector4(-1468.14, -541.82, 73.44, 30.0) },
    { id = 'flat_delperro7',   label = 'Del Perro Heights, Apt 7',  size = '1 Bedroom', coords = vector4(-1477.14, -538.75, 55.53, 30.0) },
    { id = 'flat_majestic',    label = 'Richard Majestic, Apt 2',   size = '2 Bedroom', coords = vector4(-915.81, -379.43, 113.67, 0.0) },
    { id = 'flat_tinsel',      label = 'Tinsel Towers, Apt 42',     size = '1 Bedroom', coords = vector4(-614.86, 40.68, 97.60, 180.0) },
    { id = 'flat_wildoats',    label = '3655 Wild Oats Drive',      size = '2 Bedroom', coords = vector4(-169.29, 486.49, 137.44, 0.0) },
    { id = 'flat_hillcrest',   label = '2862 Hillcrest Avenue',     size = '2 Bedroom', coords = vector4(-676.13, 588.61, 145.17, 0.0) },
    { id = 'flat_whispymound', label = '2677 Whispymound Drive',    size = '3 Bedroom', coords = vector4(120.5, 549.95, 184.10, 0.0) },

    -- Eclipse Towers — real high-end apartment interiors, each its own
    -- IPL. Share one real-world tower entrance (offset a metre or two
    -- apart so each still gets its own walk-up-and-press-E spot),
    -- teleporting into a genuinely different interior design per unit.
    -- Real estate exclusive — never offered as a free starter flat.
    { id = 'flat_eclipse_modern',   label = 'Eclipse Towers — Modern',   size = 'Penthouse', coords = vector4(-773.4, 341.8, 211.4, 70.0), ipl = 'apa_v_mp_h_01_a', interior = vector4(-786.87, 315.76, 217.64, 0.0) },
    { id = 'flat_eclipse_mody',     label = 'Eclipse Towers — Mody',     size = 'Penthouse', coords = vector4(-775.4, 343.8, 211.4, 70.0), ipl = 'apa_v_mp_h_02_a', interior = vector4(-787.07, 315.82, 217.64, 0.0) },
    { id = 'flat_eclipse_vibrant',  label = 'Eclipse Towers — Vibrant',  size = 'Penthouse', coords = vector4(-771.4, 339.8, 211.4, 70.0), ipl = 'apa_v_mp_h_03_a', interior = vector4(-786.62, 315.62, 217.64, 0.0) },
}

-- Which of the shells above are offered free, one-per-citizen, during
-- character creation (HD_Framework/html's Home Address picker). The
-- Eclipse Towers units are deliberately excluded — real estate only.
Config.StarterFlatIds = {
    'flat_integrity28', 'flat_integrity30', 'flat_delperro4', 'flat_delperro7', 'flat_majestic',
}

-- ═══════════════════════════ REAL ESTATE JOB ═════════════════════════
-- Sells whichever Config.ApartmentShells entries aren't owned yet
-- (starter-eligible ones included, once no citizen has claimed them as
-- their free flat — first-come-first-served either way). Real shells
-- are a fixed pool now, so /realestate register no longer turns
-- wherever the agent is standing into a property — it hands out the
-- next unassigned shell instead. Gated on hd.admin OR this job —
-- there's no dedicated 'realestate' job in shared/jobs.lua yet, so the
-- ACE permission is the default working path; add a job entry later if
-- you want it playable as a career instead of an admin/staff tool.
Config.RealEstate = {
    AcePermission = 'hd.admin',
    JobName = 'realestate', -- checked too, if/when you add this job to shared/jobs.lua
}

-- ═══════════════════════════ NOTIFY ══════════════════════════════════
-- ═══════════════════════════ PLACEABLE FURNITURE ═════════════════════
-- Owner-only /placewardrobe and /placestash (while inside their own
-- property) drop one of each at the owner's exact position/heading —
-- see server/main.lua's placeFurniture handler. Interiors ship
-- unfurnished by design (real gamebuild shells, not custom-decorated
-- MLOs) — this is the only furniture that exists until the owner adds it.
Config.Furniture = {
    wardrobe = { model = 'v_ilev_wardrobe01', label = 'Wardrobe' }, -- the same wardrobe prop GTA Online's own apartments use
    stash = { model = 'prop_box_wood04a', label = 'Stash' },
}
Config.FurnitureInteractDistance = 1.8

-- Must match hd_clothing/config.lua's own Config.OpenCommand exactly —
-- there's no cross-resource way to read that value directly, so it's
-- repeated here rather than guessed at.
Config.WardrobeCommand = 'outfits'

Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
