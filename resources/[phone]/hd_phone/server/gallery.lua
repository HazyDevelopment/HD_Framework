-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | GALLERY
--  A personal saved-image board — NOT a real device camera/screen-
--  capture (no such capability exists in this resource). You save an
--  image URL + caption, same whitelist Picta/Loopz already enforce.
-- ═══════════════════════════════════════════════════════════════════

RegisterNetEvent('hd_phone:server:getGallery', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end
    local rows = MySQL.query.await(
        'SELECT * FROM hd_phone_gallery WHERE citizenid = ? ORDER BY created DESC',
        { Player.PlayerData.citizenid }
    ) or {}
    TriggerClientEvent('hd_phone:client:gallery', src, rows)
end)

RegisterNetEvent('hd_phone:server:saveToGallery', function(data)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or type(data) ~= 'table' or type(data.imageUrl) ~= 'string' or data.imageUrl == '' then return end

    if not IsAllowedImageHost(data.imageUrl) then
        return TriggerClientEvent('HD:Client:Notify', src, 'That image host is not allowed.', 'error')
    end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM hd_phone_gallery WHERE citizenid = ?', { Player.PlayerData.citizenid }) or 0
    if count >= Config.Gallery.MaxPerPlayer then
        return TriggerClientEvent('HD:Client:Notify', src, 'Your gallery is full.', 'error')
    end

    local caption = type(data.caption) == 'string' and data.caption:sub(1, Config.Gallery.MaxCaptionLength) or nil
    local id = MySQL.insert.await('INSERT INTO hd_phone_gallery (citizenid, image_url, caption) VALUES (?, ?, ?)', {
        Player.PlayerData.citizenid, data.imageUrl:sub(1, 255), caption
    })
    TriggerClientEvent('hd_phone:client:galleryItemAdded', src, {
        id = id, image_url = data.imageUrl, caption = caption, created = os.time(),
    })
end)

RegisterNetEvent('hd_phone:server:deleteGalleryItem', function(id)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or not id then return end
    MySQL.query.await('DELETE FROM hd_phone_gallery WHERE id = ? AND citizenid = ?', { id, Player.PlayerData.citizenid })
    TriggerClientEvent('hd_phone:client:galleryItemDeleted', src, id)
end)
