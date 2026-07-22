-- ═══════════════════════════════════════════════════════════════════
--  HD SOCIETY | CLIENT
-- ═══════════════════════════════════════════════════════════════════

local menuOpen = false

RegisterCommand(Config.Command, function()
    if menuOpen then return end
    TriggerServerEvent('hd_society:server:open')
end, false)

RegisterNetEvent('hd_society:client:open', function(society, label, balance)
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', society = society, label = label, balance = balance })
end)

RegisterNetEvent('hd_society:client:balance', function(balance)
    SendNUIMessage({ action = 'balance', balance = balance })
end)

RegisterNUICallback('close', function(_, cb)
    menuOpen = false
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNUICallback('deposit', function(data, cb)
    TriggerServerEvent('hd_society:server:deposit', data.amount)
    cb({})
end)

RegisterNUICallback('withdraw', function(data, cb)
    TriggerServerEvent('hd_society:server:withdraw', data.amount)
    cb({})
end)
