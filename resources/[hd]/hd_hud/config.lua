Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD HUD | HAZY DEVELOPMENT | v1.0.0
--  Fully custom player + vehicle HUD, no ox_hud/qb-hud dependency.
--  Player stats (health/armour/hunger/thirst) are read straight off
--  the ped (native health/armour) and HD_Framework's own PlayerData
--  metadata (hunger/thirst — see HD_Framework/config.lua's "HUNGER /
--  THIRST" section for where those numbers actually come from), not
--  reinvented here. UK-flavoured defaults throughout: mph, litres.
-- ═══════════════════════════════════════════════════════════════════

Config.UpdateMs = 250 -- how often the player HUD refreshes

-- ═══════════════════════════ WATERMARK ═══════════════════════════════
-- Shown permanently, bottom-right. Change the text/colour here — no
-- code changes needed for a rebrand.
Config.Watermark = {
    Text = 'Hazy Development',
    Color = 'rgba(147, 51, 234, 0.35)', -- transparent purple, the default
}

-- ═══════════════════════════ THRESHOLDS ══════════════════════════════
Config.LowWarningPercent = 25 -- health/armour/hunger/thirst below this % pulses red

-- ═══════════════════════════ VEHICLE HUD ═════════════════════════════
-- UK defaults: miles per hour, litres for fuel. GetVehicleFuelLevel
-- itself only ever returns a 0-100 percentage (there's no native for
-- a "real" litre value) — Config.TankCapacityLitres is what turns that
-- percentage into a displayed litre figure, same assumption most
-- FiveM fuel scripts make.
Config.SpeedUnit = 'mph'
Config.FuelUnit = 'litres'
Config.TankCapacityLitres = 65
Config.SpeedoMaxMph = 240 -- what counts as a "full" gauge arc

-- ═══════════════════════════ SEATBELT ════════════════════════════════
Config.Seatbelt = {
    Enabled = true,
    ToggleKey = 'B',            -- RegisterKeyMapping default; rebindable in FiveM's own keybind settings
    WarningDelayMs = 3000,      -- how long unbuckled before the warning ding starts
    WarningIntervalMs = 1500,   -- how often it dings while still unbuckled
    EjectSpeedMph = 150,        -- ejection only considered above this speed
    EjectDecelPerFrame = 12.0,  -- how sudden a single-frame speed drop (m/s) counts as a "hard impact"
}

Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
