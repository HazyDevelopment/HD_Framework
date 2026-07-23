-- ═══════════════════════════════════════════════════════════════════
--  hd_ems | server/main.lua
--  Authoritative downed-state tracking. The client decides *when* a
--  player goes down (it's the only side that can see the death event
--  fire), but who's allowed to revive whom is decided here. No timer
--  ever clears a downed player on its own — only a proper EMS revive
--  or staff /revive does.
-- ═══════════════════════════════════════════════════════════════════

Framework = nil
local Downed = {} -- [src] = true

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

local function IsOnDutyAmbulance(src)
    local Player = Framework and Framework.Functions.GetPlayer(src)
    return Player ~= nil and Player.PlayerData.job.name == Config.AmbulanceJob and Player.PlayerData.job.onduty
end

local function InvReady()
    return GetResourceState('hd_inventory') == 'started'
end

local function ClearDowned(src)
    local Player = Framework and Framework.Functions.GetPlayer(src)
    if Player then Player.Functions.SetMetaData('isdead', false) end
    Downed[src] = nil
end

RegisterNetEvent('hd_ems:server:playerDowned', function()
    local src = source
    local Player = Framework and Framework.Functions.GetPlayer(src)
    if not Player then return end
    Downed[src] = true
    Player.Functions.SetMetaData('isdead', true)
end)

RegisterNetEvent('hd_ems:server:reviveRequest', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or not Downed[targetId] then return end
    if not IsOnDutyAmbulance(src) then
        return TriggerClientEvent('HD:Client:Notify', src, 'You must be on-duty ambulance to do that.', 'error')
    end

    local reviverPed, targetPed = GetPlayerPed(src), GetPlayerPed(targetId)
    if not reviverPed or reviverPed == 0 or not targetPed or targetPed == 0 then return end
    if #(GetEntityCoords(reviverPed) - GetEntityCoords(targetPed)) > Config.ReviveDistance + 1.0 then
        return TriggerClientEvent('HD:Client:Notify', src, 'Too far away.', 'error')
    end

    if InvReady() and not exports['hd_inventory']:HasItem(src, Config.ReviveItem, 1) then
        return TriggerClientEvent('HD:Client:Notify', src, ('You need a %s to do that.'):format(Config.ReviveItem), 'error')
    end

    ClearDowned(targetId)
    TriggerClientEvent('hd_ems:client:revived', targetId, Config.ReviveHealth)
    TriggerClientEvent('HD:Client:Notify', targetId, 'You have been revived by an ambulance crew.', 'success')
    TriggerClientEvent('HD:Client:Notify', src, 'Patient revived.', 'success')
end)

-- Lets a downed player still be found/interacted with by EMS clients —
-- pushed on-change rather than polled. Any on-duty ambulance client
-- gets the current downed roster whenever it changes.
local function BroadcastDownedRoster()
    if not Framework then return end
    local roster = {}
    for src in pairs(Downed) do
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            local Player = Framework.Functions.GetPlayer(src)
            roster[#roster + 1] = {
                id = src,
                name = Player and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or 'Unknown',
                x = coords.x, y = coords.y, z = coords.z,
            }
        end
    end
    for _, viewerId in ipairs(Framework.Functions.GetPlayers()) do
        if IsOnDutyAmbulance(viewerId) then
            TriggerClientEvent('hd_ems:client:downedRoster', viewerId, roster)
        end
    end
end

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    while true do
        Wait(3000)
        BroadcastDownedRoster()
    end
end)

AddEventHandler('playerDropped', function()
    Downed[source] = nil
end)

-- Staff /revive (uk_uhsjob) fires 'qb-ambulancejob:client:Revive'
-- client-side as its "let a downed script clear its state" hook —
-- client/main.lua listens for that directly. Mirror the bookkeeping
-- clear here too via the same server event uk_uhsjob's /revive
-- triggers server-side, so Downed[] doesn't go stale if staff revive
-- someone this resource still thinks is down.
RegisterNetEvent('hd_ems:server:externalRevive', function()
    ClearDowned(source)
end)
