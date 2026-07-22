-- ═══════════════════════════════════════════════════════════════════
--  HD VEHICLEKEYS | SERVER
--  VehicleLockState is the single source of truth for whether a plate
--  is locked, broadcast to every client on change. Ownership/shared
--  keys are just permission checks on top of that — never a second
--  copy of who owns what (player_vehicles.citizenid already is that).
-- ═══════════════════════════════════════════════════════════════════

local Framework = nil
CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

local VehicleLockState = {} -- [plate] = bool, lazily initialised to Config.DefaultLocked

local function GetOwnerCitizenId(plate)
    return MySQL.scalar.await('SELECT citizenid FROM player_vehicles WHERE plate = ?', { plate })
end

local function HasKeys(src, plate)
    local ownerCitizenId = GetOwnerCitizenId(plate)
    if not ownerCitizenId then return true end -- unowned/NPC vehicle — no key concept applies

    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return false end
    if Player.PlayerData.citizenid == ownerCitizenId then return true end

    return MySQL.scalar.await('SELECT 1 FROM hd_vehicle_keys WHERE plate = ? AND citizenid = ?', {
        plate, Player.PlayerData.citizenid
    }) and true or false
end

exports('HasKeys', HasKeys)

RegisterNetEvent('hd_vehiclekeys:server:queryPlate', function(plate)
    local src = source
    local ownerCitizenId = GetOwnerCitizenId(plate)
    if not ownerCitizenId then
        TriggerClientEvent('hd_vehiclekeys:client:plateStatus', src, plate, { owned = false })
        return
    end

    if VehicleLockState[plate] == nil then VehicleLockState[plate] = Config.DefaultLocked end

    TriggerClientEvent('hd_vehiclekeys:client:plateStatus', src, plate, {
        owned = true,
        hasKeys = HasKeys(src, plate),
        locked = VehicleLockState[plate],
    })
end)

RegisterNetEvent('hd_vehiclekeys:server:toggleLock', function(plate)
    local src = source
    if not GetOwnerCitizenId(plate) then return end -- can't lock an unowned vehicle
    if not HasKeys(src, plate) then
        TriggerClientEvent('HD:Client:Notify', src, "You don't have keys to that.", 'error')
        return
    end

    if VehicleLockState[plate] == nil then VehicleLockState[plate] = Config.DefaultLocked end
    VehicleLockState[plate] = not VehicleLockState[plate]

    TriggerClientEvent('hd_vehiclekeys:client:lockChanged', -1, plate, VehicleLockState[plate])
end)

RegisterNetEvent('hd_vehiclekeys:server:giveKeys', function(plate, targetId)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    local Target = Framework.Functions.GetPlayer(targetId)
    if not Player or not Target then return end

    local ownerCitizenId = GetOwnerCitizenId(plate)
    if not ownerCitizenId or ownerCitizenId ~= Player.PlayerData.citizenid then
        TriggerClientEvent('HD:Client:Notify', src, 'Only the owner can share keys.', 'error')
        return
    end

    local srcPed, targetPed = GetPlayerPed(src), GetPlayerPed(targetId)
    if #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed)) > Config.GiveKeysRadius then
        TriggerClientEvent('HD:Client:Notify', src, 'They need to be closer.', 'error')
        return
    end

    MySQL.insert.await('INSERT IGNORE INTO hd_vehicle_keys (plate, citizenid) VALUES (?, ?)', {
        plate, Target.PlayerData.citizenid
    })

    TriggerClientEvent('HD:Client:Notify', src, ('Keys to %s given.'):format(plate), 'success')
    TriggerClientEvent('HD:Client:Notify', targetId, ('You were given keys to %s.'):format(plate), 'success')
end)

RegisterNetEvent('hd_vehiclekeys:server:revokeKeys', function(plate, targetId)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    local Target = Framework.Functions.GetPlayer(targetId)
    if not Player or not Target then return end

    local ownerCitizenId = GetOwnerCitizenId(plate)
    if not ownerCitizenId or ownerCitizenId ~= Player.PlayerData.citizenid then
        TriggerClientEvent('HD:Client:Notify', src, 'Only the owner can revoke keys.', 'error')
        return
    end

    MySQL.query.await('DELETE FROM hd_vehicle_keys WHERE plate = ? AND citizenid = ?', { plate, Target.PlayerData.citizenid })
    TriggerClientEvent('HD:Client:Notify', src, 'Keys revoked.', 'success')
end)

-- ═══════════════════════════ BREAKING IN ═════════════════════════════
-- Client already committed to an uninterrupted multi-round timing
-- minigame before this ever fires (see client/main.lua) — `passed` is
-- its outcome, an INPUT to the odds below, not the outcome itself.
-- The server still rolls the actual result every time, just weighted
-- a lot more favourably on a win — a spoofed "I won" from a cheat
-- client only ever gets FailedMinigameChance's worse odds, never a
-- guarantee. Also re-validates the vehicle is actually still locked
-- and not already theirs, same as everything else here.
RegisterNetEvent('hd_vehiclekeys:server:attemptBreakIn', function(plate, coords, passed)
    local src = source
    if not Config.BreakIn.Enabled then return end
    if not GetOwnerCitizenId(plate) then return end -- nothing to break into
    if HasKeys(src, plate) then return end
    if VehicleLockState[plate] ~= true then return end

    local chance = (passed == true) and Config.BreakIn.SuccessChance or Config.BreakIn.FailedMinigameChance
    local success = math.random() <= chance
    local alarm = math.random() <= Config.BreakIn.AlarmChance

    if success then
        VehicleLockState[plate] = false
        TriggerClientEvent('hd_vehiclekeys:client:lockChanged', -1, plate, false)
        TriggerClientEvent('HD:Client:Notify', src, 'You forced the lock.', 'success')
    else
        TriggerClientEvent('HD:Client:Notify', src, 'You failed to break in.', 'error')
    end

    if alarm then
        TriggerClientEvent('hd_vehiclekeys:client:triggerAlarm', src, plate)
        if Config.BreakIn.NotifyPoliceOnAlarm and GetResourceState('hd_dispatch') == 'started' and type(coords) == 'table' then
            exports['hd_dispatch']:CreateCall('police', {
                title = 'Vehicle Break-in',
                description = ('A car alarm was triggered near a locked %s.'):format(plate),
                coords = coords,
                priority = Config.BreakIn.PoliceCallPriority,
                autoType = 'breakin',
            })
        end
    end
end)
