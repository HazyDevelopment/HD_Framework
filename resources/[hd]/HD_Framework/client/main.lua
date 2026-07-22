-- ═══════════════════════════════════════════════════════════════════
--  HD_FRAMEWORK | CLIENT CORE
--  Holds the client's cached copy of PlayerData and exposes the same
--  Functions.GetPlayerData() shape QBCore ships, so hazy_mdt's client
--  (Framework.Functions.GetPlayerData()) and any other QBCore-client
--  script works unmodified via the qb-core bridge resource.
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

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(50) end
    while not ready do
        TriggerServerEvent('hd:server:playerReady')
        Wait(2000) -- retries until hd:client:onPlayerLoaded flips `ready`, covers early-join drops
    end
end)

RegisterNetEvent('hd:client:onPlayerLoaded', function(playerData)
    ready = true
    HD.PlayerData = playerData

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
