-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | MUSIC
--  A personal saved playlist of YouTube links — same "paste a link,
--  pull the video id out" pattern hd_loadingscreen's background music
--  already uses, just per-citizen with real playback controls.
-- ═══════════════════════════════════════════════════════════════════

local function SendPlaylist(src, citizenid)
    local rows = MySQL.query.await('SELECT * FROM hd_phone_playlist WHERE citizenid = ? ORDER BY id ASC', { citizenid }) or {}
    TriggerClientEvent('hd_phone:client:playlist', src, rows)
end

RegisterNetEvent('hd_phone:server:getPlaylist', function()
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    SendPlaylist(src, Player.PlayerData.citizenid)
end)

RegisterNetEvent('hd_phone:server:addTrack', function(videoId, title)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player or type(videoId) ~= 'string' or videoId == '' then return end
    title = type(title) == 'string' and title:sub(1, 150) or 'Untitled'
    MySQL.insert.await('INSERT INTO hd_phone_playlist (citizenid, video_id, title) VALUES (?, ?, ?)', {
        Player.PlayerData.citizenid, videoId, title
    })
    SendPlaylist(src, Player.PlayerData.citizenid)
end)

RegisterNetEvent('hd_phone:server:removeTrack', function(id)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    MySQL.update('DELETE FROM hd_phone_playlist WHERE id = ? AND citizenid = ?', { id, Player.PlayerData.citizenid })
    SendPlaylist(src, Player.PlayerData.citizenid)
end)
