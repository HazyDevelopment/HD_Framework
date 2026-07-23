Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD HOUSING
--  Every owned property — a starter flat picked at character creation,
--  or a house the real estate job converted later — is one row in
--  `hd_properties`, sharing the same "walk to the exterior door, press
--  E, get moved into a small furnished interior" flow either way.
--
--  Interiors are NOT real GTA MLO/apartment assets — building or
--  importing custom map interiors isn't something achievable here.
--  Instead each property gets its own private, fully self-controlled
--  "pocket" high in the sky (guaranteed empty, zero collision with
--  anything else in the world) furnished with a handful of basic
--  props. It's genuinely "plain" — this is a functional placeholder,
--  not a decorated apartment. The exact prop set/coordinates are a
--  best-effort pick; if something looks off in-game (a prop floating
--  wrong, etc.) it's a config tweak, not a redesign.
-- ═══════════════════════════════════════════════════════════════════

Config.InteractDistance = 2.0     -- how close to an exterior door before the [E] prompt shows
Config.InteriorFloorSize = 8.0    -- half-width of the plain floor slab, in metres

-- Furniture placed relative to each property's own pocket origin —
-- same layout reused for every plain interior, starter or real-estate.
Config.PlainFurniture = {
    { model = 'prop_bed_04',        offset = vector3(-3.0, -3.0, 0.0), heading = 0.0 },
    { model = 'prop_table_03',      offset = vector3(2.0, -3.0, 0.0),  heading = 0.0 },
    { model = 'prop_dining_chr_01', offset = vector3(2.0, -2.0, 0.0),  heading = 180.0 },
    { model = 'prop_sofa_01',       offset = vector3(-3.0, 2.0, 0.0),  heading = 90.0 },
    { model = 'prop_tv_flat_01',    offset = vector3(-3.0, 3.6, 0.6),  heading = 90.0 },
}

-- Starter flats offered during character creation — free, one owner
-- each, first-picked-first-served. Add as many as you like; each
-- needs its own exteriorCoords (a real street address, just flavour —
-- precision doesn't matter beyond "roughly where the door is") and a
-- unique pocketCoords high enough up that no two properties' pockets
-- can ever overlap (each is spaced 300 units apart on X below).
Config.StarterFlats = {
    { id = 'flat_legion',  label = 'Legion Square Studio',   exteriorCoords = vector4(-190.5, -621.9, 34.0, 250.0), pocketCoords = vector3(0.0, 0.0, 1000.0) },
    { id = 'flat_davis',   label = 'Davis Ave Flat',         exteriorCoords = vector4(114.9, -1955.9, 21.1, 210.0), pocketCoords = vector3(300.0, 0.0, 1000.0) },
    { id = 'flat_vinewood',label = 'Vinewood Hills Bungalow',exteriorCoords = vector4(-1339.0, 588.0, 128.0, 180.0), pocketCoords = vector3(600.0, 0.0, 1000.0) },
    { id = 'flat_delperro',label = 'Del Perro Studio',       exteriorCoords = vector4(-1690.0, 200.0, 60.0, 90.0),  pocketCoords = vector3(900.0, 0.0, 1000.0) },
    { id = 'flat_mirror',  label = 'Mirror Park Cottage',    exteriorCoords = vector4(1204.0, -480.0, 65.0, 300.0), pocketCoords = vector3(1200.0, 0.0, 1000.0) },
}

-- ═══════════════════════════ REAL ESTATE JOB ═════════════════════════
-- Anyone with this job/grade can turn any exterior coordinate they're
-- standing at into a purchasable property (/realestate register
-- [label] [price]) and sell any unowned property to a target citizen
-- (/realestate sell [id] [server id]). Gated on hd.admin OR this job —
-- there's no dedicated 'realestate' job in shared/jobs.lua yet, so the
-- ACE permission is the default working path; add a job entry later if
-- you want it playable as a career instead of an admin/staff tool.
Config.RealEstate = {
    AcePermission = 'hd.admin',
    JobName = 'realestate', -- checked too, if/when you add this job to shared/jobs.lua
}

-- ═══════════════════════════ NOTIFY ══════════════════════════════════
Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
