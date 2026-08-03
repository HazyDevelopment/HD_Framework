Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD MECHANIC | HAZY DEVELOPMENT | v1.0.0
--  Ties together the existing `mechanic` job (shared/jobs.lua) with a
--  real shop presence: damage diagnostics, MOT, insurance, full
--  repairs, and the limp-mode consequence of a hard crash. Every
--  paid action here re-checks on-duty + `job.type == 'mechanic'`
--  server-side — the same extension point hd_dispatch/hd_radio
--  already use, so a second garage job added later with
--  `type = 'mechanic'` in shared/jobs.lua picks this up for free too.
-- ═══════════════════════════════════════════════════════════════════

-- Placeholder location — the LS Customs building already exists on
-- the map here, move to wherever your own garage is.
Config.Shops = {
    {
        key = 'ridgeway',
        label = 'Ridgeway Motor Works',
        coords = vector3(-207.0, -1330.0, 30.9),
        radius = 10.0, -- how close a vehicle/customer must be for paid actions (MOT/insurance/full repair)
        blip = { sprite = 446, colour = 69, scale = 0.8 },
    },
}

Config.Command = 'diagnose'      -- opens the Mechanic Terminal on the nearest/current vehicle (on-duty mechanics only)
Config.StatusCommand = 'vehiclestatus' -- lightweight text-only MOT/insurance/limp check anyone can run in their own vehicle

-- How close an online player (matched by citizenid against
-- player_vehicles) must be to a shop to be treated as "the customer"
-- paying for a service — see server/shop.lua.
Config.CustomerRadius = 15.0

-- ═══════════════════════════ TEMP COMPLIANCE ═══════════════════════════
-- A brand new car from hd_cardealer starts with this much temporary
-- MOT + insurance so it's legal long enough to reach a shop.
Config.TempCompliance = {
    Hours = 24,
}

-- ═══════════════════════════ MOT ═══════════════════════════════════════
Config.MOT = {
    Price = 150,          -- charged whether it passes or fails, same as a real MOT test fee
    DurationDays = 30,
    MinBodyPercent = 60,
    MinEnginePercent = 60,
    MaxBurstTyres = 1,
}

-- ═══════════════════════════ INSURANCE ══════════════════════════════════
Config.Insurance = {
    Price = 200,
    DurationDays = 30,
}

-- ═══════════════════════════ REPAIR ═════════════════════════════════════
Config.Repair = {
    FullRepairPrice = 250,   -- clears limp mode + restores engine/body/tank to 100%, persisted to player_vehicles
    AdvancedKitFloor = 600,  -- out of 1000 — what repairkit_advanced brings engine health UP TO (never down)
}

-- ═══════════════════════════ LIMP MODE ═══════════════════════════════════
-- A hard impact above SpeedThresholdMph, losing at least DeltaMph in
-- a single check tick, forces the vehicle into limp mode: engine
-- health slammed down, power/torque/top speed capped, until either
-- repairkit_advanced floors the engine back up (see server/limp.lua)
-- or a mechanic performs a full repair at a shop.
Config.LimpMode = {
    SpeedThresholdMph = 80,
    DeltaMph = 40,
    EngineHealthOnTrigger = 150, -- out of 1000 (~15%) — matches "hard impact wrecks the engine"
    PowerMultiplier = 0.2,
    TorqueMultiplier = 0.2,
    MaxSpeedMph = 25,
    ReportCooldownSeconds = 10, -- per-vehicle, stops one bad crash spamming repeated reports
}

-- ═══════════════════════════ FIELD REPAIR (RAW MATERIALS) ═══════════════
-- Raw crafting/salvage materials doubling as a cheap bodywork patch —
-- NOT the engine, that's still repairkit_advanced (limp mode) or a
-- shop's full repair. Not job-gated — same as repairkit_advanced,
-- anyone carrying the material can use it, driver's seat only so you
-- can't patch a car from across the street.
Config.FieldRepair = {
    RequireDriverSeat = true,
    -- item name -> body health restored, out of 1000. Add more here
    -- freely; nothing else needs to change for a new material.
    BodyMaterials = {
        metalscrap = 80,
        iron = 120,
        aluminum = 150,
        steel = 200,
    },
    -- Any of these fixes ONE burst tyre.
    TyreItems = { 'rubber', 'tirerepairkit' },
}

-- ═══════════════════════════ MECHANIC TABLET ═════════════════════════════
-- A reusable item (see HD_Framework/shared/items.lua's consumable=false)
-- opening the same terminal /diagnose does, but from the driver's seat
-- of any vehicle rather than needing to be near one on foot. On-duty
-- mechanics get one automatically the first time they clock on.
Config.Tablet = {
    Item = 'mechanic_tablet',
    AutoIssueOnDuty = true,
}

-- ═══════════════════════════ PARTS ORDERING ═══════════════════════════════
-- Ordering a part bills the mechanic job's hd_society fund (the same
-- fund customer repair/MOT/insurance payments feed — see shop.lua's
-- ChargeOwner) and delivers straight into StashId, an hd_inventory
-- stash any on-duty mechanic can walk up to and open like any other
-- stash. Change StashId to point at your own stash if you want the
-- delivery to land somewhere specific (e.g. a stockroom behind the
-- shop) — nothing else needs to change.
Config.PartsOrder = {
    StashId = 'mechanic_parts',
    StashLabel = 'Mechanic Parts Delivery',
    StashSlots = 50,
    StashWeight = 100000,
    Catalogue = {
        { item = 'metalscrap', label = 'Scrap Metal', price = 40, amount = 5 },
        { item = 'iron', label = 'Iron', price = 60, amount = 5 },
        { item = 'aluminum', label = 'Aluminium', price = 80, amount = 5 },
        { item = 'steel', label = 'Steel', price = 100, amount = 5 },
        { item = 'rubber', label = 'Rubber', price = 50, amount = 5 },
        { item = 'tirerepairkit', label = 'Tyre Repair Kit', price = 120, amount = 3 },
        { item = 'repairkit', label = 'Repair Kit', price = 150, amount = 2 },
        { item = 'repairkit_advanced', label = 'Advanced Repair Kit', price = 300, amount = 2 },
    },
}

Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
