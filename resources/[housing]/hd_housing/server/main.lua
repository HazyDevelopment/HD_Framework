-- ═══════════════════════════════════════════════════════════════════
--  HD HOUSING | SERVER CORE
--  Seeds Config.StarterFlats into hd_properties on boot (idempotent —
--  INSERT IGNORE on the id primary key), then exposes the exports
--  HD_Framework's character creation calls to list/claim one, plus
--  the enter/exit flow for whoever owns a property.
-- ═══════════════════════════════════════════════════════════════════

Framework = nil
CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

CreateThread(function()
    Wait(1000)
    local ok = pcall(function() MySQL.query.await('SELECT 1 FROM hd_properties LIMIT 1') end)
    if not ok then
        print('^1[hd_housing] DATABASE NOT INSTALLED. Import sql/hd_housing_install.sql before starting.^7')
        return
    end

    for _, flat in ipairs(Config.StarterFlats) do
        MySQL.insert.await([[
            INSERT IGNORE INTO hd_properties (id, label, type, price, exterior_x, exterior_y, exterior_z, exterior_w, pocket_x, pocket_y, pocket_z)
            VALUES (?, ?, 'starter', 0, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            flat.id, flat.label,
            flat.exteriorCoords.x, flat.exteriorCoords.y, flat.exteriorCoords.z, flat.exteriorCoords.w,
            flat.pocketCoords.x, flat.pocketCoords.y, flat.pocketCoords.z,
        })
    end
    print('^2[hd_housing]^7 Database verified. Starter flats seeded.')
end)

local function RowToProperty(row)
    if not row then return nil end
    return {
        id = row.id, label = row.label, citizenid = row.citizenid, type = row.type, price = row.price,
        exterior = vector4(row.exterior_x, row.exterior_y, row.exterior_z, row.exterior_w),
        pocket = vector3(row.pocket_x, row.pocket_y, row.pocket_z),
    }
end

-- ═══════════════════════════ EXPORTS FOR HD_FRAMEWORK ═════════════════
-- Called from character creation — only unowned starter flats, so two
-- new characters can never be offered (and race to claim) the same one.
exports('GetAvailableStarterFlats', function()
    local rows = MySQL.query.await("SELECT id, label FROM hd_properties WHERE type = 'starter' AND citizenid IS NULL ORDER BY id")
    return rows or {}
end)

-- Atomic claim: the WHERE citizenid IS NULL means two simultaneous
-- claims for the same flat can't both succeed — MySQL.update returns
-- the affected row count, 0 means someone else got there first.
exports('ClaimStarterFlat', function(citizenid, flatId)
    if not citizenid or not flatId then return false end
    local affected = MySQL.update.await(
        "UPDATE hd_properties SET citizenid = ? WHERE id = ? AND type = 'starter' AND citizenid IS NULL",
        { citizenid, flatId }
    )
    return affected and affected > 0
end)

exports('GetOwnedProperty', function(citizenid)
    local row = MySQL.single.await('SELECT * FROM hd_properties WHERE citizenid = ?', { citizenid })
    return RowToProperty(row)
end)

-- ═══════════════════════════ ENTER / EXIT ═════════════════════════════
local InsideInterior = {} -- [src] = propertyId

RegisterNetEvent('hd_housing:server:enter', function(propertyId)
    local src = source
    local Player = Framework and Framework.Functions.GetPlayer(src)
    if not Player then return end

    local row = MySQL.single.await('SELECT * FROM hd_properties WHERE id = ?', { propertyId })
    local property = RowToProperty(row)
    if not property or property.citizenid ~= Player.PlayerData.citizenid then return end

    InsideInterior[src] = propertyId
    TriggerClientEvent('hd_housing:client:enter', src, property)
end)

RegisterNetEvent('hd_housing:server:exit', function()
    local src = source
    local propertyId = InsideInterior[src]
    if not propertyId then return end
    InsideInterior[src] = nil

    local row = MySQL.single.await('SELECT exterior_x, exterior_y, exterior_z, exterior_w FROM hd_properties WHERE id = ?', { propertyId })
    if row then
        TriggerClientEvent('hd_housing:client:exit', src, vector4(row.exterior_x, row.exterior_y, row.exterior_z, row.exterior_w))
    end
end)

AddEventHandler('playerDropped', function()
    InsideInterior[source] = nil
end)

-- Every property with an owner — client polls this against nearby
-- players to know where to draw an [E] Enter prompt. Small table
-- (one row per owned property), fine to ship in full on request.
RegisterNetEvent('hd_housing:server:getOwnedProperties', function()
    local src = source
    local rows = MySQL.query.await("SELECT id, label, citizenid, exterior_x, exterior_y, exterior_z, exterior_w FROM hd_properties WHERE citizenid IS NOT NULL")
    local list = {}
    for _, row in ipairs(rows or {}) do
        list[#list + 1] = { id = row.id, label = row.label, citizenid = row.citizenid, coords = vector4(row.exterior_x, row.exterior_y, row.exterior_z, row.exterior_w) }
    end
    TriggerClientEvent('hd_housing:client:ownedProperties', src, list)
end)
