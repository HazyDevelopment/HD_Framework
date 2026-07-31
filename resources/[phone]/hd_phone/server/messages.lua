-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | MESSAGES
--  Threads derived on read (no separate conversation table) — same
--  shape as the old dark chat implementation, just keyed by real
--  charinfo.phone numbers instead of an alias.
-- ═══════════════════════════════════════════════════════════════════

local function GetSourceByPhone(number)
    for _, srcStr in ipairs(GetPlayers()) do
        local candidate = tonumber(srcStr)
        local Player = GetPlayerOrNil(candidate)
        if Player and Player.PlayerData.charinfo.phone == number then return candidate end
    end
    return nil
end

RegisterNetEvent('hd_phone:server:getThreads', function()
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    local number = Player.PlayerData.charinfo.phone

    local latest = MySQL.query.await([[
        SELECT m.* FROM hd_phone_messages m
        INNER JOIN (
            SELECT CASE WHEN sender = ? THEN recipient ELSE sender END AS other, MAX(id) AS maxId
            FROM hd_phone_messages WHERE sender = ? OR recipient = ?
            GROUP BY other
        ) latest ON m.id = latest.maxId
        ORDER BY m.created DESC
    ]], { number, number, number }) or {}

    local unreadRows = MySQL.query.await(
        'SELECT sender, COUNT(*) AS cnt FROM hd_phone_messages WHERE recipient = ? AND is_read = 0 GROUP BY sender',
        { number }
    ) or {}
    local unreadByNumber = {}
    for _, r in ipairs(unreadRows) do unreadByNumber[r.sender] = r.cnt end

    local threads = {}
    for _, m in ipairs(latest) do
        local other = (m.sender == number) and m.recipient or m.sender
        threads[#threads + 1] = {
            number = other,
            lastMessage = m.message,
            lastCreated = m.created,
            fromMe = m.sender == number,
            unread = unreadByNumber[other] or 0,
        }
    end
    TriggerClientEvent('hd_phone:client:threads', src, threads)
end)

RegisterNetEvent('hd_phone:server:getConversation', function(withNumber)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player or type(withNumber) ~= 'string' then return end
    local number = Player.PlayerData.charinfo.phone

    local rows = MySQL.query.await([[
        SELECT * FROM hd_phone_messages
        WHERE (sender = ? AND recipient = ?) OR (sender = ? AND recipient = ?)
        ORDER BY id DESC LIMIT ?
    ]], { number, withNumber, withNumber, number, Config.MessageHistoryLimit }) or {}

    local chrono = {}
    for i = #rows, 1, -1 do chrono[#chrono + 1] = rows[i] end

    MySQL.update('UPDATE hd_phone_messages SET is_read = 1 WHERE sender = ? AND recipient = ? AND is_read = 0', { withNumber, number })
    TriggerClientEvent('hd_phone:client:conversation', src, withNumber, chrono)
end)

RegisterNetEvent('hd_phone:server:sendMessage', function(data)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player or type(data) ~= 'table' then return end
    local number = Player.PlayerData.charinfo.phone

    local to = type(data.to) == 'string' and data.to:sub(1, 15) or ''
    local message = type(data.message) == 'string' and data.message:sub(1, Config.MaxMessageLength) or ''
    if to == '' or message == '' or to == number then return end

    local id = MySQL.insert.await('INSERT INTO hd_phone_messages (sender, recipient, message) VALUES (?, ?, ?)', {
        number, to, message
    })

    local payload = { id = id, sender = number, recipient = to, message = message, created = os.time(), is_read = 0 }
    TriggerClientEvent('hd_phone:client:newMessage', src, payload)

    local targetSrc = GetSourceByPhone(to)
    if targetSrc then TriggerClientEvent('hd_phone:client:newMessage', targetSrc, payload) end
end)

-- Exported so other resources (e.g. a future bank/marketplace system)
-- can drop a message-style notice in without knowing this file's
-- internals — mirrors HD_Framework's own SendMail export shape.
exports('SendSystemMessage', function(toNumber, fromLabel, message)
    MySQL.insert.await('INSERT INTO hd_phone_messages (sender, recipient, message) VALUES (?, ?, ?)', {
        fromLabel, toNumber, message
    })
    local targetSrc = GetSourceByPhone(toNumber)
    if targetSrc then
        TriggerClientEvent('hd_phone:client:newMessage', targetSrc, {
            sender = fromLabel, recipient = toNumber, message = message, created = os.time(), is_read = 0,
        })
    end
end)
