-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | FACETIME
--  Real two-way video/audio, peer-to-peer over WebRTC — this file is a
--  pure signalling relay (SDP offer/answer + ICE candidates) between
--  the two players' own RTCPeerConnections; media itself never
--  touches the server. Uses a public STUN server for NAT traversal —
--  there's no TURN fallback, so two very restrictive NATs could fail
--  to connect even though the ring/answer handshake succeeds.
-- ═══════════════════════════════════════════════════════════════════

local ActiveFacetimes = {} -- callId -> { caller, callee }
local SourceFacetime = {}

local function GetSourceByPhone(number)
    for _, srcStr in ipairs(GetPlayers()) do
        local candidate = tonumber(srcStr)
        local Player = GetPlayerOrNil(candidate)
        if Player and Player.PlayerData.charinfo.phone == number then return candidate end
    end
    return nil
end

local function EndFacetime(callId, reason)
    local call = ActiveFacetimes[callId]
    if not call then return end
    ActiveFacetimes[callId] = nil
    SourceFacetime[call.caller] = nil
    if call.callee then SourceFacetime[call.callee] = nil end
    TriggerClientEvent('hd_phone:client:facetimeEnded', call.caller, reason)
    if call.callee then TriggerClientEvent('hd_phone:client:facetimeEnded', call.callee, reason) end
end

RegisterNetEvent('hd_phone:server:startFacetime', function(toNumber)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player or type(toNumber) ~= 'string' then return end
    if SourceFacetime[src] then return end

    local targetSrc = GetSourceByPhone(toNumber)
    if not targetSrc or SourceFacetime[targetSrc] then
        TriggerClientEvent('hd_phone:client:facetimeEnded', src, 'unavailable')
        return
    end

    local callId = ('ft-%s-%s-%s'):format(src, targetSrc, os.time())
    ActiveFacetimes[callId] = { caller = src, callee = targetSrc }
    SourceFacetime[src] = callId
    SourceFacetime[targetSrc] = callId

    local callerName = ('%s %s'):format(Player.PlayerData.charinfo.firstname or '', Player.PlayerData.charinfo.lastname or '')
    TriggerClientEvent('hd_phone:client:incomingFacetime', targetSrc, { callId = callId, name = callerName, number = Player.PlayerData.charinfo.phone })
    TriggerClientEvent('hd_phone:client:ring', targetSrc)
    TriggerClientEvent('hd_phone:client:facetimeRinging', src, { callId = callId })
end)

RegisterNetEvent('hd_phone:server:acceptFacetime', function(callId)
    local src = source
    local call = ActiveFacetimes[callId]
    if not call or call.callee ~= src then return end
    TriggerClientEvent('hd_phone:client:stopRing', call.caller)
    TriggerClientEvent('hd_phone:client:stopRing', call.callee)
    -- Caller creates the offer once it knows the callee is ready.
    TriggerClientEvent('hd_phone:client:facetimeAccepted', call.caller, callId)
    TriggerClientEvent('hd_phone:client:facetimeAccepted', call.callee, callId)
end)

RegisterNetEvent('hd_phone:server:declineFacetime', function(callId)
    EndFacetime(callId, 'declined')
end)

RegisterNetEvent('hd_phone:server:endFacetime', function(callId)
    EndFacetime(callId, 'ended')
end)

-- ═══════════════════════════ SIGNALLING RELAY ════════════════════════
local function OtherParty(callId, src)
    local call = ActiveFacetimes[callId]
    if not call then return nil end
    return call.caller == src and call.callee or call.caller
end

RegisterNetEvent('hd_phone:server:facetimeSignal', function(callId, kind, payload)
    local src = source
    local other = OtherParty(callId, src)
    if not other then return end
    TriggerClientEvent('hd_phone:client:facetimeSignal', other, kind, payload)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local callId = SourceFacetime[src]
    if callId then EndFacetime(callId, 'disconnected') end
end)
