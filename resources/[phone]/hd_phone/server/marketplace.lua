-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | MARKETPLACE
--  Listings only — this facilitates contact, it doesn't run an
--  escrowed trade itself (no automatic money-for-goods exchange).
--  "Message Seller" just opens a normal Messages conversation, same
--  pattern as tapping a contact.
-- ═══════════════════════════════════════════════════════════════════

RegisterNetEvent('hd_phone:server:getMarketplace', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end

    local rows = MySQL.query.await('SELECT * FROM hd_phone_marketplace ORDER BY created DESC LIMIT 100') or {}
    for _, r in ipairs(rows) do r.mine = r.citizenid == Player.PlayerData.citizenid end
    TriggerClientEvent('hd_phone:client:marketplace', src, rows)
end)

RegisterNetEvent('hd_phone:server:createListing', function(data)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or type(data) ~= 'table' then return end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM hd_phone_marketplace WHERE citizenid = ?', { Player.PlayerData.citizenid }) or 0
    if count >= Config.Marketplace.ListingLimitPerPlayer then
        return TriggerClientEvent('HD:Client:Notify', src, 'You have too many active listings.', 'error')
    end

    local title = type(data.title) == 'string' and data.title:sub(1, Config.Marketplace.MaxTitleLength) or ''
    local description = type(data.description) == 'string' and data.description:sub(1, Config.Marketplace.MaxDescriptionLength) or ''
    local price = math.floor(tonumber(data.price) or -1)
    if title == '' or price < 0 or price > Config.Marketplace.MaxPrice then
        return TriggerClientEvent('HD:Client:Notify', src, 'Invalid listing.', 'error')
    end

    local imageUrl = nil
    if type(data.imageUrl) == 'string' and data.imageUrl ~= '' then
        if not IsAllowedImageHost(data.imageUrl) then
            return TriggerClientEvent('HD:Client:Notify', src, 'That image host is not allowed.', 'error')
        end
        imageUrl = data.imageUrl:sub(1, 255)
    end

    local sellerName = GetDisplayName(src)
    local sellerNumber = Player.PlayerData.charinfo.phone
    local id = MySQL.insert.await(
        'INSERT INTO hd_phone_marketplace (citizenid, seller_name, seller_number, title, price, description, image_url) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { Player.PlayerData.citizenid, sellerName, sellerNumber, title, price, description, imageUrl }
    )

    TriggerClientEvent('hd_phone:client:listingCreated', src, {
        id = id, citizenid = Player.PlayerData.citizenid, seller_name = sellerName, seller_number = sellerNumber,
        title = title, price = price, description = description, image_url = imageUrl, created = os.time(), mine = true,
    })
end)

RegisterNetEvent('hd_phone:server:deleteListing', function(id)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or not id then return end

    local row = MySQL.single.await('SELECT citizenid FROM hd_phone_marketplace WHERE id = ?', { id })
    if not row then return end
    if row.citizenid ~= Player.PlayerData.citizenid and not IsPlayerAceAllowed(src, 'hd.admin') then return end

    MySQL.query.await('DELETE FROM hd_phone_marketplace WHERE id = ?', { id })
    TriggerClientEvent('hd_phone:client:listingDeleted', src, id)
end)
