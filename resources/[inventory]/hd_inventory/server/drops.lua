-- ═══════════════════════════════════════════════════════════════════
--  HD INVENTORY | GROUND DROPS
--  Persisted to `hd_inventory_drops` (v1.1.0) — a row exists for
--  exactly as long as the drop does, created on INSERT the moment an
--  item lands on the ground, deleted the moment it's emptied. `Drops`
--  is a write-through in-memory cache of that table so LoadDrop/
--  ValidateProximity don't hit the DB on every call — it's loaded in
--  full at resource start, so a restart doesn't lose anything sitting
--  on the ground.
-- ═══════════════════════════════════════════════════════════════════

Drops = {}

-- Not persisted as its own DB column — it's fully derivable from a
-- drop's `data` (which item names it holds) any time it's needed, so
-- there's nothing to keep in sync on restart. Picks the first item
-- found (a fresh drop from server/inventory.lua's dropItem handler is
-- always single-item; one merged onto an existing pile afterward keeps
-- whatever prop the drop was created with — see config.lua's
-- Config.ItemDropProps comment for why that trade-off is fine).
function ResolveDropProp(data)
    for _, entry in pairs(data or {}) do
        local def = GetItemDef(entry.name)
        if def then
            return def.model or Config.ItemDropProps.byName[entry.name] or Config.ItemDropProps.byType[def.type] or Config.DropProp
        end
    end
    return Config.DropProp
end

CreateThread(function()
    Wait(2000) -- give server/main.lua's DB-verify check a head start; harmless either way, this is wrapped in pcall
    local ok, rows = pcall(function() return MySQL.query.await('SELECT id, x, y, z, data FROM hd_inventory_drops') end)
    if not ok or not rows then return end -- table missing (not installed yet) — Drops just stays empty

    -- ResolveDropProp needs ItemDefs (server/main.lua only populates it
    -- once HD_Framework reports 'started'), and the flat Wait(2000)
    -- above isn't a guarantee of that on a slow boot. Model is computed
    -- once right here and never revisited, so if ItemDefs were still
    -- empty at this point every restored drop would silently sit on
    -- the fallback prop for the rest of the session, not just a
    -- one-off flicker. Capped so a genuinely broken HD_Framework
    -- doesn't hang this thread forever — it just proceeds with
    -- whatever's available at that point.
    local waited = 0
    while next(ItemDefs) == nil and waited < 10000 do Wait(100) waited = waited + 100 end

    for _, row in ipairs(rows) do
        local data = json.decode(row.data) or {}
        Drops[row.id] = {
            id = row.id,
            coords = { x = row.x, y = row.y, z = row.z },
            data = data,
            model = ResolveDropProp(data),
        }
    end
    if #rows > 0 then print(('^2[hd_inventory]^7 Restored %d ground drop(s) from the last session.'):format(#rows)) end
end)

function LoadDrop(id)
    local drop = Drops[id]
    if not drop then return {}, 40, 100000 end -- generous cap; a ground pile isn't meaningfully weight-limited
    return drop.data, 40, 100000
end

function SaveDrop(id, data)
    local drop = Drops[id]
    if not drop then return end

    local isEmpty = true
    for _ in pairs(data) do isEmpty = false break end

    if isEmpty then
        Drops[id] = nil
        MySQL.query('DELETE FROM hd_inventory_drops WHERE id = ?', { id })
        TriggerClientEvent('hd_inventory:client:removeDrop', -1, id)
    else
        drop.data = data
        MySQL.update('UPDATE hd_inventory_drops SET data = ? WHERE id = ?', { json.encode(data), id })
        TriggerClientEvent('hd_inventory:client:updateDrop', -1, drop)
    end
end

function CreateDrop(coords, data)
    local id = MySQL.insert.await('INSERT INTO hd_inventory_drops (x, y, z, data) VALUES (?, ?, ?, ?)', {
        coords.x, coords.y, coords.z, json.encode(data)
    })
    Drops[id] = { id = id, coords = { x = coords.x, y = coords.y, z = coords.z }, data = data, model = ResolveDropProp(data) }
    TriggerClientEvent('hd_inventory:client:newDrop', -1, Drops[id])
    return id
end

RegisterNetEvent('hd_inventory:server:requestDrops', function()
    local src = source
    local list = {}
    for _, d in pairs(Drops) do list[#list + 1] = d end
    TriggerClientEvent('hd_inventory:client:syncDrops', src, list)
end)
