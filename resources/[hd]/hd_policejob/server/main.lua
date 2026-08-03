-- ═══════════════════════════════════════════════════════════════════
--  hd_policejob | server/main.lua
--  Framework handle + duty toggle + small rank helpers shared by
--  armoury.lua and gps.lua.
-- ═══════════════════════════════════════════════════════════════════

Framework = nil
HDPolice = HDPolice or {}

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()

    Framework.Functions.CreateCallback('hdpolice:getRank', function(src, cb)
        local Player = Framework.Functions.GetPlayer(src)
        if not Player or Player.PlayerData.job.name ~= Config.JobName then return cb(nil) end
        local rank = HDPolice.GetRank(Player.PlayerData.job.grade.level)
        cb({
            grade = Player.PlayerData.job.grade.level,
            label = rank and rank.label or Player.PlayerData.job.grade.name,
            onduty = Player.PlayerData.job.onduty,
            isArmedResponse = rank and rank.isArmedResponse or false,
            isCommand = rank and rank.isCommand or false,
            isBoss = Player.PlayerData.job.isboss or false,
        })
    end)
end)

function HDPolice.GetRank(grade)
    return Config.Ranks[tonumber(grade) or 0]
end

-- Returns ok, Player. ok is false if the source isn't logged in, isn't
-- on the police job, or (when Config.RequireOnDuty) isn't on duty —
-- Player is still returned in that last case so callers can read their
-- job/grade for messaging.
function HDPolice.IsOnDutyPolice(src)
    local Player = Framework and Framework.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.job.name ~= Config.JobName then return false, nil end
    if Config.RequireOnDuty and not Player.PlayerData.job.onduty then return false, Player end
    return true, Player
end

RegisterNetEvent('hdpolice:server:toggleDuty', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.job.name ~= Config.JobName then return end

    local newState = not Player.PlayerData.job.onduty
    Player.Functions.SetJobDuty(newState)
    TriggerClientEvent('HD:Client:Notify', src, newState and 'You are now on duty.' or 'You are now off duty.', newState and 'success' or 'info')

    if not newState then
        TriggerEvent('hdpolice:server:officerOffDuty', src) -- gps.lua listens for this
    end
end)

AddEventHandler('playerDropped', function()
    TriggerEvent('hdpolice:server:officerOffDuty', source) -- gps.lua listens for this
end)
