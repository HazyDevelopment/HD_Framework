-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | CLIENT
--  Pure shell: open/close, the phone-item gate, native-only actions
--  (waypoints, screenshots, street names), and a thin relay between
--  server events <-> NUI messages / NUI callbacks <-> server events.
--  No app logic lives here — that's server/*.lua + html/js/apps/*.js.
-- ═══════════════════════════════════════════════════════════════════

Framework = nil
CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

local phoneOpen = false

local function HasPhoneItem()
    if not Config.RequireItem then return true end
    if GetResourceState('hd_inventory') ~= 'started' then return true end
    for _, item in ipairs(Config.PhoneItems) do
        if exports['hd_inventory']:HasItem(item, 1) then return true end
    end
    return false
end

local function OpenPhone()
    if phoneOpen then return end
    if not HasPhoneItem() then
        TriggerEvent('HD:Client:Notify', "You don't have a phone on you.", 'error')
        return
    end
    phoneOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
    TriggerServerEvent('hd_phone:server:sync')
end

function ClosePhone()
    if not phoneOpen then return end
    phoneOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterCommand(Config.OpenKey, function()
    if phoneOpen then ClosePhone() else OpenPhone() end
end, false)
RegisterKeyMapping(Config.OpenKey, 'Open HD Phone', 'keyboard', Config.OpenKey)

RegisterNetEvent('hd_phone:client:open', function()
    OpenPhone()
end)

RegisterNUICallback('close', function(_, cb)
    ClosePhone()
    cb({})
end)

-- ═══════════════════════════ GENERIC RELAYS ══════════════════════════
-- server -> NUI: just forward the payload under a matching action name.
local function Relay(action)
    RegisterNetEvent('hd_phone:client:' .. action, function(...)
        SendNUIMessage({ action = action, args = { ... } })
    end)
end

for _, action in ipairs({
    'sync', 'onboarded', 'passcodeResult',
    'contacts', 'threads', 'conversation', 'newMessage',
    'incomingCall', 'callRinging', 'callConnected', 'callEnded',
    'photos', 'appInstalled', 'appRemoved',
    'feed', 'postCreated', 'likeUpdated', 'wireAccount',
    'bank', 'mail', 'listings', 'listingCreated',
    'notes', 'cryptoPrice', 'crypto',
    'myProfile', 'swipeQueue', 'newMatch',
    'myAlias', 'darkThreads', 'darkConversation', 'newDarkMessage',
    'voiceMemos', 'voiceMemoAudio',
    'vehicles', 'vehicleStored',
    'playlist',
}) do
    Relay(action)
end

-- NUI -> server: forward straight through, no extra logic needed.
local function Forward(callbackName, eventName, argOrder)
    RegisterNUICallback(callbackName, function(data, cb)
        if argOrder then
            local args = {}
            for i, key in ipairs(argOrder) do args[i] = data and data[key] end
            TriggerServerEvent(eventName, table.unpack(args))
        else
            TriggerServerEvent(eventName, data)
        end
        cb({})
    end)
end

-- Every callback below lists its argOrder explicitly — the server
-- handlers take positional args, not "here's a table", so leaving
-- argOrder off would hand them a whole data object where a single
-- string/number was expected. Only genuinely table-shaped payloads
-- (createAccount, sendMessage, createListing, sendDarkMessage) forward
-- `data` as-is.
Forward('setAppearance', 'hd_phone:server:setAppearance', { 'darkMode', 'dynamicMode' })
Forward('setPasscode', 'hd_phone:server:setPasscode', { 'passcode' })
Forward('verifyPasscode', 'hd_phone:server:verifyPasscode', { 'passcode' })
Forward('createAccount', 'hd_phone:server:createAccount')
Forward('skipOnboarding', 'hd_phone:server:skipOnboarding')
Forward('setWallpaper', 'hd_phone:server:setWallpaper', { 'wallpaperId', 'customUrl' })
Forward('setNoCallerId', 'hd_phone:server:setNoCallerId', { 'enabled' })
Forward('setReceiveDrop', 'hd_phone:server:setReceiveDrop', { 'enabled' })
Forward('setHomeOrder', 'hd_phone:server:setHomeOrder')

