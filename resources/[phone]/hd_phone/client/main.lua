-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | CLIENT
--  Opens/closes the phone, keeps a live number, and is the single
--  NUI bridge every app's callbacks route through. Per-app server
--  logic lives in server/*.lua; this file is intentionally thin.
-- ═══════════════════════════════════════════════════════════════════

local Framework = nil
CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
    TriggerServerEvent('hd_phone:server:ready')
end)

local phoneOpen = false
local myNumber = nil

local function HasPhone()
    if not Config.RequireItem then return true end
    if GetResourceState('hd_inventory') ~= 'started' then return true end -- degrade gracefully if the inventory isn't installed
    return exports['hd_inventory']:HasItem(Config.Item, 1)
end

-- Standard, widely-used GTA phone-in-hand anim. Bounded wait (not an
-- unconditional loop) so an unexpected missing dict on some game build
-- can't hang the resource — it just skips the animation that once.
local function PlayPhoneAnim()
    local ped = PlayerPedId()
    RequestAnimDict('cellphone@')
    local waited = 0
    while not HasAnimDictLoaded('cellphone@') and waited < 2000 do Wait(50) waited = waited + 50 end
    if not HasAnimDictLoaded('cellphone@') then return end
    TaskPlayAnim(ped, 'cellphone@', 'cellphone_call_listen_base', 3.0, 3.0, -1, 49, 0, false, false, false)
end

local function StopPhoneAnim()
    StopAnimTask(PlayerPedId(), 'cellphone@', 'cellphone_call_listen_base', 1.0)
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
    PlayPhoneAnim()
end

local function ClosePhone()
    phoneOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    StopPhoneAnim()
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

-- ═══════════════════════════ FACETIME ═════════════════════════════════
RegisterNUICallback('facetimeStart', function(data, cb)
    TriggerServerEvent('hd_phone:server:facetimeStart', data.number)
    cb({})
end)
RegisterNUICallback('facetimeAnswer', function(data, cb)
    TriggerServerEvent('hd_phone:server:facetimeAnswer', data.id)
    cb({})
end)
RegisterNUICallback('facetimeDecline', function(data, cb)
    TriggerServerEvent('hd_phone:server:facetimeDecline', data.id)
    cb({})
end)
RegisterNUICallback('facetimeEnd', function(data, cb)
    TriggerServerEvent('hd_phone:server:facetimeEnd', data.id)
    cb({})
end)
RegisterNUICallback('facetimeSignal', function(data, cb)
    TriggerServerEvent('hd_phone:server:facetimeSignal', data)
    cb({})
end)
RegisterNetEvent('hd_phone:client:facetimeRinging', function(id, toNumber)
    SendNUIMessage({ action = 'facetimeRinging', id = id, toNumber = toNumber })
end)
RegisterNetEvent('hd_phone:client:facetimeIncoming', function(id, fromNumber, fromName)
    if not phoneOpen then OpenPhone() end
    SendNUIMessage({ action = 'facetimeIncoming', id = id, fromNumber = fromNumber, fromName = fromName })
end)
RegisterNetEvent('hd_phone:client:facetimeAnswered', function(id, isOfferer)
    SendNUIMessage({ action = 'facetimeAnswered', id = id, isOfferer = isOfferer })
end)
RegisterNetEvent('hd_phone:client:facetimeEnded', function(id, reason)
    SendNUIMessage({ action = 'facetimeEnded', id = id, reason = reason })
end)
RegisterNetEvent('hd_phone:client:facetimeFailed', function(reason)
    SendNUIMessage({ action = 'facetimeFailed', reason = reason })
end)
RegisterNetEvent('hd_phone:client:facetimeSignal', function(id, signal)
    SendNUIMessage({ action = 'facetimeSignal', id = id, signal = signal })
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

-- ═══════════════════════════ BANK ═════════════════════════════════════
RegisterNUICallback('getBankAccount', function(_, cb)
    TriggerServerEvent('hd_phone:server:getBankAccount')
    cb({})
end)
RegisterNUICallback('getBankLog', function(_, cb)
    TriggerServerEvent('hd_phone:server:getBankLog')
    cb({})
end)
RegisterNUICallback('bankDeposit', function(data, cb)
    TriggerServerEvent('hd_phone:server:bankDeposit', data.amount)
    cb({})
end)
RegisterNUICallback('bankWithdraw', function(data, cb)
    TriggerServerEvent('hd_phone:server:bankWithdraw', data.amount)
    cb({})
end)
RegisterNUICallback('bankTransfer', function(data, cb)
    TriggerServerEvent('hd_phone:server:bankTransfer', data)
    cb({})
end)
RegisterNetEvent('hd_phone:client:bankAccount', function(account)
    SendNUIMessage({ action = 'bankAccount', account = account })
end)
RegisterNetEvent('hd_phone:client:bankLog', function(rows)
    SendNUIMessage({ action = 'bankLog', rows = rows })
end)

-- ═══════════════════════════ MAIL ═════════════════════════════════════
RegisterNUICallback('getMail', function(_, cb)
    TriggerServerEvent('hd_phone:server:getMail')
    cb({})
end)
RegisterNUICallback('readMail', function(data, cb)
    TriggerServerEvent('hd_phone:server:readMail', data.id)
    cb({})
end)
RegisterNUICallback('deleteMail', function(data, cb)
    TriggerServerEvent('hd_phone:server:deleteMail', data.id)
    cb({})
end)
RegisterNetEvent('hd_phone:client:mail', function(rows)
    SendNUIMessage({ action = 'mail', rows = rows })
end)
RegisterNetEvent('hd_phone:client:mailDeleted', function(id)
    SendNUIMessage({ action = 'mailDeleted', id = id })
end)
RegisterNetEvent('hd_phone:client:newMail', function()
    SendNUIMessage({ action = 'newMail' })
    if phoneOpen then SendNUIMessage({ action = 'alertSound' }) end
end)

-- ═══════════════════════════ MARKETPLACE ══════════════════════════════
RegisterNUICallback('getMarketplace', function(_, cb)
    TriggerServerEvent('hd_phone:server:getMarketplace')
    cb({})
end)
RegisterNUICallback('createListing', function(data, cb)
    TriggerServerEvent('hd_phone:server:createListing', data)
    cb({})
end)
RegisterNUICallback('deleteListing', function(data, cb)
    TriggerServerEvent('hd_phone:server:deleteListing', data.id)
    cb({})
end)
RegisterNetEvent('hd_phone:client:marketplace', function(rows)
    SendNUIMessage({ action = 'marketplace', rows = rows })
end)
RegisterNetEvent('hd_phone:client:listingCreated', function(listing)
    SendNUIMessage({ action = 'listingCreated', listing = listing })
end)
RegisterNetEvent('hd_phone:client:listingDeleted', function(id)
    SendNUIMessage({ action = 'listingDeleted', id = id })
end)

-- ═══════════════════════════ NOTES ════════════════════════════════════
RegisterNUICallback('getNotes', function(_, cb)
    TriggerServerEvent('hd_phone:server:getNotes')
    cb({})
end)
RegisterNUICallback('saveNote', function(data, cb)
    TriggerServerEvent('hd_phone:server:saveNote', data)
    cb({})
end)
RegisterNUICallback('deleteNote', function(data, cb)
    TriggerServerEvent('hd_phone:server:deleteNote', data.id)
    cb({})
end)
RegisterNetEvent('hd_phone:client:notes', function(rows)
    SendNUIMessage({ action = 'notes', rows = rows })
end)
RegisterNetEvent('hd_phone:client:noteSaved', function(note)
    SendNUIMessage({ action = 'noteSaved', note = note })
end)
RegisterNetEvent('hd_phone:client:noteDeleted', function(id)
    SendNUIMessage({ action = 'noteDeleted', id = id })
end)

-- ═══════════════════════════ CRYPTO ═══════════════════════════════════
RegisterNUICallback('getCrypto', function(_, cb)
    TriggerServerEvent('hd_phone:server:getCrypto')
    cb({})
end)
RegisterNUICallback('cryptoBuy', function(data, cb)
    TriggerServerEvent('hd_phone:server:cryptoBuy', data.amount)
    cb({})
end)
RegisterNUICallback('cryptoSell', function(data, cb)
    TriggerServerEvent('hd_phone:server:cryptoSell', data.amount)
    cb({})
end)
RegisterNetEvent('hd_phone:client:crypto', function(data)
    SendNUIMessage({ action = 'crypto', data = data })
end)

-- ═══════════════════════════ GALLERY ══════════════════════════════════
RegisterNUICallback('getGallery', function(_, cb)
    TriggerServerEvent('hd_phone:server:getGallery')
    cb({})
end)
RegisterNUICallback('saveToGallery', function(data, cb)
    TriggerServerEvent('hd_phone:server:saveToGallery', data)
    cb({})
end)
RegisterNUICallback('deleteGalleryItem', function(data, cb)
    TriggerServerEvent('hd_phone:server:deleteGalleryItem', data.id)
    cb({})
end)
RegisterNetEvent('hd_phone:client:gallery', function(rows)
    SendNUIMessage({ action = 'gallery', rows = rows })
end)
RegisterNetEvent('hd_phone:client:galleryItemAdded', function(item)
    SendNUIMessage({ action = 'galleryItemAdded', item = item })
end)
RegisterNetEvent('hd_phone:client:galleryItemDeleted', function(id)
    SendNUIMessage({ action = 'galleryItemDeleted', id = id })
end)

-- ═══════════════════════════ SETTINGS ═════════════════════════════════
RegisterNUICallback('getSettings', function(_, cb)
    TriggerServerEvent('hd_phone:server:getSettings')
    cb({})
end)
RegisterNUICallback('saveSettings', function(data, cb)
    TriggerServerEvent('hd_phone:server:saveSettings', data)
    cb({})
end)
RegisterNetEvent('hd_phone:client:settings', function(data)
    SendNUIMessage({ action = 'settings', data = data })
end)
RegisterNetEvent('hd_phone:client:settingsSaved', function(data)
    SendNUIMessage({ action = 'settingsSaved', wallpaper = data.wallpaper, customWallpaperUrl = data.customWallpaperUrl })
end)

-- ═══════════════════════════ APP STORE ════════════════════════════════
RegisterNUICallback('getInstalledApps', function(_, cb)
    TriggerServerEvent('hd_phone:server:getInstalledApps')
    cb({})
end)
RegisterNUICallback('installApp', function(data, cb)
    TriggerServerEvent('hd_phone:server:installApp', data)
    cb({})
end)
RegisterNUICallback('uninstallApp', function(data, cb)
    TriggerServerEvent('hd_phone:server:uninstallApp', data)
    cb({})
end)
RegisterNetEvent('hd_phone:client:installedApps', function(ids)
    SendNUIMessage({ action = 'installedApps', ids = ids })
end)

-- ═══════════════════════════ AIRDROP ══════════════════════════════════
RegisterNUICallback('airdropShare', function(_, cb)
    TriggerServerEvent('hd_phone:server:airdropShare')
    cb({})
end)
RegisterNetEvent('hd_phone:client:airdropIncoming', function(data)
    if not phoneOpen then OpenPhone() end
    SendNUIMessage({ action = 'airdropIncoming', data = data })
end)
