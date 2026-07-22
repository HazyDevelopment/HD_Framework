-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | SOCIAL (Wire / Picta / Loopz)
--  One table, `app` column tells them apart. Feeds aren't pushed live
--  to everyone viewing them — a poster's own client gets their new
--  post/like instantly, everyone else sees it on their next refresh.
--  That matches how most FiveM phone social apps behave and avoids
--  tracking who currently has which app open.
-- ═══════════════════════════════════════════════════════════════════

local function IsAllowedImageHost(url)
    if not Config.ImageHostWhitelist or #Config.ImageHostWhitelist == 0 then return true end
    if type(url) ~= 'string' then return false end
    local host = url:match('^https?://([^/]+)/?')
    if not host then return false end
    host = host:lower()
    for _, allowed in ipairs(Config.ImageHostWhitelist) do
        if host == allowed or host:sub(-(#allowed + 1)) == '.' .. allowed then return true end
    end
    return false
end

RegisterNetEvent('hd_phone:server:getFeed', function(app)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or not Config.SocialApps[app] then return end

    local posts = MySQL.query.await([[
        SELECT p.*, (SELECT COUNT(*) FROM hd_phone_post_likes l WHERE l.post_id = p.id) AS likeCount
        FROM hd_phone_posts p WHERE p.app = ? ORDER BY p.created DESC LIMIT 50
    ]], { app }) or {}

    local myLikes = MySQL.query.await('SELECT post_id FROM hd_phone_post_likes WHERE citizenid = ?', {
        Player.PlayerData.citizenid
    }) or {}
    local likedSet = {}
    for _, r in ipairs(myLikes) do likedSet[r.post_id] = true end

    for _, p in ipairs(posts) do
        p.liked = likedSet[p.id] or false
        p.mine = p.citizenid == Player.PlayerData.citizenid
    end

    TriggerClientEvent('hd_phone:client:feed', src, app, posts)
end)

RegisterNetEvent('hd_phone:server:createPost', function(data)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or type(data) ~= 'table' then return end

    local appCfg = Config.SocialApps[data.app]
    if not appCfg then return end

    local content = type(data.content) == 'string' and data.content:sub(1, appCfg.maxLength) or ''
    local imageUrl = nil
    if appCfg.allowImage and type(data.imageUrl) == 'string' and data.imageUrl ~= '' then
        if not IsAllowedImageHost(data.imageUrl) then
            TriggerClientEvent('HD:Client:Notify', src, 'That image host is not allowed.', 'error')
            return
        end
        imageUrl = data.imageUrl:sub(1, 255)
    end

    if content == '' and not imageUrl then return end

    local name = GetDisplayName(src)
    local id = MySQL.insert.await(
        'INSERT INTO hd_phone_posts (app, citizenid, author_name, content, image_url) VALUES (?, ?, ?, ?, ?)',
        { data.app, Player.PlayerData.citizenid, name, content, imageUrl }
    )

    TriggerClientEvent('hd_phone:client:postCreated', src, {
        id = id, app = data.app, citizenid = Player.PlayerData.citizenid, author_name = name,
        content = content, image_url = imageUrl, created = os.time(), likeCount = 0, liked = false, mine = true,
    })
end)

RegisterNetEvent('hd_phone:server:likePost', function(postId)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or not postId then return end
    local citizenid = Player.PlayerData.citizenid

    local existing = MySQL.scalar.await('SELECT 1 FROM hd_phone_post_likes WHERE post_id = ? AND citizenid = ?', { postId, citizenid })
    if existing then
        MySQL.query.await('DELETE FROM hd_phone_post_likes WHERE post_id = ? AND citizenid = ?', { postId, citizenid })
    else
        MySQL.insert.await('INSERT INTO hd_phone_post_likes (post_id, citizenid) VALUES (?, ?)', { postId, citizenid })
    end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM hd_phone_post_likes WHERE post_id = ?', { postId }) or 0
    TriggerClientEvent('hd_phone:client:postLikeUpdated', src, postId, count, not existing)
end)

RegisterNetEvent('hd_phone:server:deletePost', function(postId)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or not postId then return end

    local row = MySQL.single.await('SELECT citizenid FROM hd_phone_posts WHERE id = ?', { postId })
    if not row then return end
    if row.citizenid ~= Player.PlayerData.citizenid and not IsPlayerAceAllowed(src, 'hd.admin') then return end

    MySQL.query.await('DELETE FROM hd_phone_posts WHERE id = ?', { postId })
    TriggerClientEvent('hd_phone:client:postDeleted', src, postId)
end)
