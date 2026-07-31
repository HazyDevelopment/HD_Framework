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
    local Player = GetPlayerOrNil(src)
    local citizenid = Player and Player.PlayerData.citizenid or ''

    local posts
    if app == 'wire' then
        -- Wire posts show the account's username/pfp (falling back to
        -- whatever author_name was stored, for any post made before the
        -- account gate existed) instead of the character's real name.
        posts = MySQL.query.await([[
            SELECT p.*,
                COALESCE(w.username, p.author_name) AS author_name,
                w.pfp_url AS author_pfp,
                (SELECT COUNT(*) FROM hd_phone_post_likes WHERE post_id = p.id) AS likeCount,
                EXISTS(SELECT 1 FROM hd_phone_post_likes WHERE post_id = p.id AND citizenid = ?) AS likedByMe
            FROM hd_phone_posts p
            LEFT JOIN hd_phone_wire_accounts w ON w.citizenid = p.citizenid
            WHERE p.app = 'wire' ORDER BY p.id DESC LIMIT 100
        ]], { citizenid }) or {}
    else
        posts = MySQL.query.await([[
            SELECT p.*,
                (SELECT COUNT(*) FROM hd_phone_post_likes WHERE post_id = p.id) AS likeCount,
                EXISTS(SELECT 1 FROM hd_phone_post_likes WHERE post_id = p.id AND citizenid = ?) AS likedByMe
            FROM hd_phone_posts p WHERE p.app = ? ORDER BY p.id DESC LIMIT 100
        ]], { citizenid, app }) or {}
    end
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

    local authorName
    if app == 'wire' then
        local account = GetWireAccount(Player.PlayerData.citizenid)
        if not account then
            Notify(src, 'Create your Wire account first.', 'error')
            return
        end
        authorName = account.username
    else
        authorName = ('%s %s'):format(Player.PlayerData.charinfo.firstname or '', Player.PlayerData.charinfo.lastname or '')
    end

    MySQL.insert('INSERT INTO hd_phone_posts (app, citizenid, author_name, content, image_url) VALUES (?, ?, ?, ?, ?)', {
        app, Player.PlayerData.citizenid, authorName, content, imageUrl
    })
    TriggerClientEvent('hd_phone:client:postCreated', -1, app)
end)

-- ═══════════════════════════ WIRE ACCOUNT GATE ═══════════════════════
-- Wire specifically (not Picta/Loopz) requires its own username/
-- password/profile picture — a real separate social-app login, not
-- just your character's name. Checked once per app open
-- (getWireAccount), created once (createWireAccount); after that,
-- Wire posts use the account's username/pfp (see getFeed/createPost
-- above) instead of the character's real name.
function GetWireAccount(citizenid)
    return MySQL.single.await('SELECT username, pfp_url FROM hd_phone_wire_accounts WHERE citizenid = ?', { citizenid })
end

RegisterNetEvent('hd_phone:server:getWireAccount', function()
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    TriggerClientEvent('hd_phone:client:wireAccount', src, GetWireAccount(Player.PlayerData.citizenid))
end)

RegisterNetEvent('hd_phone:server:createWireAccount', function(data)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player or type(data) ~= 'table' then return end
    local citizenid = Player.PlayerData.citizenid

    local username = type(data.username) == 'string' and data.username:match('^%s*(.-)%s*$') or ''
    local password = type(data.password) == 'string' and data.password or ''
    local pfpUrl = type(data.pfpUrl) == 'string' and data.pfpUrl:sub(1, 255) or ''

    if not username:match('^[%w_%.]+$') or #username < 3 or #username > 30 then
        Notify(src, 'Username must be 3-30 characters: letters, numbers, _ or . only.', 'error')
        return
    end
    if #password < 4 then
        Notify(src, 'Password must be at least 4 characters.', 'error')
        return
    end
    if not CheckImageHost(pfpUrl) then
        Notify(src, 'That image host is not allowed.', 'error')
        return
    end

    if MySQL.scalar.await('SELECT 1 FROM hd_phone_wire_accounts WHERE username = ?', { username }) then
        Notify(src, 'That username is already taken.', 'error')
        return
    end

    local hash = MySQL.scalar.await('SELECT SHA2(?, 256)', { password })
    local ok = pcall(function()
        MySQL.insert.await('INSERT INTO hd_phone_wire_accounts (citizenid, username, password_hash, pfp_url) VALUES (?, ?, ?, ?)', {
            citizenid, username, hash, (pfpUrl ~= '' and pfpUrl) or nil
        })
    end)
    if not ok then
        Notify(src, 'That username is already taken.', 'error')
        return
    end

    TriggerClientEvent('hd_phone:client:wireAccount', src, { username = username, pfp_url = (pfpUrl ~= '' and pfpUrl) or nil })
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
