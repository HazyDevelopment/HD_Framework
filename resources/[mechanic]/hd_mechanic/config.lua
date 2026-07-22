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

Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
