-- ═══════════════════════════════════════════════════════════════════
--  HD MECHANIC | SERVER CORE
--  IsMechanic is the one real gate every paid action in shop.lua and
--  limp.lua calls independently — global on purpose, all server/*.lua
--  files in this resource share one Lua environment. Reuses the same
--  `job.type == 'mechanic'` extension point hd_dispatch and hd_radio
--  already key off, not a hardcoded job name.
-- ═══════════════════════════════════════════════════════════════════

Framework = nil

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

CreateThread(function()
    Wait(1500)
    local ok = pcall(function() MySQL.query.await('SELECT 1 FROM `hd_vehicle_compliance` LIMIT 1') end)
    if not ok then
        print('^1[hd_mechanic] ============================================================^7')
        print('^1[hd_mechanic] DATABASE NOT INSTALLED.^7')
        print('^1[hd_mechanic] Import sql/hd_mechanic_install.sql before using this resource.^7')
        print('^1[hd_mechanic] ============================================================^7')
    else
        print('^2[hd_mechanic]^7 Database verified. Ready.')
    end
end)

function IsMechanic(src)
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return false end
    local job = Player.PlayerData.job
    return job.type == 'mechanic' and job.onduty == true
end

function Notify(src, msg, ntype)
    TriggerClientEvent('HD:Client:Notify', src, msg, ntype or 'info')
end

function TrimPlate(p)
    return (p or ''):gsub('%s+$', ''):gsub('^%s+', '')
end
