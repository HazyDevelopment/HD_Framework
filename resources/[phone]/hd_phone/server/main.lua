-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | SERVER CORE
--  Shared bridge + helpers every other server/*.lua module in this
--  resource uses. Phone numbers ARE charinfo.phone from HD_Framework
--  (generated once per character on creation) — nothing here
--  duplicates or reassigns numbers.
-- ═══════════════════════════════════════════════════════════════════

Framework = nil
CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

CreateThread(function()
    Wait(1000)
    local ok = pcall(function() MySQL.query.await('SELECT 1 FROM `hd_phone_messages` LIMIT 1') end)
    if not ok then
        print('^1[hd_phone] ============================================================^7')
        print('^1[hd_phone] DATABASE NOT INSTALLED.^7')
        print('^1[hd_phone] Import sql/hd_phone_install.sql before using the phone.^7')
        print('^1[hd_phone] ============================================================^7')
    else
        print('^2[hd_phone]^7 Database verified. Ready.')
    end
end)

function GetPhoneNumber(src)
    local Player = Framework.Functions.GetPlayer(src)
    return Player and Player.PlayerData.charinfo.phone or nil
end

function GetDisplayName(src)
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return 'Unknown' end
    local ci = Player.PlayerData.charinfo
    return (ci.firstname or '?') .. ' ' .. (ci.lastname or '?')
end

function GetSourceByPhone(number)
    for src, Player in pairs(Framework.Players) do
        if Player.PlayerData.charinfo.phone == number then return src end
    end
    return nil
end

RegisterNetEvent('hd_phone:server:ready', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end
    TriggerClientEvent('hd_phone:client:setNumber', src, Player.PlayerData.charinfo.phone)
end)
