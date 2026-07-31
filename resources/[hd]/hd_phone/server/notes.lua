-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | NOTES
-- ═══════════════════════════════════════════════════════════════════

local function SendNotes(src, citizenid)
    local rows = MySQL.query.await('SELECT * FROM hd_phone_notes WHERE citizenid = ? ORDER BY updated DESC', { citizenid }) or {}
    TriggerClientEvent('hd_phone:client:notes', src, rows)
end

RegisterNetEvent('hd_phone:server:getNotes', function()
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    SendNotes(src, Player.PlayerData.citizenid)
end)

RegisterNetEvent('hd_phone:server:saveNote', function(id, content)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    content = type(content) == 'string' and content:sub(1, 2000) or ''
    local citizenid = Player.PlayerData.citizenid

    if id then
        MySQL.update('UPDATE hd_phone_notes SET content = ? WHERE id = ? AND citizenid = ?', { content, id, citizenid })
    else
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM hd_phone_notes WHERE citizenid = ?', { citizenid }) or 0
        if count >= Config.Notes.MaxPerPlayer then
            Notify(src, 'You have reached your note limit.', 'error')
            return
        end
        MySQL.insert('INSERT INTO hd_phone_notes (citizenid, content) VALUES (?, ?)', { citizenid, content })
    end
    SendNotes(src, citizenid)
end)

RegisterNetEvent('hd_phone:server:deleteNote', function(id)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    MySQL.update('DELETE FROM hd_phone_notes WHERE id = ? AND citizenid = ?', { id, Player.PlayerData.citizenid })
    SendNotes(src, Player.PlayerData.citizenid)
end)
