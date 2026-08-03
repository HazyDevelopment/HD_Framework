-- ═══════════════════════════════════════════════════════════════════
--  HD INVENTORY | CLIENT CORE
--  Opens the player's own grid (TAB), routes NUI drag-drop/use/drop
--  callbacks to the server, and keeps a cached copy of the left panel
--  so the always-on hotbar HUD (and the HasItem export) don't need a
--  round trip for something already pushed a moment ago.
-- ═══════════════════════════════════════════════════════════════════

local Framework = nil
CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
    TriggerServerEvent('hd_inventory:server:ready')
end)

local invOpen = false
local LeftPanelCache = nil

local function OpenInventory(secondary)
    if invOpen then return end
    invOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'show' })
    TriggerServerEvent('hd_inventory:server:open', secondary)
end

local function CloseInventory()
    if not invOpen then return end
    invOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    TriggerServerEvent('hd_inventory:server:close')
end

RegisterKeyMapping('hd_inventory_toggle', 'HD Inventory: open/close', 'keyboard', Config.Keybind)
RegisterCommand('hd_inventory_toggle', function()
    if invOpen then
        CloseInventory()
        return
    end
    -- In a vehicle, TAB opens straight into the glovebox on the right
    -- panel instead of a bare inventory — mirrors /glovebox's own
    -- "any seat counts" check so this is just that command auto-fired.
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh ~= 0 then
        OpenInventory({ type = 'glovebox', netId = NetworkGetNetworkIdFromEntity(veh) })
    else
        OpenInventory()
    end
end, false)

for i = 1, Config.HotbarSlots do
    RegisterKeyMapping('hd_inventory_hotbar_' .. i, ('HD Inventory: use hotbar slot %d'):format(i), 'keyboard', tostring(i))
    RegisterCommand('hd_inventory_hotbar_' .. i, function()
        TriggerServerEvent('hd_inventory:server:useHotbar', i)
    end, false)
end

-- Hotbar HUD is hidden by default and only shows while the key is
-- physically held down. FiveM's +/- keymapping convention binds
-- keydown to the '+' command and keyup to the '-' command
-- automatically via a single RegisterKeyMapping call.
RegisterKeyMapping('hd_inventory_hotbar_toggle', 'HD Inventory: hold to show hotbar', 'keyboard', Config.HotbarToggleKey)
RegisterCommand('+hd_inventory_hotbar_toggle', function()
    SendNUIMessage({ action = 'hotbarVisibility', hidden = false })
end, false)
RegisterCommand('-hd_inventory_hotbar_toggle', function()
    SendNUIMessage({ action = 'hotbarVisibility', hidden = true })
end, false)

-- ═══════════════════════════ NUI → SERVER ═════════════════════════════
RegisterNUICallback('close', function(_, cb) CloseInventory() cb({}) end)
RegisterNUICallback('moveItem', function(data, cb) TriggerServerEvent('hd_inventory:server:moveItem', data) cb({}) end)
RegisterNUICallback('useItem', function(data, cb) TriggerServerEvent('hd_inventory:server:useItem', data) cb({}) end)
RegisterNUICallback('useItemAmount', function(data, cb) TriggerServerEvent('hd_inventory:server:useItemAmount', data) cb({}) end)
RegisterNUICallback('giveClosest', function(data, cb) TriggerServerEvent('hd_inventory:server:giveClosest', data) cb({}) end)
RegisterNUICallback('dropItem', function(data, cb) TriggerServerEvent('hd_inventory:server:dropItem', data) cb({}) end)

-- ═══════════════════════════ SERVER → NUI ═════════════════════════════
RegisterNetEvent('hd_inventory:client:panel', function(side, payload)
    if side == 'left' then LeftPanelCache = payload end
    SendNUIMessage({ action = 'panel', side = side, payload = payload })
end)

RegisterNetEvent('hd_inventory:client:forceOpen', function()
    if invOpen then return end
    invOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'show' })
end)

-- ═══════════════════════════ WEAPON-TYPE ITEMS ═════════════════════════
-- "Use" on a type='weapon' item (server/inventory.lua) toggles it in the
-- ped's hand instead of consuming it — item name IS the weapon hash,
-- lowercased (e.g. 'weapon_nightstick' -> WEAPON_NIGHTSTICK), the same
-- convention QBCore-ecosystem weapon items use.
RegisterNetEvent('hd_inventory:client:toggleWeapon', function(itemName, ammo)
    local ped = PlayerPedId()
    local hash = GetHashKey(itemName:upper())
    if HasPedGotWeapon(ped, hash, false) then
        RemoveWeaponFromPed(ped, hash)
    else
        GiveWeaponToPed(ped, hash, ammo or 0, false, true)
        SetCurrentPedWeapon(ped, hash, true)
    end
end)

-- Force-unequip regardless of current state — used when a weapon item is
-- removed from the inventory entirely (returned to an armoury, dropped,
-- etc.) so a held weapon can't become a phantom no longer backed by an
-- inventory slot.
RegisterNetEvent('hd_inventory:client:forceUnequipWeapon', function(itemName)
    RemoveWeaponFromPed(PlayerPedId(), GetHashKey(itemName:upper()))
end)

-- ═══════════════════════════ EXPORTS FOR OTHER RESOURCES ══════════════
exports('OpenStash', function(id, label, slots, weight)
    OpenInventory({ type = 'stash', id = id, label = label, slots = slots, weight = weight })
end)

-- Quick client-cache check for UI gating only (e.g. hd_phone's "do you
-- have a phone" prompt) — not authoritative. Anything security-
-- sensitive should use the server export instead.
exports('HasItem', function(itemName, amount)
    if not LeftPanelCache or not LeftPanelCache.slots then return false end
    local total = 0
    for _, slot in pairs(LeftPanelCache.slots) do
        if slot.name == itemName then total = total + slot.amount end
    end
    return total >= (amount or 1)
end)

-- Exposed for client/vehicles.lua and client/drops.lua.
OpenSecondaryInventory = OpenInventory
CloseInventoryUI = CloseInventory
IsInventoryOpen = function() return invOpen end
