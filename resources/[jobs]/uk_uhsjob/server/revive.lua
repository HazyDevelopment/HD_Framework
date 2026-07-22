-- ===================================================================
-- server/revive.lua
-- Staff-only /revive command (QBCore & ESX).
--   /revive        -> revive yourself
--   /revive [id]   -> revive the player with that server ID
-- Permission is checked against Config.Revive (ace / QB perms / ESX
-- groups). Delivery is done client-side via native resurrect, so it
-- works even without qb-ambulancejob / esx_ambulancejob installed.
-- ===================================================================

if not Config.Revive or not Config.Revive.Enabled then return end

local QBCore, ESX
if Config.Framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif Config.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
end

-- Is this source allowed to use the revive command?
local function IsStaff(src)
    if src == 0 then return true end -- server console

    local R = Config.Revive
    if R.AcePermission ~= '' and IsPlayerAceAllowed(src, R.AcePermission) then return true end
    if R.AllowGenericCommandAce and IsPlayerAceAllowed(src, 'command') then return true end

    if Config.Framework == 'qbcore' then
        for _, perm in ipairs(R.QBAdminPermissions or {}) do
            if QBCore.Functions.HasPermission(src, perm) then return true end
        end
    else
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            local grp = (xPlayer.getGroup and xPlayer.getGroup()) or xPlayer.group
            for _, g in ipairs(R.ESXAdminGroups or {}) do
                if grp == g then return true end
            end
        end
    end
    return false
end

-- Server-side notify to a specific player (or console print for src 0)
local function NotifyStaff(src, message, ntype)
    if not Config.Revive.Notify then return end
    if src == 0 then print('[ukhs] ' .. message); return end
    if Config.Framework == 'qbcore' then
        TriggerClientEvent('QBCore:Notify', src, message, ntype or 'primary')
    else
        TriggerClientEvent('esx:showNotification', src, message)
    end
end

-- Is a given server ID currently connected?
local function PlayerOnline(target)
    return target and GetPlayerName(target) ~= nil
end

RegisterCommand(Config.Revive.Command, function(source, args)
    local src = source
    if not IsStaff(src) then
        NotifyStaff(src, 'You do not have permission to use this command.', 'error')
        return
    end

    -- Resolve target: no arg = self, else the given server ID
    local target = src
    if args[1] then
        target = tonumber(args[1])
        if not target then
            NotifyStaff(src, 'Invalid ID. Usage: /' .. Config.Revive.Command .. ' [server id]', 'error')
            return
        end
    end

    if src ~= 0 and target == src then
        -- self revive is always fine for staff
    elseif not PlayerOnline(target) then
        NotifyStaff(src, ('No player online with ID %s.'):format(tostring(target)), 'error')
        return
    end

    TriggerClientEvent('ukhs:client:revive', target, {
        restoreArmor = Config.Revive.RestoreArmor,
        clearWanted = Config.Revive.ClearWanted,
        fireFrameworkEvents = Config.Revive.FireFrameworkEvents
    })

    if target == src then
        NotifyStaff(src, 'You revived yourself.', 'success')
    else
        NotifyStaff(src, ('Revived player %s.'):format(tostring(target)), 'success')
        NotifyStaff(target, 'You have been revived by staff.', 'success')
    end
end, false) -- registered unrestricted; permission handled by IsStaff above

-- Optional: expose a server export so other resources/admin menus can revive too.
exports('RevivePlayer', function(target)
    if not Config.Revive.Enabled then return false end
    if not PlayerOnline(target) then return false end
    TriggerClientEvent('ukhs:client:revive', target, {
        restoreArmor = Config.Revive.RestoreArmor,
        clearWanted = Config.Revive.ClearWanted,
        fireFrameworkEvents = Config.Revive.FireFrameworkEvents
    })
    return true
end)
