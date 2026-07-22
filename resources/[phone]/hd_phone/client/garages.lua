-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | GARAGES (client)
--  Actual vehicle spawn/despawn natives. Server already re-validates
--  ownership, state and proximity before ever sending these events —
--  this file just carries out what the server approved.
-- ═══════════════════════════════════════════════════════════════════

local function TrimPlate(p)
    return (p or ''):gsub('%s+$', ''):gsub('^%s+', '')
end

RegisterNUICallback('storeVehicle', function(data, cb)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or TrimPlate(GetVehicleNumberPlateText(veh)) ~= TrimPlate(data.plate) then
        Config.Notify('Get in the vehicle you want to store first.', 'error')
        cb({})
        return
    end
    TriggerServerEvent('hd_phone:server:storeVehicle', {
        plate = data.plate,
        garageKey = data.garageKey,
        netId = VehToNet(veh),
        engine = GetVehicleEngineHealth(veh),
        body = GetVehicleBodyHealth(veh),
    })
    cb({})
end)

RegisterNUICallback('retrieveVehicle', function(data, cb)
    TriggerServerEvent('hd_phone:server:retrieveVehicle', { plate = data.plate, garageKey = data.garageKey })
    cb({})
end)

RegisterNetEvent('hd_phone:client:despawnVehicle', function(netId)
    if not netId then return end
    local veh = NetToVeh(netId)
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    end
end)

RegisterNetEvent('hd_phone:client:spawnVehicle', function(data)
    local hash = GetHashKey(data.model)
    RequestModel(hash)
    local waited = 0
    while not HasModelLoaded(hash) and waited < 5000 do Wait(50) waited = waited + 50 end
    if not HasModelLoaded(hash) then
        Config.Notify('Could not load that vehicle model.', 'error')
        return
    end

    local spawn = data.spawn
    local veh = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleNumberPlateText(veh, data.plate)
    SetVehicleFuelLevel(veh, (data.fuel or 100) + 0.0)
    SetVehicleEngineHealth(veh, (data.engine or 1000) + 0.0)
    SetVehicleBodyHealth(veh, (data.body or 1000) + 0.0)
    SetModelAsNoLongerNeeded(hash)

    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    Config.Notify(('%s retrieved.'):format(data.plate), 'success')
end)
