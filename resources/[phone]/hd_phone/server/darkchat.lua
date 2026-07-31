-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | DARK CHAT
--  Anonymous-flavoured messaging — mirrors messages.lua, just keyed by
--  a persistent per-citizen alias instead of the real phone number.
-- ═══════════════════════════════════════════════════════════════════

local function GenerateAlias()
    return Config.DarkChat.AliasPrefix .. tostring(math.random(1000, 9999))
end

local function GenerateUniqueAlias()
    local alias
    repeat
        alias = GenerateAlias()
        local exists = MySQL.scalar.await('SELECT 1 FROM hd_phone_darkchat_identity WHERE alias = ?', { alias })
    until not exists
    return alias
end

-- INSERT IGNORE + re-read: two calls for the same citizenid can both
-- pass the "no row yet" SELECT before either INSERT lands (this ran
-- into exactly that race in production once already) — IGNORE means
-- the loser doesn't error on the unique keys, then the re-read picks
-- up whichever alias actually won.
function GetOrCreateAlias(citizenid)
    local row = MySQL.single.await('SELECT alias FROM hd_phone_darkchat_identity WHERE citizenid = ?', { citizenid })
    if row then return row.alias end

    local alias = GenerateUniqueAlias()
    MySQL.insert.await('INSERT IGNORE INTO hd_phone_darkchat_identity (citizenid, alias) VALUES (?, ?)', { citizenid, alias })
    row = MySQL.single.await('SELECT alias FROM hd_phone_darkchat_identity WHERE citizenid = ?', { citizenid })
    return row and row.alias or alias
end

local function GetSourceByAlias(alias)
    for _, srcStr in ipairs(GetPlayers()) do
        local candidate = tonumber(srcStr)
        local Player = GetPlayerOrNil(candidate)
        if Player and GetOrCreateAlias(Player.PlayerData.citizenid) == alias then return candidate end
    end
    return nil
end

RegisterNetEvent('hd_phone:server:getMyAlias', function()
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    TriggerClientEvent('hd_phone:client:myAlias', src, GetOrCreateAlias(Player.PlayerData.citizenid))
end)

RegisterNetEvent('hd_phone:server:getDarkThreads', function()
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    local alias = GetOrCreateAlias(Player.PlayerData.citizenid)

    local latest = MySQL.query.await([[
        SELECT m.* FROM hd_phone_darkchat_messages m
        INNER JOIN (
            SELECT CASE WHEN sender = ? THEN recipient ELSE sender END AS other, MAX(id) AS maxId
            FROM hd_phone_darkchat_messages WHERE sender = ? OR recipient = ?
            GROUP BY other
        ) latest ON m.id = latest.maxId
        ORDER BY m.created DESC
    ]], { alias, alias, alias }) or {}

    local unreadRows = MySQL.query.await(
        'SELECT sender, COUNT(*) AS cnt FROM hd_phone_darkchat_messages WHERE recipient = ? AND is_read = 0 GROUP BY sender',
        { alias }
    ) or {}
    local unreadByAlias = {}
    for _, r in ipairs(unreadRows) do unreadByAlias[r.sender] = r.cnt end

    local threads = {}
    for _, m in ipairs(latest) do
        local other = (m.sender == alias) and m.recipient or m.sender
        threads[#threads + 1] = {
            alias = other, lastMessage = m.message, lastCreated = m.created,
            fromMe = m.sender == alias, unread = unreadByAlias[other] or 0,
        }
    end
    TriggerClientEvent('hd_phone:client:darkThreads', src, threads)
end)

RegisterNetEvent('hd_phone:server:getDarkConversation', function(withAlias)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player or type(withAlias) ~= 'string' then return end
    local alias = GetOrCreateAlias(Player.PlayerData.citizenid)

    local rows = MySQL.query.await([[
        SELECT * FROM hd_phone_darkchat_messages
        WHERE (sender = ? AND recipient = ?) OR (sender = ? AND recipient = ?)
        ORDER BY id DESC LIMIT ?
    ]], { alias, withAlias, withAlias, alias, Config.MessageHistoryLimit }) or {}

    local chrono = {}
    for i = #rows, 1, -1 do chrono[#chrono + 1] = rows[i] end
    MySQL.update('UPDATE hd_phone_darkchat_messages SET is_read = 1 WHERE sender = ? AND recipient = ? AND is_read = 0', { withAlias, alias })
    TriggerClientEvent('hd_phone:client:darkConversation', src, withAlias, chrono)
end)

RegisterNetEvent('hd_phone:server:sendDarkMessage', function(data)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player or type(data) ~= 'table' then return end
    local alias = GetOrCreateAlias(Player.PlayerData.citizenid)

    local to = type(data.to) == 'string' and data.to:sub(1, 30) or ''
    local message = type(data.message) == 'string' and data.message:sub(1, Config.MaxMessageLength) or ''
    if to == '' or message == '' or to == alias then return end

    local id = MySQL.insert.await('INSERT INTO hd_phone_darkchat_messages (sender, recipient, message) VALUES (?, ?, ?)', { alias, to, message })
    local payload = { id = id, sender = alias, recipient = to, message = message, created = os.time(), is_read = 0 }
    TriggerClientEvent('hd_phone:client:newDarkMessage', src, payload)
    local targetSrc = GetSourceByAlias(to)
    if targetSrc then TriggerClientEvent('hd_phone:client:newDarkMessage', targetSrc, payload) end
end)
