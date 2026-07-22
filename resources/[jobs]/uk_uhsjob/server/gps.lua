-- ===================================================================
-- server/gps.lua
-- GPS tracking for on-duty ambulance, seen by on-duty members of
-- Config.GPS.ViewerJobs (police + ambulance by default).
-- Config.GPS.UseWasabiGPS is the single true/false switch:
--
--  true  → if a resource named Config.GPS.WasabiResourceName is
--          installed and running, this resource registers "ambulance"
--          with it via wasabi_gps's real, documented exports
--          (docs.wasabiscripts.com/wasabi-scripts/free-releases/wasabi_gps/exports):
--            exports.wasabi_gps:registerJob({ job, tracked, subscribers, blipSettings, item })
--            exports.wasabi_gps:unregisterJob(job)
--          Once registered, wasabi_gps owns tracking, subscriptions,
--          and blips for "ambulance" entirely — this resource's own
--          ping/blip system stays OFF while wasabi_gps is active.
--  false → (or wasabi_gps isn't installed/running) this resource runs
--          its own lightweight ping + blip system instead — see
--          client/gps.lua. Zero external dependencies either way.
--
-- This resource only ever registers/pushes ITS OWN job ("ambulance").
-- If uk_policejob is also installed, it independently registers
-- "police" the same way — together the two give full mutual
-- visibility without either one double-registering the other's job.
-- ===================================================================

local usingWasabi = false

local function isTrackable(player)
    if not player then return false end
    if Config.RequireOnDuty and not player.jobOnDuty then return false end
    for _, job in ipairs(Config.GPS.TrackableJobs) do
        if player.jobName == job then return true end
    end
    return false
end

local function isViewer(player)
    if not player then return false end
    if Config.RequireOnDuty and not player.jobOnDuty then return false end
    for _, job in ipairs(Config.GPS.ViewerJobs) do
        if player.jobName == job then return true end
    end
    return false
end

-- ---------------------------------------------------------------
-- wasabi_gps hand-off
-- ---------------------------------------------------------------

local function tryRegisterWithWasabi()
    if not Config.GPS.UseWasabiGPS then return false end
    local resourceName = Config.GPS.WasabiResourceName
    if GetResourceState(resourceName) ~= 'started' then return false end

    local ok = pcall(function()
        for _, job in ipairs(Config.GPS.TrackableJobs) do
            local registered = exports[resourceName]:registerJob({
                job = job,
                tracked = true,
                subscribers = Config.GPS.ViewerJobs,
                blipSettings = Config.GPS.BlipSettings and Config.GPS.BlipSettings[job] or nil,
                item = Config.GPS.Item, -- optional item-gated toggle; nil = always tracked while on duty
            })
            if not registered then
                error(('wasabi_gps did not accept registerJob for "%s"'):format(job))
            end
        end
    end)

    if ok then
        print(('[ukhs] GPS tracking handed off to %s for: %s'):format(resourceName, table.concat(Config.GPS.TrackableJobs, ', ')))
    end
    return ok
end

local function unregisterFromWasabi()
    local resourceName = Config.GPS.WasabiResourceName
    if GetResourceState(resourceName) ~= 'started' then return end
    pcall(function()
        for _, job in ipairs(Config.GPS.TrackableJobs) do
            exports[resourceName]:unregisterJob(job)
        end
    end)
end

CreateThread(function()
    usingWasabi = tryRegisterWithWasabi()
    if not usingWasabi and Config.GPS.UseWasabiGPS then
        print('[ukhs] wasabi_gps not active — using the built-in GPS fallback instead.')
    end
end)

-- Load-order safety: if wasabi_gps starts after this resource, retry.
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == Config.GPS.WasabiResourceName and not usingWasabi then
        usingWasabi = tryRegisterWithWasabi()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and usingWasabi then
        unregisterFromWasabi()
    end
end)

Bridge.CreateCallback('ukhs:server:isUsingWasabiGps', function(source, cb)
    cb(usingWasabi)
end)

Bridge.CreateCallback('ukhs:server:isGpsViewer', function(source, cb)
    cb(isViewer(Bridge.GetPlayer(source)))
end)

-- ---------------------------------------------------------------
-- Built-in fallback (only does anything while usingWasabi is false)
-- ---------------------------------------------------------------

RegisterNetEvent('ukhs:server:gpsPing', function(coords)
    if usingWasabi then return end -- wasabi_gps is handling delivery; ignore

    local source = source
    local player = Bridge.GetPlayer(source)
    if not isTrackable(player) then return end

    for _, viewer in ipairs(Bridge.GetOnlinePlayers()) do
        if isViewer(viewer) then
            TriggerClientEvent('ukhs:client:gpsUpdate', viewer.source, {
                source = player.source,
                name = player.name,
                jobName = player.jobName,
                coords = coords,
            })
        end
    end
end)

RegisterNetEvent('ukhs:server:gpsOffDuty', function()
    if usingWasabi then return end

    local source = source
    for _, viewer in ipairs(Bridge.GetOnlinePlayers()) do
        if isViewer(viewer) then
            TriggerClientEvent('ukhs:client:gpsRemove', viewer.source, source)
        end
    end
end)
