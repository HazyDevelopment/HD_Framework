-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | GARAGES
--  Reads/writes the `player_vehicles` table HD_Framework already
--  created — no new table needed here. Store/retrieve state and
--  health are re-validated server-side, the client only ever suggests
--  which plate and which garage.
-- ═══════════════════════════════════════════════════════════════════

function TrimPlate(p) return (p or ''):gsub('%s+$', ''):gsub('^%s+', '') end

local function SendVehicles(src, citizenid)
    local rows = MySQL.query.await('SELECT plate, vehicle, garage, state, engine, body FROM player_vehicles WHERE citizenid = ?', {
        citizenid
    }) or {}
    TriggerClientEvent('hd_phone:client:vehicles', src, rows)
end

RegisterNetEvent('hd_phone:server:getVehicles', function()
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    SendVehicles(src, Player.PlayerData.citizenid)
end)

local function FindGarage(key)
    for _, g in ipairs(Config.Garages) do
        if g.key == key then return g end
    end
    return nil
end

-- Client already confirmed it's inside the vehicle and reported live
-- health — this just re-validates ownership before persisting.
RegisterNetEvent('hd_phone:server:storeVehicle', function(plate, garageKey, engineHealth, bodyHealth)
    local src = source
    local Player = GetPlayerOrNil(src)
    local garage = FindGarage(garageKey)
    if not Player or not garage then return end
    plate = TrimPlate(plate or '')

    local owned = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ? AND citizenid = ?', { plate, Player.PlayerData.citizenid })
    if not owned then return end

    engineHealth = math.max(0, math.min(1000, tonumber(engineHealth) or 1000))
    bodyHealth = math.max(0, math.min(1000, tonumber(bodyHealth) or 1000))
    MySQL.update('UPDATE player_vehicles SET garage = ?, state = 1, engine = ?, body = ? WHERE plate = ?', {
        garageKey, engineHealth, bodyHealth, plate
    })
    TriggerClientEvent('hd_phone:client:vehicleStored', src, plate)
    Notify(src, 'Vehicle stored.', 'success')
    SendVehicles(src, Player.PlayerData.citizenid)
end)

RegisterNetEvent('hd_phone:server:retrieveVehicle', function(plate, garageKey)
    local src = source
    local Player = GetPlayerOrNil(src)
    local garage = FindGarage(garageKey)
    if not Player or not garage then return end
    plate = TrimPlate(plate or '')

    local row = MySQL.single.await('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', { plate, Player.PlayerData.citizenid })
    if not row then return end
    if row.state ~= 1 or row.garage ~= garageKey then
        Notify(src, "That vehicle isn't in this garage.", 'error')
        return
    end

    MySQL.update('UPDATE player_vehicles SET state = 0 WHERE plate = ?', { plate })
    TriggerClientEvent('hd_phone:client:vehicleRetrieved', src, {
        plate = plate, model = row.vehicle, engine = row.engine, body = row.body,
        coords = garage.coords,
    })
    SendVehicles(src, Player.PlayerData.citizenid)
end)
