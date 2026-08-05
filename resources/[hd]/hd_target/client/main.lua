-- ═══════════════════════════════════════════════════════════════════
--  HD TARGET | CLIENT
--  Pure client-side: raycasts from the camera centre while Config.
--  HoldKey is held, matches whatever's under the reticle against
--  registered model/entity options, and lets E confirm (scroll cycles
--  between multiple options on the same thing). The NUI is a passive
--  display only — no SetNuiFocus, no mouse capture, since this has to
--  work while free-looking with the camera exactly like aiming does.
--  Whatever an option's `event`/`serverEvent` actually DOES is entirely
--  up to whoever registered it; this resource only ever decides WHAT's
--  being looked at and WHICH option is selected, never whether the
--  action itself is allowed — same trust boundary as hd_radial's menu.
-- ═══════════════════════════════════════════════════════════════════

local ModelOptions = {}  -- [modelHash] = { option, ... }
local EntityOptions = {} -- [entity] = { option, ... }
local GlobalVehicleOptions = {} -- any vehicle, any model — for options that don't care which one (e.g. "diagnose")
local GlobalPedOptions = {}
local GlobalObjectOptions = {}
local Zones = {} -- [id] = { coords, radius, options } — coordinate-based, not raycast-based (see AddZone below)

local holding = false
local currentTarget = nil -- { entity, options } (entity nil for a zone match) — only set while a valid target is actually shown
local selectedIndex = 1

-- ═══════════════════════════ REGISTRATION API ══════════════════════════
-- `options` is a list of { icon, label, distance, event, serverEvent,
-- args, canInteract }. `event` is TriggerEvent'd locally (entity, args);
-- `serverEvent` is TriggerServerEvent'd instead, with the entity's
-- network id in place of the raw handle (server-side never trusts a
-- raw client entity handle) — set whichever fits what the option does,
-- not both. For a zone match there's no entity at all, so
-- serverEvent/event just get `args` directly. `canInteract(entity)`, if
-- given, is called fresh every poll so an option can hide itself
-- contextually (e.g. "only if unlocked") — entity is nil for a zone.
exports('AddModel', function(models, options)
    if type(models) ~= 'table' then models = { models } end
    for _, m in ipairs(models) do
        local hash = type(m) == 'string' and GetHashKey(m) or m
        ModelOptions[hash] = ModelOptions[hash] or {}
        for _, opt in ipairs(options) do table.insert(ModelOptions[hash], opt) end
    end
end)

exports('AddEntity', function(entity, options)
    EntityOptions[entity] = EntityOptions[entity] or {}
    for _, opt in ipairs(options) do table.insert(EntityOptions[entity], opt) end
end)

exports('RemoveEntity', function(entity)
    EntityOptions[entity] = nil
end)

-- "Any vehicle/ped/object" fallback — checked only once a raycast hit
-- entity has no specific model/entity registration of its own. For
-- something like "diagnose this vehicle" that applies to every vehicle
-- model in the game, registering each one individually isn't practical.
exports('AddGlobalVehicle', function(options)
    for _, opt in ipairs(options) do table.insert(GlobalVehicleOptions, opt) end
end)
exports('AddGlobalPed', function(options)
    for _, opt in ipairs(options) do table.insert(GlobalPedOptions, opt) end
end)
exports('AddGlobalObject', function(options)
    for _, opt in ipairs(options) do table.insert(GlobalObjectOptions, opt) end
end)

