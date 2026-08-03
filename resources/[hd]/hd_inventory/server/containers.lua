-- ═══════════════════════════════════════════════════════════════════
--  HD INVENTORY | CONTAINERS
--  One data shape for every kind of container: a sparse table keyed
--  by slot number, each slot { name, amount, metadata }. Every
--  primitive below (add/remove/weight/stack) operates on that same
--  shape regardless of whether it came from a player, a stash, a
--  vehicle, or a ground drop — that's what lets any container
--  drag-drop into any other for free.
--
--  Container ref = { type = 'player'|'stash'|'glovebox'|'trunk'|'drop', id = <string|number> }
-- ═══════════════════════════════════════════════════════════════════

-- ═══════════════════════════ WEIGHT / STACK PRIMITIVES ═══════════════
function CalcWeight(data)
    local total = 0
    for _, item in pairs(data) do
        local def = GetItemDef(item.name)
        if def then total = total + (def.weight * item.amount) end
    end
    return total
end

local function FindStackableSlot(data, itemName)
    local def = GetItemDef(itemName)
    if not def or def.unique then return nil end
    for slot, item in pairs(data) do
        if item.name == itemName then return slot end
    end
    return nil
end

local function FindEmptySlot(data, maxSlots)
    for i = 1, maxSlots do
        if not data[i] then return i end
    end
    return nil
end

-- Mutates `data` in place. Returns true, or false + a reason key
-- ('unknown-item' | 'too-heavy' | 'no-space').
function AddItemToData(data, maxSlots, maxWeight, itemName, amount, metadata)
    local def = GetItemDef(itemName)
    if not def then return false, 'unknown-item' end
    if CalcWeight(data) + (def.weight * amount) > maxWeight then return false, 'too-heavy' end

    if def.unique then
        for _ = 1, amount do
            local slot = FindEmptySlot(data, maxSlots)
            if not slot then return false, 'no-space' end
            data[slot] = { name = itemName, amount = 1, metadata = metadata or {} }
        end
        return true
    end

    local stackSlot = FindStackableSlot(data, itemName)
    if stackSlot then
        data[stackSlot].amount = data[stackSlot].amount + amount
        return true
    end

    local slot = FindEmptySlot(data, maxSlots)
    if not slot then return false, 'no-space' end
    data[slot] = { name = itemName, amount = amount, metadata = metadata or {} }
    return true
end

-- Same as AddItemToData, but tries `preferredSlot` first (used for
-- drag-drop onto a specific slot in a different container) before
-- falling back to normal auto-placement if that slot's occupied by
-- something incompatible.
function AddItemToDataAtSlot(data, maxSlots, maxWeight, itemName, amount, metadata, preferredSlot)
    local def = GetItemDef(itemName)
    if not def then return false, 'unknown-item' end
    if CalcWeight(data) + (def.weight * amount) > maxWeight then return false, 'too-heavy' end

    if preferredSlot and preferredSlot >= 1 and preferredSlot <= maxSlots and not def.unique then
        local existing = data[preferredSlot]
        if not existing then
            data[preferredSlot] = { name = itemName, amount = amount, metadata = metadata or {} }
            return true
        elseif existing.name == itemName then
            existing.amount = existing.amount + amount
            return true
        end
    end

    return AddItemToData(data, maxSlots, maxWeight, itemName, amount, metadata)
end

-- Removes up to `amount` of itemName across whichever slots have it,
-- oldest slot first. Returns true only if the full amount was removed
-- (never partially removes on failure).
function RemoveItemFromData(data, itemName, amount)
    if CountItem(data, itemName) < amount then return false end
    local remaining = amount
    for slot, item in pairs(data) do
        if remaining <= 0 then break end
        if item.name == itemName then
            if item.amount <= remaining then
                remaining = remaining - item.amount
                data[slot] = nil
            else
                item.amount = item.amount - remaining
                remaining = 0
            end
        end
    end
    return true
end

function CountItem(data, itemName)
    local total = 0
    for _, item in pairs(data) do
        if item.name == itemName then total = total + item.amount end
    end
    return total
end

