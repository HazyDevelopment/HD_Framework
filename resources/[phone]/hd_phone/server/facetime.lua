-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | FACETIME
--  Ring/answer/decline/hangup mirrors server/calls.lua exactly, but
--  this app carries real camera+mic over WebRTC instead of pma-voice —
--  this file is purely a signaling relay (SDP offer/answer + ICE
--  candidates) between the two clients' own RTCPeerConnections. The
--  actual media never touches the server.
-- ═══════════════════════════════════════════════════════════════════

local ActiveFacetimes = {}
local nextFacetimeId = 1

local function EndFacetimeInternal(id, reason)
    local call = ActiveFacetimes[id]
    if not call then return end
    ActiveFacetimes[id] = nil
    TriggerClientEvent('hd_phone:client:facetimeEnded', call.callerSrc, id, reason)
    if call.targetSrc then
        TriggerClientEvent('hd_phone:client:facetimeEnded', call.targetSrc, id, reason)
    end
end

RegisterNetEvent('hd_phone:server:facetimeStart', function(toNumber)
    local src = source
    local myNumber = GetPhoneNumber(src)
    if not myNumber or type(toNumber) ~= 'string' or toNumber == myNumber then return end

    local targetSrc = GetSourceByPhone(toNumber)
    if not targetSrc then
        TriggerClientEvent('hd_phone:client:facetimeFailed', src, 'Number unreachable.')
        return
    end

    local id = nextFacetimeId
    nextFacetimeId = nextFacetimeId + 1
    ActiveFacetimes[id] = { id = id, callerSrc = src, targetSrc = targetSrc, status = 'ringing' }

    local displayNumber = HasNoCallerId(src) and 'Unknown' or myNumber
    TriggerClientEvent('hd_phone:client:facetimeRinging', src, id, toNumber)
    TriggerClientEvent('hd_phone:client:facetimeIncoming', targetSrc, id, displayNumber, GetDisplayName(src))

    CreateThread(function()
        Wait(Config.Calls.RingTimeoutSeconds * 1000)
        local call = ActiveFacetimes[id]
        if call and call.status == 'ringing' then
            EndFacetimeInternal(id, 'no-answer')
        end
    end)
end)

RegisterNetEvent('hd_phone:server:facetimeAnswer', function(id)
    local src = source
    local call = ActiveFacetimes[id]
    if not call or call.targetSrc ~= src or call.status ~= 'ringing' then return end

    call.status = 'active'
    TriggerClientEvent('hd_phone:client:facetimeAnswered', call.callerSrc, id, true)  -- true = you're the offerer
    TriggerClientEvent('hd_phone:client:facetimeAnswered', call.targetSrc, id, false)
end)

RegisterNetEvent('hd_phone:server:facetimeDecline', function(id)
    local src = source
    local call = ActiveFacetimes[id]
    if not call or (src ~= call.callerSrc and src ~= call.targetSrc) then return end
    EndFacetimeInternal(id, 'declined')
end)

RegisterNetEvent('hd_phone:server:facetimeEnd', function(id)
    local src = source
    local call = ActiveFacetimes[id]
    if not call or (src ~= call.callerSrc and src ~= call.targetSrc) then return end
    EndFacetimeInternal(id, 'ended')
end)

-- Relay only — sender must be a party to that exact call id, and the
-- payload is forwarded untouched to whichever side didn't send it.
RegisterNetEvent('hd_phone:server:facetimeSignal', function(data)
    local src = source
    if type(data) ~= 'table' or not data.id or data.signal == nil then return end
    local call = ActiveFacetimes[data.id]
    if not call then return end

    if src == call.callerSrc then
        TriggerClientEvent('hd_phone:client:facetimeSignal', call.targetSrc, data.id, data.signal)
    elseif src == call.targetSrc then
        TriggerClientEvent('hd_phone:client:facetimeSignal', call.callerSrc, data.id, data.signal)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for id, call in pairs(ActiveFacetimes) do
        if call.callerSrc == src or call.targetSrc == src then
            EndFacetimeInternal(id, 'disconnected')
        end
    end
end)
