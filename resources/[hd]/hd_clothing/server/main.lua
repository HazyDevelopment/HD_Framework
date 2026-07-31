-- ═══════════════════════════════════════════════════════════════════
--  HD_CLOTHING | SERVER
--  Named outfits in hd_clothing_outfits, plus a `clothing` column on
--  `players` itself for whatever's currently worn — re-applied the
--  moment a character finishes loading (hd_clothing:server:getMyClothing,
--  fired by the client off HD:Client:OnPlayerLoaded) so a citizen looks
--  the same after a relog without reopening the wardrobe.
-- ═══════════════════════════════════════════════════════════════════

local Framework = nil
CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

CreateThread(function()
    Wait(1500)
    local ok = pcall(function() MySQL.query.await('SELECT 1 FROM `hd_clothing_outfits` LIMIT 1') end)
    if not ok then
        print('^1[hd_clothing] ============================================================^7')
        print('^1[hd_clothing] DATABASE NOT INSTALLED.^7')
        print('^1[hd_clothing] Import sql/hd_clothing_install.sql before using the wardrobe.^7')
        print('^1[hd_clothing] ============================================================^7')
    else
        print('^2[hd_clothing]^7 Database verified. Ready.')
    end
end)

local function Notify(src, msg, ntype)
    TriggerClientEvent('HD:Client:Notify', src, msg, ntype or 'info')
end

-- ═══════════════════════════ LAST-WORN (on load) ═══════════════════════
RegisterNetEvent('hd_clothing:server:getMyClothing', function()
    local src = source
    local Player = Framework and Framework.Functions.GetPlayer(src)
    if not Player then return end

    local row = MySQL.single.await('SELECT clothing FROM players WHERE citizenid = ?', { Player.PlayerData.citizenid })
    if row and row.clothing then
        TriggerClientEvent('hd_clothing:client:outfitApplied', src, json.decode(row.clothing))
    end
end)

local function PersistLastWorn(citizenid, components, props)
    MySQL.update('UPDATE players SET clothing = ? WHERE citizenid = ?', {
        json.encode({ components = components, props = props }), citizenid
    })
end

-- ═══════════════════════════ OUTFIT LIST ═══════════════════════════════
local function SendOutfitList(src, citizenid)
    local rows = MySQL.query.await('SELECT id, label FROM hd_clothing_outfits WHERE citizenid = ? ORDER BY created DESC', { citizenid }) or {}
    TriggerClientEvent('hd_clothing:client:outfitsList', src, rows)
end

RegisterNetEvent('hd_clothing:server:getOutfits', function()
    local src = source
    local Player = Framework and Framework.Functions.GetPlayer(src)
    if not Player then return end
    SendOutfitList(src, Player.PlayerData.citizenid)
end)

-- ═══════════════════════════ SAVE / BUY ═════════════════════════════════
RegisterNetEvent('hd_clothing:server:saveOutfit', function(data)
    local src = source
    local Player = Framework and Framework.Functions.GetPlayer(src)
    if not Player or type(data) ~= 'table' then return end

    local label = type(data.label) == 'string' and data.label:match('^%s*(.-)%s*$'):sub(1, 60) or ''
    if label == '' then
        TriggerClientEvent('hd_clothing:client:saveResult', src, false, 'Enter a name for this outfit.')
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM hd_clothing_outfits WHERE citizenid = ?', { citizenid }) or 0
    if count >= (Config.MaxOutfits or 15) then
        TriggerClientEvent('hd_clothing:client:saveResult', src, false, 'You have too many saved outfits — delete one first.')
        return
    end

    if data.storeIndex then
        local store = Config.Stores[tonumber(data.storeIndex)]
        if not store then
            TriggerClientEvent('hd_clothing:client:saveResult', src, false, 'Invalid store.')
            return
        end
        if not Player.Functions.RemoveMoney('bank', store.OutfitPrice, 'hd-clothing-purchase') then
            TriggerClientEvent('hd_clothing:client:saveResult', src, false, 'Insufficient bank funds.')
            return
        end
        if GetResourceState('hd_society') == 'started' then
            exports['hd_society']:AddFunds('clothingstore', store.OutfitPrice, 'clothing-sale', citizenid)
        end
    end

    MySQL.insert.await('INSERT INTO hd_clothing_outfits (citizenid, label, components, props) VALUES (?, ?, ?, ?)', {
        citizenid, label, json.encode(data.components or {}), json.encode(data.props or {})
    })
    PersistLastWorn(citizenid, data.components or {}, data.props or {})

    TriggerClientEvent('hd_clothing:client:saveResult', src, true, data.storeIndex and 'Purchased and saved.' or 'Outfit saved.')
    SendOutfitList(src, citizenid)
end)

-- ═══════════════════════════ WEAR / DELETE ══════════════════════════════
RegisterNetEvent('hd_clothing:server:wearOutfit', function(id)
    local src = source
    local Player = Framework and Framework.Functions.GetPlayer(src)
    if not Player then return end

    local row = MySQL.single.await('SELECT components, props FROM hd_clothing_outfits WHERE id = ? AND citizenid = ?', {
        tonumber(id), Player.PlayerData.citizenid
    })
    if not row then return end

    local components, props = json.decode(row.components), json.decode(row.props)
    PersistLastWorn(Player.PlayerData.citizenid, components, props)
    TriggerClientEvent('hd_clothing:client:outfitApplied', src, { components = components, props = props })
end)

RegisterNetEvent('hd_clothing:server:deleteOutfit', function(id)
    local src = source
    local Player = Framework and Framework.Functions.GetPlayer(src)
    if not Player then return end

    MySQL.query.await('DELETE FROM hd_clothing_outfits WHERE id = ? AND citizenid = ?', {
        tonumber(id), Player.PlayerData.citizenid
    })
    SendOutfitList(src, Player.PlayerData.citizenid)
end)
