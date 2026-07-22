-- ═══════════════════════════════════════════════════════════════════
--  HD RADIO | CLIENT
--  No PTT key is registered here on purpose — pma-voice already owns
--  radio transmission (its '+radiotalk'/'-radiotalk' commands, default
--  LMENU). This file only: sends channel-change requests, mutes
--  pma-voice's stock mic-click audio, and plays the synthesised UK
--  tone off pma-voice's own 'pma-voice:radioActive' event.
-- ═══════════════════════════════════════════════════════════════════

CreateThread(function()
    while GetResourceState('pma-voice') ~= 'started' do Wait(500) end
    if Config.Tone.MuteStockClick then
        exports['pma-voice']:setMicClickOnVolume(0)
        exports['pma-voice']:setMicClickOffVolume(0)
    end
end)

RegisterCommand(Config.Command, function(_, args)
    if args[1] then
        TriggerServerEvent('hd_radio:server:setChannel', args[1])
    else
        TriggerServerEvent('hd_radio:server:checkChannel')
    end
end, false)

RegisterNetEvent('hd_radio:client:channelSet', function(channel)
    Config.Notify(channel > 0 and ('Radio set to channel %d.'):format(channel) or 'Radio turned off.', 'success')
    SendNUIMessage({ action = 'channel', channel = channel })
end)

-- Fires on the LOCAL player's own PTT press/release (see pma-voice's
-- client/module/radio.lua) — this is a self-confirmation tone, the
-- same thing a real Airwave radio's pip confirms to whoever's
-- holding it, not something broadcast to other listeners.
AddEventHandler('pma-voice:radioActive', function(radioTalking)
    if not Config.Tone.Enabled then return end
    SendNUIMessage({ action = 'tone', on = radioTalking })
end)