Forward('getContacts', 'hd_phone:server:getContacts')
Forward('saveContact', 'hd_phone:server:saveContact', { 'name', 'number' })
Forward('deleteContact', 'hd_phone:server:deleteContact', { 'id' })

Forward('getThreads', 'hd_phone:server:getThreads')
Forward('getConversation', 'hd_phone:server:getConversation', { 'withNumber' })
Forward('sendMessage', 'hd_phone:server:sendMessage')

Forward('startCall', 'hd_phone:server:startCall', { 'to' })
Forward('answerCall', 'hd_phone:server:answerCall', { 'callId' })
Forward('declineCall', 'hd_phone:server:declineCall', { 'callId' })
Forward('endCall', 'hd_phone:server:endCall', { 'callId' })

Forward('getPhotos', 'hd_phone:server:getPhotos')
Forward('saveFromCamera', 'hd_phone:server:saveFromCamera', { 'imageUrl' })

Forward('installApp', 'hd_phone:server:installApp', { 'appId' })
Forward('removeApp', 'hd_phone:server:removeApp', { 'appId' })

Forward('getFeed', 'hd_phone:server:getFeed', { 'app' })
Forward('createPost', 'hd_phone:server:createPost', { 'app', 'content', 'imageUrl' })
Forward('toggleLike', 'hd_phone:server:toggleLike', { 'postId' })
Forward('deletePost', 'hd_phone:server:deletePost', { 'postId' })

Forward('getWireAccount', 'hd_phone:server:getWireAccount')
Forward('createWireAccount', 'hd_phone:server:createWireAccount')

Forward('getBank', 'hd_phone:server:getBank')
Forward('bankDeposit', 'hd_phone:server:bankDeposit', { 'amount' })
Forward('bankWithdraw', 'hd_phone:server:bankWithdraw', { 'amount' })
Forward('bankTransfer', 'hd_phone:server:bankTransfer', { 'to', 'amount' })

Forward('getMail', 'hd_phone:server:getMail')
Forward('readMail', 'hd_phone:server:readMail', { 'id' })
Forward('deleteMail', 'hd_phone:server:deleteMail', { 'id' })

Forward('getListings', 'hd_phone:server:getListings')
Forward('createListing', 'hd_phone:server:createListing')
Forward('deleteListing', 'hd_phone:server:deleteListing', { 'id' })

Forward('getNotes', 'hd_phone:server:getNotes')
Forward('saveNote', 'hd_phone:server:saveNote', { 'id', 'content' })
Forward('deleteNote', 'hd_phone:server:deleteNote', { 'id' })

Forward('getCrypto', 'hd_phone:server:getCrypto')
Forward('cryptoBuy', 'hd_phone:server:cryptoBuy', { 'amount' })
Forward('cryptoSell', 'hd_phone:server:cryptoSell', { 'amount' })

Forward('getMyProfile', 'hd_phone:server:getMyProfile')
Forward('saveProfile', 'hd_phone:server:saveProfile', { 'bio', 'photoUrl', 'active' })
Forward('getSwipeQueue', 'hd_phone:server:getSwipeQueue')
Forward('swipe', 'hd_phone:server:swipe', { 'targetCitizenId', 'liked' })

Forward('getMyAlias', 'hd_phone:server:getMyAlias')
Forward('getDarkThreads', 'hd_phone:server:getDarkThreads')
Forward('getDarkConversation', 'hd_phone:server:getDarkConversation', { 'withAlias' })
Forward('sendDarkMessage', 'hd_phone:server:sendDarkMessage')

