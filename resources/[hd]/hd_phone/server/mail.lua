-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | MAIL
--  Other resources drop system mail in via the SendMail export (bank
--  receipts already do — see server/bank.lua's SendSystemMessage,
--  which is a Messages-app notice; this is the Mail-app equivalent).
-- ═══════════════════════════════════════════════════════════════════

RegisterNetEvent('hd_phone:server:getMail', function()
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    local rows = MySQL.query.await('SELECT * FROM hd_phone_mail WHERE citizenid = ? ORDER BY id DESC LIMIT ?', {
        Player.PlayerData.citizenid, Config.Mail.MaxPerPlayer
    }) or {}
    TriggerClientEvent('hd_phone:client:mail', src, rows)
end)

RegisterNetEvent('hd_phone:server:readMail', function(id)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    MySQL.update('UPDATE hd_phone_mail SET is_read = 1 WHERE id = ? AND citizenid = ?', { id, Player.PlayerData.citizenid })
end)

RegisterNetEvent('hd_phone:server:deleteMail', function(id)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    MySQL.update('DELETE FROM hd_phone_mail WHERE id = ? AND citizenid = ?', { id, Player.PlayerData.citizenid })
end)

exports('SendMail', function(citizenid, senderLabel, subject, body)
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM hd_phone_mail WHERE citizenid = ?', { citizenid }) or 0
    if count >= Config.Mail.MaxPerPlayer then
        MySQL.query.await([[
            DELETE FROM hd_phone_mail WHERE citizenid = ? ORDER BY id ASC LIMIT ?
        ]], { citizenid, count - Config.Mail.MaxPerPlayer + 1 })
    end
    MySQL.insert('INSERT INTO hd_phone_mail (citizenid, sender_label, subject, body) VALUES (?, ?, ?, ?)', {
        citizenid, senderLabel, subject, body
    })
end)
