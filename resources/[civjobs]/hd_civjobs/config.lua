Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD CIVJOBS | HAZY DEVELOPMENT | v1.0.0
--  One reusable "shift" engine — pick up cargo/passengers/whatever at
--  one or more points, drop it off at one or more points, get paid —
--  instead of seven near-identical copy-pasted resources. Each job
--  below is just data: a vehicle, a depot, and a `stops` function that
--  builds a fresh randomised route every time someone starts a shift.
--
--  A "stop" is { label, points = {vector3, ...} }. The player must
--  visit EVERY point in the current stop (any order) before the next
--  stop unlocks. That one shape covers everything here:
--    • pickup → dropoff (taxi, HGV)                    = 2 single-point stops
--    • one pickup → several dropoffs (postal)            = stop 2 has N points
--    • several pickups → one dropoff (waste collection)  = stop 1 has N points
--    • a fixed circuit (bus)                              = N single-point stops in order
--    • a single checkpoint (reporter, estate agent)       = 1 stop, 1 point
--
--  All coordinates below are starter placeholders — move them to
--  wherever makes sense on your map, same convention uk_policejob
--  uses for its Config.Stations.
-- ═══════════════════════════════════════════════════════════════════

Config.InteractRadius = 3.0
Config.Keybind = 'G' -- interact with the current stop

