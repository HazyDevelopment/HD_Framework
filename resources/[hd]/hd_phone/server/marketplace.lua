-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | MARKETPLACE
-- ═══════════════════════════════════════════════════════════════════

local function CheckImageHost(url)
    if not url or url == '' then return true end
    for _, host in ipairs(Config.ImageHostWhitelist) do
        if url:find(host, 1, true) then return true end
    end
    return false
end

RegisterNetEvent('hd_phone:server:getListings', function()
    local src = source
    local rows = MySQL.query.await('SELECT * FROM hd_phone_marketplace ORDER BY id DESC LIMIT 200') or {}
    TriggerClientEvent('hd_phone:client:listings', src, rows)
end)

RegisterNetEvent('hd_phone:server:createListing', function(data)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player or type(data) ~= 'table' then return end
    local citizenid = Player.PlayerData.citizenid

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM hd_phone_marketplace WHERE citizenid = ?', { citizenid }) or 0
    if count >= Config.Marketplace.ListingLimitPerPlayer then
        Notify(src, 'You have reached your listing limit.', 'error')
        return
    end

    local title = type(data.title) == 'string' and data.title:sub(1, 80) or ''
    local price = math.floor(tonumber(data.price) or 0)
    local description = type(data.description) == 'string' and data.description:sub(1, 500) or nil
    local imageUrl = type(data.imageUrl) == 'string' and data.imageUrl:sub(1, 255) or nil
    if title == '' or price <= 0 then
        Notify(src, 'Enter a title and a price.', 'error')
        return
    end
    if not CheckImageHost(imageUrl) then
        Notify(src, 'That image host is not allowed.', 'error')
        return
    end

    local sellerName = ('%s %s'):format(Player.PlayerData.charinfo.firstname or '', Player.PlayerData.charinfo.lastname or '')
    MySQL.insert('INSERT INTO hd_phone_marketplace (citizenid, seller_name, seller_number, title, price, description, image_url) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        citizenid, sellerName, Player.PlayerData.charinfo.phone, title, price, description, imageUrl
    })
    TriggerClientEvent('hd_phone:client:listingCreated', -1)
end)

RegisterNetEvent('hd_phone:server:deleteListing', function(id)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    MySQL.update('DELETE FROM hd_phone_marketplace WHERE id = ? AND citizenid = ?', { id, Player.PlayerData.citizenid })
end)
