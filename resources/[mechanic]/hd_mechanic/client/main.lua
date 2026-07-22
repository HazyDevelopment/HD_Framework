-- ═══════════════════════════════════════════════════════════════════
--  HD MECHANIC | CLIENT
--  Pure rendering + input relay for the shop/NUI side; the server
--  re-validates on-duty status, shop proximity and ownership on every
--  action regardless of what this file does. The crash-detection and
--  limp-mode application below are the one exception — real-time
--  vehicle physics only exist client-side, so this file is the source
--  of truth for "did a hard impact just happen" and "apply the power/
--  torque/speed cap right now", not just a UI shell for those two.
-- ═══════════════════════════════════════════════════════════════════

local function VehToNet(veh) return NetworkGetNetworkIdFromEntity(veh) end
local function NetToVeh(netId) return NetworkGetEntityFromNetworkId(netId) end

local function IsPlayerNearVehicle(veh, maxDist)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    return #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(veh)) <= (maxDist or 20.0)
end

-- ═══════════════════════════ SHOP BLIPS ═════════════════════════════════
CreateThread(function()
    for _, shop in ipairs(Config.Shops) do
        local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, shop.blip.sprite)
        SetBlipColour(blip, shop.blip.colour)
        SetBlipScale(blip, shop.blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(shop.label)
        EndTextCommandSetBlipName(blip)
    end
end)

-- ═══════════════════════════ CRASH DETECTION ════════════════════════════
-- Driver-only, polled every 200ms — a sudden loss of at least DeltaMph
-- while already above SpeedThresholdMph reads as a hard impact. This
-- is an inherently client-reported signal (see file header); the
-- server still clamps the claimed speed and rate-limits per plate.
local lastSpeedMph = 0.0

CreateThread(function()
    while true do
        Wait(200)
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(veh, -1) == ped then
                local speedMph = GetEntitySpeed(veh) * 2.236936
                if lastSpeedMph >= Config.LimpMode.SpeedThresholdMph
                    and (lastSpeedMph - speedMph) >= Config.LimpMode.DeltaMph then
                    TriggerServerEvent('hd_mechanic:server:reportImpact', VehToNet(veh), math.floor(lastSpeedMph))
                end
                lastSpeedMph = speedMph
            else
                lastSpeedMph = 0.0
            end
        else
            lastSpeedMph = 0.0
        end
    end
end)

-- ═══════════════════════════ LIMP MODE APPLICATION ══════════════════════
-- Driven by the vehicle's own `hd_limpMode` state bag, not a direct
-- event — state bags replicate automatically to every client that has
-- the entity loaded, so passengers/bystanders see the same struggling
-- engine as the driver, not just whoever triggered it.
local LimpVehicles = {}

local function ApplyLimpCap(veh)
    SetVehicleEnginePowerMultiplier(veh, Config.LimpMode.PowerMultiplier)
    SetVehicleEngineTorqueMultiplier(veh, Config.LimpMode.TorqueMultiplier) -- must be reapplied every frame to hold
    SetEntityMaxSpeed(veh, Config.LimpMode.MaxSpeedMph * 0.44704)
end

local function ClearLimpCap(veh)
    SetVehicleEnginePowerMultiplier(veh, 1.0)
    SetVehicleEngineTorqueMultiplier(veh, 1.0)
    SetEntityMaxSpeed(veh, 100.0) -- effectively uncapped for anything in this game
end

AddStateBagChangeHandler('hd_limpMode', '', function(bagName, _, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    if value then
        LimpVehicles[entity] = true
    else
        LimpVehicles[entity] = nil
        ClearLimpCap(entity)
    end
end)

CreateThread(function()
    while true do
        local any = false
        for veh in pairs(LimpVehicles) do
            if DoesEntityExist(veh) then
                any = true
                ApplyLimpCap(veh)
            else
                LimpVehicles[veh] = nil
            end
        end
        Wait(any and 0 or 500)
    end
end)

-- ═══════════════════════════ HEALTH PUSHES FROM SERVER ══════════════════
-- Broadcast to everyone; only clients actually near the vehicle apply
-- the native calls, so a parked-and-empty car being serviced at the
-- shop still gets fixed (proximity, not "am I the driver").
RegisterNetEvent('hd_mechanic:client:setEngineHealth', function(netId, mode, value)
    local veh = NetToVeh(netId)
    if not IsPlayerNearVehicle(veh) then return end

    NetworkRequestControlOfEntity(veh)
    if mode == 'floor' then
        if GetVehicleEngineHealth(veh) < value then
            SetVehicleEngineHealth(veh, value + 0.0)
        end
    else
        SetVehicleEngineHealth(veh, value + 0.0)
    end
end)

RegisterNetEvent('hd_mechanic:client:fullRepairVisual', function(netId)
    local veh = NetToVeh(netId)
    if not IsPlayerNearVehicle(veh) then return end

    NetworkRequestControlOfEntity(veh)
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleUndriveable(veh, false)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleDirtLevel(veh, 0.0)
    for i = 0, 5 do
        SetVehicleTyreFixed(veh, i)
    end
end)

-- ═══════════════════════════ TARGET VEHICLE RESOLUTION ══════════════════
local function GetClosestVehicle(coords, maxDistance)
    local closest, closestDist = nil, maxDistance
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local dist = #(GetEntityCoords(veh) - coords)
        if dist < closestDist then closest, closestDist = veh, dist end
    end
    return closest
end

local function GetTargetVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    return GetClosestVehicle(GetEntityCoords(ped), 8.0)
end

-- ═══════════════════════════ /diagnose — MECHANIC TERMINAL ══════════════
RegisterCommand(Config.Command, function()
    local veh = GetTargetVehicle()
    if not veh then
        Config.Notify('No vehicle nearby.', 'error')
        return
    end
    TriggerServerEvent('hd_mechanic:server:openTerminal', VehToNet(veh))
end, false)

local currentNetId = nil

RegisterNetEvent('hd_mechanic:client:terminal', function(data)
    currentNetId = data.netId
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNUICallback('fullRepair', function(_, cb)
    if currentNetId then TriggerServerEvent('hd_mechanic:server:fullRepair', currentNetId) end
    cb({})
end)

RegisterNUICallback('issueMOT', function(_, cb)
    if currentNetId then TriggerServerEvent('hd_mechanic:server:issueMOT', currentNetId) end
    cb({})
end)

RegisterNUICallback('issueInsurance', function(_, cb)
    if currentNetId then TriggerServerEvent('hd_mechanic:server:issueInsurance', currentNetId) end
    cb({})
end)

-- ═══════════════════════════ /vehiclestatus — SELF-SERVICE CHECK ════════
RegisterCommand(Config.StatusCommand, function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        Config.Notify('Get in a vehicle first.', 'error')
        return
    end
    TriggerServerEvent('hd_mechanic:server:getStatus', VehToNet(GetVehiclePedIsIn(ped, false)))
end, false)

RegisterNetEvent('hd_mechanic:client:status', function(plate, compliance)
    local mot = compliance.motValid and ('MOT valid until ' .. tostring(compliance.motExpiry)) or 'MOT EXPIRED/NONE'
    local ins = compliance.insuranceValid and ('Insurance valid until ' .. tostring(compliance.insuranceExpiry)) or 'INSURANCE EXPIRED/NONE'
    Config.Notify(('%s — %s'):format(plate, mot), compliance.motValid and 'info' or 'error')
    Config.Notify(ins, compliance.insuranceValid and 'info' or 'error')
    if compliance.limpMode then
        Config.Notify('LIMP MODE ACTIVE — needs an advanced repair kit or a mechanic.', 'error')
    end
end)
