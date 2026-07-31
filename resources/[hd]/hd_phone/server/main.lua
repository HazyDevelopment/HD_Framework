-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | SERVER CORE
--  Framework bootstrap, the phone-item→open hook, and the one big
--  "sync" payload the NUI needs on open (account/settings state +
--  installed apps) — everything else is per-app server/*.lua files.
-- ═══════════════════════════════════════════════════════════════════

Framework = nil

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
    local ok = pcall(function() MySQL.query.await('SELECT 1 FROM `hd_phone_settings` LIMIT 1') end)
    if not ok then
        print('^1[hd_phone] ============================================================^7')
        print('^1[hd_phone] DATABASE NOT INSTALLED.^7')
        print('^1[hd_phone] Import sql/hd_phone_install.sql before using this resource.^7')
        print('^1[hd_phone] ============================================================^7')
    else
        print('^2[hd_phone]^7 Database verified. Ready.')
    end
end)

function Notify(src, msg, ntype)
    TriggerClientEvent('HD:Client:Notify', src, msg, ntype or 'info')
end

function GetPlayerOrNil(src)
    if not Framework then return nil end
    return Framework.Functions.GetPlayer(src)
end

-- ═══════════════════════════ SETTINGS / ACCOUNT ROW ══════════════════
-- One row per citizen, created lazily the first time the phone opens.
-- Holds onboarding state, HD ID credentials, passcode, and every
-- Settings/Control-Center toggle — see sql/hd_phone_install.sql.
function GetOrCreateSettings(citizenid)
    local row = MySQL.single.await('SELECT * FROM hd_phone_settings WHERE citizenid = ?', { citizenid })
    if row then return row end
    MySQL.insert.await('INSERT IGNORE INTO hd_phone_settings (citizenid, wallpaper) VALUES (?, ?)', { citizenid, 'aurora' })
    return MySQL.single.await('SELECT * FROM hd_phone_settings WHERE citizenid = ?', { citizenid })
end

local function InstalledAppIds(citizenid)
    local rows = MySQL.query.await('SELECT app_id FROM hd_phone_installed_apps WHERE citizenid = ?', { citizenid }) or {}
    local ids = {}
    for _, r in ipairs(rows) do ids[#ids + 1] = r.app_id end
    return ids
end

-- ═══════════════════════════ OPEN / SYNC ═════════════════════════════
RegisterNetEvent('hd_phone:server:sync', function()
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid

    local settings = GetOrCreateSettings(citizenid)
    TriggerClientEvent('hd_phone:client:sync', src, {
        number = Player.PlayerData.charinfo.phone,
        name = (Player.PlayerData.charinfo.firstname or '') .. ' ' .. (Player.PlayerData.charinfo.lastname or ''),
        settings = {
            onboarded = settings.onboarded == 1,
            email = settings.email,
            wallpaper = settings.wallpaper,
            customWallpaperUrl = settings.custom_wallpaper_url,
            darkMode = settings.dark_mode == 1,
            dynamicMode = settings.dynamic_mode == 1,
            noCallerId = settings.no_caller_id == 1,
            receiveDrop = settings.receive_drop == 1,
            hasPasscode = settings.passcode ~= nil and settings.passcode ~= '',
        },
        homeOrder = settings.home_order and json.decode(settings.home_order) or nil,
        installedApps = InstalledAppIds(citizenid),
        apps = Config.Apps,
        wallpapers = Config.Wallpapers,
    })
end)

-- ═══════════════════════════ PHONE-ITEM → OPEN ═══════════════════════
AddEventHandler('hd_inventory:server:onItemUsed', function(src, itemName)
    local isPhone = false
    for _, name in ipairs(Config.PhoneItems) do
        if name == itemName then isPhone = true break end
    end
    if not isPhone then return end
    TriggerClientEvent('hd_phone:client:open', src)
end)
