-- ═══════════════════════════════════════════════════════════════════
--  HD CARDEALER | SERVER
--  Price and proximity are both re-checked here — the NUI catalog is
--  just a display, never trusted for the actual charge.
-- ═══════════════════════════════════════════════════════════════════

local Framework = nil
CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

local function FindCatalogEntry(model)
    for _, entry in ipairs(Config.Catalog) do
        if entry.model == model then return entry end
    end
    return nil
end

local function GeneratePlate()
    local chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    local plate
    repeat
        local part = 'HD'
        for _ = 1, 5 do
            local i = math.random(1, #chars)
            part = part .. chars:sub(i, i)
        end
        plate = part
        local exists = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { plate })
    until not exists
    return plate
end

RegisterNetEvent('hd_cardealer:server:purchase', function(model)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end

    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - Config.Dealership.coords) > (Config.InteractRadius + 3.0) then
        TriggerClientEvent('HD:Client:Notify', src, 'You need to be at the dealership.', 'error')
        return
    end

    local entry = FindCatalogEntry(model)
    if not entry then return end

    if not Player.Functions.RemoveMoney('bank', entry.price, 'vehicle-purchase') then
        TriggerClientEvent('HD:Client:Notify', src, 'Insufficient funds in your bank account.', 'error')
        return
    end

    local plate = GeneratePlate()
    MySQL.insert.await(
        'INSERT INTO player_vehicles (license, citizenid, vehicle, plate, state, fuel, engine, body) VALUES (?, ?, ?, ?, 0, 100, 1000, 1000)',
        { Player.PlayerData.license, Player.PlayerData.citizenid, entry.model, plate }
    )

    if GetResourceState('hd_society') == 'started' and Config.SocietyCut > 0 then
        exports['hd_society']:AddFunds('cardealer', math.floor(entry.price * Config.SocietyCut))
    end

    if GetResourceState('hd_mechanic') == 'started' then
        exports['hd_mechanic']:InitTempCompliance(plate)
    end

    TriggerClientEvent('hd_cardealer:client:purchased', src, entry.model, plate)
    TriggerClientEvent('HD:Client:Notify', src, ('Bought a %s (%s) for £%d.'):format(entry.label, plate, entry.price), 'success')
end)
