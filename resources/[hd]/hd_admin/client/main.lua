-- ═══════════════════════════════════════════════════════════════════
--  HD ADMIN | CLIENT
--  isAdmin is a client-side CACHE only, checked once so /admin can
--  silently no-op for a non-admin instead of opening a broken panel —
--  every actual action still round-trips to the server, which
--  re-checks the real permission itself regardless of this flag.
-- ═══════════════════════════════════════════════════════════════════

local isAdmin = false
local panelOpen = false
local noclip = false
local godmode = false
local spectating = nil -- target server id, or nil
local spectateCam = nil

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    TriggerServerEvent('hd_admin:server:checkAdmin')
end)

RegisterNetEvent('hd_admin:client:isAdmin', function(value)
    isAdmin = value == true
end)

-- ═══════════════════════════ OPEN / CLOSE ═════════════════════════════
RegisterCommand(Config.Command, function()
    if not isAdmin then return end
    if panelOpen then return end
    TriggerServerEvent('hd_admin:server:open')
    TriggerServerEvent('hd_admin:server:getOptions')
end, false)

RegisterNetEvent('hd_admin:client:open', function()
    panelOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
end)

RegisterNUICallback('close', function(_, cb)
    panelOpen = false
    SetNuiFocus(false, false)
    cb({})
end)

-- ═══════════════════════════ NUI → SERVER (thin relay) ════════════════
local function relay(nuiName, serverEvent)
    RegisterNUICallback(nuiName, function(data, cb)
        TriggerServerEvent(serverEvent, table.unpack(data.args or {}))
        cb({})
    end)
end

relay('getPlayers', 'hd_admin:server:getPlayers')
relay('getBans', 'hd_admin:server:getBans')
relay('teleportTo', 'hd_admin:server:teleportTo')
relay('bringHere', 'hd_admin:server:bringHere')
relay('heal', 'hd_admin:server:heal')
relay('toggleFreeze', 'hd_admin:server:toggleFreeze')
relay('kick', 'hd_admin:server:kick')
relay('ban', 'hd_admin:server:ban')
relay('unban', 'hd_admin:server:unban')
relay('giveMoney', 'hd_admin:server:giveMoney')
relay('setJob', 'hd_admin:server:setJob')
relay('giveItem', 'hd_admin:server:giveItem')
relay('setWeather', 'hd_admin:server:setWeather')
relay('setTime', 'hd_admin:server:setTime')
relay('announce', 'hd_admin:server:announce')

-- ═══════════════════════════ SERVER → CLIENT (data pushes) ════════════
RegisterNetEvent('hd_admin:client:players', function(list) SendNUIMessage({ action = 'players', list = list }) end)
RegisterNetEvent('hd_admin:client:options', function(opts) SendNUIMessage({ action = 'options', opts = opts }) end)
RegisterNetEvent('hd_admin:client:bans', function(list) SendNUIMessage({ action = 'bans', list = list }) end)
RegisterNetEvent('hd_admin:client:announce', function(message) SendNUIMessage({ action = 'announce', message = message }) end)

-- ═══════════════════════════ ACTIONS THAT RUN LOCALLY ═════════════════
RegisterNetEvent('hd_admin:client:teleport', function(coords)
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
end)

RegisterNetEvent('hd_admin:client:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent('hd_admin:client:toggleFreeze', function()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, not IsEntityPositionFrozen(ped))
end)

RegisterNetEvent('hd_admin:client:setWeather', function(weatherType)
    SetWeatherTypeNow(weatherType)
end)

RegisterNetEvent('hd_admin:client:setTime', function(hour)
    NetworkOverrideClockTime(hour, 0, 0)
end)

-- ═══════════════════════════ SELF: NOCLIP / GODMODE / SPECTATE ════════
-- Both just relay to server/self.lua now — it re-checks IsAdmin and
-- bounces back the actual toggle, same "server owns the real
-- permission check" pattern every other action in this panel already
-- follows, and the only way hd_anticheat gets a trustworthy admin
-- identity to exempt rather than trusting whatever the client claims.
RegisterNUICallback('toggleNoclip', function(_, cb)
    TriggerServerEvent('hd_admin:server:toggleNoclip')
    cb({})
end)

RegisterNUICallback('toggleGodmode', function(_, cb)
    TriggerServerEvent('hd_admin:server:toggleGodmode')
    cb({})
end)

RegisterNetEvent('hd_admin:client:toggleNoclip', function()
    noclip = not noclip
    local ped = PlayerPedId()
    SetEntityCollision(ped, not noclip, not noclip)
    SetEntityInvincible(ped, noclip or godmode)
    Config.Notify(noclip and 'Noclip ON' or 'Noclip OFF', 'info')
    SendNUIMessage({ action = 'selfState', noclip = noclip, godmode = godmode })
end)

RegisterNetEvent('hd_admin:client:toggleGodmode', function()
    godmode = not godmode
    SetEntityInvincible(PlayerPedId(), godmode or noclip)
    Config.Notify(godmode and 'God mode ON' or 'God mode OFF', 'info')
    SendNUIMessage({ action = 'selfState', noclip = noclip, godmode = godmode })
end)

