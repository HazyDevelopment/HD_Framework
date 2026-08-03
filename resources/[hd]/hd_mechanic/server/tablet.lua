-- ═══════════════════════════════════════════════════════════════════
--  HD MECHANIC | TABLET
--  A reusable (consumable = false, see HD_Framework/shared/items.lua)
--  item that opens the same terminal /diagnose does, but from the
--  driver's seat of any vehicle instead of needing to be near one on
--  foot. Auto-issued once per on-duty mechanic below so nobody has to
--  be manually handed one.
-- ═══════════════════════════════════════════════════════════════════

AddEventHandler('hd_inventory:server:onItemUsed', function(src, itemName)
    if itemName ~= Config.Tablet.Item then return end

    if not IsMechanic(src) then
        Notify(src, 'You need to be on duty as a mechanic to use this.', 'error')
        return
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then
        Notify(src, "You need to be in the driver's seat to use the tablet.", 'error')
        return
    end

    -- OpenTerminalForPlayer (shop.lua) is a plain function, not a net
    -- event — this isn't a client->server hop, so `source` inside a
    -- RegisterNetEvent handler isn't the right tool here; src is
    -- already known from onItemUsed's own argument.
    OpenTerminalForPlayer(src, NetworkGetNetworkIdFromEntity(veh))
end)

-- ═══════════════════════════ AUTO-ISSUE ON DUTY ══════════════════════════
if Config.Tablet.AutoIssueOnDuty then
    AddEventHandler('HD:Server:OnDutyUpdate', function(src, onduty)
        if not onduty or not IsMechanic(src) then return end
        if GetResourceState('hd_inventory') ~= 'started' then return end
        if exports['hd_inventory']:HasItem(src, Config.Tablet.Item, 1) then return end

        exports['hd_inventory']:AddItem(src, Config.Tablet.Item, 1)
        Notify(src, 'A mechanic tablet has been added to your inventory.', 'info')
    end)
end
