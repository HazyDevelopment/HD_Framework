-- ═══════════════════════════════════════════════════════════════════
--  HD MECHANIC | SHOP — DIAGNOSTICS / FULL REPAIR / MOT / INSURANCE
--  Every event here re-checks IsMechanic(src) and shop proximity
--  itself — the NUI only ever showing action buttons near a shop is a
--  UX nicety, never the real gate. "The customer" is whichever online
--  player's citizenid matches player_vehicles.citizenid for this
--  plate AND is physically at the shop — no offline money mutation,
--  no trusting the client's word on who owns what.
-- ═══════════════════════════════════════════════════════════════════

local function ResolveVehicle(netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    if GetEntityType(veh) ~= 2 then return nil end
    return veh
end

local function FindShop(key)
    for _, s in ipairs(Config.Shops) do
        if s.key == key then return s end
    end
    return nil
end

local function PlayerNearShop(src, shop)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - shop.coords) <= shop.radius
end

local function VehicleNearShop(veh, shop)
    return #(GetEntityCoords(veh) - shop.coords) <= shop.radius
end

local function ShopServicing(src, veh)
    for _, s in ipairs(Config.Shops) do
        if PlayerNearShop(src, s) and VehicleNearShop(veh, s) then return s end
    end
    return nil
end

local function FindOnlineOwner(ownerCitizenId, shop)
    if not ownerCitizenId then return nil end
    for _, srcStr in ipairs(GetPlayers()) do
        local candidate = tonumber(srcStr)
        local CandidatePlayer = Framework.Functions.GetPlayer(candidate)
        if CandidatePlayer and CandidatePlayer.PlayerData.citizenid == ownerCitizenId and PlayerNearShop(candidate, shop) then
            return candidate, CandidatePlayer
        end
    end
    return nil
end

local function ChargeOwner(src, plate, shop, price, reason)
    local ownerRow = MySQL.single.await('SELECT citizenid FROM player_vehicles WHERE plate = ?', { plate })
    if not ownerRow then
        Notify(src, "That vehicle isn't registered — can't bill an owner for it.", 'error')
        return false
    end

    local ownerSrc, OwnerPlayer = FindOnlineOwner(ownerRow.citizenid, shop)
    if not ownerSrc then
        Notify(src, 'The owner needs to be here to pay for this.', 'error')
        return false
    end

    if not OwnerPlayer.Functions.RemoveMoney('bank', price, reason) then
        Notify(src, "Owner doesn't have enough in their bank.", 'error')
        Notify(ownerSrc, ('Insufficient funds for the £%d charge (%s).'):format(price, reason), 'error')
        return false
    end

    if GetResourceState('hd_society') == 'started' then
        exports['hd_society']:AddFunds('mechanic', price)
    end
    Notify(ownerSrc, ('Charged £%d — %s.'):format(price, reason), 'info')
    return true
end

