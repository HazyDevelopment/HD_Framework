-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | PHONE CALLS
--  Real two-way audio via pma-voice — exports['pma-voice']:setPlayerCall
--  puts both sides on the same voice call channel once answered.
-- ═══════════════════════════════════════════════════════════════════

local ActiveCalls = {} -- callId -> { caller = src, callee = src, callerNumber, calleeNumber, connected = bool }
local SourceCall = {}  -- src -> callId, so hangup/disconnect can find the right call

local function GetSourceByPhone(number)
    for _, srcStr in ipairs(GetPlayers()) do
        local candidate = tonumber(srcStr)
        local Player = GetPlayerOrNil(candidate)
        if Player and Player.PlayerData.charinfo.phone == number then return candidate end
    end
    return nil
end

local function LogCall(citizenid, name, number, direction)
    MySQL.insert('INSERT INTO hd_phone_call_log (citizenid, name, number, direction) VALUES (?, ?, ?, ?)', {
        citizenid, name, number, direction
    })
end

local function EndCall(callId, reason)
    local call = ActiveCalls[callId]
    if not call then return end
    ActiveCalls[callId] = nil
    SourceCall[call.caller] = nil
    if call.callee then SourceCall[call.callee] = nil end

    if GetResourceState('pma-voice') == 'started' then
        exports['pma-voice']:setPlayerCall(call.caller, 0)
        if call.callee then exports['pma-voice']:setPlayerCall(call.callee, 0) end
    end

    TriggerClientEvent('hd_phone:client:callEnded', call.caller, reason)
    if call.callee then TriggerClientEvent('hd_phone:client:callEnded', call.callee, reason) end
    if call.caller then TriggerClientEvent('hd_phone:client:stopRing', call.caller) end
    if call.callee then TriggerClientEvent('hd_phone:client:stopRing', call.callee) end
end

RegisterNetEvent('hd_phone:server:startCall', function(toNumber)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player or type(toNumber) ~= 'string' then return end
    if SourceCall[src] then return end -- already on a call

    local myNumber = Player.PlayerData.charinfo.phone
    local targetSrc = GetSourceByPhone(toNumber)
    if not targetSrc or SourceCall[targetSrc] then
        TriggerClientEvent('hd_phone:client:callEnded', src, 'unavailable')
        LogCall(Player.PlayerData.citizenid, nil, toNumber, 'missed')
        return
    end

    local callId = ('%s-%s-%s'):format(src, targetSrc, os.time())
    ActiveCalls[callId] = { caller = src, callee = targetSrc, callerNumber = myNumber, calleeNumber = toNumber }
    SourceCall[src] = callId
    SourceCall[targetSrc] = callId

    local callerName = ('%s %s'):format(Player.PlayerData.charinfo.firstname or '', Player.PlayerData.charinfo.lastname or '')
    local showNumber = myNumber
    local settings = GetOrCreateSettings(Player.PlayerData.citizenid)
    if settings.no_caller_id == 1 then
        callerName = 'Unknown'
        showNumber = nil
    end

    TriggerClientEvent('hd_phone:client:incomingCall', targetSrc, { callId = callId, name = callerName, number = showNumber })
    TriggerClientEvent('hd_phone:client:ring', targetSrc)
    TriggerClientEvent('hd_phone:client:callRinging', src, { callId = callId })
end)

RegisterNetEvent('hd_phone:server:answerCall', function(callId)
    local src = source
    local call = ActiveCalls[callId]
    if not call or call.callee ~= src then return end

    if GetResourceState('pma-voice') == 'started' then
        exports['pma-voice']:setPlayerCall(call.caller, callId)
        exports['pma-voice']:setPlayerCall(call.callee, callId)
    end

    TriggerClientEvent('hd_phone:client:stopRing', call.caller)
    TriggerClientEvent('hd_phone:client:stopRing', call.callee)
    TriggerClientEvent('hd_phone:client:callConnected', call.caller, callId)
    TriggerClientEvent('hd_phone:client:callConnected', call.callee, callId)

    local callerPlayer = GetPlayerOrNil(call.caller)
    local calleePlayer = GetPlayerOrNil(call.callee)
    if callerPlayer then LogCall(callerPlayer.PlayerData.citizenid, nil, call.calleeNumber, 'outgoing') end
    if calleePlayer then LogCall(calleePlayer.PlayerData.citizenid, nil, call.callerNumber, 'incoming') end
end)

RegisterNetEvent('hd_phone:server:declineCall', function(callId)
    local call = ActiveCalls[callId]
    if not call then return end
    local callerPlayer = GetPlayerOrNil(call.caller)
    if callerPlayer then LogCall(callerPlayer.PlayerData.citizenid, nil, call.calleeNumber, 'missed') end
    EndCall(callId, 'declined')
end)

RegisterNetEvent('hd_phone:server:endCall', function(callId)
    EndCall(callId, 'ended')
end)

AddEventHandler('playerDropped', function()
    local src = source
    local callId = SourceCall[src]
    if callId then EndCall(callId, 'disconnected') end
end)