local function PickOne(pool)
    return pool[math.random(1, #pool)]
end

local function PickN(pool, n)
    local copy = {}
    for _, v in ipairs(pool) do copy[#copy + 1] = v end
    local picked = {}
    n = math.min(n, #copy)
    for _ = 1, n do
        local i = math.random(1, #copy)
        picked[#picked + 1] = copy[i]
        table.remove(copy, i)
    end
    return picked
end

Config.Jobs = {}

-- ═══════════════════════════ TAXI ════════════════════════════════════
Config.Jobs.taxi = {
    label = 'Private Hire Driver',
    vehicle = 'taxi',
    depot = { coords = vector3(898.5, -179.3, 74.7), spawn = vector4(913.8, -178.6, 74.1, 70.0) },
    payMin = 70, payMax = 140,
    pickupPool = { vector3(-269.4, -955.3, 31.2), vector3(-615.0, -150.0, 38.1), vector3(-1156.0, -1520.0, 4.6) },
    dropoffPool = { vector3(380.0, 570.0, 130.0), vector3(-1034.0, -2733.0, 13.8), vector3(441.9, -982.0, 30.7) },
    stops = function(cfg)
        return {
            { label = 'Pick up your fare', points = { PickOne(cfg.pickupPool) } },
            { label = 'Drop them at their destination', points = { PickOne(cfg.dropoffPool) } },
        }
    end,
}

-- ═══════════════════════════ HGV ═════════════════════════════════════
Config.Jobs.hgv = {
    label = 'HGV Driver',
    vehicle = 'mule',
    depot = { coords = vector3(-30.0, -1470.0, 30.0), spawn = vector4(-42.0, -1478.0, 29.6, 320.0) },
    payMin = 150, payMax = 260,
    dropoffPool = { vector3(1961.0, 3740.0, 32.3), vector3(-448.0, 6008.0, 31.7), vector3(-1034.0, -2733.0, 13.8) },
    stops = function(cfg)
        return {
            { label = 'Load cargo at the depot', points = { cfg.depot.coords } },
            { label = 'Deliver the cargo', points = { PickOne(cfg.dropoffPool) } },
        }
    end,
}

-- ═══════════════════════════ POSTAL ══════════════════════════════════
Config.Jobs.postal = {
    label = 'National Mail Service',
    vehicle = 'speedo',
    depot = { coords = vector3(-42.0, -1478.0, 30.0), spawn = vector4(-55.0, -1490.0, 29.6, 320.0) },
    payMin = 100, payMax = 180,
    dropoffPool = {
        vector3(-269.4, -955.3, 31.2), vector3(441.9, -982.0, 30.7), vector3(-615.0, -150.0, 38.1),
        vector3(380.0, 570.0, 130.0), vector3(-1156.0, -1520.0, 4.6),
    },
    stops = function(cfg)
        return {
            { label = 'Collect the parcels', points = { cfg.depot.coords } },
            { label = 'Deliver to every address', points = PickN(cfg.dropoffPool, 3) },
        }
    end,
}

-- ═══════════════════════════ WASTE COLLECTION ════════════════════════
Config.Jobs.binman = {
    label = 'Waste Collector',
    vehicle = 'trash',
    depot = { coords = vector3(-330.0, -1620.0, 26.0), spawn = vector4(-345.0, -1630.0, 25.6, 210.0) },
    payMin = 90, payMax = 160,
    pickupPool = {
        vector3(-269.4, -955.3, 31.2), vector3(441.9, -982.0, 30.7), vector3(-615.0, -150.0, 38.1),
        vector3(-1156.0, -1520.0, 4.6),
    },
    stops = function(cfg)
        return {
            { label = 'Empty every bin point', points = PickN(cfg.pickupPool, 3) },
            { label = 'Tip the load at the depot', points = { cfg.depot.coords } },
        }
    end,
}

-- ═══════════════════════════ BUS DRIVER ══════════════════════════════
-- A fixed circuit, not randomised — a real route, driven in order.
Config.Jobs.busdriver = {
    label = 'Bus Driver',
    vehicle = 'bus',
    depot = { coords = vector3(428.0, -636.0, 28.0), spawn = vector4(415.0, -648.0, 27.7, 90.0) },
    payMin = 120, payMax = 120, -- flat rate per completed circuit
    route = {
        vector3(-269.4, -955.3, 31.2), vector3(441.9, -982.0, 30.7), vector3(-615.0, -150.0, 38.1),
        vector3(380.0, 570.0, 130.0), vector3(428.0, -636.0, 28.0),
    },
    stops = function(cfg)
        local stops = {}
        for i, point in ipairs(cfg.route) do
            stops[i] = { label = ('Stop %d'):format(i), points = { point } }
        end
        return stops
    end,
}

-- ═══════════════════════════ JOURNALIST (Wire/Picta-adjacent) ═══════
Config.Jobs.reporter = {
    label = 'City News Network',
    vehicle = nil, -- on foot, drive there themselves
    depot = nil,
    payMin = 80, payMax = 150,
    locationPool = { vector3(-269.4, -955.3, 31.2), vector3(-1156.0, -1520.0, 4.6), vector3(1961.0, 3740.0, 32.3) },
    stops = function(cfg)
        return { { label = 'Cover the story', points = { PickOne(cfg.locationPool) } } }
    end,
}

-- ═══════════════════════════ ESTATE AGENT ═══════════════════════════
Config.Jobs.realestate = {
    label = 'Estate Agent',
    vehicle = nil,
    depot = nil,
    payMin = 90, payMax = 170,
    locationPool = { vector3(-615.0, -150.0, 38.1), vector3(380.0, 570.0, 130.0), vector3(-1034.0, -2733.0, 13.8) },
    stops = function(cfg)
        return { { label = 'Appraise the property', points = { PickOne(cfg.locationPool) } } }
    end,
}

-- ═══════════════════════════ NOT INCLUDED, ON PURPOSE ═══════════════
-- `solicitor` and `judiciary` have no shift engine here — every UK RP
-- server treats those as pure roleplay professions (consultations,
-- courtroom scenes), not grindy routes. Forcing a "deliver 3 legal
-- documents" minigame onto a solicitor would be a worse fit than just
-- leaving the job payable (/setjob) and duty-toggleable (/duty) with
-- no automated loop. `mechanic` also isn't here — its gameplay loop is
-- already hd_dispatch's recovery calls.

-- ═══════════════════════════ NOTIFY ══════════════════════════════════
Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
