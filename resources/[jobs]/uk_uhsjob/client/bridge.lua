-- ===================================================================
-- client/bridge.lua
-- Thin client-side framework abstraction, mirrors server/bridge.lua.
-- ===================================================================

Bridge = {}

local QBCore, ESX

if Config.Framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif Config.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
else
    error('[ukhs] Config.Framework must be "qbcore" or "esx" — check config.lua')
end

local function ambulanceJobName()
    return Config.AmbulanceJob[Config.Framework]
end

function Bridge.TriggerCallback(name, cb, ...)
    if Config.Framework == 'qbcore' then
        QBCore.Functions.TriggerCallback(name, cb, ...)
    else
        ESX.TriggerServerCallback(name, cb, ...)
    end
end

function Bridge.Notify(message, type)
    if Config.Framework == 'qbcore' then
        QBCore.Functions.Notify(message, type or 'primary')
    else
        ESX.ShowNotification(message)
    end
end

-- Returns { jobName, grade, onDuty, isAmbulance } for the local
-- player, or nil while player data hasn't loaded yet.
function Bridge.GetLocalJob()
    if Config.Framework == 'qbcore' then
        local pd = QBCore.Functions.GetPlayerData()
        if not pd or not pd.job then return nil end
        return {
            jobName = pd.job.name,
            grade = pd.job.grade and pd.job.grade.level or 0,
            onDuty = pd.job.onduty or false,
            isAmbulance = pd.job.name == ambulanceJobName(),
        }
    else
        local xPlayer = ESX.GetPlayerData()
        if not xPlayer or not xPlayer.job then return nil end
        return {
            jobName = xPlayer.job.name,
            grade = xPlayer.job.grade or 0,
            onDuty = nil, -- ESX has no native flag; client/main.lua tracks its own local duty state
            isAmbulance = xPlayer.job.name == ambulanceJobName(),
        }
    end
end
