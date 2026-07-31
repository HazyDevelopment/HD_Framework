-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | APP STORE
--  Install/remove — validated against Config.Apps server-side so a
--  tampered NUI callback can't install an arbitrary id. Core apps
--  can't be removed; this is enforced here, not just hidden in the UI.
-- ═══════════════════════════════════════════════════════════════════

local function FindApp(appId)
    for _, app in ipairs(Config.Apps) do
        if app.id == appId then return app end
    end
    return nil
end

RegisterNetEvent('hd_phone:server:installApp', function(appId)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    local app = FindApp(appId)
    if not app or app.core then return end

    MySQL.insert.await('INSERT IGNORE INTO hd_phone_installed_apps (citizenid, app_id) VALUES (?, ?)', {
        Player.PlayerData.citizenid, appId
    })
    TriggerClientEvent('hd_phone:client:appInstalled', src, appId)
end)

RegisterNetEvent('hd_phone:server:removeApp', function(appId)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    local app = FindApp(appId)
    if not app or app.core then return end

    MySQL.update('DELETE FROM hd_phone_installed_apps WHERE citizenid = ? AND app_id = ?', {
        Player.PlayerData.citizenid, appId
    })
    TriggerClientEvent('hd_phone:client:appRemoved', src, appId)
end)
