-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | CLIENT
--  Opens/closes the phone, keeps a live number, and is the single
--  NUI bridge every app's callbacks route through. Per-app server
--  logic lives in server/*.lua; this file is intentionally thin.
-- ═══════════════════════════════════════════════════════════════════

local Framework = nil
CreateThread(function()
    while GetResourceState('qb-core') ~= 'started' do Wait(100) end
    Framework = exports['qb-core']:GetCoreObject()
    TriggerServerEvent('hd_phone:server:ready')
end)

local phoneOpen = false
local myNumber = nil

local function HasPhone()
    if not Config.RequireItem then return true end
    if GetResourceState('hd_inventory') ~= 'started' then return true end -- degrade gracefully if the inventory isn't installed
    return exports['hd_inventory']:HasItem(Config.Item, 1)
end

local function OpenPhone()
    if phoneOpen then return end
    if not HasPhone() then
        Config.Notify("You don't have a phone on you.", 'error')
        return
    end
    local garageList = {}
    for _, g in ipairs(Config.Garages) do
        garageList[#garageList + 1] = { key = g.key, label = g.label }
    end

    phoneOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', number = myNumber, garages = garageList, socialApps = Config.SocialApps })
end

local function ClosePhone()
    phoneOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterKeyMapping('hd_phone_toggle', 'HD Phone: open/close', 'keyboard', Config.Keybind)
RegisterCommand('hd_phone_toggle', function()
    if phoneOpen then ClosePhone() else OpenPhone() end
end, false)

RegisterNetEvent('hd_phone:client:setNumber', function(number)
    myNumber = number
end)

-- ═══════════════════════════ GENERIC NUI CALLBACKS ═══════════════════
RegisterNUICallback('close', function(_, cb)
    ClosePhone()
    cb({})
end)

-- ═══════════════════════════ CONTACTS ═════════════════════════════════
RegisterNUICallback('getContacts', function(_, cb)
    TriggerServerEvent('hd_phone:server:getContacts')
    cb({})
end)
RegisterNUICallback('saveContact', function(data, cb)
    TriggerServerEvent('hd_phone:server:saveContact', data)
    cb({})
end)
RegisterNUICallback('deleteContact', function(data, cb)
    TriggerServerEvent('hd_phone:server:deleteContact', data.id)
    cb({})
end)
RegisterNetEvent('hd_phone:client:contacts', function(rows)
    SendNUIMessage({ action = 'contacts', rows = rows })
end)

-- ═══════════════════════════ MESSAGES ═════════════════════════════════
RegisterNUICallback('getThreads', function(_, cb)
    TriggerServerEvent('hd_phone:server:getThreads')
    cb({})
end)
RegisterNUICallback('getConversation', function(data, cb)
    TriggerServerEvent('hd_phone:server:getConversation', data.number)
    cb({})
end)
RegisterNUICallback('sendMessage', function(data, cb)
    TriggerServerEvent('hd_phone:server:sendMessage', data)
    cb({})
end)
RegisterNetEvent('hd_phone:client:threads', function(rows)
    SendNUIMessage({ action = 'threads', rows = rows })
end)
RegisterNetEvent('hd_phone:client:conversation', function(number, rows)
    SendNUIMessage({ action = 'conversation', number = number, rows = rows })
end)
RegisterNetEvent('hd_phone:client:newMessage', function(msg)
    SendNUIMessage({ action = 'newMessage', msg = msg })
    if phoneOpen then SendNUIMessage({ action = 'alertSound' }) end
end)

-- ═══════════════════════════ CALLS ════════════════════════════════════
RegisterNUICallback('startCall', function(data, cb)
    TriggerServerEvent('hd_phone:server:startCall', data.number)
    cb({})
end)
RegisterNUICallback('answerCall', function(data, cb)
    TriggerServerEvent('hd_phone:server:answerCall', data.id)
    cb({})
end)
RegisterNUICallback('declineCall', function(data, cb)
    TriggerServerEvent('hd_phone:server:declineCall', data.id)
    cb({})
end)
RegisterNUICallback('endCall', function(data, cb)
    TriggerServerEvent('hd_phone:server:endCall', data.id)
    cb({})
end)
RegisterNetEvent('hd_phone:client:callRinging', function(id, toNumber)
    SendNUIMessage({ action = 'callRinging', id = id, toNumber = toNumber })
end)
RegisterNetEvent('hd_phone:client:incomingCall', function(id, fromNumber, fromName)
    if not phoneOpen then OpenPhone() end
    SendNUIMessage({ action = 'incomingCall', id = id, fromNumber = fromNumber, fromName = fromName })
    SendNUIMessage({ action = 'alertSound' })
end)
RegisterNetEvent('hd_phone:client:callAnswered', function(id)
    SendNUIMessage({ action = 'callAnswered', id = id })
end)
RegisterNetEvent('hd_phone:client:callEnded', function(id, reason)
    SendNUIMessage({ action = 'callEnded', id = id, reason = reason })
end)
RegisterNetEvent('hd_phone:client:callFailed', function(reason)
    SendNUIMessage({ action = 'callFailed', reason = reason })
end)

-- ═══════════════════════════ SOCIAL (Wire/Picta/Loopz) ════════════════
RegisterNUICallback('getFeed', function(data, cb)
    TriggerServerEvent('hd_phone:server:getFeed', data.app)
    cb({})
end)
RegisterNUICallback('createPost', function(data, cb)
    TriggerServerEvent('hd_phone:server:createPost', data)
    cb({})
end)
RegisterNUICallback('likePost', function(data, cb)
    TriggerServerEvent('hd_phone:server:likePost', data.id)
    cb({})
end)
RegisterNUICallback('deletePost', function(data, cb)
    TriggerServerEvent('hd_phone:server:deletePost', data.id)
    cb({})
end)
RegisterNetEvent('hd_phone:client:feed', function(app, posts)
    SendNUIMessage({ action = 'feed', app = app, posts = posts })
end)
RegisterNetEvent('hd_phone:client:postCreated', function(post)
    SendNUIMessage({ action = 'postCreated', post = post })
end)
RegisterNetEvent('hd_phone:client:postLikeUpdated', function(id, likeCount, liked)
    SendNUIMessage({ action = 'postLikeUpdated', id = id, likeCount = likeCount, liked = liked })
end)
RegisterNetEvent('hd_phone:client:postDeleted', function(id)
    SendNUIMessage({ action = 'postDeleted', id = id })
end)

-- ═══════════════════════════ GARAGES ══════════════════════════════════
RegisterNUICallback('getVehicles', function(_, cb)
    TriggerServerEvent('hd_phone:server:getVehicles')
    cb({})
end)
RegisterNetEvent('hd_phone:client:vehicles', function(rows)
    SendNUIMessage({ action = 'vehicles', rows = rows })
end)
