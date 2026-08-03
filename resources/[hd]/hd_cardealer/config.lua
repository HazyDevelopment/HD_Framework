Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD CARDEALER | HAZY DEVELOPMENT | v1.0.0
--  Replaces HD_Framework's /givevehicle admin command as the real way
--  players acquire a vehicle. Open to anyone, not job-gated — the
--  'cardealer' job (shared/jobs.lua) is the staff role for whoever
--  works here, paid via HD_Framework's on-duty salary loop out of the
--  'cardealer' hd_society fund this resource feeds on every sale, not
--  a restriction on who can buy.
-- ═══════════════════════════════════════════════════════════════════

Config.InteractRadius = 8.0
Config.Command = 'dealership' -- opens the catalog while standing at Config.Dealership.coords

-- Cut of every sale that goes into the 'cardealer' hd_society fund
-- (0.2 = 20%) — the rest is a pure sink, representing stock/overhead.
-- No-op if hd_society isn't installed.
Config.SocietyCut = 0.2

-- Placeholder location — move to wherever your showroom is.
Config.Dealership = {
    coords = vector3(-56.0, -1096.0, 26.4),
    spawn = vector4(-46.0, -1105.0, 26.4, 210.0),
}

-- Every model below is a real stock GTA V vehicle — this is just the
-- price list; add/remove entries freely.
Config.Catalog = {
    { model = 'panto', label = 'City Car', class = 'Economy', price = 5200 },
    { model = 'blista', label = 'Compact Hatchback', class = 'Economy', price = 8500 },
    { model = 'futo', label = 'Hot Hatch', class = 'Hot Hatch', price = 19500 },
    { model = 'asea', label = 'Family Saloon', class = 'Saloon', price = 11500 },
    { model = 'tailgater', label = 'Executive Saloon', class = 'Executive', price = 24000 },
    { model = 'sultan', label = 'Sports Saloon', class = 'Sports', price = 32000 },
}

Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
