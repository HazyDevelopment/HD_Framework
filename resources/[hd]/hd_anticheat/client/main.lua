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
local reportFormOpen = false
local bigScreenTarget = nil -- server id currently being spectated via the Monitor tab's big screen, or nil

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
    if panelOpen or reportFormOpen then return end
    TriggerServerEvent('hd_anticheat:server:open')
end, false)

RegisterNetEvent('hd_anticheat:client:open', function()
    panelOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
    -- Same "fetch the extra tabs' data right after open" pattern
    -- hd_admin's own /admin uses for getOptions — Overview/Detections
    -- data was already pushed by the server's own open handler
    -- (server/main.lua), these cover the tabs added on top of it.
    TriggerServerEvent('hd_anticheat:server:getRoster')
    TriggerServerEvent('hd_anticheat:server:getReports')
    TriggerServerEvent('hd_anticheat:server:getDutyState')
end)

-- ═══════════════════════════ /acreport FORM ═════════════════════════
-- Deliberately a separate tiny overlay from the admin panel above, not
-- a tab inside it — this one has to be reachable by every player, not
-- just admins, and the admin panel's very own open path is gated on
-- isAdmin. The server only ever sees the finished title+message
-- (server/reports.lua's submitReport), never raw chat args — this is a
-- proper form, not a "/acreport <message>" one-liner.
RegisterCommand(Config.ReportCommand, function()
    if reportFormOpen or panelOpen then return end
    reportFormOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openReportForm' })
end, false)

local function CloseReportForm()
    if not reportFormOpen then return end
    reportFormOpen = false
    SetNuiFocus(false, false)
end

RegisterNUICallback('closeReportForm', function(_, cb)
    CloseReportForm()
    cb({})
end)

RegisterNUICallback('submitReport', function(data, cb)
    TriggerServerEvent('hd_anticheat:server:submitReport', data.title, data.message)
    cb({})
end)

RegisterNetEvent('hd_anticheat:client:reportSubmitted', function()
    CloseReportForm()
end)

-- Leaving the panel entirely while the Monitor tab's big screen was
-- active shouldn't leave the admin's own camera stuck spectating — same
-- cleanup the big-screen "back" button does, just also reachable via
-- ESC/closeBtn.
local function EndBigScreen()
    if not bigScreenTarget then return end
    bigScreenTarget = nil
    TriggerServerEvent('hd_admin:server:stopSpectate')
end

RegisterNUICallback('close', function(_, cb)
    panelOpen = false
    SetNuiFocus(false, false)
    EndBigScreen()
    TriggerServerEvent('hd_anticheat:server:monitorStop')
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

-- ═══════════════════════════ GENERIC NUI → SERVER RELAY ═══════════════
-- Same thin-relay idea hd_admin's client/main.lua already uses — the
-- server re-checks IsExemptAdmin (and, where relevant, IsOnDuty) on
-- every single one of these regardless of what the NUI sends.
local function relay(nuiName, serverEvent)
    RegisterNUICallback(nuiName, function(data, cb)
        TriggerServerEvent(serverEvent, table.unpack(data.args or {}))
        cb({})
    end)
end

relay('getRoster', 'hd_anticheat:server:getRoster')
relay('kick', 'hd_anticheat:server:kick')
relay('teleportTo', 'hd_anticheat:server:teleportTo')
relay('worldReset', 'hd_anticheat:server:worldReset')
relay('announce', 'hd_anticheat:server:announce')
relay('getReports', 'hd_anticheat:server:getReports')
relay('resolveReport', 'hd_anticheat:server:resolveReport')
relay('toggleDuty', 'hd_anticheat:server:toggleDuty')
relay('sendChat', 'hd_anticheat:server:sendChat')
relay('getChat', 'hd_anticheat:server:getChat')

RegisterNUICallback('monitorStart', function(_, cb)
    TriggerServerEvent('hd_anticheat:server:monitorStart')
    cb({})
end)

RegisterNUICallback('monitorStop', function(_, cb)
    EndBigScreen()
    TriggerServerEvent('hd_anticheat:server:monitorStop')
    cb({})
end)

-- Monitor tab's big screen: reuses hd_admin's own spectate camera
-- wholesale (server/self.lua + client/main.lua there) rather than
-- reimplementing it — it already handles the camera math, the target
-- disappearing mid-spectate, and cleanup on resource stop. This panel
-- stays open and focused throughout (see html/css's big-screen mode),
-- so the real spectate camera renders straight through the transparent
-- viewport underneath it — genuine live video, not a simulation of one.
RegisterNUICallback('startBigScreen', function(data, cb)
    bigScreenTarget = tonumber(data.targetId)
    TriggerServerEvent('hd_admin:server:startSpectate', data.targetId)
    cb({})
end)

RegisterNUICallback('stopBigScreen', function(_, cb)
    EndBigScreen()
    cb({})
end)

-- Reports carry the coords captured at submit time rather than a
-- player id — the reporter may well have disconnected by the time an
-- admin gets to it. Purely local, same as hd_admin's own
-- 'teleportWaypoint' callback (moving the admin's own client needs no
-- server round trip; the server-side gate is that this NUI is only
-- reachable at all through 'hd_anticheat:server:open', which already
-- re-checks IsExemptAdmin).
RegisterNUICallback('teleportToCoords', function(data, cb)
    local args = data.args or {}
    local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
    if x and y and z then
        SetEntityCoords(PlayerPedId(), x, y, z + 1.0, false, false, false, false)
    end
    cb({})
end)

RegisterNetEvent('hd_anticheat:client:push', function(action, data)
    SendNUIMessage({ action = action, data = data })
end)

RegisterNetEvent('hd_anticheat:client:dutyState', function(onDuty)
    SendNUIMessage({ action = 'dutyState', onDuty = onDuty == true })
end)

RegisterNetEvent('hd_anticheat:client:chat', function(entry)
    SendNUIMessage({ action = 'chat', data = entry })
end)

RegisterNetEvent('hd_anticheat:client:teleport', function(coords)
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
end)

-- See config.lua's WorldResetRadius comment — this is the one native
-- that actually does something here: forces stray/broken dynamic
-- objects near THIS client's own position back to their default
-- streamed state. Every connected client gets this event, so a World
-- Reset covers wherever players actually are, not just one spot.
RegisterNetEvent('hd_anticheat:client:worldReset', function(radius)
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)
    ClearAreaOfObjects(coords.x, coords.y, coords.z, tonumber(radius) or 200.0, 0)
end)

RegisterNetEvent('hd_anticheat:client:announce', function(message, adminName)
    SendNUIMessage({ action = 'announce', message = message, admin = adminName, ms = Config.AnnouncementBannerMs })
    TriggerEvent('chat:addMessage', {
        color = { 192, 132, 252 },
        multiline = true,
        args = { 'HD ANTICHEAT', message },
    })
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
