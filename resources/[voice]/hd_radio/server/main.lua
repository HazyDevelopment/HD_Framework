-- ═══════════════════════════════════════════════════════════════════
--  HD RADIO | SERVER
--  All this does is decide who's allowed on a channel and forward
--  that decision to pma-voice's own exports['pma-voice']:setPlayerRadio
--  — pma-voice owns the actual audio routing and PTT key entirely.
-- ═══════════════════════════════════════════════════════════════════

local Framework = nil
CreateThread(function()
    while GetResourceState('qb-core') ~= 'started' do Wait(100) end
    Framework = exports['qb-core']:GetCoreObject()
end)

local PlayerChannel = {} -- [src] = channel, for /radio's status reply

local function HasRadioItem(src)
    if GetResourceState('hd_inventory') ~= 'started' then return true end -- degrade open if inventory isn't installed
    return exports['hd_inventory']:HasItem(src, Config.Item, 1)
end

-- Shared by the setChannel handler (so a rejected player gets a clear
-- reason) and the pma-voice addChannelCheck callbacks below (the real
-- enforcement, in case anything ever calls setPlayerRadio without
-- going through hd_radio's own event).
local function IsEligibleForChannel(src, channel)
    local reserved = Config.ReservedChannels[channel]
    if not reserved then return true end

    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return false end
    local job = Player.PlayerData.job

    if Config.RequireDutyOnReserved and not job.onduty then return false end

    if reserved.jobType and job.type == reserved.jobType then return true end
    for _, j in ipairs(reserved.jobs or {}) do
        if j == job.name then return true end
    end
    return false
end

RegisterNetEvent('hd_radio:server:setChannel', function(channel)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end

    channel = tonumber(channel)
    if not channel or channel < 0 or channel > Config.MaxChannel then
        TriggerClientEvent('HD:Client:Notify', src, ('Channel must be between %d and %d.'):format(Config.MinChannel, Config.MaxChannel), 'error')
        return
    end

    if channel > 0 and not HasRadioItem(src) then
        TriggerClientEvent('HD:Client:Notify', src, 'You need a radio to do that.', 'error')
        return
    end

    if channel > 0 and not IsEligibleForChannel(src, channel) then
        local reserved = Config.ReservedChannels[channel]
        TriggerClientEvent('HD:Client:Notify', src, ('Channel %d (%s) is restricted.'):format(channel, reserved.label), 'error')
        return
    end

    if GetResourceState('pma-voice') ~= 'started' then
        TriggerClientEvent('HD:Client:Notify', src, 'Voice plugin not running — ask an admin to start pma-voice.', 'error')
        return
    end

    exports['pma-voice']:setPlayerRadio(src, channel)
    PlayerChannel[src] = channel > 0 and channel or nil
    TriggerClientEvent('hd_radio:client:channelSet', src, channel)
end)

-- Real enforcement at the audio layer, per pma-voice's own docs: "If
-- the player fails the server side radio channel check they will be
-- reset to no channel." This is what actually stops someone bypassing
-- hd_radio's own event and hitting pma-voice's exports directly.
CreateThread(function()
    while GetResourceState('pma-voice') ~= 'started' do Wait(500) end
    for channel in pairs(Config.ReservedChannels) do
        exports['pma-voice']:addChannelCheck(channel, function(src)
            return IsEligibleForChannel(src, channel)
        end)
    end
end)

RegisterNetEvent('hd_radio:server:checkChannel', function()
    local src = source
    TriggerClientEvent('HD:Client:Notify', src, PlayerChannel[src] and ('Current channel: %d'):format(PlayerChannel[src]) or 'Radio is off.', 'info')
end)

AddEventHandler('playerDropped', function()
    PlayerChannel[source] = nil
end)
