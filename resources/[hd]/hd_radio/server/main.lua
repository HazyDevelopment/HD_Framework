-- ═══════════════════════════════════════════════════════════════════
--  HD RADIO | SERVER
--  Decides who's allowed on a channel, who's powered on, and forwards
--  that to pma-voice's own exports['pma-voice']:setPlayerRadio — pma-
--  voice owns the actual audio routing and PTT key entirely. Panic and
--  P2P are hd_radio's own channel-wide alert events on top of that.
-- ═══════════════════════════════════════════════════════════════════

local Framework = nil
CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

local PlayerChannel = {} -- [src] = last tuned channel (remembered even while powered off), for /radio's status reply and power-on restore
local PlayerPower = {} -- [src] = true once they've powered the handheld on
local PlayerPanicAt = {} -- [src] = GetGameTimer() of their last panic press, for the cooldown

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

local function ApplyChannel(src, channel)
    if GetResourceState('pma-voice') ~= 'started' then
        TriggerClientEvent('hd_radio:client:denied', src, 'Voice plugin not running — ask an admin to start pma-voice.')
        return false
    end
    exports['pma-voice']:setPlayerRadio(src, channel)
    return true
end

RegisterNetEvent('hd_radio:server:setChannel', function(freqInput)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end

    -- freqInput arrives as a raw string/number from either the radio
    -- NUI ("45.20") or the /radio command's args table — both go
    -- through the exact same Config.FreqToChannel conversion so a
    -- player on 45.2 from the NUI and 45.20 from the command line land
    -- on the identical integer channel.
    local channel = Config.FreqToChannel(freqInput)
    if not channel or channel < Config.MinChannel or channel > Config.MaxChannel then
        TriggerClientEvent('hd_radio:client:denied', src, ('Frequency must be between %.2f and %.2f.'):format(Config.MinFreq, Config.MaxFreq))
        return
    end

    if channel > 0 then
        if not HasRadioItem(src) then
            TriggerClientEvent('hd_radio:client:denied', src, 'You need a radio to do that.')
            return
        end
        if not PlayerPower[src] then
            TriggerClientEvent('hd_radio:client:denied', src, 'Turn the radio on first.')
            return
        end
        if not IsEligibleForChannel(src, channel) then
            local reserved = Config.ReservedChannels[channel]
            TriggerClientEvent('hd_radio:client:denied', src, ('%s (%s) is restricted.'):format(Config.ChannelToFreq(channel), reserved.label))
            return
        end
    end

    if not ApplyChannel(src, channel) then return end
    PlayerChannel[src] = channel > 0 and channel or nil
    TriggerClientEvent('hd_radio:client:channelSet', src, channel)
end)

RegisterNetEvent('hd_radio:server:setPower', function(on)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end

    if on and not HasRadioItem(src) then
        TriggerClientEvent('hd_radio:client:denied', src, 'You need a radio to do that.')
        return
    end

    PlayerPower[src] = on

    if on then
        -- Restore whatever they last had tuned, re-checking eligibility
        -- in case their job/duty changed while the radio was off.
        local channel = PlayerChannel[src]
        if channel and IsEligibleForChannel(src, channel) then
            ApplyChannel(src, channel)
            TriggerClientEvent('hd_radio:client:channelSet', src, channel)
        end
    else
        ApplyChannel(src, 0) -- radio's off, so it neither transmits nor receives — PlayerChannel keeps the memory for next power-on
    end

    TriggerClientEvent('hd_radio:client:powerSet', src, on)
end)

-- Real enforcement at the audio layer, per pma-voice's own docs: "If
-- the player fails the server side radio channel check they will be
-- reset to no channel." This is what actually stops someone bypassing
-- hd_radio's own event and hitting pma-voice's exports directly.
CreateThread(function()
    while GetResourceState('pma-voice') ~= 'started' do Wait(500) end
    for channel in pairs(Config.ReservedChannels) do
        exports['pma-voice']:addChannelCheck(channel, function(src)
            return PlayerPower[src] and IsEligibleForChannel(src, channel)
        end)
    end
end)

RegisterNetEvent('hd_radio:server:checkChannel', function()
    local src = source
    local channel = PlayerPower[src] and PlayerChannel[src] or nil
    TriggerClientEvent('hd_radio:client:currentChannel', src, channel or 0)
end)

-- ═══════════════════════════ PANIC BUTTON ════════════════════════════
-- A dedicated emergency alert, same idea as a real TETRA handheld's
-- panic button: raises a real police call (same board a 999 lands on)
-- and rings the panic tone for everyone else currently on the same
-- channel, so a squad on the same frequency hears it too.
RegisterNetEvent('hd_radio:server:panic', function()
    if not Config.Panic.Enabled then return end
    local src = source
    if not PlayerPower[src] or not HasRadioItem(src) then return end

    local now = GetGameTimer()
    if PlayerPanicAt[src] and (now - PlayerPanicAt[src]) < (Config.Panic.Cooldown * 1000) then return end
    PlayerPanicAt[src] = now

    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)

    if GetResourceState('hd_dispatch') == 'started' then
        exports['hd_dispatch']:CreateCall(Config.Panic.DispatchKind, {
            title = 'Radio Panic Alert',
            description = ('%s %s triggered their radio panic button.'):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname),
            coords = { x = coords.x, y = coords.y, z = coords.z },
            priority = 'high',
        })
    end

    local channel = PlayerChannel[src]
    if channel then
        for _, targetSrc in ipairs(exports['pma-voice']:getPlayersInRadioChannel(channel) or {}) do
            TriggerClientEvent('hd_radio:client:panicTone', targetSrc)
        end
    else
        TriggerClientEvent('hd_radio:client:panicTone', src)
    end
end)

-- ═══════════════════════════ P2P (DIRECT) CALL ═══════════════════════
-- TETRA's "Direct" mode ring — presses the green call button to alert
-- everyone else on the same channel, same as keying up to get someone
-- specific's attention rather than a full emergency alert.
RegisterNetEvent('hd_radio:server:p2pCall', function()
    local src = source
    if not PlayerPower[src] or not HasRadioItem(src) then return end

    local channel = PlayerChannel[src]
    if not channel then
        TriggerClientEvent('hd_radio:client:denied', src, 'Tune a frequency first.')
        return
    end

    for _, targetSrc in ipairs(exports['pma-voice']:getPlayersInRadioChannel(channel) or {}) do
        TriggerClientEvent('hd_radio:client:p2pTone', targetSrc)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    PlayerChannel[src] = nil
    PlayerPower[src] = nil
    PlayerPanicAt[src] = nil
end)
