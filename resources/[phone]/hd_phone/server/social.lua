-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | WIRE / PICTA / LOOPZ (social feeds)
--  Same table, `app` column distinguishes feeds — public, likes,
--  no follow graph (same simplified shape as the previous build).
-- ═══════════════════════════════════════════════════════════════════

local VALID_APPS = { wire = true, picta = true, loopz = true }

local function CheckImageHost(url)
    if not url or url == '' then return true end
    for _, host in ipairs(Config.ImageHostWhitelist) do
        if url:find(host, 1, true) then return true end
    end
    return false
end

RegisterNetEvent('hd_phone:server:getFeed', function(app)
    local src = source
    if not VALID_APPS[app] then return end
    local posts = MySQL.query.await([[
        SELECT p.*,
            (SELECT COUNT(*) FROM hd_phone_post_likes WHERE post_id = p.id) AS likeCount,
            EXISTS(SELECT 1 FROM hd_phone_post_likes WHERE post_id = p.id AND citizenid = ?) AS likedByMe
        FROM hd_phone_posts p WHERE p.app = ? ORDER BY p.id DESC LIMIT 100
    ]], { GetPlayerOrNil(src) and GetPlayerOrNil(src).PlayerData.citizenid or '', app }) or {}
    TriggerClientEvent('hd_phone:client:feed', src, app, posts)
end)

RegisterNetEvent('hd_phone:server:createPost', function(app, content, imageUrl)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player or not VALID_APPS[app] then return end
    content = type(content) == 'string' and content:sub(1, 300) or nil
    imageUrl = type(imageUrl) == 'string' and imageUrl:sub(1, 255) or nil
    if not CheckImageHost(imageUrl) then
        Notify(src, 'That image host is not allowed.', 'error')
        return
    end
    if (not content or content == '') and (not imageUrl or imageUrl == '') then return end

    local authorName = ('%s %s'):format(Player.PlayerData.charinfo.firstname or '', Player.PlayerData.charinfo.lastname or '')
    MySQL.insert('INSERT INTO hd_phone_posts (app, citizenid, author_name, content, image_url) VALUES (?, ?, ?, ?, ?)', {
        app, Player.PlayerData.citizenid, authorName, content, imageUrl
    })
    TriggerClientEvent('hd_phone:client:postCreated', -1, app)
end)

RegisterNetEvent('hd_phone:server:toggleLike', function(postId)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local liked = MySQL.scalar.await('SELECT 1 FROM hd_phone_post_likes WHERE post_id = ? AND citizenid = ?', { postId, citizenid })
    if liked then
        MySQL.query.await('DELETE FROM hd_phone_post_likes WHERE post_id = ? AND citizenid = ?', { postId, citizenid })
    else
        MySQL.query.await('INSERT IGNORE INTO hd_phone_post_likes (post_id, citizenid) VALUES (?, ?)', { postId, citizenid })
    end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM hd_phone_post_likes WHERE post_id = ?', { postId })
    TriggerClientEvent('hd_phone:client:likeUpdated', src, postId, count, not liked)
end)

RegisterNetEvent('hd_phone:server:deletePost', function(postId)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    MySQL.query.await('DELETE FROM hd_phone_posts WHERE id = ? AND citizenid = ?', { postId, Player.PlayerData.citizenid })
end)
