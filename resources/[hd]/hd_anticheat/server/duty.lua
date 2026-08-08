-- ═══════════════════════════════════════════════════════════════════
--  HD ANTICHEAT | ADMIN DUTY + ADMIN CHAT
--  OnDuty is a plain on/off flag an admin sets on themselves via
--  '/acduty' (or the NUI sidebar toggle) — it gates nothing about what
--  an admin CAN do (every real action still only checks IsExemptAdmin),
--  it only decides who the admin-chat channel is shown to and
--  broadcast to. A verified admin who's never toggled duty on is simply
--  not part of that channel, same as if they were an ordinary player.
-- ═══════════════════════════════════════════════════════════════════

OnDuty = {} -- [src] = true while on duty; absent (not false) means off — IsOnDuty below treats both the same

function IsOnDuty(src)
    return OnDuty[src] == true
end

function ToggleDuty(src)
    if not IsExemptAdmin(src) then return end
    if OnDuty[src] then
        OnDuty[src] = nil
    else
        OnDuty[src] = true
    end
    Notify(src, IsOnDuty(src) and 'You are now on AntiCheat duty.' or 'You are now off AntiCheat duty.', 'info')
    TriggerClientEvent('hd_anticheat:client:dutyState', src, IsOnDuty(src))
end

RegisterCommand(Config.DutyCommand, function(src)
    if src == 0 then return end
    ToggleDuty(src)
end, false)

RegisterNetEvent('hd_anticheat:server:toggleDuty', function()
    ToggleDuty(source)
end)

RegisterNetEvent('hd_anticheat:server:getDutyState', function()
    TriggerClientEvent('hd_anticheat:client:dutyState', source, IsOnDuty(source))
end)

AddEventHandler('playerDropped', function()
    OnDuty[source] = nil
end)

-- ═══════════════════════════ ADMIN CHAT ═════════════════════════════════
-- Ephemeral on purpose — this is a live coordination channel for
-- whoever's on duty right now, not an audit log (hd_anticheat_flags and
-- hd_anticheat_reports already cover the things worth keeping forever).
local RecentChat = {}
local CHAT_LOG_LIMIT = 100

local function BroadcastChat(src, message)
    local name = GetPlayerName(src) or ('Player %d'):format(src)
    local entry = { name = name, src = src, message = message, at = os.time() }
    table.insert(RecentChat, 1, entry)
    if #RecentChat > CHAT_LOG_LIMIT then table.remove(RecentChat) end

    for adminSrc in pairs(OnDuty) do
        TriggerClientEvent('hd_anticheat:client:chat', adminSrc, entry)
    end
end

local function SendAdminChat(src, message)
    if not IsExemptAdmin(src) then return end
    if not IsOnDuty(src) then
        Notify(src, ('Go on duty first (/%s) to use admin chat.'):format(Config.DutyCommand), 'error')
        return
    end
    message = tostring(message or ''):sub(1, 255)
    if message == '' then return end
    BroadcastChat(src, message)
end

RegisterCommand(Config.ChatCommand, function(src, args)
    if src == 0 then return end
    SendAdminChat(src, table.concat(args, ' '))
end, false)

RegisterNetEvent('hd_anticheat:server:sendChat', function(message)
    SendAdminChat(source, message)
end)

RegisterNetEvent('hd_anticheat:server:getChat', function()
    local src = source
    if not IsExemptAdmin(src) or not IsOnDuty(src) then return end
    TriggerClientEvent('hd_anticheat:client:push', src, 'chatHistory', RecentChat)
end)
