-- ═══════════════════════════════════════════════════════════════════
--  HD ADMIN | SERVER CORE
--  IsAdmin is the one real gate every action in players.lua/world.lua/
--  bans.lua calls independently — global on purpose, all four
--  server/*.lua files in this resource share one Lua environment.
-- ═══════════════════════════════════════════════════════════════════

Framework = nil
Jobs = {}  -- cached from Framework.Shared.Jobs — HD_Framework's shared/jobs.lua globals only exist in ITS OWN environment, not ours
Items = {} -- same deal, from Framework.Shared.Items

CreateThread(function()
    while GetResourceState('qb-core') ~= 'started' do Wait(100) end
    Framework = exports['qb-core']:GetCoreObject()
    Jobs = Framework.Shared and Framework.Shared.Jobs or {}
    Items = Framework.Shared and Framework.Shared.Items or {}
end)

CreateThread(function()
    Wait(1500)
    local ok = pcall(function() MySQL.query.await('SELECT 1 FROM `hd_admin_bans` LIMIT 1') end)
    if not ok then
        print('^1[hd_admin] ============================================================^7')
        print('^1[hd_admin] DATABASE NOT INSTALLED.^7')
        print('^1[hd_admin] Import sql/hd_admin_install.sql before using /admin.^7')
        print('^1[hd_admin] ============================================================^7')
    else
        print('^2[hd_admin]^7 Database verified. Ready.')
    end
end)

function IsAdmin(src)
    return src == 0 or IsPlayerAceAllowed(src, Config.Permission)
end

function Notify(src, msg, ntype)
    TriggerClientEvent('HD:Client:Notify', src, msg, ntype or 'info')
end

-- Client-side cache only — a UX nicety so the /admin command doesn't
-- even try to open the panel for a non-admin. Never the real gate;
-- every action below re-checks IsAdmin(src) on its own regardless of
-- what this said.
RegisterNetEvent('hd_admin:server:checkAdmin', function()
    TriggerClientEvent('hd_admin:client:isAdmin', source, IsAdmin(source))
end)

RegisterNetEvent('hd_admin:server:open', function()
    local src = source
    if not IsAdmin(src) then
        Notify(src, 'No permission.', 'error')
        return
    end
    TriggerClientEvent('hd_admin:client:open', src)
    -- PushPlayers is a global defined in server/players.lua, called
    -- directly rather than via TriggerEvent — an internal TriggerEvent
    -- doesn't reliably carry `src` through as the handler's `source`,
    -- a real bug I caught once already elsewhere in this build.
    PushPlayers(src)
end)
