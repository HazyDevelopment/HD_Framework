-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | CALLS
--  Ring / accept / decline / hang-up state machine, now linked to
--  pma-voice for real audio: each call's own numeric `id` doubles as
--  its pma-voice call channel (unique per call, no extra bookkeeping
--  needed) via the server-side exports['pma-voice']:setPlayerCall(src,
--  channel) export. If pma-voice isn't installed/running this
--  degrades to exactly what it was before — a realistic-feeling call
--  UI with no audio channel behind it — rather than erroring.
-- ═══════════════════════════════════════════════════════════════════

local ActiveCalls = {}
local nextCallId = 1

local function PmaVoiceReady()
    return GetResourceState('pma-voice') == 'started'
end

local function LinkCallVoice(id, callerSrc, targetSrc)
    if not PmaVoiceReady() then return end
    exports['pma-voice']:setPlayerCall(callerSrc, id)
    exports['pma-voice']:setPlayerCall(targetSrc, id)
end

local function UnlinkCallVoice(callerSrc, targetSrc)
    if not PmaVoiceReady() then return end
    exports['pma-voice']:setPlayerCall(callerSrc, 0)
    if targetSrc then exports['pma-voice']:setPlayerCall(targetSrc, 0) end
end

local function EndCallInternal(id, reason)
    local call = ActiveCalls[id]
    if not call then return end
    ActiveCalls[id] = nil
    UnlinkCallVoice(call.callerSrc, call.targetSrc)
    TriggerClientEvent('hd_phone:client:callEnded', call.callerSrc, id, reason)
    if call.targetSrc then
        TriggerClientEvent('hd_phone:client:callEnded', call.targetSrc, id, reason)
    end
end

RegisterNetEvent('hd_phone:server:startCall', function(toNumber)
    local src = source
    local myNumber = GetPhoneNumber(src)
    if not myNumber or type(toNumber) ~= 'string' or toNumber == myNumber then return end

    local targetSrc = GetSourceByPhone(toNumber)
    if not targetSrc then
        TriggerClientEvent('hd_phone:client:callFailed', src, 'Number unreachable.')
        return
    end

    local id = nextCallId
    nextCallId = nextCallId + 1
    ActiveCalls[id] = { id = id, callerSrc = src, callerNumber = myNumber, targetSrc = targetSrc, targetNumber = toNumber, status = 'ringing' }

    TriggerClientEvent('hd_phone:client:callRinging', src, id, toNumber)
    TriggerClientEvent('hd_phone:client:incomingCall', targetSrc, id, myNumber, GetDisplayName(src))

    CreateThread(function()
        Wait(Config.Calls.RingTimeoutSeconds * 1000)
        local call = ActiveCalls[id]
        if call and call.status == 'ringing' then
            EndCallInternal(id, 'no-answer')
        end
    end)
end)

RegisterNetEvent('hd_phone:server:answerCall', function(id)
    local src = source
    local call = ActiveCalls[id]
    if not call or call.targetSrc ~= src or call.status ~= 'ringing' then return end

    call.status = 'active'
    LinkCallVoice(id, call.callerSrc, call.targetSrc)

    TriggerClientEvent('hd_phone:client:callAnswered', call.callerSrc, id)
    TriggerClientEvent('hd_phone:client:callAnswered', call.targetSrc, id)
end)

RegisterNetEvent('hd_phone:server:declineCall', function(id)
    local src = source
    local call = ActiveCalls[id]
    if not call or (src ~= call.callerSrc and src ~= call.targetSrc) then return end
    EndCallInternal(id, 'declined')
end)

RegisterNetEvent('hd_phone:server:endCall', function(id)
    local src = source
    local call = ActiveCalls[id]
    if not call or (src ~= call.callerSrc and src ~= call.targetSrc) then return end
    EndCallInternal(id, 'ended')
end)

AddEventHandler('playerDropped', function()
    local src = source
    for id, call in pairs(ActiveCalls) do
        if call.callerSrc == src or call.targetSrc == src then
            EndCallInternal(id, 'disconnected')
        end
    end
end)
