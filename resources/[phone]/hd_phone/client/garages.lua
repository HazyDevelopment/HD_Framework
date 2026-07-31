-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | GARAGES (CLIENT)
--  Store needs to be inside the vehicle to read its live health;
--  retrieve just needs to be at the garage. Both re-validated
--  server-side regardless of what this file reports.
-- ═══════════════════════════════════════════════════════════════════

local function TrimPlate(p) return (p or ''):gsub('%s+$', ''):gsub('^%s+', '') end

RegisterNUICallback('storeVehicle', function(data, cb)
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        cb({ ok = false, reason = 'Get in the vehicle first.' })
        return
    end
    local veh = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        cb({ ok = false, reason = 'Only the driver can store this vehicle.' })
        return
    end
    local plate = TrimPlate(GetVehicleNumberPlateText(veh))
    local engine = GetVehicleEngineHealth(veh)
    local body = GetVehicleBodyHealth(veh)
    TriggerServerEvent('hd_phone:server:storeVehicle', plate, data.garageKey, engine, body)
    cb({ ok = true })
end)

RegisterNUICallback('retrieveVehicle', function(data, cb)
    TriggerServerEvent('hd_phone:server:retrieveVehicle', data.plate, data.garageKey)
    cb({ ok = true })
end)

RegisterNetEvent('hd_phone:client:vehicleStored', function(plate)
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if TrimPlate(GetVehicleNumberPlateText(veh)) == plate then
            DeleteEntity(veh)
            break
        end
    end
end)

RegisterNetEvent('hd_phone:client:vehicleRetrieved', function(data)
    local hash = GetHashKey(data.model)
    RequestModel(hash)
    local waited = 0
    while not HasModelLoaded(hash) and waited < 5000 do Wait(50) waited = waited + 50 end
    if not HasModelLoaded(hash) then return end

    local veh = CreateVehicle(hash, data.coords.x, data.coords.y, data.coords.z, data.coords.w, true, false)
    SetVehicleNumberPlateText(veh, data.plate)
    SetVehicleEngineHealth(veh, data.engine + 0.0)
    SetVehicleBodyHealth(veh, data.body + 0.0)
    SetVehicleFuelLevel(veh, 100.0)
    SetVehicleOnGroundProperly(veh)
    SetModelAsNoLongerNeeded(hash)
    SendNUIMessage({ action = 'vehicleSpawned', plate = data.plate })
end)
