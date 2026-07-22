-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | GARAGES
--  Store/retrieve is gated server-side on: the vehicle actually
--  belonging to this citizenid, its current state matching what's
--  being requested, and the player's ped being within the garage's
--  radius — never trust the client's word alone on any of these.
-- ═══════════════════════════════════════════════════════════════════

local function FindGarage(key)
    for _, g in ipairs(Config.Garages) do
        if g.key == key then return g end
    end
    return nil
end

local function PlayerNearGarage(src, garage)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    return #(coords - garage.coords) <= garage.radius
end

RegisterNetEvent('hd_phone:server:getVehicles', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end

    local rows = MySQL.query.await(
        'SELECT plate, vehicle, garage, state, fuel, engine, body FROM player_vehicles WHERE citizenid = ? ORDER BY vehicle ASC',
        { Player.PlayerData.citizenid }
    ) or {}
    TriggerClientEvent('hd_phone:client:vehicles', src, rows)
end)

RegisterNetEvent('hd_phone:server:storeVehicle', function(data)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or type(data) ~= 'table' then return end

    local garage = FindGarage(data.garageKey)
    if not garage or not PlayerNearGarage(src, garage) then
        TriggerClientEvent('HD:Client:Notify', src, 'You need to be at the garage to store a vehicle.', 'error')
        return
    end

    local row = MySQL.single.await('SELECT plate, state FROM player_vehicles WHERE plate = ? AND citizenid = ?', {
        data.plate, Player.PlayerData.citizenid
    })
    if not row or row.state == 1 then
        TriggerClientEvent('HD:Client:Notify', src, "That vehicle isn't yours or is already stored.", 'error')
        return
    end

    -- Client-reported, so clamp to the native's real 0-1000 range before
    -- persisting — this is what actually makes hd_mechanic's repairs
    -- (or any crash damage) stick across a store/retrieve cycle; before
    -- this, store never wrote live health back, so a car always came
    -- back at whatever `engine`/`body` was last written (usually still
    -- 1000 from the original purchase insert, forever).
    local engine = math.max(0, math.min(1000, tonumber(data.engine) or 1000))
    local body = math.max(0, math.min(1000, tonumber(data.body) or 1000))

    MySQL.update('UPDATE player_vehicles SET state = 1, garage = ?, engine = ?, body = ? WHERE plate = ?', {
        garage.key, engine, body, data.plate
    })
    TriggerClientEvent('hd_phone:client:despawnVehicle', src, data.netId)
    TriggerClientEvent('HD:Client:Notify', src, ('%s stored at %s.'):format(data.plate, garage.label), 'success')
end)

RegisterNetEvent('hd_phone:server:retrieveVehicle', function(data)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or type(data) ~= 'table' then return end

    local garage = FindGarage(data.garageKey)
    if not garage or not PlayerNearGarage(src, garage) then
        TriggerClientEvent('HD:Client:Notify', src, 'You need to be at the garage to retrieve a vehicle.', 'error')
        return
    end

    local row = MySQL.single.await(
        'SELECT plate, vehicle, garage, state, fuel, engine, body FROM player_vehicles WHERE plate = ? AND citizenid = ?',
        { data.plate, Player.PlayerData.citizenid }
    )
    if not row or row.state == 0 or row.garage ~= garage.key then
        TriggerClientEvent('HD:Client:Notify', src, "That vehicle isn't stored at this garage.", 'error')
        return
    end

    MySQL.update('UPDATE player_vehicles SET state = 0 WHERE plate = ?', { row.plate })
    TriggerClientEvent('hd_phone:client:spawnVehicle', src, {
        plate = row.plate, model = row.vehicle, spawn = garage.spawn,
        fuel = row.fuel, engine = row.engine, body = row.body,
    })
end)
