-- ═══════════════════════════════════════════════════════════════════
--  HD INVENTORY | NUI-FACING LOGIC
--  The LEFT panel is always the acting player's own inventory — every
--  open flow enforces that, which is what makes every other
--  validation simpler (no case where "left" needs a permission check).
--  RIGHT is whatever secondary container they opened alongside it,
--  or nil for "just my own inventory".
--
--  OpenContext[src] = { left = ref, right = ref|nil }
--  ref = { type, id, netId? }  -- netId only set for glovebox/trunk,
--  used to re-resolve the live vehicle entity on every move so a
--  snapshot coordinate can't go stale if the car gets driven off.
-- ═══════════════════════════════════════════════════════════════════

local OpenContext = {}

-- ═══════════════════════════ HELPERS ═════════════════════════════════
local function GetCitizenId(src)
    local Player = Framework.Functions.GetPlayer(src)
    return Player and Player.PlayerData.citizenid or nil
end

local function ResolveForClient(data)
    local out = {}
    for slot, item in pairs(data) do
        local def = GetItemDef(item.name) or {}
        out[tostring(slot)] = {
            slot = slot,
            name = item.name,
            amount = item.amount,
            metadata = item.metadata or {},
            label = def.label or item.name,
            weight = def.weight or 0,
            useable = def.useable or false,
            unique = def.unique or false,
            description = def.description or '',
            image = def.image,
        }
    end
    return out
end

local function PushContainer(src, side, ref, data, maxSlots, maxWeight)
    if not data then
        TriggerClientEvent('hd_inventory:client:panel', src, side, nil)
        return
    end
    TriggerClientEvent('hd_inventory:client:panel', src, side, {
        type = ref.type,
        id = ref.id,
        slots = ResolveForClient(data),
        maxSlots = maxSlots,
        maxWeight = maxWeight,
        currentWeight = CalcWeight(data),
    })
end

local function PushSide(src, side)
    local ctx = OpenContext[src]
    local ref = ctx and ctx[side]
    if not ref then
        TriggerClientEvent('hd_inventory:client:panel', src, side, nil)
        return
    end
    local data, maxSlots, maxWeight = LoadContainer(ref)
    PushContainer(src, side, ref, data, maxSlots, maxWeight)
end

-- Pushes the player's own inventory as the 'left' panel regardless of
-- whether they currently have the full grid open — the hotbar HUD
-- listens for this too, so it has to work at any time (on join, after
-- a hotbar use, after AddItem/RemoveItem from another resource), not
-- just while OpenContext[src] exists.
local function PushOwnInventory(src)
    local citizenid = GetCitizenId(src)
    if not citizenid then return end
    local ref = { type = 'player', id = citizenid }
    local data, maxSlots, maxWeight = LoadContainer(ref)
    PushContainer(src, 'left', ref, data, maxSlots, maxWeight)
end

RegisterNetEvent('hd_inventory:server:ready', function()
    PushOwnInventory(source)
end)

-- Re-validated on every move, not just at open time — a snapshot
-- distance check would let someone open a container then walk away
-- (or drive off, for vehicles) and keep looting. For glovebox/trunk
-- this also re-checks vehicle keys every time (not just at open), so
-- an owner revoking someone's shared keys mid-loot actually cuts them
-- off live, same as the distance check already does.
local function HasVehicleKeys(src, plate)
    if GetResourceState('HD_vehiclekeys') ~= 'started' then return true end -- degrade open if not installed
    return exports['HD_vehiclekeys']:HasKeys(src, plate)
end

local function ValidateProximity(src, ref)
    if ref.type == 'player' or ref.type == 'stash' then return true end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pcoords = GetEntityCoords(ped)

    if ref.type == 'glovebox' or ref.type == 'trunk' then
        local veh = ref.netId and NetworkGetEntityFromNetworkId(ref.netId)
        if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
        if not GetCapacityForClass(GetVehicleClass(veh), ref.type) then return false end -- this vehicle class has no storage of this kind
        if not HasVehicleKeys(src, ref.id) then return false end
        return #(GetEntityCoords(veh) - pcoords) <= (Config.VehicleInteractDistance + 2.0)
    end

    if ref.type == 'drop' then
        local drop = Drops[ref.id]
        if not drop then return false end
        local dcoords = vector3(drop.coords.x, drop.coords.y, drop.coords.z)
        return #(dcoords - pcoords) <= (Config.DropRadius + 2.0)
    end

    return false
end

