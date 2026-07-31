-- ═══════════════════════════════════════════════════════════════════
--  hd_ems | server/gps.lua
--  GPS tracking for on-duty ambulance, seen by on-duty members of
--  Config.GPS.ViewerJobs (police + ambulance by default).
--  Config.GPS.UseWasabiGPS is the single true/false switch:
--
--   true  → if a resource named Config.GPS.WasabiResourceName is
--           installed and running, this resource registers "ambulance"
--           with it via wasabi_gps's real, documented exports
--           (docs.wasabiscripts.com/wasabi-scripts/free-releases/wasabi_gps/exports):
--             exports.wasabi_gps:registerJob({ job, tracked, subscribers, blipSettings, item })
--             exports.wasabi_gps:unregisterJob(job)
--           Once registered, wasabi_gps owns tracking, subscriptions,
--           and blips for "ambulance" entirely — this resource's own
--           ping/blip system stays OFF while wasabi_gps is active.
--   false → (or wasabi_gps isn't installed/running) this resource runs
--           its own lightweight ping + blip system instead — see
--           client/gps.lua. Zero external dependencies either way.
--
-- Event names below are kept as "ukhs:*" — see config.lua's GPS
-- section for why (hd_policejob's own server/gps.lua calls these
-- exact client event names to piggyback on the same blip renderer).
-- This resource only ever registers/pushes ITS OWN job ("ambulance");
-- hd_policejob independently registers "police" the same way.
-- ═══════════════════════════════════════════════════════════════════

local usingWasabi = false

local function contains(list, val)
    for _, v in ipairs(list) do if v == val then return true end end
    return false
end

local function isTrackable(Player)
    if not Player then return false end
    if Config.RequireOnDuty and not Player.PlayerData.job.onduty then return false end
    return contains(Config.GPS.TrackableJobs, Player.PlayerData.job.name)
end

local function isViewer(Player)
    if not Player then return false end
    if Config.RequireOnDuty and not Player.PlayerData.job.onduty then return false end
    return contains(Config.GPS.ViewerJobs, Player.PlayerData.job.name)
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
                item = Config.GPS.Item,
            })
            if not registered then
                error(('wasabi_gps did not accept registerJob for "%s"'):format(job))
            end
        end
    end)

    if ok then
        print(('[hd_ems] GPS tracking handed off to %s for: %s'):format(resourceName, table.concat(Config.GPS.TrackableJobs, ', ')))
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
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    while not Framework do Wait(50) end

    usingWasabi = tryRegisterWithWasabi()
    if not usingWasabi and Config.GPS.UseWasabiGPS then
        print('[hd_ems] wasabi_gps not active — using the built-in GPS fallback instead.')
    end

    Framework.Functions.CreateCallback('ukhs:server:isUsingWasabiGps', function(src, cb)
        cb(usingWasabi)
    end)

    Framework.Functions.CreateCallback('ukhs:server:isGpsViewer', function(src, cb)
        cb(isViewer(Framework.Functions.GetPlayer(src)))
    end)

    while true do
        Wait(Config.GPS.UpdateInterval)
        if not usingWasabi then
            for _, src in ipairs(Framework.Functions.GetPlayers()) do
                local Player = Framework.Functions.GetPlayer(src)
                if isTrackable(Player) then
                    local ped = GetPlayerPed(src)
                    if ped and ped ~= 0 then
                        local coords = GetEntityCoords(ped)
                        local name = (Player.PlayerData.charinfo.firstname or '') .. ' ' .. (Player.PlayerData.charinfo.lastname or '')

                        for _, viewerSrc in ipairs(Framework.Functions.GetPlayers()) do
                            if isViewer(Framework.Functions.GetPlayer(viewerSrc)) then
                                TriggerClientEvent('ukhs:client:gpsUpdate', viewerSrc, {
                                    source = src,
                                    name = name,
                                    jobName = Player.PlayerData.job.name,
                                    coords = { x = coords.x, y = coords.y, z = coords.z },
                                })
                            end
                        end
                    end
                end
            end
        end
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

RegisterNetEvent('ukhs:server:gpsPing', function(coords)
    if usingWasabi then return end -- wasabi_gps is handling delivery; ignore

    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not isTrackable(Player) then return end

    for _, viewerSrc in ipairs(Framework.Functions.GetPlayers()) do
        if isViewer(Framework.Functions.GetPlayer(viewerSrc)) then
            TriggerClientEvent('ukhs:client:gpsUpdate', viewerSrc, {
                source = src,
                name = (Player.PlayerData.charinfo.firstname or '') .. ' ' .. (Player.PlayerData.charinfo.lastname or ''),
                jobName = Player.PlayerData.job.name,
                coords = coords,
            })
        end
    end
end)

RegisterNetEvent('ukhs:server:gpsOffDuty', function()
    if usingWasabi then return end
    local src = source
    for _, viewerSrc in ipairs(Framework.Functions.GetPlayers()) do
        if isViewer(Framework.Functions.GetPlayer(viewerSrc)) then
            TriggerClientEvent('ukhs:client:gpsRemove', viewerSrc, src)
        end
    end
end)

-- Fired by server/job.lua on duty-off / disconnect.
AddEventHandler('hd_ems:server:medicOffDuty', function(src)
    if not Framework or usingWasabi then return end
    for _, viewerSrc in ipairs(Framework.Functions.GetPlayers()) do
        if isViewer(Framework.Functions.GetPlayer(viewerSrc)) then
            TriggerClientEvent('ukhs:client:gpsRemove', viewerSrc, src)
        end
    end
end)
