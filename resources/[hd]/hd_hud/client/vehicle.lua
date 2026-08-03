-- ═══════════════════════════════════════════════════════════════════
--  HD_HUD | CLIENT — VEHICLE HUD + SEATBELT
--  Speedometer (mph), fuel (litres, derived from GetVehicleFuelLevel's
--  0-100 percentage via Config.TankCapacityLitres), gear. Seatbelt:
--  toggle with Config.Seatbelt.ToggleKey (B by default), a repeating
--  warning ding if you're driving unbuckled, and a real consequence —
--  get thrown from the vehicle on a hard impact above EjectSpeedMph
--  while unbuckled, not just a cosmetic reminder.
-- ═══════════════════════════════════════════════════════════════════

-- nil (not false) on purpose — forces one real resync below on the
-- very first loop tick regardless of prior state, so a resource
-- restart (or any dropped 'vehicleShow' message) can never leave the
-- vehicle HUD/minimap frame stuck visible while genuinely on foot.
local inVehicle = nil
local seatbelt = false
local unbuckledSince = 0
local lastWarningAt = 0
local lastSpeedMs = 0.0 -- native units (m/s), used frame-to-frame to detect a hard impact
local lastCompassAt = 0

-- Compass strip on the minimap cluster's header. GTA's own entity
-- heading runs opposite a real-world bearing (turning left increases
-- it), hence the `360 - heading` flip below — if North ever visibly
-- points the wrong way in-game, that's the one line to flip back.
local COMPASS_DIRS = { 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW' }
local function CompassDirection(heading)
    local bearing = (360 - heading) % 360
    local idx = math.floor((bearing + 22.5) / 45) % 8 + 1
    return COMPASS_DIRS[idx]
end

local function StreetLabel(coords)
    local streetHash, crossHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash)
    local cross = crossHash ~= 0 and GetStreetNameFromHashKey(crossHash) or ''
    if street == '' then return '' end
    return (cross ~= '' and cross ~= street) and (street .. ' / ' .. cross) or street
end

local MS_TO_MPH = 2.236936

RegisterKeyMapping('hd_seatbelt', 'Toggle Seatbelt', 'keyboard', Config.Seatbelt.ToggleKey)
RegisterCommand('hd_seatbelt', function()
    if not Config.Seatbelt.Enabled or not inVehicle then return end
    seatbelt = not seatbelt
    if not seatbelt then unbuckledSince = GetGameTimer() end
    Config.Notify(seatbelt and 'Seatbelt on.' or 'Seatbelt off.', seatbelt and 'success' or 'error')
    SendNUIMessage({ action = 'seatbelt', on = seatbelt })
end, false)

-- Thrown clear of the vehicle, not just popped out via the normal exit
-- animation — moving the ped's own coords directly is what actually
-- detaches it from the vehicle seat in the engine; the ragdoll after
-- is what sells "thrown", not what causes the detach itself.
local function EjectFromVehicle(veh)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(veh)
    SetEntityCoordsNoOffset(ped, coords.x + forward.x * 2.5, coords.y + forward.y * 2.5, coords.z + 1.2, false, false, false)
    SetPedToRagdoll(ped, 1500, 1500, 0, false, false, false)
    local health = GetEntityHealth(ped)
    SetEntityHealth(ped, math.max(105, health - 60)) -- hurts badly, deliberately not an instant kill
    Config.Notify('Thrown from the vehicle — no seatbelt.', 'error')
end

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()

        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if inVehicle ~= true then
                inVehicle = true
                seatbelt = false
                unbuckledSince = GetGameTimer()
                lastSpeedMs = GetEntitySpeed(veh)
                SendNUIMessage({ action = 'vehicleShow', show = true })
                SendNUIMessage({ action = 'seatbelt', on = false })
            end
            sleep = 0

            local speedMs = GetEntitySpeed(veh)
            local speedMph = speedMs * MS_TO_MPH
            local fuelPct = GetVehicleFuelLevel(veh)
            local litres = (fuelPct / 100.0) * Config.TankCapacityLitres
            local gear = GetVehicleCurrentGear(veh)

            SendNUIMessage({
                action = 'vehicleUpdate',
                speed = math.floor(speedMph + 0.5),
                maxSpeed = Config.SpeedoMaxMph,
                fuel = math.floor(litres + 0.5),
                tank = Config.TankCapacityLitres,
                gear = gear,
                engineOn = GetIsVehicleEngineRunning(veh),
            })

            -- Throttled — a street-name lookup is heavier than the
            -- speedo/fuel reads above, and it only needs to feel
            -- responsive, not frame-perfect.
            local now2 = GetGameTimer()
            if now2 - lastCompassAt > 1000 then
                lastCompassAt = now2
                SendNUIMessage({
                    action = 'compass',
                    heading = CompassDirection(GetEntityHeading(veh)),
                    street = StreetLabel(GetEntityCoords(veh)),
                })
            end

            if Config.Seatbelt.Enabled then
                if not seatbelt then
                    local now = GetGameTimer()
                    if now - unbuckledSince > Config.Seatbelt.WarningDelayMs and now - lastWarningAt > Config.Seatbelt.WarningIntervalMs then
                        lastWarningAt = now
                        PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
                    end

                    -- A hard single-frame speed drop while genuinely fast and
                    -- unbuckled — a wall/head-on hit does exactly this; normal
                    -- braking never drops this much in one frame.
                    local delta = lastSpeedMs - speedMs
                    if delta > Config.Seatbelt.EjectDecelPerFrame and (lastSpeedMs * MS_TO_MPH) > Config.Seatbelt.EjectSpeedMph then
                        EjectFromVehicle(veh)
                        inVehicle = false
                        SendNUIMessage({ action = 'vehicleShow', show = false })
                    end
                end
            end

            lastSpeedMs = speedMs
        elseif inVehicle ~= false then
            inVehicle = false
            SendNUIMessage({ action = 'vehicleShow', show = false })
        end

        Wait(sleep)
    end
end)