-- ═══════════════════════════ PLAYER ══════════════════════════════════
local function LoadPlayerInv(citizenid)
    local row = MySQL.single.await('SELECT inventory FROM players WHERE citizenid = ?', { citizenid })
    if not row then return {}, Config.MaxSlots, Config.MaxWeight end

    if not row.inventory or row.inventory == '' then
        local data = {}
        for _, starter in ipairs(Config.StarterItems) do
            AddItemToData(data, Config.MaxSlots, Config.MaxWeight, starter.name, starter.amount)
        end
        MySQL.update('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode(data), citizenid })
        return data, Config.MaxSlots, Config.MaxWeight
    end

    return json.decode(row.inventory) or {}, Config.MaxSlots, Config.MaxWeight
end

local function SavePlayerInv(citizenid, data)
    MySQL.update('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode(data), citizenid })
end

-- ═══════════════════════════ STASH ═══════════════════════════════════
function EnsureStash(id, label, slots, weight)
    local exists = MySQL.scalar.await('SELECT 1 FROM hd_inventory_stashes WHERE id = ?', { id })
    if not exists then
        MySQL.insert.await(
            'INSERT INTO hd_inventory_stashes (id, label, slots, weight, data) VALUES (?, ?, ?, ?, ?)',
            { id, label or 'Stash', slots or Config.StashDefaults.slots, weight or Config.StashDefaults.weight, '{}' }
        )
    end
end

local function LoadStash(id)
    local row = MySQL.single.await('SELECT * FROM hd_inventory_stashes WHERE id = ?', { id })
    if not row then
        EnsureStash(id)
        return {}, Config.StashDefaults.slots, Config.StashDefaults.weight
    end
    return json.decode(row.data or '{}') or {}, row.slots, row.weight
end

local function SaveStash(id, data)
    MySQL.update('UPDATE hd_inventory_stashes SET data = ? WHERE id = ?', { json.encode(data), id })
end

-- ═══════════════════════════ VEHICLE (glovebox / trunk) ══════════════
-- Capacity depends on the vehicle's real GetVehicleClass(), resolved
-- from the live entity via ref.netId — that's why glovebox/trunk refs
-- always carry a netId (see inventory.lua's open handler). A class
-- with no entry for that column (e.g. a motorcycle's glovebox) has NO
-- storage of that kind at all, not just a small one.
function GetCapacityForClass(vehicleClass, column)
    local perClass = vehicleClass and Config.VehicleClassCapacity[vehicleClass]
    if perClass then
        return perClass[column] -- may be nil — that class explicitly has none of this column
    end
    return Config.DefaultCapacity[column]
end

local function ResolveVehicleClass(ref)
    local veh = ref.netId and NetworkGetEntityFromNetworkId(ref.netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    return GetVehicleClass(veh)
end

-- `column` is always the literal string 'glovebox' or 'trunk' from
-- code below, never user input, so string-building the column name
-- into the query is safe here.
local function LoadVehicleContainer(ref, column)
    local capacity = GetCapacityForClass(ResolveVehicleClass(ref), column)
    if not capacity then return nil, 0, 0 end -- this vehicle class has no storage of this kind

    local row = MySQL.single.await('SELECT `' .. column .. '` AS data FROM player_vehicles WHERE plate = ?', { ref.id })
    if not row then return {}, capacity.slots, capacity.weight end
    return (row.data and json.decode(row.data)) or {}, capacity.slots, capacity.weight
end

local function SaveVehicleContainer(plate, column, data)
    MySQL.update('UPDATE player_vehicles SET `' .. column .. '` = ? WHERE plate = ?', { json.encode(data), plate })
end

-- ═══════════════════════════ GENERIC DISPATCH ═════════════════════════
function LoadContainer(ref)
    if ref.type == 'player' then return LoadPlayerInv(ref.id)
    elseif ref.type == 'stash' then return LoadStash(ref.id)
    elseif ref.type == 'glovebox' then return LoadVehicleContainer(ref, 'glovebox')
    elseif ref.type == 'trunk' then return LoadVehicleContainer(ref, 'trunk')
    elseif ref.type == 'drop' then return LoadDrop(ref.id) -- server/drops.lua
    end
    return nil
end

function SaveContainer(ref, data)
    if ref.type == 'player' then SavePlayerInv(ref.id, data)
    elseif ref.type == 'stash' then SaveStash(ref.id, data)
    elseif ref.type == 'glovebox' then SaveVehicleContainer(ref.id, 'glovebox', data)
    elseif ref.type == 'trunk' then SaveVehicleContainer(ref.id, 'trunk', data)
    elseif ref.type == 'drop' then SaveDrop(ref.id, data) -- server/drops.lua
    end
end
