-- ═══════════════════════════════════════════════════════════════════
--  HD MECHANIC | COMPLIANCE (MOT / INSURANCE / LIMP MODE)
--  One row per plate in hd_vehicle_compliance. Validity is always
--  computed in SQL (`expiry IS NOT NULL AND expiry > NOW()`), never
--  pulled into Lua and compared, same reasoning hd_admin's ban expiry
--  check already documents — sidesteps any timezone/parsing mismatch.
-- ═══════════════════════════════════════════════════════════════════

function EnsureComplianceRow(plate)
    MySQL.query.await('INSERT IGNORE INTO hd_vehicle_compliance (plate) VALUES (?)', { plate })
end

-- Returns { motValid, motExpiry, insuranceValid, insuranceExpiry, limpMode }
function GetCompliance(plate)
    EnsureComplianceRow(plate)
    local row = MySQL.single.await(
        [[SELECT
            (mot_expiry IS NOT NULL AND mot_expiry > NOW()) AS motValid, mot_expiry AS motExpiry,
            (insurance_expiry IS NOT NULL AND insurance_expiry > NOW()) AS insuranceValid, insurance_expiry AS insuranceExpiry,
            limp_mode AS limpMode
        FROM hd_vehicle_compliance WHERE plate = ?]],
        { plate }
    )
    if not row then
        return { motValid = false, motExpiry = nil, insuranceValid = false, insuranceExpiry = nil, limpMode = false }
    end
    return {
        motValid = row.motValid == 1,
        motExpiry = row.motExpiry,
        insuranceValid = row.insuranceValid == 1,
        insuranceExpiry = row.insuranceExpiry,
        limpMode = row.limpMode == 1,
    }
end

-- Called by hd_cardealer right after a purchase — brand new cars get
-- a short grace period of temp MOT + insurance so they're legal long
-- enough to actually reach a shop.
exports('InitTempCompliance', function(plate)
    if type(plate) ~= 'string' or plate == '' then return end
    EnsureComplianceRow(plate)
    MySQL.update(
        'UPDATE hd_vehicle_compliance SET mot_expiry = DATE_ADD(NOW(), INTERVAL ? HOUR), insurance_expiry = DATE_ADD(NOW(), INTERVAL ? HOUR) WHERE plate = ?',
        { Config.TempCompliance.Hours, Config.TempCompliance.Hours, plate }
    )
end)

-- For other resources to check without going through the NUI — e.g.
-- hazy_mdt's vehicle search enriches its results with this.
exports('GetCompliance', function(plate)
    return GetCompliance(TrimPlate(plate))
end)

-- ═══════════════════════════ /vehiclestatus (self-service) ═════════════
-- Lightweight, no NUI, no mechanic gate — anyone can check their own
-- current vehicle's MOT/insurance/limp state without a mechanic online.
RegisterNetEvent('hd_mechanic:server:getStatus', function(netId)
    local src = source
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return end

    local plate = TrimPlate(GetVehicleNumberPlateText(veh))
    TriggerClientEvent('hd_mechanic:client:status', src, plate, GetCompliance(plate))
end)