local function BuildDiagnostics(veh)
    local bodyHealth = GetVehicleBodyHealth(veh)
    local engineHealth = GetVehicleEngineHealth(veh)
    local tankHealth = GetVehiclePetrolTankHealth(veh)
    local dirt = GetVehicleDirtLevel(veh)

    local tyres = {}
    for i = 0, 5 do
        tyres[#tyres + 1] = IsVehicleTyreBurst(veh, i, false)
    end

    return {
        plate = TrimPlate(GetVehicleNumberPlateText(veh)),
        model = GetDisplayNameFromVehicleModel(GetEntityModel(veh)),
        bodyPercent = math.floor((math.max(bodyHealth, 0) / 1000) * 100),
        enginePercent = math.floor((math.max(engineHealth, 0) / 1000) * 100),
        tankPercent = math.floor((math.max(tankHealth, 0) / 1000) * 100),
        dirtPercent = math.floor((math.max(dirt, 0) / 15) * 100),
        tyres = tyres,
    }
end

-- ═══════════════════════════ OPEN TERMINAL ═════════════════════════════
RegisterNetEvent('hd_mechanic:server:openTerminal', function(netId)
    local src = source
    if not IsMechanic(src) then
        Notify(src, 'You need to be on duty as a mechanic.', 'error')
        return
    end

    local veh = ResolveVehicle(netId)
    if not veh then
        Notify(src, 'No vehicle found.', 'error')
        return
    end

    local diag = BuildDiagnostics(veh)
    local compliance = GetCompliance(diag.plate)
    local shop = ShopServicing(src, veh)

    TriggerClientEvent('hd_mechanic:client:terminal', src, {
        netId = tonumber(netId),
        diagnostics = diag,
        compliance = compliance,
        canService = shop ~= nil,
        prices = { repair = Config.Repair.FullRepairPrice, mot = Config.MOT.Price, insurance = Config.Insurance.Price },
    })
end)

-- ═══════════════════════════ FULL REPAIR ════════════════════════════════
RegisterNetEvent('hd_mechanic:server:fullRepair', function(netId)
    local src = source
    if not IsMechanic(src) then return end

    local veh = ResolveVehicle(netId)
    if not veh then return end

    local shop = ShopServicing(src, veh)
    if not shop then
        Notify(src, 'Bring the vehicle to the shop first.', 'error')
        return
    end

    local plate = TrimPlate(GetVehicleNumberPlateText(veh))
    if not ChargeOwner(src, plate, shop, Config.Repair.FullRepairPrice, 'Full vehicle repair') then return end

    EnsureComplianceRow(plate)
    MySQL.update('UPDATE player_vehicles SET engine = 1000, body = 1000 WHERE plate = ?', { plate })
    MySQL.update('UPDATE hd_vehicle_compliance SET limp_mode = 0 WHERE plate = ?', { plate })

    Entity(veh).state:set('hd_limpMode', false, true)
    TriggerClientEvent('hd_mechanic:client:fullRepairVisual', -1, tonumber(netId))

    Notify(src, ('Full repair complete on %s.'):format(plate), 'success')
end)

-- ═══════════════════════════ MOT ════════════════════════════════════════
RegisterNetEvent('hd_mechanic:server:issueMOT', function(netId)
    local src = source
    if not IsMechanic(src) then return end

    local veh = ResolveVehicle(netId)
    if not veh then return end

    local shop = ShopServicing(src, veh)
    if not shop then
        Notify(src, 'Bring the vehicle to the shop first.', 'error')
        return
    end

    local diag = BuildDiagnostics(veh)
    if not ChargeOwner(src, diag.plate, shop, Config.MOT.Price, 'MOT test') then return end

    local burst = 0
    for _, isBurst in ipairs(diag.tyres) do if isBurst then burst = burst + 1 end end

    local passed = diag.bodyPercent >= Config.MOT.MinBodyPercent
        and diag.enginePercent >= Config.MOT.MinEnginePercent
        and burst <= Config.MOT.MaxBurstTyres

    if passed then
        EnsureComplianceRow(diag.plate)
        MySQL.update(
            'UPDATE hd_vehicle_compliance SET mot_expiry = DATE_ADD(NOW(), INTERVAL ? DAY) WHERE plate = ?',
            { Config.MOT.DurationDays, diag.plate }
        )
        Notify(src, ('MOT PASS — %s certified for %d days.'):format(diag.plate, Config.MOT.DurationDays), 'success')
    else
        local reasons = {}
        if diag.bodyPercent < Config.MOT.MinBodyPercent then
            reasons[#reasons + 1] = ('bodywork %d%% (need %d%%)'):format(diag.bodyPercent, Config.MOT.MinBodyPercent)
        end
        if diag.enginePercent < Config.MOT.MinEnginePercent then
            reasons[#reasons + 1] = ('engine %d%% (need %d%%)'):format(diag.enginePercent, Config.MOT.MinEnginePercent)
        end
        if burst > Config.MOT.MaxBurstTyres then
            reasons[#reasons + 1] = ('%d burst tyre(s)'):format(burst)
        end
        Notify(src, ('MOT FAIL — %s: %s'):format(diag.plate, table.concat(reasons, ', ')), 'error')
    end
end)

-- ═══════════════════════════ INSURANCE ══════════════════════════════════
RegisterNetEvent('hd_mechanic:server:issueInsurance', function(netId)
    local src = source
    if not IsMechanic(src) then return end

    local veh = ResolveVehicle(netId)
    if not veh then return end

    local shop = ShopServicing(src, veh)
    if not shop then
        Notify(src, 'Bring the vehicle to the shop first.', 'error')
        return
    end

    local plate = TrimPlate(GetVehicleNumberPlateText(veh))
    if not ChargeOwner(src, plate, shop, Config.Insurance.Price, 'Insurance') then return end

    EnsureComplianceRow(plate)
    MySQL.update(
        'UPDATE hd_vehicle_compliance SET insurance_expiry = DATE_ADD(NOW(), INTERVAL ? DAY) WHERE plate = ?',
        { Config.Insurance.DurationDays, plate }
    )
    Notify(src, ('Insurance issued — %s covered for %d days.'):format(plate, Config.Insurance.DurationDays), 'success')
end)
