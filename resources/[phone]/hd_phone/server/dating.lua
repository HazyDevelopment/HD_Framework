-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | MATCHUP (dating)
--  Swipe queue is only currently-online players with an active
--  profile — never browses offline citizens' saved data. A match is
--  just both directions of one swipes row existing with liked = 1,
--  computed live rather than a separate matches table.
-- ═══════════════════════════════════════════════════════════════════

local function CheckImageHost(url)
    if not url or url == '' then return true end
    for _, host in ipairs(Config.ImageHostWhitelist) do
        if url:find(host, 1, true) then return true end
    end
    return false
end

RegisterNetEvent('hd_phone:server:getMyProfile', function()
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    local row = MySQL.single.await('SELECT * FROM hd_phone_dating_profiles WHERE citizenid = ?', { Player.PlayerData.citizenid })
    TriggerClientEvent('hd_phone:client:myProfile', src, row or { bio = '', photo_url = '', active = 0 })
end)

RegisterNetEvent('hd_phone:server:saveProfile', function(bio, photoUrl, active)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    bio = type(bio) == 'string' and bio:sub(1, 200) or ''
    photoUrl = type(photoUrl) == 'string' and photoUrl:sub(1, 255) or ''
    if not CheckImageHost(photoUrl) then
        Notify(src, 'That image host is not allowed.', 'error')
        return
    end
    MySQL.query.await([[
        INSERT INTO hd_phone_dating_profiles (citizenid, bio, photo_url, active) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE bio = VALUES(bio), photo_url = VALUES(photo_url), active = VALUES(active)
    ]], { Player.PlayerData.citizenid, bio, photoUrl, active and 1 or 0 })
    Notify(src, 'Profile saved.', 'success')
end)

RegisterNetEvent('hd_phone:server:getSwipeQueue', function()
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    local myId = Player.PlayerData.citizenid

    local queue = {}
    for _, srcStr in ipairs(GetPlayers()) do
        local candidate = tonumber(srcStr)
        if candidate ~= src then
            local CandidatePlayer = GetPlayerOrNil(candidate)
            if CandidatePlayer then
                local cid = CandidatePlayer.PlayerData.citizenid
                local profile = MySQL.single.await('SELECT * FROM hd_phone_dating_profiles WHERE citizenid = ? AND active = 1', { cid })
                local alreadySwiped = MySQL.scalar.await('SELECT 1 FROM hd_phone_dating_swipes WHERE citizenid = ? AND target_citizenid = ?', { myId, cid })
                if profile and not alreadySwiped then
                    queue[#queue + 1] = {
                        citizenid = cid,
                        name = ('%s %s'):format(CandidatePlayer.PlayerData.charinfo.firstname or '', CandidatePlayer.PlayerData.charinfo.lastname or ''),
                        bio = profile.bio, photoUrl = profile.photo_url,
                    }
                end
            end
        end
    end
    TriggerClientEvent('hd_phone:client:swipeQueue', src, queue)
end)

RegisterNetEvent('hd_phone:server:swipe', function(targetCitizenId, liked)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player or type(targetCitizenId) ~= 'string' then return end
    local myId = Player.PlayerData.citizenid

    MySQL.query.await([[
        INSERT INTO hd_phone_dating_swipes (citizenid, target_citizenid, liked) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE liked = VALUES(liked)
    ]], { myId, targetCitizenId, liked and 1 or 0 })

    if not liked then return end
    local theyLikedMe = MySQL.scalar.await(
        'SELECT liked FROM hd_phone_dating_swipes WHERE citizenid = ? AND target_citizenid = ?',
        { targetCitizenId, myId }
    )
    if theyLikedMe ~= 1 then return end

    -- Mutual like: save each other to real Contacts (same
    -- INSERT ... ON DUPLICATE KEY UPDATE contacts.lua itself uses).
    local myNumber = Player.PlayerData.charinfo.phone
    local myName = ('%s %s'):format(Player.PlayerData.charinfo.firstname or '', Player.PlayerData.charinfo.lastname or '')

    for _, srcStr in ipairs(GetPlayers()) do
        local candidate = tonumber(srcStr)
        local CandidatePlayer = GetPlayerOrNil(candidate)
        if CandidatePlayer and CandidatePlayer.PlayerData.citizenid == targetCitizenId then
            local theirNumber = CandidatePlayer.PlayerData.charinfo.phone
            local theirName = ('%s %s'):format(CandidatePlayer.PlayerData.charinfo.firstname or '', CandidatePlayer.PlayerData.charinfo.lastname or '')
            MySQL.query.await('INSERT INTO hd_phone_contacts (owner, name, number) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name)', { myId, theirName, theirNumber })
            MySQL.query.await('INSERT INTO hd_phone_contacts (owner, name, number) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name)', { targetCitizenId, myName, myNumber })
            TriggerClientEvent('hd_phone:client:newMatch', src, theirName)
            TriggerClientEvent('hd_phone:client:newMatch', candidate, myName)
            break
        end
    end
end)
