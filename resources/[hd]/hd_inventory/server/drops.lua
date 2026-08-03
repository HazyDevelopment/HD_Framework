-- ═══════════════════════════════════════════════════════════════════
--  HD INVENTORY | GROUND DROPS
--  Backed by `hd_inventory_drops` only for as long as the current
--  server session lasts — a row exists for exactly as long as the drop
--  does, created on INSERT the moment an item lands on the ground,
--  deleted the moment it's emptied. `Drops` is the in-memory table
--  LoadDrop/SaveDrop actually work against; the table is wiped at
--  resource start on purpose (every restart should leave a clean
--  ground, not scatter last session's drops back out), so it never
--  needs reading from at boot beyond that.
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
    local ok, count = pcall(function() return MySQL.scalar.await('SELECT COUNT(*) FROM hd_inventory_drops') end)
    if not ok or not count then return end -- table missing (not installed yet) — nothing to clear

    MySQL.query('DELETE FROM hd_inventory_drops')
    if count > 0 then print(('^2[hd_inventory]^7 Cleared %d leftover ground drop(s) from the last session.'):format(count)) end
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
