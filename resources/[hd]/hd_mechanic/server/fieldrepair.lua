-- ═══════════════════════════════════════════════════════════════════
--  HD MECHANIC | FIELD REPAIR — RAW MATERIALS
--  Scrap metal/iron/aluminium/steel patch bodywork, rubber (or a proper
--  tirerepairkit) fixes one burst tyre — a cheap, no-job-required
--  alternative to a shop visit, same trust boundary repairkit_advanced
--  already accepts in limp.lua: the item is already consumed by the
--  time this fires, so a wasted use on an undamaged car just means a
--  clear notification instead of a silent nothing.
-- ═══════════════════════════════════════════════════════════════════

local function IsTyreItem(itemName)
    for _, name in ipairs(Config.FieldRepair.TyreItems) do
        if name == itemName then return true end
    end
    return false
end

AddEventHandler('hd_inventory:server:onItemUsed', function(src, itemName)
    local bodyRestore = Config.FieldRepair.BodyMaterials[itemName]
    local isTyreItem = IsTyreItem(itemName)
    if not bodyRestore and not isTyreItem then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or (Config.FieldRepair.RequireDriverSeat and GetPedInVehicleSeat(veh, -1) ~= ped) then
        Notify(src, "You need to be in the driver's seat of the vehicle to do that.", 'error')
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(veh)

    if bodyRestore then
        if GetVehicleBodyHealth(veh) >= 999.0 then
            Notify(src, "The bodywork doesn't need patching — wasted.", 'error')
            return
        end
        TriggerClientEvent('hd_mechanic:client:setBodyHealth', -1, netId, 'add', bodyRestore)
        Notify(src, 'Patched up some bodywork damage.', 'success')
        return
    end

    local hasBurstTyre = false
    for i = 0, 5 do
        if IsVehicleTyreBurst(veh, i, false) then hasBurstTyre = true break end
    end
    if not hasBurstTyre then
        Notify(src, 'No burst tyres — wasted.', 'error')
        return
    end

    TriggerClientEvent('hd_mechanic:client:fixOneTyre', -1, netId)
    Notify(src, 'Fixed a tyre.', 'success')
end)
