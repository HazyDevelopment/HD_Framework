-- ═══════════════════════════════════════════════════════════════════
--  HD INVENTORY | VEHICLE STORAGE (client)
--  No vehicle locking/keys system exists yet in this framework, so
--  both commands are open to anyone with physical access — trunk to
--  anyone standing nearby, glovebox to whoever's actually in the
--  vehicle. Server re-validates both live from the vehicle entity, so
--  this file just finds the vehicle and asks.
-- ═══════════════════════════════════════════════════════════════════

local function GetClosestVehicle(coords, maxDistance)
    local closest, closestDist = nil, maxDistance
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local dist = #(GetEntityCoords(veh) - coords)
        if dist < closestDist then closest, closestDist = veh, dist end
    end
    return closest
end

RegisterCommand('trunk', function()
    if IsInventoryOpen() then return end
    local ped = PlayerPedId()
    local veh = GetClosestVehicle(GetEntityCoords(ped), Config.VehicleInteractDistance)
    if not veh then
        Config.Notify('No vehicle nearby.', 'error')
        return
    end
    OpenSecondaryInventory({ type = 'trunk', netId = NetworkGetNetworkIdFromEntity(veh) })
end, false)

RegisterCommand('glovebox', function()
    if IsInventoryOpen() then return end
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then
        Config.Notify('Get in a vehicle first.', 'error')
        return
    end
    OpenSecondaryInventory({ type = 'glovebox', netId = NetworkGetNetworkIdFromEntity(veh) })
end, false)
