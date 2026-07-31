-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | VOICE MEMO
-- ═══════════════════════════════════════════════════════════════════

local function SendVoiceMemos(src, citizenid)
    local rows = MySQL.query.await('SELECT id, duration, created FROM hd_phone_voicememos WHERE citizenid = ? ORDER BY id DESC', {
        citizenid
    }) or {}
    TriggerClientEvent('hd_phone:client:voiceMemos', src, rows)
end

RegisterNetEvent('hd_phone:server:getVoiceMemos', function()
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    SendVoiceMemos(src, Player.PlayerData.citizenid)
end)

RegisterNetEvent('hd_phone:server:getVoiceMemoAudio', function(id)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    local row = MySQL.single.await('SELECT audio_data FROM hd_phone_voicememos WHERE id = ? AND citizenid = ?', { id, Player.PlayerData.citizenid })
    if row then TriggerClientEvent('hd_phone:client:voiceMemoAudio', src, id, row.audio_data) end
end)

RegisterNetEvent('hd_phone:server:saveVoiceMemo', function(audioData, duration)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player or type(audioData) ~= 'string' then return end
    duration = math.min(Config.VoiceMemo.MaxDurationSeconds, math.floor(tonumber(duration) or 0))
    local citizenid = Player.PlayerData.citizenid

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM hd_phone_voicememos WHERE citizenid = ?', { citizenid }) or 0
    if count >= Config.VoiceMemo.MaxPerPlayer then
        Notify(src, 'You have reached your voice memo limit.', 'error')
        return
    end
    MySQL.insert.await('INSERT INTO hd_phone_voicememos (citizenid, audio_data, duration) VALUES (?, ?, ?)', { citizenid, audioData, duration })
    SendVoiceMemos(src, citizenid)
end)

RegisterNetEvent('hd_phone:server:deleteVoiceMemo', function(id)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    MySQL.update('DELETE FROM hd_phone_voicememos WHERE id = ? AND citizenid = ?', { id, Player.PlayerData.citizenid })
end)
