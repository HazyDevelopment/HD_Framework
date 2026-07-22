-- ═══════════════════════════════════════════════════════════════════
--  HD ADMIN | BANS
--  Bans key off `license`, not citizenid — a banned player is blocked
--  before they ever get a character loaded. The expiry check is done
--  entirely in SQL (`expires IS NULL OR expires > NOW()`), not pulled
--  into Lua and compared, to sidestep any timezone/parsing mismatch
--  between the DB and the game server's clock.
-- ═══════════════════════════════════════════════════════════════════

function PushBans(src)
    if not IsAdmin(src) then return end
    local rows = MySQL.query.await(
        'SELECT id, license, name, reason, banned_by, expires, created FROM hd_admin_bans WHERE active = 1 ORDER BY id DESC LIMIT 100'
    ) or {}
    TriggerClientEvent('hd_admin:client:bans', src, rows)
end

RegisterNetEvent('hd_admin:server:getBans', function()
    PushBans(source)
end)

RegisterNetEvent('hd_admin:server:ban', function(targetId, reason, hours)
    local src = source
    if not IsAdmin(src) then return end

    local id = tonumber(targetId)
    local Target = id and Framework.Functions.GetPlayer(id)
    if not Target then
        Notify(src, 'Player not found.', 'error')
        return
    end

    reason = tostring(reason or ''):sub(1, 255)
    if reason == '' then reason = 'No reason given' end

    local Admin = Framework.Functions.GetPlayer(src)
    local adminName = Admin and (Admin.PlayerData.charinfo.firstname .. ' ' .. Admin.PlayerData.charinfo.lastname) or 'Console'
    local targetName = Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname
    local hoursNum = tonumber(hours)

    if hoursNum and hoursNum > 0 then
        MySQL.insert.await(
            'INSERT INTO hd_admin_bans (license, name, reason, banned_by, expires) VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))',
            { Target.PlayerData.license, targetName, reason, adminName, hoursNum }
        )
    else
        MySQL.insert.await(
            'INSERT INTO hd_admin_bans (license, name, reason, banned_by, expires) VALUES (?, ?, ?, ?, NULL)',
            { Target.PlayerData.license, targetName, reason, adminName }
        )
    end

    local expiresText = (hoursNum and hoursNum > 0) and ('Expires in %d hour(s).'):format(hoursNum) or 'Permanent.'
    DropPlayer(id, Config.BanMessage:format(reason, expiresText))
    Notify(src, 'Banned.', 'success')
    PushBans(src)
end)

RegisterNetEvent('hd_admin:server:unban', function(banId)
    local src = source
    if not IsAdmin(src) then return end
    MySQL.update('UPDATE hd_admin_bans SET active = 0 WHERE id = ?', { tonumber(banId) or 0 })
    Notify(src, 'Unbanned.', 'success')
    PushBans(src)
end)

-- ═══════════════════════════ CONNECTION CHECK ═════════════════════════
-- Independent of HD_Framework's own playerConnecting handler (which
-- only checks for a valid license identifier) — FiveM supports
-- multiple resources each deferring and resolving their own check,
-- which is exactly how a separate ban resource is meant to coexist
-- alongside a core framework.
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)

    local license = nil
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id:match('^license:') then license = id break end
    end
    if not license then
        deferrals.done() -- not our check to make; HD_Framework's own handler covers "no license at all"
        return
    end

    local ban = MySQL.single.await(
        'SELECT reason, expires FROM hd_admin_bans WHERE license = ? AND active = 1 AND (expires IS NULL OR expires > NOW()) ORDER BY id DESC LIMIT 1',
        { license }
    )
    if ban then
        local expiresText = ban.expires and ('Expires: %s'):format(ban.expires) or 'Permanent.'
        deferrals.done(Config.BanMessage:format(ban.reason, expiresText))
        return
    end

    deferrals.done()
end)
