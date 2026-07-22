-- ═══════════════════════════════════════════════════════════════════
--  HD_FRAMEWORK | CLIENT EVENTS
--  Placeholder notification renderer — native GTA notification for
--  now. The phone/UI build phase replaces this with a proper HUD
--  toast that matches the phone's styling; nothing else needs to
--  change since every resource just fires 'HD:Client:Notify'.
-- ═══════════════════════════════════════════════════════════════════

RegisterNetEvent('HD:Client:Notify', function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(('%s %s'):format(ntype == 'error' and '[!]' or ntype == 'success' and '[OK]' or '[i]', msg))
    DrawNotification(false, false)
end)
