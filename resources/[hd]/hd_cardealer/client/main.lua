-- ═══════════════════════════════════════════════════════════════════
--  HD CARDEALER | CLIENT
-- ═══════════════════════════════════════════════════════════════════

local nuiOpen = false

local function CloseCatalog()
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterCommand(Config.Command, function()
    if nuiOpen then return end
    local ped = PlayerPedId()
    if #(GetEntityCoords(ped) - Config.Dealership.coords) > Config.InteractRadius then
        Config.Notify('You need to be at the dealership.', 'error')
        return
    end
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', catalog = Config.Catalog })
end, false)

RegisterNUICallback('close', function(_, cb) CloseCatalog() cb({}) end)
RegisterNUICallback('buy', function(data, cb)
    TriggerServerEvent('hd_cardealer:server:purchase', data.model)
    cb({})
end)

RegisterNetEvent('hd_cardealer:client:purchased', function(model, plate)
    CloseCatalog()

    local hash = GetHashKey(model)
    RequestModel(hash)
    local waited = 0
    while not HasModelLoaded(hash) and waited < 5000 do Wait(50) waited = waited + 50 end
    if not HasModelLoaded(hash) then return end

    local spawn = Config.Dealership.spawn
    local veh = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleNumberPlateText(veh, plate)
    SetModelAsNoLongerNeeded(hash)
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
end)
