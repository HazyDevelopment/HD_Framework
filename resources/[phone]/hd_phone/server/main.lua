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

-- Shared by social.lua, marketplace.lua, gallery.lua — anywhere a
-- player submits an arbitrary image URL. Matches hazy_mdt's
-- Config.MugshotWhitelist convention.
function IsAllowedImageHost(url)
    if not Config.ImageHostWhitelist or #Config.ImageHostWhitelist == 0 then return true end
    if type(url) ~= 'string' then return false end
    local host = url:match('^https?://([^/]+)/?')
    if not host then return false end
    host = host:lower()
    for _, allowed in ipairs(Config.ImageHostWhitelist) do
        if host == allowed or host:sub(-(#allowed + 1)) == '.' .. allowed then return true end
    end
    return false
end

RegisterNetEvent('hd_phone:server:ready', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end
    TriggerClientEvent('hd_phone:client:setNumber', src, Player.PlayerData.charinfo.phone)
end)
