-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | CONTACTS
-- ═══════════════════════════════════════════════════════════════════

local function SendContacts(src, citizenid)
    local rows = MySQL.query.await('SELECT id, name, number FROM hd_phone_contacts WHERE owner = ? ORDER BY name ASC', {
        citizenid
    }) or {}
    TriggerClientEvent('hd_phone:client:contacts', src, rows)
end

RegisterNetEvent('hd_phone:server:getContacts', function()
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    SendContacts(src, Player.PlayerData.citizenid)
end)

RegisterNetEvent('hd_phone:server:saveContact', function(name, number)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    name = type(name) == 'string' and name:sub(1, 60) or ''
    number = type(number) == 'string' and number:sub(1, 15) or ''
    if name == '' or number == '' then return end

    MySQL.query.await([[
        INSERT INTO hd_phone_contacts (owner, name, number) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name)
    ]], { Player.PlayerData.citizenid, name, number })
    SendContacts(src, Player.PlayerData.citizenid)
end)

RegisterNetEvent('hd_phone:server:deleteContact', function(id)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    MySQL.update('DELETE FROM hd_phone_contacts WHERE id = ? AND owner = ?', { id, Player.PlayerData.citizenid })
    SendContacts(src, Player.PlayerData.citizenid)
end)
