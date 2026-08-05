-- ═══════════════════════════════════════════════════════════════════
--  HD ANTICHEAT | CLIENT
--  Thin shell, same shape as hd_admin's — isAdmin is a UX-only cache,
--  the server re-checks IsExemptAdmin on every single action anyway.
--  No detection logic lives here at all; a client-side "anticheat"
--  check is one a cheat can just patch out, so every real check is
--  server-authoritative (server/detection.lua).
-- ═══════════════════════════════════════════════════════════════════

local isAdmin = false
local panelOpen = false

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
end)

-- Tells the server "this character just finished loading" so it can
-- open a short movement-check grace window — same hook every other
-- resource here already keys off HD_Framework's player-loaded event.
RegisterNetEvent('HD:Client:OnPlayerLoaded', function()
    TriggerServerEvent('hd_anticheat:server:playerLoaded')
    TriggerServerEvent('hd_admin:server:checkAdmin') -- reuses hd_admin's own admin check so this doesn't need its own Discord round trip
end)

RegisterNetEvent('hd_admin:client:isAdmin', function(value)
    isAdmin = value == true
end)

RegisterCommand(Config.Command, function()
    if not isAdmin then return end
    if panelOpen then return end
    TriggerServerEvent('hd_anticheat:server:open')
end, false)

RegisterNetEvent('hd_anticheat:client:open', function()
    panelOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
end)

RegisterNUICallback('close', function(_, cb)
    panelOpen = false
    SetNuiFocus(false, false)
    TriggerServerEvent('hd_anticheat:server:close')
    cb({})
end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('hd_anticheat:server:refresh')
    cb({})
end)

RegisterNUICallback('manualBan', function(data, cb)
    TriggerServerEvent('hd_anticheat:server:manualBan', data.targetId, data.reason)
    cb({})
end)

RegisterNUICallback('clearScore', function(data, cb)
    TriggerServerEvent('hd_anticheat:server:clearScore', data.targetId)
    cb({})
end)

RegisterNetEvent('hd_anticheat:client:push', function(action, data)
    SendNUIMessage({ action = action, data = data })
end)

-- ═══════════════════════ DASHBOARD SCREENSHOT BURST ═══════════════════
-- Only ever fired at whoever's actually about to be banned for an
-- injection tripwire (server/dashboard.lua), never anything a normal
-- player would notice or need a UI for. Each shot uploads straight
-- from this client to the dashboard over screenshot-basic's own
-- client-side export — the raw image never passes through this
-- resource's server side at all. Silently does nothing if
-- screenshot-basic isn't installed on this server, same as every other
-- optional-dependency check in this resource.
RegisterNetEvent('hd_anticheat:client:captureBurst', function(uploadUrl, count, delayMs)
    if GetResourceState('screenshot-basic') ~= 'started' then return end
    for _ = 1, (tonumber(count) or 3) do
        pcall(function()
            exports['screenshot-basic']:requestScreenshotUpload(uploadUrl, 'file', { encoding = 'jpg', quality = 0.6 }, function(_) end)
        end)
        Wait(tonumber(delayMs) or 450)
    end
end)
