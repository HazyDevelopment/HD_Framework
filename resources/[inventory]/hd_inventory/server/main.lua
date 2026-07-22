-- ═══════════════════════════════════════════════════════════════════
--  HD INVENTORY | SERVER CORE
--  Framework bridge + the item-definitions cache every other
--  server/*.lua module reads from.
-- ═══════════════════════════════════════════════════════════════════

Framework = nil
ItemDefs = {}

CreateThread(function()
    while GetResourceState('qb-core') ~= 'started' do Wait(100) end
    Framework = exports['qb-core']:GetCoreObject()
    ItemDefs = Framework.Shared and Framework.Shared.Items or {}
end)

CreateThread(function()
    Wait(1500)
    local ok = pcall(function()
        MySQL.query.await('SELECT `inventory` FROM `players` LIMIT 1')
        MySQL.query.await('SELECT 1 FROM `hd_inventory_stashes` LIMIT 1')
        MySQL.query.await('SELECT 1 FROM `hd_inventory_drops` LIMIT 1')
    end)
    if not ok then
        print('^1[hd_inventory] ============================================================^7')
        print('^1[hd_inventory] DATABASE NOT INSTALLED.^7')
        print('^1[hd_inventory] Import sql/hd_inventory_install.sql before using the inventory.^7')
        print('^1[hd_inventory] ============================================================^7')
    else
        print('^2[hd_inventory]^7 Database verified. Ready.')
    end
end)

function GetItemDef(name)
    return ItemDefs[name]
end
