-- ═══════════════════════════════════════════════════════════════════
--  hd_ems | server/revive.lua
--  Staff-only /revive command.
--    /revive        -> revive yourself
--    /revive [id]   -> revive the player with that server ID
--  Permission is checked against Config.Revive (ace / HD_Framework
--  perms). Clears this resource's own downed bookkeeping directly via
--  EMS.ClearDowned (see server/main.lua) and reuses the exact same
--  'hd_ems:client:revived' event the in-person EMS revive fires, so a
--  staff revive and a real paramedic's revive land through identical
--  client-side code (client/main.lua's StandUp()).
-- ═══════════════════════════════════════════════════════════════════

if not Config.Revive or not Config.Revive.Enabled then return end

-- Is this source allowed to use the revive command?
local function IsStaff(src)
    if src == 0 then return true end -- server console

    local R = Config.Revive
    if R.AcePermission ~= '' and IsPlayerAceAllowed(src, R.AcePermission) then return true end
    if R.AllowGenericCommandAce and IsPlayerAceAllowed(src, 'command') then return true end
    return false
end

-- Server-side notify to a specific player (or console print for src 0)
local function NotifyStaff(src, message, ntype)
    if not Config.Revive.Notify then return end
    if src == 0 then print('[hd_ems] ' .. message); return end
    TriggerClientEvent('HD:Client:Notify', src, message, ntype or 'primary')
end

-- Is a given server ID currently connected?
local function PlayerOnline(target)
    return target and GetPlayerName(target) ~= nil
end

local function DoRevive(target)
    EMS.ClearDowned(target)
    TriggerClientEvent('hd_ems:client:revived', target, Config.ReviveHealth)
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

    DoRevive(target)

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
    DoRevive(target)
    return true
end)
