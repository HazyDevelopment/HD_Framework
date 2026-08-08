-- ═══════════════════════════════════════════════════════════════════
--  HD ANTICHEAT | MONITOR TAB
--  Be precise about what the Monitor tab's small "screens" actually
--  are: live position/heading telemetry pulled straight from
--  GetEntityCoords, not a video feed — FiveM has no native that lets a
--  server capture one client's rendered frame and stream it to
--  another's NUI, and rendering dozens of simultaneous in-game cameras
--  on one client isn't something the engine supports either. What IS
--  real, genuine live video is the big-screen view (client/main.lua's
--  big-screen handling): it reuses hd_admin's own tested spectate
--  camera and shows it through a transparent cutout in this panel, so
--  what an admin sees there is the actual game world rendering through,
--  not a simulation of one.
-- ═══════════════════════════════════════════════════════════════════

MonitorViewers = {} -- [src] = true while that admin's Monitor tab is open

RegisterNetEvent('hd_anticheat:server:monitorStart', function()
    local src = source
    if not IsExemptAdmin(src) then return end
    MonitorViewers[src] = true
end)

RegisterNetEvent('hd_anticheat:server:monitorStop', function()
    MonitorViewers[source] = nil
end)

AddEventHandler('playerDropped', function()
    MonitorViewers[source] = nil
end)

-- Same real-world coords/timer this file already samples on its own
-- interval, just kept from one tick to the next so a genuine m/s figure
-- can be shown alongside the radar — every field in the snapshot below
-- (this one included) is real telemetry read straight off the entity,
-- same honesty rule as the rest of this file's header.
local LastMonitorSample = {} -- [src] = { x, y, at (GetGameTimer ms) }

local function BuildMonitorSnapshot()
    local list = {}
    local now = GetGameTimer()
    for _, srcStr in ipairs(GetPlayers()) do
        local src = tonumber(srcStr)
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)

            local speed = 0.0
            local last = LastMonitorSample[src]
            if last then
                local elapsedS = (now - last.at) / 1000.0
                if elapsedS > 0 then
                    speed = #(vector2(coords.x, coords.y) - vector2(last.x, last.y)) / elapsedS
                end
            end
            LastMonitorSample[src] = { x = coords.x, y = coords.y, at = now }

            list[#list + 1] = {
                id = src,
                name = GetPlayerName(src) or ('Player %d'):format(src),
                x = coords.x, y = coords.y,
                heading = GetEntityHeading(ped),
                inVehicle = IsPedInAnyVehicle(ped, false),
                admin = IsExemptAdmin(src),
                ping = GetPlayerPing(src),
                speed = speed,
            }
        end
    end
    return list
end

AddEventHandler('playerDropped', function()
    LastMonitorSample[source] = nil
end)

CreateThread(function()
    while true do
        Wait(Config.MonitorIntervalMs)

        local hasViewers = false
        for _ in pairs(MonitorViewers) do hasViewers = true break end

        if hasViewers then
            local snapshot = BuildMonitorSnapshot()
            for src in pairs(MonitorViewers) do
                TriggerClientEvent('hd_anticheat:client:push', src, 'monitor', snapshot)
            end
        end
    end
end)
