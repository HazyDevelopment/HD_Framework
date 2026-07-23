-- ═══════════════════════════════════════════════════════════════════
--  HD_FRAMEWORK | CLIENT CORE
--  Holds the client's cached copy of PlayerData and exposes it via
--  Functions.GetPlayerData(), reached directly through
--  exports['HD_Framework']:GetCoreObject() — no bridge resource.
-- ═══════════════════════════════════════════════════════════════════

HD = {}
HD.PlayerData = {}
HD.Functions = {}
HD.Shared = { Jobs = Jobs, Items = Items } -- Jobs/Items are shared_scripts, so both globals already exist client-side too

function HD.Functions.GetPlayerData()
    return HD.PlayerData
end

-- ═══════════════════════════ CALLBACKS ═══════════════════════════════
-- Client half of the standard QBCore.Functions.CreateCallback/
-- TriggerCallback pattern — see server/main.lua for why this exists.
local PendingCallbacks = {}
local NextCallbackId = 0

function HD.Functions.TriggerCallback(name, cb, ...)
    NextCallbackId = NextCallbackId + 1
    local requestId = NextCallbackId
    PendingCallbacks[requestId] = cb
    TriggerServerEvent('QBCore:Server:TriggerCallback', name, requestId, ...)
end

RegisterNetEvent('QBCore:Client:TriggerCallback', function(requestId, ...)
    local cb = PendingCallbacks[requestId]
    if not cb then return end
    PendingCallbacks[requestId] = nil
    cb(...)
end)

exports('GetCoreObject', function() return HD end)

-- ═══════════════════════════ READY HANDSHAKE ═════════════════════════
local ready = false
local awaitingSelection = false

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(50) end
    while not ready do
        TriggerServerEvent('hd:server:playerReady')
        Wait(2000) -- retries until hd:client:onPlayerLoaded flips `ready`, covers early-join drops
    end
end)

-- Frozen + faded to black + NUI-focused on character select the whole
-- time a license has no character loaded yet — mirrors the same
-- freeze pattern hd_ems already uses for its downed state, just for a
-- different reason.
CreateThread(function()
    while true do
        local sleep = 500
        if awaitingSelection then
            sleep = 0
            local ped = PlayerPedId()
            DisableControlAction(0, 1, true)  -- look
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 30, true) -- move
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 24, true) -- attack
            DisableControlAction(0, 25, true) -- aim
            DisableControlAction(0, 37, true) -- weapon wheel
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('hd:client:showCharacterSelect', function(characters, maxSlots)
    awaitingSelection = true
    DoScreenFadeOut(0)
    FreezeEntityPosition(PlayerPedId(), true)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'showSelect', characters = characters, maxSlots = maxSlots })
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    TriggerServerEvent('hd:server:selectCharacter', data.citizenid)
    cb({})
end)
RegisterNUICallback('deleteCharacter', function(data, cb)
    TriggerServerEvent('hd:server:deleteCharacter', data.citizenid)
    cb({})
end)
RegisterNUICallback('getStarterFlats', function(_, cb)
    TriggerServerEvent('hd:server:getStarterFlats')
    cb({})
end)
RegisterNUICallback('createCharacter', function(data, cb)
    TriggerServerEvent('hd:server:createCharacter', data)
    cb({})
end)
RegisterNetEvent('hd:client:starterFlats', function(flats)
    SendNUIMessage({ action = 'starterFlats', flats = flats })
end)

RegisterNetEvent('hd:client:onPlayerLoaded', function(playerData)
    ready = true
    HD.PlayerData = playerData

    if awaitingSelection then
        awaitingSelection = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'hide' })
        FreezeEntityPosition(PlayerPedId(), false)
    end

    -- Spawn the ped at their saved position (or the configured default
    -- for brand-new citizens) now that data has arrived.
    local pos = playerData.position
    local ped = PlayerPedId()
    if pos and pos.x then
        SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
        SetEntityHeading(ped, pos.w or 0.0)
    end
    DoScreenFadeIn(500)

    TriggerEvent('HD:Client:OnPlayerLoaded', HD.PlayerData)
end)

RegisterNetEvent('hd:client:onPlayerDataUpdate', function(playerData)
    HD.PlayerData = playerData
    TriggerEvent('HD:Client:OnPlayerDataUpdate', HD.PlayerData)
end)
