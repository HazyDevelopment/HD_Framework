-- ═══════════════════════════════════════════════════════════════════
--  hd_ems | server/job.lua
--  Duty toggle + rank helpers shared by armoury.lua, garage.lua, and
--  gps.lua. `Framework` and `EMS` are the same globals server/main.lua
--  declares and assigns — job.lua loads after main.lua (see
--  fxmanifest.lua) so both are ready by the time anything here runs.
-- ═══════════════════════════════════════════════════════════════════

function EMS.GetRank(grade)
    return Config.Ranks[tonumber(grade) or 0]
end

-- Returns ok, Player. ok is false if the source isn't logged in, isn't
-- on the ambulance job, or (when Config.RequireOnDuty) isn't on duty —
-- Player is still returned in that last case so callers can read their
-- job/grade for messaging.
function EMS.IsOnDutyAmbulance(src)
    local Player = Framework and Framework.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.job.name ~= Config.AmbulanceJob then return false, nil end
    if Config.RequireOnDuty and not Player.PlayerData.job.onduty then return false, Player end
    return true, Player
end

RegisterNetEvent('hd_ems:server:toggleDuty', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.job.name ~= Config.AmbulanceJob then return end

    local newState = not Player.PlayerData.job.onduty
    Player.Functions.SetJobDuty(newState)
    TriggerClientEvent('HD:Client:Notify', src, newState and 'You are now on duty.' or 'You are now off duty.', newState and 'success' or 'info')
    TriggerClientEvent('hd_ems:client:dutyChanged', src, newState)

    if not newState then
        TriggerEvent('hd_ems:server:medicOffDuty', src) -- gps.lua listens for this
    end
end)

AddEventHandler('playerDropped', function()
    TriggerEvent('hd_ems:server:medicOffDuty', source) -- gps.lua listens for this
end)
