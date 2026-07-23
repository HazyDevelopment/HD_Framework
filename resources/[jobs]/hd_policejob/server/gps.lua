-- ═══════════════════════════════════════════════════════════════════
--  hd_policejob | server/gps.lua
--  Companion to uk_uhsjob/server/gps.lua: tracks/pushes ONLY this
--  resource's own job ("police"). Deliberately reuses uk_uhsjob's
--  existing client-side event names (ukhs:client:gpsUpdate /
--  ukhs:client:gpsRemove) — that renderer is a plain client_script,
--  already running on every connected client regardless of job, and
--  already color-codes a unit blue when jobName == 'police'. Piggy-
--  backing on it means officers show up on the map with zero new
--  client-side blip code, and it's exactly the extension point
--  uk_uhsjob/config.lua's own GPS comment describes.
-- ═══════════════════════════════════════════════════════════════════

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

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    while not Framework do Wait(50) end

    while true do
        Wait(Config.GPS.UpdateInterval)

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
end)

-- Fired by server/main.lua on duty-off / disconnect.
AddEventHandler('hdpolice:server:officerOffDuty', function(src)
    if not Framework then return end
    for _, viewerSrc in ipairs(Framework.Functions.GetPlayers()) do
        if isViewer(Framework.Functions.GetPlayer(viewerSrc)) then
            TriggerClientEvent('ukhs:client:gpsRemove', viewerSrc, src)
        end
    end
end)