-- ═══════════════════════════ OPEN / CLOSE ═════════════════════════════
RegisterNetEvent('hd_inventory:server:open', function(secondary)
    local src = source
    local citizenid = GetCitizenId(src)
    if not citizenid then return end

    OpenContext[src] = { left = { type = 'player', id = citizenid } }

    local specificDenialSent = false

    if type(secondary) == 'table' then
        if secondary.type == 'glovebox' or secondary.type == 'trunk' then
            local ref = { type = secondary.type, id = nil, netId = secondary.netId }
            local veh = secondary.netId and NetworkGetEntityFromNetworkId(secondary.netId)
            if veh and veh ~= 0 and DoesEntityExist(veh) then
                ref.id = GetVehicleNumberPlateText(veh):gsub('%s+$', '')
                if not GetCapacityForClass(GetVehicleClass(veh), ref.type) then
                    TriggerClientEvent('HD:Client:Notify', src, ('This vehicle has no %s.'):format(ref.type), 'error')
                    specificDenialSent = true
                elseif not HasVehicleKeys(src, ref.id) then
                    TriggerClientEvent('HD:Client:Notify', src, "You don't have keys to that vehicle.", 'error')
                    specificDenialSent = true
                elseif ValidateProximity(src, ref) then
                    OpenContext[src].right = ref
                end
            end
        elseif secondary.type == 'drop' then
            local ref = { type = 'drop', id = tonumber(secondary.id) }
            if ValidateProximity(src, ref) then
                OpenContext[src].right = ref
            end
        elseif secondary.type == 'stash' then
            -- Sane caps regardless of what a client requests — a
            -- resource that needs a bigger/permissioned stash should
            -- use the server export instead (see bottom of file).
            local slots = math.min(tonumber(secondary.slots) or Config.StashDefaults.slots, 100)
            local weight = math.min(tonumber(secondary.weight) or Config.StashDefaults.weight, 100000)
            local id = tostring(secondary.id):sub(1, 50)
            EnsureStash(id, tostring(secondary.label or 'Stash'):sub(1, 60), slots, weight)
            OpenContext[src].right = { type = 'stash', id = id }
        end

        if not OpenContext[src].right and not specificDenialSent then
            TriggerClientEvent('HD:Client:Notify', src, "Couldn't access that.", 'error')
        end
    end

    PushSide(src, 'left')
    PushSide(src, 'right')
end)

RegisterNetEvent('hd_inventory:server:close', function()
    OpenContext[source] = nil
end)

AddEventHandler('playerDropped', function()
    OpenContext[source] = nil
end)

-- ═══════════════════════════ MOVE ITEM ════════════════════════════════
local function SameRef(a, b)
    return a.type == b.type and a.id == b.id
end

RegisterNetEvent('hd_inventory:server:moveItem', function(req)
    local src = source
    local ctx = OpenContext[src]
    if not ctx or type(req) ~= 'table' then return end

    local fromRef, toRef = ctx[req.fromSide], ctx[req.toSide]
    if not fromRef or not toRef then return end
    if not ValidateProximity(src, fromRef) or not ValidateProximity(src, toRef) then
        TriggerClientEvent('HD:Client:Notify', src, 'You moved too far away.', 'error')
        PushSide(src, req.fromSide)
        PushSide(src, req.toSide)
        return
    end

    local fromSlot, toSlot = tonumber(req.fromSlot), tonumber(req.toSlot)
    if not fromSlot then return end

    if SameRef(fromRef, toRef) then
        local data, maxSlots, maxWeight = LoadContainer(fromRef)
        if fromRef.type == 'player' then maxSlots, maxWeight = Config.MaxSlots, Config.MaxWeight end
        local item = data[fromSlot]
        if not item then return end
        local amount = math.min(tonumber(req.amount) or item.amount, item.amount)
        local dest = data[toSlot]
        local def = GetItemDef(item.name) or {}

        if dest and dest.name == item.name and not def.unique then
            dest.amount = dest.amount + amount
            if amount >= item.amount then data[fromSlot] = nil else item.amount = item.amount - amount end
        elseif dest then
            if amount ~= item.amount then
                TriggerClientEvent('HD:Client:Notify', src, "Can't split onto an occupied slot.", 'error')
                return
            end
            data[fromSlot], data[toSlot] = dest, item
        else
            if amount >= item.amount then
                data[toSlot] = item
                data[fromSlot] = nil
            else
                data[toSlot] = { name = item.name, amount = amount, metadata = item.metadata }
                item.amount = item.amount - amount
            end
        end

        SaveContainer(fromRef, data)
        PushContainer(src, req.fromSide, fromRef, data, maxSlots, maxWeight)
    else
        local fromData, fromSlots, fromWeight = LoadContainer(fromRef)
        if fromRef.type == 'player' then fromSlots, fromWeight = Config.MaxSlots, Config.MaxWeight end
        local toData, toSlots, toWeight = LoadContainer(toRef)
        if toRef.type == 'player' then toSlots, toWeight = Config.MaxSlots, Config.MaxWeight end

        local item = fromData[fromSlot]
        if not item then return end
        local amount = math.min(tonumber(req.amount) or item.amount, item.amount)

        local ok, reason = AddItemToDataAtSlot(toData, toSlots, toWeight, item.name, amount, item.metadata, toSlot)
        if not ok then
            local msg = reason == 'too-heavy' and 'Too heavy for that container.' or reason == 'no-space' and 'No space.' or 'Cannot move that.'
            TriggerClientEvent('HD:Client:Notify', src, msg, 'error')
            return
        end

        if amount >= item.amount then fromData[fromSlot] = nil else item.amount = item.amount - amount end

        SaveContainer(fromRef, fromData)
        SaveContainer(toRef, toData)
        PushContainer(src, req.fromSide, fromRef, fromData, fromSlots, fromWeight)
        PushContainer(src, req.toSide, toRef, toData, toSlots, toWeight)
    end
end)

