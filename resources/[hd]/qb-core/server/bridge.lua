-- ═══════════════════════════════════════════════════════════════════
--  QB-CORE COMPATIBILITY BRIDGE (server)
--  This resource is deliberately named 'qb-core' so
--  exports['qb-core']:GetCoreObject() and GetResourceState('qb-core')
--  resolve exactly the way every QBCore-ecosystem resource expects.
--  It holds no player data itself — every call forwards straight to
--  HD_Framework, which is the real core.
-- ═══════════════════════════════════════════════════════════════════

exports('GetCoreObject', function()
    return exports['HD_Framework']:GetCoreObject()
end)

-- Mirror the canonical QBCore server event names so off-the-shelf
-- QBCore resources that hook these directly (instead of going through
-- GetCoreObject) still work without modification.
AddEventHandler('HD:Server:PlayerLoaded', function(Player)
    TriggerEvent('QBCore:Server:PlayerLoaded', Player)
end)

AddEventHandler('HD:Server:PlayerDropped', function(Player)
    TriggerEvent('QBCore:Server:PlayerDropped', Player)
end)

AddEventHandler('HD:Server:OnJobUpdate', function(src, job)
    TriggerEvent('QBCore:Server:OnJobUpdate', src, job)
end)

AddEventHandler('HD:Server:OnMoneyChange', function(src, account, action, amount, reason)
    TriggerEvent('QBCore:Server:OnMoneyChange', src, account, action, amount, reason)
end)
