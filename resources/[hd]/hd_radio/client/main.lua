-- ═══════════════════════════════════════════════════════════════════
--  HD RADIO | CLIENT
--  No PTT key is registered here on purpose — pma-voice already owns
--  radio transmission (its '+radiotalk'/'-radiotalk' commands, default
--  LMENU). This file only: sends power/frequency/volume changes,
--  drives the handheld radio NUI, and plays the bundled UI sounds off
--  pma-voice's own 'pma-voice:radioActive' event and hd_radio's own
--  panic/P2P server events.
-- ═══════════════════════════════════════════════════════════════════

local radioOpen = false
local radioOn = false
local currentVolume = Config.DefaultVolume

local function ApplyVolume(volume)
    currentVolume = volume
    SetResourceKvp('hd_radio_volume', tostring(volume))
    if GetResourceState('pma-voice') == 'started' then
        exports['pma-voice']:setRadioVolume(volume)
    end
end

CreateThread(function()
    local saved = GetResourceKvpString('hd_radio_volume')
    if saved then currentVolume = tonumber(saved) or Config.DefaultVolume end

    while GetResourceState('pma-voice') ~= 'started' do Wait(500) end
    exports['pma-voice']:setRadioVolume(currentVolume)
    exports['pma-voice']:setMicClickOnVolume(0) -- hd_radio's own PTT.ogg replaces pma-voice's stock click entirely
    exports['pma-voice']:setMicClickOffVolume(0)
end)

local function CloseRadio()
    if not radioOpen then return end
    radioOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'toggle', open = false })
end

local function OpenRadio()
    if radioOpen then CloseRadio() return end
    radioOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'toggle', open = true, volume = currentVolume, on = radioOn })
    TriggerServerEvent('hd_radio:server:checkChannel')
end

RegisterCommand('hd_radio:openTuner', OpenRadio, false)
RegisterKeyMapping('hd_radio:openTuner', 'Open handheld radio', 'keyboard', Config.OpenKey)

RegisterNUICallback('tune', function(data, cb)
    TriggerServerEvent('hd_radio:server:setChannel', data.freq)
    cb({})
end)

RegisterNUICallback('off', function(_, cb)
    TriggerServerEvent('hd_radio:server:setChannel', 0)
    cb({})
end)

RegisterNUICallback('power', function(data, cb)
    TriggerServerEvent('hd_radio:server:setPower', not not data.on)
    cb({})
end)

RegisterNUICallback('volume', function(data, cb)
    local vol = math.max(0, math.min(100, math.floor(tonumber(data.volume) or currentVolume)))
    ApplyVolume(vol)
    cb({})
end)

RegisterNUICallback('panic', function(_, cb)
    TriggerServerEvent('hd_radio:server:panic')
    cb({})
end)

RegisterNUICallback('p2p', function(_, cb)
    TriggerServerEvent('hd_radio:server:p2pCall')
    cb({})
end)

RegisterNUICallback('close', function(_, cb)
    CloseRadio()
    cb({})
end)

-- /radio <freq> still works as a quick fallback (e.g. /radio 45.2), and
-- /radio with no argument reports the current frequency.
RegisterCommand(Config.Command, function(_, args)
    if args[1] then
        TriggerServerEvent('hd_radio:server:setChannel', args[1])
    else
        TriggerServerEvent('hd_radio:server:checkChannel')
    end
end, false)

RegisterNetEvent('hd_radio:client:channelSet', function(channel)
    local freq = Config.ChannelToFreq(channel)
    Config.Notify(channel > 0 and ('Radio set to %s.'):format(freq) or 'Radio turned off.', 'success')
    SendNUIMessage({ action = 'channel', channel = channel, freq = channel > 0 and freq or nil })
end)

RegisterNetEvent('hd_radio:client:currentChannel', function(channel)
    SendNUIMessage({ action = 'channel', channel = channel, freq = channel > 0 and Config.ChannelToFreq(channel) or nil })
end)

RegisterNetEvent('hd_radio:client:powerSet', function(on)
    radioOn = on
    Config.Notify(on and 'Radio powered on.' or 'Radio powered off.', 'success')
    SendNUIMessage({ action = 'power', on = on })
end)

RegisterNetEvent('hd_radio:client:denied', function(reason)
    Config.Notify(reason, 'error')
end)

-- Fires on the LOCAL player's own PTT press/release (see pma-voice's
-- client/module/radio.lua) — this is a self-confirmation tone, the
-- same thing a real Airwave radio's pip confirms to whoever's
-- holding it, not something broadcast to other listeners.
AddEventHandler('pma-voice:radioActive', function(radioTalking)
    SendNUIMessage({ action = 'tone', on = radioTalking })
end)

-- Panic/P2P are genuine channel-wide events, so every listener on the
-- same channel (not just the presser) hears the alert/ring tone.
RegisterNetEvent('hd_radio:client:panicTone', function()
    SendNUIMessage({ action = 'panicTone' })
end)

RegisterNetEvent('hd_radio:client:p2pTone', function()
    SendNUIMessage({ action = 'p2pTone' })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if radioOpen then SetNuiFocus(false, false) end
end)