-- ═══════════════════════════ USE ITEM ═════════════════════════════════
RegisterNetEvent('hd_inventory:server:useItem', function(req)
    local src = source
    local ctx = OpenContext[src]
    if not ctx or type(req) ~= 'table' then return end
    local ref = ctx[req.side]
    if not ref or ref.type ~= 'player' then return end

    local data = LoadContainer(ref)
    local item = data[tonumber(req.slot)]
    if not item then return end
    local def = GetItemDef(item.name)
    if not def or not def.useable then return end

    -- Default behaviour: consume one unit and notify. Item-specific
    -- effects (heal, open a sub-menu, etc.) are a natural extension
    -- point — branch on def.name here per item as they're added.
    RemoveItemFromData(data, item.name, 1)
    SaveContainer(ref, data)
    PushContainer(src, req.side, ref, data, Config.MaxSlots, Config.MaxWeight)
    TriggerClientEvent('HD:Client:Notify', src, ('Used %s.'):format(def.label), 'success')
    TriggerEvent('hd_inventory:server:onItemUsed', src, item.name)
end)

-- Same as useItem, but works with no open inventory context at all —
-- this is what the 1-5 hotbar keybinds call, since they need to work
-- any time, not just while the grid's open.
RegisterNetEvent('hd_inventory:server:useHotbar', function(slot)
    local src = source
    local citizenid = GetCitizenId(src)
    if not citizenid then return end
    local ref = { type = 'player', id = citizenid }
    local data = LoadContainer(ref)
    local item = data[tonumber(slot)]
    if not item then return end
    local def = GetItemDef(item.name)
    if not def or not def.useable then return end

    RemoveItemFromData(data, item.name, 1)
    SaveContainer(ref, data)
    PushOwnInventory(src)
    TriggerClientEvent('HD:Client:Notify', src, ('Used %s.'):format(def.label), 'success')
    TriggerEvent('hd_inventory:server:onItemUsed', src, item.name)
end)

-- ═══════════════════════════ DROP TO GROUND / PICK UP ═════════════════
RegisterNetEvent('hd_inventory:server:dropItem', function(req)
    local src = source
    local ctx = OpenContext[src]
    if not ctx or type(req) ~= 'table' then return end
    local ref = ctx[req.side]
    if not ref or ref.type ~= 'player' then return end

    local data = LoadContainer(ref)
    local item = data[tonumber(req.slot)]
    if not item then return end
    local amount = math.min(tonumber(req.amount) or item.amount, item.amount)

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local dropData = {}
    AddItemToData(dropData, 40, 100000, item.name, amount, item.metadata)

    if amount >= item.amount then data[tonumber(req.slot)] = nil else item.amount = item.amount - amount end
    SaveContainer(ref, data)
    PushContainer(src, req.side, ref, data, Config.MaxSlots, Config.MaxWeight)

    CreateDrop(coords, dropData)
end)

-- ═══════════════════════════ SERVER-SIDE EXPORTS ═══════════════════════
-- For other resources: give/take/check items without going through
-- the NUI at all (e.g. a future car dealer handing over keys).
exports('AddItem', function(src, itemName, amount, metadata)
    local citizenid = GetCitizenId(src)
    if not citizenid then return false end
    local data = LoadContainer({ type = 'player', id = citizenid })
    local ok = AddItemToData(data, Config.MaxSlots, Config.MaxWeight, itemName, amount or 1, metadata)
    if ok then
        SaveContainer({ type = 'player', id = citizenid }, data)
        PushOwnInventory(src)
    end
    return ok
end)

exports('RemoveItem', function(src, itemName, amount)
    local citizenid = GetCitizenId(src)
    if not citizenid then return false end
    local data = LoadContainer({ type = 'player', id = citizenid })
    local ok = RemoveItemFromData(data, itemName, amount or 1)
    if ok then
        SaveContainer({ type = 'player', id = citizenid }, data)
        PushOwnInventory(src)
    end
    return ok
end)

exports('HasItem', function(src, itemName, amount)
    local citizenid = GetCitizenId(src)
    if not citizenid then return false end
    local data = LoadContainer({ type = 'player', id = citizenid })
    return CountItem(data, itemName) >= (amount or 1)
end)

-- Remote-open a stash on a specific player from trusted server code
-- that has already done its own permission/proximity check (e.g. an
-- evidence locker script). Bypasses the client-requested size caps.
exports('OpenStash', function(src, id, label, slots, weight)
    id = tostring(id):sub(1, 50)
    EnsureStash(id, label, slots, weight)
    OpenContext[src] = OpenContext[src] or { left = { type = 'player', id = GetCitizenId(src) } }
    OpenContext[src].right = { type = 'stash', id = id }
    PushSide(src, 'left')
    PushSide(src, 'right')
    TriggerClientEvent('hd_inventory:client:forceOpen', src)
end)
