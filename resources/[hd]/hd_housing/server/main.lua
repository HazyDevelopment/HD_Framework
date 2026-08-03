-- ═══════════════════════════════════════════════════════════════════
--  HD HOUSING | SERVER CORE
--  Seeds the Config.StarterFlatIds subset of Config.ApartmentShells
--  into hd_properties on boot (idempotent — INSERT IGNORE on the id
--  primary key); the rest of the shell pool is real-estate-exclusive
--  and only gets a row once /realestate register actually lists one
--  (see server/realestate.lua). Exposes the exports HD_Framework's
--  character creation calls to list/claim a starter flat, plus the
--  enter/exit flow for whoever owns a property.
-- ═══════════════════════════════════════════════════════════════════

Framework = nil
CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

-- Looked up by id from both the boot-seed thread and
-- server/realestate.lua's register command.
function FindShell(id)
    for _, shell in ipairs(Config.ApartmentShells) do
        if shell.id == id then return shell end
    end
    return nil
end

function IsStarterId(id)
    for _, sid in ipairs(Config.StarterFlatIds) do
        if sid == id then return true end
    end
    return false
end

CreateThread(function()
    Wait(1000)
    local ok = pcall(function() MySQL.query.await('SELECT 1 FROM hd_properties LIMIT 1') end)
    if not ok then
        print('^1[hd_housing] DATABASE NOT INSTALLED. Import sql/hd_housing_install.sql before starting.^7')
        return
    end

    for _, shellId in ipairs(Config.StarterFlatIds) do
        local shell = FindShell(shellId)
        if shell then
            local interior = shell.interior or shell.coords
            MySQL.insert.await([[
                INSERT IGNORE INTO hd_properties (id, label, type, price, exterior_x, exterior_y, exterior_z, exterior_w, pocket_x, pocket_y, pocket_z, ipl)
                VALUES (?, ?, 'starter', 0, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], {
                shell.id, shell.label,
                shell.coords.x, shell.coords.y, shell.coords.z, shell.coords.w,
                interior.x, interior.y, interior.z,
                shell.ipl,
            })
        end
    end
    print('^2[hd_housing]^7 Database verified. Starter flats seeded.')
end)

local function RowToProperty(row)
    if not row then return nil end
    return {
        id = row.id, label = row.label, citizenid = row.citizenid, type = row.type, price = row.price,
        exterior = vector4(row.exterior_x, row.exterior_y, row.exterior_z, row.exterior_w),
        pocket = vector3(row.pocket_x, row.pocket_y, row.pocket_z),
        ipl = row.ipl,
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

-- Called by HD_Framework/server/characters.lua right after a
-- successful ClaimStarterFlat, so a brand-new character's very first
-- spawn position is inside the home they just picked instead of a
-- generic street spawn — never IPL'd (starter flats are always plain
-- base-map shells, see config.lua's Config.StarterFlatIds), so this is
-- just the raw interior coords with no streaming to arrange first.
exports('GetShellInteriorCoords', function(shellId)
    local shell = FindShell(shellId)
    if not shell then return nil end
    local interior = shell.interior or shell.coords
    return { x = interior.x, y = interior.y, z = interior.z, w = 0.0 }
end)

-- ═══════════════════════════ ENTER / EXIT ═════════════════════════════
-- Entry is driven off Config.ApartmentShells directly, not a
-- hd_properties row — every shell is walkable/enterable for a preview
-- the moment the server boots, whether or not a real estate agent has
-- registered it yet (see the top-level README's Housing section for
-- why: "viewable without a real estate agent"). The DB row only comes
-- into it as an ownership check — owned by someone else is the one
-- case that blocks entry; unowned (registered or not) and "owned by
-- the person asking" both allow it.
local InsideInterior = {} -- [src] = propertyId
local GuestAccess = {} -- [propertyId] = { [src] = true } — one-time, consumed the moment it's used to enter

-- A brand-new character's very first spawn lands them directly inside
-- their claimed starter flat (HD_Framework/server/characters.lua sets
-- their spawn position to it) — no teleport to run here, just marking
-- them as home so the buzzer/furniture systems agree with where they
-- visibly already are. Ownership re-checked server-side regardless of
-- what the client claims, same as every other entry path.
RegisterNetEvent('hd_housing:server:setInsideFromSpawn', function(propertyId)
    local src = source
    local Player = Framework and Framework.Functions.GetPlayer(src)
    if not Player then return end
    local row = MySQL.single.await('SELECT citizenid FROM hd_properties WHERE id = ?', { propertyId })
    if not row or row.citizenid ~= Player.PlayerData.citizenid then return end
    InsideInterior[src] = propertyId
end)

RegisterNetEvent('hd_housing:server:enter', function(propertyId)
    local src = source
    local Player = Framework and Framework.Functions.GetPlayer(src)
    if not Player then return end

    local shell = FindShell(propertyId)
    if not shell then return end

    local row = MySQL.single.await('SELECT citizenid, furniture FROM hd_properties WHERE id = ?', { propertyId })
    local owned = row and row.citizenid and row.citizenid ~= Player.PlayerData.citizenid
    if owned then
        -- Not the owner — only lets them in if the owner buzzed them in
        -- for THIS visit (see buzzRespond below). Consumed immediately
        -- either way, so getting buzzed in once doesn't grant a
        -- standing key — they'd need to ring again next time.
        local guest = GuestAccess[propertyId] and GuestAccess[propertyId][src]
        if not guest then return end
        GuestAccess[propertyId][src] = nil
    end

    local interior = shell.interior or shell.coords
    InsideInterior[src] = propertyId
    TriggerClientEvent('hd_housing:client:enter', src, {
        id = shell.id,
        label = shell.label,
        exterior = shell.coords,
        pocket = vector3(interior.x, interior.y, interior.z),
        ipl = shell.ipl,
        furniture = row and row.furniture and json.decode(row.furniture) or {},
    })
end)

-- ═══════════════════════════ PLACEABLE FURNITURE ═══════════════════════
-- Owner-only to place (checked below); once placed, anyone currently
-- inside — owner or a buzzed-in guest — can use the wardrobe/stash,
-- same as real shared furniture in a home. Position/heading are read
-- straight off the networked ped server-side, same pattern as
-- hd_dispatch's playerDowned — never trusted from the client.
RegisterNetEvent('hd_housing:server:placeFurniture', function(kind)
    local src = source
    if kind ~= 'wardrobe' and kind ~= 'stash' then return end
    local propertyId = InsideInterior[src]
    if not propertyId then return end

    local Player = Framework and Framework.Functions.GetPlayer(src)
    if not Player then return end

    local row = MySQL.single.await('SELECT citizenid, furniture FROM hd_properties WHERE id = ?', { propertyId })
    if not row or row.citizenid ~= Player.PlayerData.citizenid then
        TriggerClientEvent('HD:Client:Notify', src, 'You can only place furniture in your own home.', 'error')
        return
    end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local furniture = row.furniture and json.decode(row.furniture) or {}
    furniture[kind] = { x = coords.x, y = coords.y, z = coords.z, h = GetEntityHeading(ped) }
    MySQL.update('UPDATE hd_properties SET furniture = ? WHERE id = ?', { json.encode(furniture), propertyId })

    -- Live-update anyone else currently inside the same property too.
    for checkSrc, insideId in pairs(InsideInterior) do
        if insideId == propertyId then
            TriggerClientEvent('hd_housing:client:furnitureUpdated', checkSrc, furniture)
        end
    end
    TriggerClientEvent('HD:Client:Notify', src, ('%s placed.'):format(kind == 'wardrobe' and 'Wardrobe' or 'Stash'), 'success')
end)

RegisterNetEvent('hd_housing:server:openStash', function(propertyId)
    local src = source
    if InsideInterior[src] ~= propertyId then return end -- must actually be inside this property right now
    if GetResourceState('hd_inventory') ~= 'started' then
        TriggerClientEvent('HD:Client:Notify', src, 'Inventory is not running.', 'error')
        return
    end
    local row = MySQL.single.await('SELECT label FROM hd_properties WHERE id = ?', { propertyId })
    exports['hd_inventory']:OpenStash(src, 'housing_' .. propertyId, (row and row.label or 'Home') .. ' Stash', 40, 80000)
end)

-- ═══════════════════════════ BUZZER ═══════════════════════════════════
-- Only the owner has a standing key (the check above). Anyone else can
-- ring the buzzer instead — if the owner is actually home (inside that
-- exact property right now), they get an accept/decline prompt; if not,
-- the visitor just gets "No answer," same as a real intercom.
RegisterNetEvent('hd_housing:server:buzz', function(propertyId)
    local src = source
    local Player = Framework and Framework.Functions.GetPlayer(src)
    if not Player then return end

    local row = MySQL.single.await('SELECT citizenid FROM hd_properties WHERE id = ?', { propertyId })
    if not row or not row.citizenid then return end -- unowned properties don't need buzzing, they're previewable

    local ownerSrc = nil
    for _, checkSrc in ipairs(Framework.Functions.GetPlayers()) do
        local OwnerPlayer = Framework.Functions.GetPlayer(checkSrc)
        if OwnerPlayer and OwnerPlayer.PlayerData.citizenid == row.citizenid and InsideInterior[checkSrc] == propertyId then
            ownerSrc = checkSrc
            break
        end
    end

    if not ownerSrc then
        TriggerClientEvent('HD:Client:Notify', src, 'No answer.', 'info')
        return
    end

    local visitorName = ('%s %s'):format(Player.PlayerData.charinfo.firstname or '?', Player.PlayerData.charinfo.lastname or '?')
    TriggerClientEvent('hd_housing:client:buzzRequest', ownerSrc, { propertyId = propertyId, visitorSrc = src, visitorName = visitorName })
    TriggerClientEvent('HD:Client:Notify', src, 'Ringing the buzzer…', 'info')
end)

RegisterNetEvent('hd_housing:server:buzzRespond', function(propertyId, visitorSrc, accept)
    local src = source
    if InsideInterior[src] ~= propertyId then return end -- only the resident who was actually asked can answer
    visitorSrc = tonumber(visitorSrc)
    if not visitorSrc or GetPlayerName(visitorSrc) == nil then return end

    if accept then
        GuestAccess[propertyId] = GuestAccess[propertyId] or {}
        GuestAccess[propertyId][visitorSrc] = true
        TriggerClientEvent('hd_housing:client:accessGranted', visitorSrc, propertyId)
        TriggerClientEvent('HD:Client:Notify', visitorSrc, "You've been let in — head on in.", 'success')
    else
        TriggerClientEvent('HD:Client:Notify', visitorSrc, 'No answer.', 'info')
    end
end)

RegisterNetEvent('hd_housing:server:exit', function()
    local src = source
    local propertyId = InsideInterior[src]
    if not propertyId then return end
    InsideInterior[src] = nil

    local shell = FindShell(propertyId)
    if shell then
        -- Most shells exit back out through the same door they entered —
        -- `exit` only exists where that door isn't a safe/sensible place
        -- to pop back out (e.g. Del Perro Heights, where the buzzer/entry
        -- spot and the actual street-level exit are two different sides
        -- of the building).
        TriggerClientEvent('hd_housing:client:exit', src, shell.exit or shell.coords)
    end
end)

AddEventHandler('playerDropped', function()
    InsideInterior[source] = nil
end)

-- ═══════════════════════════ STATUS FOR EVERY SHELL ════════════════════
-- Every one of the 12 shells, not just owned ones — the client uses
-- this for map blips and to decide whether a nearby door gets an
-- "Enter" prompt (owned by you), a "Brochure" prompt (unowned), or
-- both for sale info. `registered` distinguishes "an agent has priced
-- this and it's a real listing" from "nobody's touched this shell yet,
-- but you can still walk in and look" — the brochure shows
-- accordingly. This doubles as the old getOwnedProperties (superset).
RegisterNetEvent('hd_housing:server:getAllProperties', function()
    local src = source
    local rows = MySQL.query.await('SELECT id, citizenid, price FROM hd_properties') or {}
    local rowById = {}
    for _, row in ipairs(rows) do rowById[row.id] = row end

    local list = {}
    for _, shell in ipairs(Config.ApartmentShells) do
        local row = rowById[shell.id]
        list[#list + 1] = {
            id = shell.id,
            label = shell.label,
            size = shell.size or 'Studio',
            coords = shell.coords,
            citizenid = row and row.citizenid or nil,
            price = row and row.price or nil,
            registered = row ~= nil,
        }
    end
    TriggerClientEvent('hd_housing:client:allProperties', src, list)
end)
