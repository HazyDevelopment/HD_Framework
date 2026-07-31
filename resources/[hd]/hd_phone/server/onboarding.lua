-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | ONBOARDING + SETTINGS
--  The setup wizard (appearance/passcode/HD ID) and every toggle the
--  Settings app and Control Center expose, all on the one
--  hd_phone_settings row GetOrCreateSettings (server/main.lua) already
--  lazily creates.
-- ═══════════════════════════════════════════════════════════════════

local function CitizenId(src)
    local Player = GetPlayerOrNil(src)
    return Player and Player.PlayerData.citizenid or nil
end

RegisterNetEvent('hd_phone:server:setAppearance', function(darkMode, dynamicMode)
    local citizenid = CitizenId(source)
    if not citizenid then return end
    GetOrCreateSettings(citizenid)
    MySQL.update('UPDATE hd_phone_settings SET dark_mode = ?, dynamic_mode = ? WHERE citizenid = ?', {
        darkMode and 1 or 0, dynamicMode and 1 or 0, citizenid
    })
end)

RegisterNetEvent('hd_phone:server:setPasscode', function(passcode)
    local src = source
    local citizenid = CitizenId(src)
    if not citizenid then return end
    if passcode ~= nil and (type(passcode) ~= 'string' or not passcode:match('^%d%d%d%d$')) then return end
    GetOrCreateSettings(citizenid)
    MySQL.update('UPDATE hd_phone_settings SET passcode = ? WHERE citizenid = ?', { passcode, citizenid })
    Notify(src, passcode and 'Passcode set.' or 'Passcode removed.', 'success')
end)

RegisterNetEvent('hd_phone:server:verifyPasscode', function(passcode)
    local src = source
    local citizenid = CitizenId(src)
    if not citizenid then return end
    local row = GetOrCreateSettings(citizenid)
    local ok = row.passcode == nil or row.passcode == '' or row.passcode == passcode
    TriggerClientEvent('hd_phone:client:passcodeResult', src, ok)
end)

-- HD ID: display-only account flourish (email/password/security
-- question), same shape as the "Fruit ID"-style step every iOS-parody
-- phone script has — password is hashed, never round-tripped back to
-- the client, and nothing in this build actually gates phone access on
-- it (losing it can't lock you out of your own phone).
RegisterNetEvent('hd_phone:server:createAccount', function(data)
    local src = source
    local citizenid = CitizenId(src)
    if not citizenid or type(data) ~= 'table' then return end

    local email = type(data.email) == 'string' and data.email:sub(1, 60) or ''
    local password = type(data.password) == 'string' and data.password or ''
    local securityAnswer = type(data.securityAnswer) == 'string' and data.securityAnswer:sub(1, 100) or ''
    if email == '' or password == '' then
        Notify(src, 'Enter an email and password.', 'error')
        return
    end

    GetOrCreateSettings(citizenid)
    local hash = MySQL.scalar.await('SELECT SHA2(?, 256)', { password })
    MySQL.update('UPDATE hd_phone_settings SET email = ?, password_hash = ?, security_answer = ?, onboarded = 1 WHERE citizenid = ?', {
        email .. '@hazydev.com', hash, securityAnswer, citizenid
    })
    TriggerClientEvent('hd_phone:client:onboarded', src, email .. '@hazydev.com')
end)

RegisterNetEvent('hd_phone:server:skipOnboarding', function()
    local citizenid = CitizenId(source)
    if not citizenid then return end
    GetOrCreateSettings(citizenid)
    MySQL.update('UPDATE hd_phone_settings SET onboarded = 1 WHERE citizenid = ?', { citizenid })
end)

RegisterNetEvent('hd_phone:server:setWallpaper', function(wallpaperId, customUrl)
    local citizenid = CitizenId(source)
    if not citizenid then return end
    if customUrl and customUrl ~= '' then
        local hostOk = false
        for _, host in ipairs(Config.ImageHostWhitelist) do
            if customUrl:find(host, 1, true) then hostOk = true break end
        end
        if not hostOk then
            Notify(source, 'That image host is not allowed.', 'error')
            return
        end
    end
    MySQL.update('UPDATE hd_phone_settings SET wallpaper = ?, custom_wallpaper_url = ? WHERE citizenid = ?', {
        wallpaperId or 'aurora', (customUrl ~= '' and customUrl) or nil, citizenid
    })
end)

RegisterNetEvent('hd_phone:server:setNoCallerId', function(enabled)
    local citizenid = CitizenId(source)
    if not citizenid then return end
    MySQL.update('UPDATE hd_phone_settings SET no_caller_id = ? WHERE citizenid = ?', { enabled and 1 or 0, citizenid })
end)

RegisterNetEvent('hd_phone:server:setReceiveDrop', function(enabled)
    local citizenid = CitizenId(source)
    if not citizenid then return end
    MySQL.update('UPDATE hd_phone_settings SET receive_drop = ? WHERE citizenid = ?', { enabled and 1 or 0, citizenid })
end)

-- Home screen icon order — { grid = {ids}, dock = {ids} } — saved
-- whenever the player finishes a long-press drag (see html/js/app.js's
-- exitReorderMode). Trusted as opaque id strings; the client-side
-- renderHome() ignores any id that isn't currently a real, installed
-- app, so a stale/tampered order can't smuggle in anything.
RegisterNetEvent('hd_phone:server:setHomeOrder', function(data)
    local citizenid = CitizenId(source)
    if not citizenid or type(data) ~= 'table' then return end
    GetOrCreateSettings(citizenid)
    MySQL.update('UPDATE hd_phone_settings SET home_order = ? WHERE citizenid = ?', { json.encode(data), citizenid })
end)