Forward('getVoiceMemos', 'hd_phone:server:getVoiceMemos')
Forward('saveVoiceMemo', 'hd_phone:server:saveVoiceMemo', { 'audioData', 'duration' })
Forward('deleteVoiceMemo', 'hd_phone:server:deleteVoiceMemo', { 'id' })
Forward('getVoiceMemoAudio', 'hd_phone:server:getVoiceMemoAudio', { 'id' })

Forward('getVehicles', 'hd_phone:server:getVehicles')

Forward('getPlaylist', 'hd_phone:server:getPlaylist')
Forward('addTrack', 'hd_phone:server:addTrack', { 'videoId', 'title' })
Forward('removeTrack', 'hd_phone:server:removeTrack', { 'id' })

Forward('startFacetime', 'hd_phone:server:startFacetime', { 'to' })
Forward('acceptFacetime', 'hd_phone:server:acceptFacetime', { 'callId' })
Forward('declineFacetime', 'hd_phone:server:declineFacetime', { 'callId' })
Forward('endFacetime', 'hd_phone:server:endFacetime', { 'callId' })
Forward('facetimeSignal', 'hd_phone:server:facetimeSignal', { 'callId', 'kind', 'payload' })

for _, action in ipairs({ 'incomingFacetime', 'facetimeRinging', 'facetimeAccepted', 'facetimeEnded', 'facetimeSignal' }) do
    Relay(action)
end

-- ═══════════════════════════ NATIVE-ONLY ACTIONS ═════════════════════
RegisterNUICallback('setWaypoint', function(data, cb)
    if data and data.x and data.y then SetNewWaypoint(data.x + 0.0, data.y + 0.0) end
    cb({})
end)

-- Config is a shared_script, already loaded client-side — no server
-- round trip needed for a static pin list.
RegisterNUICallback('getMapPins', function(_, cb)
    local pins = {}
    for _, pin in ipairs(Config.Maps.Pins) do
        pins[#pins + 1] = { label = pin.label, category = pin.category, x = pin.coords.x, y = pin.coords.y, z = pin.coords.z }
    end
    cb({ pins = pins })
end)

RegisterNUICallback('getStreetName', function(_, cb)
    local coords = GetEntityCoords(PlayerPedId())
    local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local name = GetStreetNameFromHashKey(street1)
    if street2 and street2 ~= 0 then name = name .. ' & ' .. GetStreetNameFromHashKey(street2) end
    cb({ name = name })
end)

-- screenshot-basic (vendored at resources/[screenshot]/screenshot-basic)
-- rasterises the frame — still degrades to a clear error rather than
-- faking a photo if it's ever removed or fails to start.
RegisterNUICallback('takePhoto', function(_, cb)
    if GetResourceState('screenshot-basic') ~= 'started' then
        cb({ ok = false, reason = 'screenshot-basic is not installed on this server.' })
        return
    end
    exports['screenshot-basic']:requestScreenshotUpload(Config.Camera.WebhookUrl or '', 'files[]', function(data)
        local resp = json.decode(data)
        if resp and resp.url then cb({ ok = true, url = resp.url }) else cb({ ok = false, reason = 'Upload failed.' }) end
    end)
end)

RegisterNUICallback('sendAirdrop', function(_, cb)
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('hd_phone:server:sendAirdrop', coords.x, coords.y, coords.z)
    cb({})
end)

RegisterNetEvent('hd_phone:client:airdropOffer', function(fromName, fromNumber)
    SendNUIMessage({ action = 'airdropOffer', name = fromName, number = fromNumber })
end)

RegisterNUICallback('airdropRespond', function(data, cb)
    TriggerServerEvent('hd_phone:server:airdropRespond', data.accept)
    cb({})
end)

RegisterNetEvent('hd_phone:client:ring', function() SendNUIMessage({ action = 'ring' }) end)
RegisterNetEvent('hd_phone:client:stopRing', function() SendNUIMessage({ action = 'stopRing' }) end)
