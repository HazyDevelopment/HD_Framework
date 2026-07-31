-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | PHOTOS (GALLERY)
-- ═══════════════════════════════════════════════════════════════════

local function SendPhotos(src, citizenid)
    local rows = MySQL.query.await('SELECT id, image_url, caption, created FROM hd_phone_gallery WHERE citizenid = ? ORDER BY id DESC', {
        citizenid
    }) or {}
    TriggerClientEvent('hd_phone:client:photos', src, rows)
end

RegisterNetEvent('hd_phone:server:getPhotos', function()
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    SendPhotos(src, Player.PlayerData.citizenid)
end)

-- Called directly (same-resource Lua function, not a net event) by
-- anything that already has a citizenid in hand — Camera below, and
-- available to other future apps the same way.
function SaveToGallery(citizenid, imageUrl, caption)
    MySQL.insert('INSERT INTO hd_phone_gallery (citizenid, image_url, caption) VALUES (?, ?, ?)', {
        citizenid, imageUrl, caption
    })
end

RegisterNetEvent('hd_phone:server:saveFromCamera', function(imageUrl)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player or type(imageUrl) ~= 'string' or imageUrl == '' then return end
    SaveToGallery(Player.PlayerData.citizenid, imageUrl, nil)
    SendPhotos(src, Player.PlayerData.citizenid)
end)
