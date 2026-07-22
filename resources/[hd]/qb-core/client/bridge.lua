-- ═══════════════════════════════════════════════════════════════════
--  QB-CORE COMPATIBILITY BRIDGE (client)
--  See server/bridge.lua for why this resource exists and is named
--  'qb-core'.
-- ═══════════════════════════════════════════════════════════════════

exports('GetCoreObject', function()
    return exports['HD_Framework']:GetCoreObject()
end)

-- Mirror the canonical QBCore client event names.
AddEventHandler('HD:Client:OnPlayerLoaded', function(playerData)
    TriggerEvent('QBCore:Client:OnPlayerLoaded', playerData)
end)

AddEventHandler('HD:Client:OnPlayerDataUpdate', function(playerData)
    TriggerEvent('QBCore:Client:OnPlayerDataUpdate', playerData)
end)

RegisterNetEvent('HD:Client:Notify', function(msg, ntype)
    TriggerEvent('QBCore:Notify', msg, ntype)
end)