-- Frozen + hidden + collision-off rather than an actual teleport — the
-- spectator's own position never moves, so there's nothing for
-- hd_anticheat's movement checks to even see here.
local function EndSpectate()
    if not spectating then return end
    spectating = nil
    local ped = PlayerPedId()
    RenderScriptCams(false, true, 500, true, true)
    if spectateCam then DestroyCam(spectateCam) spectateCam = nil end
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true, true)
    SendNUIMessage({ action = 'spectateState', active = false })
end

RegisterNUICallback('startSpectate', function(data, cb)
    TriggerServerEvent('hd_admin:server:startSpectate', data.targetId)
    cb({})
end)

RegisterNUICallback('stopSpectate', function(_, cb)
    TriggerServerEvent('hd_admin:server:stopSpectate')
    EndSpectate()
    cb({})
end)

RegisterNetEvent('hd_admin:client:startSpectate', function(targetId)
    if spectating then EndSpectate() end
    spectating = targetId
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false, false)
    spectateCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    RenderScriptCams(true, false, 0, true, true)
    Config.Notify('Spectating.', 'info')
    SendNUIMessage({ action = 'spectateState', active = true })
end)

RegisterNetEvent('hd_admin:client:stopSpectate', function() EndSpectate() end)

CreateThread(function()
    while true do
        local sleep = 500
        if spectating then
            sleep = 0
            local targetPed = GetPlayerPed(spectating)
            if not targetPed or targetPed == 0 or not DoesEntityExist(targetPed) then
                Config.Notify('Target is no longer available — spectate ended.', 'info')
                EndSpectate()
            else
                local coords = GetEntityCoords(targetPed)
                local forward = GetEntityForwardVector(targetPed)
                local camPos = coords - forward * 4.0 + vector3(0.0, 0.0, 2.0)
                SetCamCoord(spectateCam, camPos.x, camPos.y, camPos.z)
                PointCamAtEntity(spectateCam, targetPed, 0.0, 0.0, 0.6, true)
            end
        end
        Wait(sleep)
    end
end)

-- Safety net — a stray hidden/frozen/collision-off ped left behind by a
-- resource restart mid-spectate would be a real problem for whoever's
-- using it, not just a visual glitch.
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and spectating then EndSpectate() end
end)

RegisterNUICallback('teleportWaypoint', function(_, cb)
    local blip = GetFirstBlipInfoId(8) -- waypoint blip type
    if not DoesBlipExist(blip) then
        Config.Notify('No waypoint set.', 'error')
        cb({})
        return
    end
    local wp = GetBlipInfoIdCoord(blip)
    local ped = PlayerPedId()
    local groundZ = select(2, GetGroundZFor_3dCoord(wp.x, wp.y, 300.0, false))
    SetEntityCoords(ped, wp.x, wp.y, (groundZ ~= 0.0 and groundZ or wp.z) + 1.0, false, false, false, false)
    cb({})
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    local model = tostring(data.model or '')
    local hash = GetHashKey(model)
    RequestModel(hash)
    local waited = 0
    while not HasModelLoaded(hash) and waited < 5000 do Wait(50) waited = waited + 50 end
    if not HasModelLoaded(hash) then
        Config.Notify('Could not load that vehicle model.', 'error')
        cb({})
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetModelAsNoLongerNeeded(hash)
    TaskWarpPedIntoVehicle(ped, veh, -1)
    cb({})
end)

CreateThread(function()
    while true do
        if noclip then
            Wait(0)
            local ped = PlayerPedId()
            DisableControlAction(0, 24, true) -- attack
            DisableControlAction(0, 25, true) -- aim

            -- keep the ped facing wherever the camera looks, so its own
            -- forward vector is always "where you're looking" — avoids
            -- hand-deriving movement from raw camera pitch/rotation
            SetEntityHeading(ped, GetGameplayCamRelativeHeading() + GetEntityHeading(ped))

            local speed = IsControlPressed(0, 21) and 1.2 or 0.4 -- 21 = sprint, doubles as a speed boost here
            local forward = GetEntityForwardVector(ped)
            local right = vector3(forward.y, -forward.x, 0.0)
            local coords = GetEntityCoords(ped)
            local move = vector3(0.0, 0.0, 0.0)

            if IsControlPressed(0, 32) then move = move + forward end -- W
            if IsControlPressed(0, 33) then move = move - forward end -- S
            if IsControlPressed(0, 34) then move = move - right end   -- A
            if IsControlPressed(0, 35) then move = move + right end   -- D
            if IsControlPressed(0, 22) then move = move + vector3(0.0, 0.0, 1.0) end -- Space up
            if IsControlPressed(0, 36) then move = move - vector3(0.0, 0.0, 1.0) end -- Left Ctrl down

            if move.x ~= 0.0 or move.y ~= 0.0 or move.z ~= 0.0 then
                SetEntityCoordsNoOffset(ped, coords.x + move.x * speed, coords.y + move.y * speed, coords.z + move.z * speed, false, false, false)
            end
        else
            Wait(300)
        end
    end
end)
