-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | APP STORE
--  Core apps (Phone, Messages, Contacts, App Store, Settings) are
--  always available and never touch this table. Everything else is
--  install/uninstall gated per-citizen, validated against
--  Config.DownloadableApps so a tampered NUI callback can't "install"
--  an arbitrary id.
-- ═══════════════════════════════════════════════════════════════════

local function IsDownloadable(id)
    for _, appId in ipairs(Config.DownloadableApps) do
        if appId == id then return true end
    end
    return false
end

local function PushInstalledApps(src, citizenid)
    local rows = MySQL.query.await('SELECT app_id FROM hd_phone_installed_apps WHERE citizenid = ?', { citizenid })
    local ids = {}
    for _, row in ipairs(rows) do ids[#ids + 1] = row.app_id end
    TriggerClientEvent('hd_phone:client:installedApps', src, ids)
end

RegisterNetEvent('hd_phone:server:getInstalledApps', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end
    PushInstalledApps(src, Player.PlayerData.citizenid)
end)

RegisterNetEvent('hd_phone:server:installApp', function(data)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or type(data) ~= 'table' or not IsDownloadable(data.id) then return end

    MySQL.query.await(
        'INSERT IGNORE INTO hd_phone_installed_apps (citizenid, app_id) VALUES (?, ?)',
        { Player.PlayerData.citizenid, data.id }
    )
    PushInstalledApps(src, Player.PlayerData.citizenid)
end)

RegisterNetEvent('hd_phone:server:uninstallApp', function(data)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or type(data) ~= 'table' or not IsDownloadable(data.id) then return end

    MySQL.query.await(
        'DELETE FROM hd_phone_installed_apps WHERE citizenid = ? AND app_id = ?',
        { Player.PlayerData.citizenid, data.id }
    )
    PushInstalledApps(src, Player.PlayerData.citizenid)
end)
