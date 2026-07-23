-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | NOTES
--  Simple private CRUD, citizenid-owned. No sharing/collaboration.
-- ═══════════════════════════════════════════════════════════════════

RegisterNetEvent('hd_phone:server:getNotes', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end
    local rows = MySQL.query.await(
        'SELECT * FROM hd_phone_notes WHERE citizenid = ? ORDER BY updated DESC',
        { Player.PlayerData.citizenid }
    ) or {}
    TriggerClientEvent('hd_phone:client:notes', src, rows)
end)

RegisterNetEvent('hd_phone:server:saveNote', function(data)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or type(data) ~= 'table' then return end

    local content = type(data.content) == 'string' and data.content:sub(1, Config.Notes.MaxLength) or ''
    if content == '' then return end

    if data.id then
        MySQL.update('UPDATE hd_phone_notes SET content = ? WHERE id = ? AND citizenid = ?', {
            content, data.id, Player.PlayerData.citizenid
        })
        TriggerClientEvent('hd_phone:client:noteSaved', src, { id = data.id, content = content, updated = os.time() })
    else
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM hd_phone_notes WHERE citizenid = ?', { Player.PlayerData.citizenid }) or 0
        if count >= Config.Notes.MaxPerPlayer then
            return TriggerClientEvent('HD:Client:Notify', src, 'You have too many notes saved.', 'error')
        end
        local id = MySQL.insert.await('INSERT INTO hd_phone_notes (citizenid, content) VALUES (?, ?)', {
            Player.PlayerData.citizenid, content
        })
        TriggerClientEvent('hd_phone:client:noteSaved', src, { id = id, content = content, created = os.time(), updated = os.time() })
    end
end)

RegisterNetEvent('hd_phone:server:deleteNote', function(id)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or not id then return end
    MySQL.query.await('DELETE FROM hd_phone_notes WHERE id = ? AND citizenid = ?', { id, Player.PlayerData.citizenid })
    TriggerClientEvent('hd_phone:client:noteDeleted', src, id)
end)
