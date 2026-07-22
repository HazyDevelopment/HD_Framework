-- ===================================================================
-- server/bridge.lua
-- Framework abstraction layer — the only file that talks to QBCore or
-- ESX directly. Everything else calls Bridge.*.
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

function Bridge.CreateCallback(name, handler)
    if Config.Framework == 'qbcore' then
        QBCore.Functions.CreateCallback(name, handler)
    else
        ESX.RegisterServerCallback(name, handler)
    end
end

-- -------------------------------------------------------------------
-- Normalized player object:
-- { source, identifier, name, jobName, grade, isAmbulance, jobOnDuty, _raw }
-- On-duty: QBCore reports it natively (job.onduty). ESX has no native
-- duty flag, so this resource keeps its own state in the `ukhs_duty`
-- table for ESX (see Bridge.SetDuty / Bridge.HydrateESXDuty below).
-- -------------------------------------------------------------------
local esxDutyCache = {} -- identifier -> bool, hydrated from ukhs_duty on demand

function Bridge.GetPlayer(source)
    if Config.Framework == 'qbcore' then
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return nil end
        local pd = Player.PlayerData
        return {
            source = source,
            identifier = pd.citizenid,
            name = (pd.charinfo.firstname or '') .. ' ' .. (pd.charinfo.lastname or ''),
            jobName = pd.job and pd.job.name or 'unemployed',
            grade = pd.job and pd.job.grade and pd.job.grade.level or 0,
            isAmbulance = pd.job and pd.job.name == ambulanceJobName(),
            jobOnDuty = pd.job and pd.job.onduty or false,
            _raw = Player,
        }
    else
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return nil end
        local job = xPlayer.getJob and xPlayer.getJob() or xPlayer.job
        local identifier = xPlayer.identifier

        return {
            source = source,
            identifier = identifier,
            name = (xPlayer.get and (xPlayer.get('firstName') or xPlayer.get('firstname'))
                    or (xPlayer.getFirstName and xPlayer.getFirstName()) or '') .. ' ' ..
                   (xPlayer.get and (xPlayer.get('lastName') or xPlayer.get('lastname'))
                    or (xPlayer.getLastName and xPlayer.getLastName()) or ''),
            jobName = job and job.name or 'unemployed',
            grade = job and job.grade or 0,
            isAmbulance = job and job.name == ambulanceJobName(),
            jobOnDuty = esxDutyCache[identifier] or false,
            _raw = xPlayer,
        }
    end
end

-- -------------------------------------------------------------------
-- Duty
-- -------------------------------------------------------------------
function Bridge.SetDuty(source, onDuty)
    if Config.Framework == 'qbcore' then
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end
        Player.Functions.SetJobDuty(onDuty)
    else
        local player = Bridge.GetPlayer(source)
        if not player then return end
        esxDutyCache[player.identifier] = onDuty
        MySQL.query.await([[
            INSERT INTO ukhs_duty (identifier, on_duty) VALUES (?, ?)
            ON DUPLICATE KEY UPDATE on_duty = VALUES(on_duty)
        ]], { player.identifier, onDuty and 1 or 0 })
    end
end

-- Call once at resource start to warm the ESX duty cache from DB so a
-- reconnecting player's duty state survives a restart.
function Bridge.HydrateESXDuty()
    if Config.Framework ~= 'esx' then return end
    local rows = MySQL.query.await('SELECT identifier, on_duty FROM ukhs_duty')
    for _, row in ipairs(rows or {}) do
        esxDutyCache[row.identifier] = row.on_duty == 1
    end
end

-- -------------------------------------------------------------------
-- Armoury: give items (no weapons — this is a medical service)
-- -------------------------------------------------------------------
function Bridge.GiveItem(source, itemName, count)
    if Config.Framework == 'qbcore' then
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end
        Player.Functions.AddItem(itemName, count or 1)
    else
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return end
        xPlayer.addInventoryItem(itemName, count or 1)
    end
end

-- -------------------------------------------------------------------
-- Online players, normalized
-- -------------------------------------------------------------------
function Bridge.GetOnlinePlayers()
    local list = {}
    if Config.Framework == 'qbcore' then
        local players = QBCore.Functions.GetQBPlayers()
        for src, _ in pairs(players) do
            local normalized = Bridge.GetPlayer(src)
            if normalized then list[#list + 1] = normalized end
        end
    else
        for _, src in ipairs(ESX.GetPlayers() or {}) do
            local normalized = Bridge.GetPlayer(src)
            if normalized then list[#list + 1] = normalized end
        end
    end
    return list
end
