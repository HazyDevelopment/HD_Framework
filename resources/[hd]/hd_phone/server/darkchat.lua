-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | DARK CHAT
--  Anonymous-flavoured messaging — mirrors server/messages.lua almost
--  exactly (threads derived on read, no separate conversation table),
--  just keyed by a persistent per-citizen `alias` instead of the real
--  phone number, in its own tables so it never touches or exposes
--  charinfo.phone/name.
-- ═══════════════════════════════════════════════════════════════════

local function GenerateAlias()
    local range = Config.DarkChat.AliasNumberRange
    return Config.DarkChat.AliasPrefix .. tostring(math.random(range[1], range[2]))
end

-- Same repeat/until-unique pattern HD_Framework's GenerateCitizenId and
-- GenerateUKPhoneNumber already use.
local function GenerateUniqueAlias()
    local alias
    repeat
        alias = GenerateAlias()
        local exists = MySQL.scalar.await('SELECT 1 FROM hd_phone_darkchat_identity WHERE alias = ?', { alias })
    until not exists
    return alias
end

function GetOrCreateAlias(citizenid)
    local row = MySQL.single.await('SELECT alias FROM hd_phone_darkchat_identity WHERE citizenid = ?', { citizenid })
    if row then return row.alias end

    -- Two calls for the same citizenid can both pass the check above before
    -- either INSERT lands (getMyAlias/getDarkThreads fire back-to-back when
    -- the app opens) — INSERT IGNORE means the loser doesn't error on the
    -- citizenid/alias unique keys, then a re-read picks up whichever alias
    -- actually won the race instead of trusting our own insert blindly.
    local alias = GenerateUniqueAlias()
    MySQL.insert.await('INSERT IGNORE INTO hd_phone_darkchat_identity (citizenid, alias) VALUES (?, ?)', { citizenid, alias })
    row = MySQL.single.await('SELECT alias FROM hd_phone_darkchat_identity WHERE citizenid = ?', { citizenid })
    return row and row.alias or alias
end

local function GetAliasBySource(src)
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return nil end
    return GetOrCreateAlias(Player.PlayerData.citizenid)
end

-- For other online players' aliases to resolve to a live source, same
-- shape as HD_Framework's own GetSourceByPhone in server/main.lua.
local function GetSourceByAlias(alias)
    for _, srcStr in ipairs(GetPlayers()) do
        local candidate = tonumber(srcStr)
        local Player = Framework.Functions.GetPlayer(candidate)
        if Player and GetOrCreateAlias(Player.PlayerData.citizenid) == alias then return candidate end
    end
    return nil
end

RegisterNetEvent('hd_phone:server:getMyAlias', function()
    local src = source
    local alias = GetAliasBySource(src)
    if alias then TriggerClientEvent('hd_phone:client:myAlias', src, alias) end
end)

RegisterNetEvent('hd_phone:server:getDarkThreads', function()
    local src = source
    local alias = GetAliasBySource(src)
    if not alias then return end

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
            alias = other,
            lastMessage = m.message,
            lastCreated = m.created,
            fromMe = m.sender == alias,
            unread = unreadByAlias[other] or 0,
        }
    end
    TriggerClientEvent('hd_phone:client:darkThreads', src, threads)
end)

RegisterNetEvent('hd_phone:server:getDarkConversation', function(withAlias)
    local src = source
    local alias = GetAliasBySource(src)
    if not alias or type(withAlias) ~= 'string' then return end

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
    local alias = GetAliasBySource(src)
    if not alias or type(data) ~= 'table' then return end

    local to = type(data.to) == 'string' and data.to:sub(1, 30) or ''
    local message = type(data.message) == 'string' and data.message:sub(1, Config.MaxMessageLength) or ''
    if to == '' or message == '' or to == alias then return end

    local id = MySQL.insert.await('INSERT INTO hd_phone_darkchat_messages (sender, recipient, message) VALUES (?, ?, ?)', {
        alias, to, message
    })

    local payload = { id = id, sender = alias, recipient = to, message = message, created = os.time(), is_read = 0 }
    TriggerClientEvent('hd_phone:client:newDarkMessage', src, payload)

    local targetSrc = GetSourceByAlias(to)
    if targetSrc then TriggerClientEvent('hd_phone:client:newDarkMessage', targetSrc, payload) end
end)
