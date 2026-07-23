-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | SETTINGS
--  Just a wallpaper preference for now (see html/css/style.css's
--  "WALLPAPERS" section for the actual look each key maps to) — a
--  natural place to add ringtone/sound toggles etc. later.
-- ═══════════════════════════════════════════════════════════════════

local function IsValidWallpaper(key)
    for _, w in ipairs(Config.Wallpapers) do
        if w.key == key then return true end
    end
    return false
end

RegisterNetEvent('hd_phone:server:getSettings', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end
    local row = MySQL.single.await(
        'SELECT wallpaper, no_caller_id, custom_wallpaper_url FROM hd_phone_settings WHERE citizenid = ?',
        { Player.PlayerData.citizenid }
    )
    TriggerClientEvent('hd_phone:client:settings', src, {
        wallpaper = (row and row.wallpaper) or 'default',
        wallpapers = Config.Wallpapers,
        noCallerId = row and row.no_caller_id == 1,
        customWallpaperUrl = row and row.custom_wallpaper_url or nil,
        number = GetPhoneNumber(src),
    })
end)

RegisterNetEvent('hd_phone:server:saveSettings', function(data)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or type(data) ~= 'table' then return end

    local citizenid = Player.PlayerData.citizenid
    local existing = MySQL.single.await('SELECT wallpaper, no_caller_id, custom_wallpaper_url FROM hd_phone_settings WHERE citizenid = ?', { citizenid })

    local wallpaper = existing and existing.wallpaper or 'default'
    local noCallerId = existing and existing.no_caller_id or 0
    local customUrl = existing and existing.custom_wallpaper_url or nil

    if data.wallpaper ~= nil then
        if not IsValidWallpaper(data.wallpaper) then return end
        wallpaper = data.wallpaper
    end
    if data.noCallerId ~= nil then
        noCallerId = data.noCallerId and 1 or 0
    end
    if data.customWallpaperUrl ~= nil then
        if data.customWallpaperUrl == '' then
            customUrl = nil
        elseif IsAllowedImageHost(data.customWallpaperUrl) then
            customUrl = data.customWallpaperUrl
            wallpaper = 'custom'
        else
            TriggerClientEvent('HD:Client:Notify', src, 'That image host is not allowed.', 'error')
            return
        end
    end

    MySQL.query.await([[
        INSERT INTO hd_phone_settings (citizenid, wallpaper, no_caller_id, custom_wallpaper_url) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE wallpaper = VALUES(wallpaper), no_caller_id = VALUES(no_caller_id), custom_wallpaper_url = VALUES(custom_wallpaper_url)
    ]], { citizenid, wallpaper, noCallerId, customUrl })

    TriggerClientEvent('hd_phone:client:settingsSaved', src, { wallpaper = wallpaper, customWallpaperUrl = customUrl })
end)

-- Whether `src` currently has No Caller ID on — used by server/calls.lua
-- to decide whether to mask the caller's number on an outgoing call.
function HasNoCallerId(src)
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return false end
    local row = MySQL.scalar.await('SELECT no_caller_id FROM hd_phone_settings WHERE citizenid = ?', { Player.PlayerData.citizenid })
    return row == 1
end
