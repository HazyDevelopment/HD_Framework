-- ═══════════════════════════════════════════════════════════════════
--  HD MECHANIC | LIMP MODE
--  The client can only ever REPORT a hard impact — real-time vehicle
--  physics don't exist server-side, so there's no way to independently
--  re-derive "did this car just crash at 80mph" the way proximity or
--  on-duty status can be re-checked elsewhere in this build. Same
--  trust boundary HD_vehiclekeys' break-in minigame already accepts
--  for its "passed" flag: a spoofed report only ever forces the
--  reporter's OWN vehicle into limp mode, never touches money, another
--  player, or anything server-authoritative beyond one plate's row.
-- ═══════════════════════════════════════════════════════════════════

local LastReport = {} -- [plate] = os.time() of the last accepted report, anti-spam only

RegisterNetEvent('hd_mechanic:server:reportImpact', function(netId, reportedSpeedMph)
    local src = source
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return end

    -- Only the driver's report counts — matches the client, which only
    -- runs its crash-detection thread while it's the one actually driving.
    if GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(src) then return end

    reportedSpeedMph = tonumber(reportedSpeedMph)
    if not reportedSpeedMph or reportedSpeedMph < Config.LimpMode.SpeedThresholdMph or reportedSpeedMph > 400 then return end

    local plate = TrimPlate(GetVehicleNumberPlateText(veh))
    local now = os.time()
    if LastReport[plate] and (now - LastReport[plate]) < Config.LimpMode.ReportCooldownSeconds then return end
    LastReport[plate] = now

    local compliance = GetCompliance(plate)
    if compliance.limpMode then return end -- already limping, nothing new to do

    EnsureComplianceRow(plate)
    MySQL.update('UPDATE hd_vehicle_compliance SET limp_mode = 1 WHERE plate = ?', { plate })

    Entity(veh).state:set('hd_limpMode', true, true)
    TriggerClientEvent('hd_mechanic:client:setEngineHealth', -1, tonumber(netId), 'set', Config.LimpMode.EngineHealthOnTrigger)
    Notify(src, 'That hit wrecked your engine — limp mode. Get an advanced repair kit or a mechanic.', 'error')
end)

-- ═══════════════════════════ ADVANCED REPAIR KIT ════════════════════════
-- Fires for EVERY useable item hd_inventory consumes — filter to just
-- ours. The item is already gone from their inventory by this point
-- (hd_inventory's generic useItem handler consumes it unconditionally,
-- same latent limitation every other useable item in this build
-- already has); wasting one on a car that isn't limping just means a
-- clear notification instead of a silent nothing.
AddEventHandler('hd_inventory:server:onItemUsed', function(src, itemName)
    if itemName ~= 'repairkit_advanced' then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then
        Notify(src, "You need to be in the driver's seat of the broken-down vehicle to use that.", 'error')
        return
    end

    local plate = TrimPlate(GetVehicleNumberPlateText(veh))
    local compliance = GetCompliance(plate)
    if not compliance.limpMode then
        Notify(src, "That vehicle isn't in limp mode — kit wasted.", 'error')
        return
    end

    MySQL.update('UPDATE hd_vehicle_compliance SET limp_mode = 0 WHERE plate = ?', { plate })
    Entity(veh).state:set('hd_limpMode', false, true)

    local netId = NetworkGetNetworkIdFromEntity(veh)
    TriggerClientEvent('hd_mechanic:client:setEngineHealth', -1, netId, 'floor', Config.Repair.AdvancedKitFloor)
    Notify(src, 'Engine limped back up — get to a mechanic for a full repair.', 'success')
end)
