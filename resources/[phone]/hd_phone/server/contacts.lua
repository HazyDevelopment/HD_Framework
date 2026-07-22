-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | CONTACTS
-- ═══════════════════════════════════════════════════════════════════

local function SendContacts(src, citizenid)
    local rows = MySQL.query.await('SELECT id, name, number FROM hd_phone_contacts WHERE owner = ? ORDER BY name ASC', {
        citizenid
    })
    TriggerClientEvent('hd_phone:client:contacts', src, rows or {})
end

RegisterNetEvent('hd_phone:server:getContacts', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end
    SendContacts(src, Player.PlayerData.citizenid)
end)

RegisterNetEvent('hd_phone:server:saveContact', function(data)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end
    if type(data) ~= 'table' or type(data.name) ~= 'string' or type(data.number) ~= 'string' then return end

    local name = data.name:sub(1, 60)
    local number = data.number:gsub('%D', ''):sub(1, 15)
    if name == '' or number == '' then return end

    MySQL.insert.await(
        'INSERT INTO hd_phone_contacts (owner, name, number) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name)',
        { Player.PlayerData.citizenid, name, number }
    )
    SendContacts(src, Player.PlayerData.citizenid)
end)

RegisterNetEvent('hd_phone:server:deleteContact', function(id)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or not id then return end

    MySQL.query.await('DELETE FROM hd_phone_contacts WHERE id = ? AND owner = ?', { id, Player.PlayerData.citizenid })
    SendContacts(src, Player.PlayerData.citizenid)
end)
