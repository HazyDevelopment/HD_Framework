-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | MAIL
--  A system inbox, not player-to-player chat (that's Messages) —
--  populated by SendMail(), a global this resource's own apps call
--  (Bank receipts) and also exports for other resources to use
--  (an admin broadcast, a future marketplace-sale receipt, etc.).
-- ═══════════════════════════════════════════════════════════════════

function SendMail(citizenid, senderLabel, subject, body)
    if not citizenid or not senderLabel or not subject or not body then return end
    MySQL.insert.await(
        'INSERT INTO hd_phone_mail (citizenid, sender_label, subject, body) VALUES (?, ?, ?, ?)',
        { citizenid, senderLabel:sub(1, 60), subject:sub(1, 120), body }
    )

    -- Trim anything past Config.Mail.MaxPerPlayer, oldest first.
    MySQL.query.await([[
        DELETE FROM hd_phone_mail WHERE citizenid = ? AND id NOT IN (
            SELECT id FROM (SELECT id FROM hd_phone_mail WHERE citizenid = ? ORDER BY created DESC LIMIT ?) keep
        )
    ]], { citizenid, citizenid, Config.Mail.MaxPerPlayer })

    local src = Framework and GetSourceByCitizenId(citizenid)
    if src then TriggerClientEvent('hd_phone:client:newMail', src) end
end
exports('SendMail', SendMail)

function GetSourceByCitizenId(citizenid)
    for src, Player in pairs(Framework.Players) do
        if Player.PlayerData.citizenid == citizenid then return src end
    end
    return nil
end

RegisterNetEvent('hd_phone:server:getMail', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end

    local rows = MySQL.query.await(
        'SELECT * FROM hd_phone_mail WHERE citizenid = ? ORDER BY created DESC LIMIT ?',
        { Player.PlayerData.citizenid, Config.Mail.MaxPerPlayer }
    ) or {}
    TriggerClientEvent('hd_phone:client:mail', src, rows)
end)

RegisterNetEvent('hd_phone:server:readMail', function(id)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or not id then return end
    MySQL.update('UPDATE hd_phone_mail SET is_read = 1 WHERE id = ? AND citizenid = ?', { id, Player.PlayerData.citizenid })
end)

RegisterNetEvent('hd_phone:server:deleteMail', function(id)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or not id then return end
    MySQL.query.await('DELETE FROM hd_phone_mail WHERE id = ? AND citizenid = ?', { id, Player.PlayerData.citizenid })
    TriggerClientEvent('hd_phone:client:mailDeleted', src, id)
end)