-- A fixed world coordinate with no real entity behind it at all (an
-- apartment's street entrance is just open air, not a solid prop) —
-- checked by plain distance from the player every poll, independent of
-- where the camera's actually pointed, same as ox_target's box zones.
-- `id` lets the caller update/remove this exact zone later.
exports('AddZone', function(id, coords, radius, options)
    Zones[id] = { coords = coords, radius = radius, options = options }
end)
exports('RemoveZone', function(id)
    Zones[id] = nil
end)

-- Entities get deleted/despawned all the time (a dropped item picked
-- up, a vehicle that's driven far enough to get culled) — without this
-- EntityOptions would just accumulate stale handles forever.
CreateThread(function()
    while true do
        Wait(30000)
        for entity in pairs(EntityOptions) do
            if not DoesEntityExist(entity) then EntityOptions[entity] = nil end
        end
    end
end)

-- ═══════════════════════════ RAYCAST ═══════════════════════════════════
-- Standard camera-centre raycast — GetGameplayCamCoord/Rot converted to
-- a forward direction, then a ray shape-test out to Config.MaxDistance.
local function RotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function RaycastCamera(maxDistance)
    local camCoord = GetGameplayCamCoord()
    local direction = RotationToDirection(GetGameplayCamRot(2))
    local destination = camCoord + direction * maxDistance
    local rayHandle = StartShapeTestRay(
        camCoord.x, camCoord.y, camCoord.z, destination.x, destination.y, destination.z,
        -1, PlayerPedId(), 0
    )
    local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)
    return hit == 1, entityHit
end

-- `entity` is nil for a zone match — `refCoords` (the zone's own centre,
-- or the entity's coords) is what per-option `distance` is measured
-- against either way.
local function UsableOptions(entity, refCoords, options)
    local usable = {}
    local pedCoords = GetEntityCoords(PlayerPedId())
    for _, opt in ipairs(options) do
        if not opt.distance or opt.distance <= 0 or #(pedCoords - refCoords) <= opt.distance then
            if not opt.canInteract or opt.canInteract(entity) then
                usable[#usable + 1] = opt
            end
        end
    end
    return usable
end

local function ResolveEntityOptions(entity)
    local options = EntityOptions[entity] or ModelOptions[GetEntityModel(entity)]
    if options then return options end
    if IsEntityAVehicle(entity) then return #GlobalVehicleOptions > 0 and GlobalVehicleOptions or nil end
    if IsEntityAPed(entity) then return #GlobalPedOptions > 0 and GlobalPedOptions or nil end
    if IsEntityAnObject(entity) then return #GlobalObjectOptions > 0 and GlobalObjectOptions or nil end
    return nil
end

-- Closest in-range zone to the player, or nil — zones aren't mutually
-- exclusive by design (two could theoretically overlap) but only one
-- can be "the" target at a time, same as an entity under the reticle.
local function ClosestZone()
    local pedCoords = GetEntityCoords(PlayerPedId())
    local best, bestDist = nil, nil
    for id, zone in pairs(Zones) do
        local dist = #(pedCoords - zone.coords)
        if dist <= zone.radius and (not bestDist or dist < bestDist) then
            best, bestDist = { id = id, zone = zone }, dist
        end
    end
    return best
end

local function DisplayList(options)
    local list = {}
    for i, opt in ipairs(options) do
        list[i] = { icon = opt.icon, label = opt.label }
    end
    return list
end

-- ═══════════════════════════ HOLD KEY ══════════════════════════════════
RegisterKeyMapping('hd_target_hold', 'HD Target: hold to interact', 'keyboard', Config.HoldKey)
RegisterCommand('+hd_target_hold', function()
    holding = true
    SendNUIMessage({ action = 'show' })
end, false)
RegisterCommand('-hd_target_hold', function()
    holding = false
    currentTarget = nil
    SendNUIMessage({ action = 'hide' })
end, false)

CreateThread(function()
    while true do
        local sleep = 300
        if holding then
            sleep = Config.PollMs
            local hit, entity = RaycastCamera(Config.MaxDistance)
            local entityOptions = (hit and entity ~= 0) and ResolveEntityOptions(entity) or nil
            local usable, targetKey = {}, nil

            -- Aiming at something registered beats an ambient zone —
            -- only fall back to the closest in-range zone if the
            -- raycast found nothing usable this tick.
            if entityOptions then
                usable = UsableOptions(entity, GetEntityCoords(entity), entityOptions)
                targetKey = entity
            end
            if #usable == 0 then
                local closest = ClosestZone()
                if closest then
                    usable = UsableOptions(nil, closest.zone.coords, closest.zone.options)
                    targetKey = 'zone:' .. tostring(closest.id)
                    entity = nil
                end
            end

            if #usable > 0 then
                if not currentTarget or currentTarget.key ~= targetKey then selectedIndex = 1 end
                currentTarget = { key = targetKey, entity = entity, options = usable }
                if selectedIndex > #usable then selectedIndex = 1 end
                SendNUIMessage({ action = 'options', list = DisplayList(usable), selected = selectedIndex })
            else
                currentTarget = nil
                SendNUIMessage({ action = 'options', list = {} })
            end
        end
        Wait(sleep)
    end
end)

-- ═══════════════════════════ SELECT / CONFIRM ══════════════════════════
-- `entity` is nil for a zone match — nothing to resolve a network id
-- from, so the event/serverEvent just gets `args` directly instead.
local function TriggerOption(entity, opt)
    if entity then
        if opt.serverEvent then
            TriggerServerEvent(opt.serverEvent, NetworkGetNetworkIdFromEntity(entity), opt.args)
        elseif opt.event then
            TriggerEvent(opt.event, entity, opt.args)
        end
    else
        if opt.serverEvent then
            TriggerServerEvent(opt.serverEvent, opt.args)
        elseif opt.event then
            TriggerEvent(opt.event, opt.args)
        end
    end
end

CreateThread(function()
    while true do
        local sleep = 300
        if holding and currentTarget then
            sleep = 0
            local count = #currentTarget.options

            if count > 1 and IsControlJustPressed(0, 15) then -- scroll down
                selectedIndex = selectedIndex % count + 1
                SendNUIMessage({ action = 'select', selected = selectedIndex })
            elseif count > 1 and IsControlJustPressed(0, 16) then -- scroll up
                selectedIndex = (selectedIndex - 2) % count + 1
                SendNUIMessage({ action = 'select', selected = selectedIndex })
            elseif IsControlJustPressed(0, Config.InteractKey) then
                TriggerOption(currentTarget.entity, currentTarget.options[selectedIndex])
            end
        end
        Wait(sleep)
    end
end)
