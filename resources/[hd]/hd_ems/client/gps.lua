-- ═══════════════════════════════════════════════════════════════════
--  hd_ems | client/gps.lua
--  Shared GPS blip renderer/pinger for BOTH this job and hd_policejob
--  — see config.lua's GPS section for why the event names below are
--  still "ukhs:*" rather than "hd_ems:*". We ask the server once
--  (cached) whether wasabi_gps is handling tracking:
--    true  → wasabi_gps draws its own map blips for subscriber jobs.
--            This resource doesn't send pings or draw anything itself
--            — /gps just points the player at their map.
--    false → built-in fallback: we push our own position periodically
--            and draw/track blips for everyone we're subscribed to,
--            plus a NUI list with a "Waypoint" button per unit.
-- ═══════════════════════════════════════════════════════════════════

local trackedUnits = {}   -- [serverId] = { name, jobName, coords, blip }
local usingWasabiCache = nil -- nil = not yet checked

local function isUsingWasabi(cb)
    if usingWasabiCache ~= nil then return cb(usingWasabiCache) end
    Framework.Functions.TriggerCallback('ukhs:server:isUsingWasabiGps', function(result)
        usingWasabiCache = result and true or false
        cb(usingWasabiCache)
    end)
end

RegisterCommand('gps', function()
    Framework.Functions.TriggerCallback('ukhs:server:isGpsViewer', function(isViewer)
        if not isViewer then
            TriggerEvent('HD:Client:Notify', 'You do not have GPS tracker access.', 'error')
            return
        end

        isUsingWasabi(function(wasabi)
            if wasabi then
                TriggerEvent('HD:Client:Notify', 'GPS tracking is active on your map — live blips are handled by wasabi_gps.', 'primary')
                return
            end
            SetNuiFocus(true, true)
            SendNUIMessage({ action = 'open', tab = 'gps', department = Config.DepartmentName })
        end)
    end)
end, false)
RegisterKeyMapping('gps', 'Open GPS Tracker', 'keyboard', 'F7')

RegisterNUICallback('getGpsUnits', function(_, cb)
    local list = {}
    for serverId, unit in pairs(trackedUnits) do
        list[#list + 1] = { source = serverId, name = unit.name, jobName = unit.jobName }
    end
    cb(list)
end)

RegisterNUICallback('gpsWaypoint', function(data, cb)
    local unit = trackedUnits[tonumber(data.source)]
    if unit and unit.coords then
        SetNewWaypoint(unit.coords.x, unit.coords.y)
        TriggerEvent('HD:Client:Notify', 'Waypoint set to ' .. unit.name .. '.', 'success')
    end
    cb('ok')
end)

-- ---------------------------------------------------------------
-- Built-in fallback: receiving tracked positions
-- (the server only ever emits these while wasabi_gps is inactive)
-- ---------------------------------------------------------------
RegisterNetEvent('ukhs:client:gpsUpdate', function(data)
    local unit = trackedUnits[data.source]
    if not unit then
        local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, data.jobName == 'police' and 3 or 2)
        SetBlipScale(blip, 0.9)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(data.name)
        EndTextCommandSetBlipName(blip)
        unit = { blip = blip }
        trackedUnits[data.source] = unit
    else
        SetBlipCoords(unit.blip, data.coords.x, data.coords.y, data.coords.z)
    end
    unit.name = data.name
    unit.jobName = data.jobName
    unit.coords = data.coords
end)

RegisterNetEvent('ukhs:client:gpsRemove', function(serverId)
    local unit = trackedUnits[serverId]
    if unit and unit.blip then RemoveBlip(unit.blip) end
    trackedUnits[serverId] = nil
end)

-- ---------------------------------------------------------------
-- Built-in fallback: sending our own position, if we're on duty as
-- ambulance. Skipped entirely once we know wasabi_gps is active, so
-- there's no redundant network traffic either way.
-- ---------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(Config.GPS.UpdateInterval)

        isUsingWasabi(function(wasabi)
            if wasabi then return end
            if not Framework then return end

            local pd = Framework.Functions.GetPlayerData()
            if not pd or not pd.job then return end

            local isTrackableJob = false
            for _, j in ipairs(Config.GPS.TrackableJobs) do
                if pd.job.name == j then isTrackableJob = true break end
            end
            if isTrackableJob then
                local coords = GetEntityCoords(PlayerPedId())
                TriggerServerEvent('ukhs:server:gpsPing', { x = coords.x, y = coords.y, z = coords.z })
            end
        end)
    end
end)
