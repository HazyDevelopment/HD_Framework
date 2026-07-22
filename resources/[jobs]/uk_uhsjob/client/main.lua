-- ===================================================================
-- client/main.lua
-- Blips + proximity interactions for every station location, plus the
-- garage vehicle spawn/return and armoury draw. Self-contained (no
-- ox_target / qb-target dependency) — proximity marker + [E] to
-- interact.
-- ===================================================================

local inMenu = false
local localOnDuty = false -- tracked client-side too, since ESX has no native duty flag

local INTERACT_KEY = 38 -- E

-- ---------------------------------------------------------------
-- Build one flat list of interaction points across all stations so
-- the proximity loop only has to walk one table.
-- ---------------------------------------------------------------
local interactionPoints = {}

local function addPoint(kind, stationLabel, vec4)
    interactionPoints[#interactionPoints + 1] = {
        kind = kind,
        station = stationLabel,
        coords = vector3(vec4.x, vec4.y, vec4.z),
        label = ( {
            clockin = 'Clock In / Out',
            armoury = 'Open Equipment Store',
            garage  = 'Vehicle Garage',
        } )[kind] or kind,
    }
end

CreateThread(function()
    for _, station in ipairs(Config.Stations) do
        addPoint('clockin', station.label, station.ClockIn)
        addPoint('armoury', station.label, station.Armoury)
        addPoint('garage', station.label, station.Garage.Trigger)
    end
end)

-- ---------------------------------------------------------------
-- Blips
-- ---------------------------------------------------------------
CreateThread(function()
    for _, station in ipairs(Config.Stations) do
        local blip = AddBlipForCoord(station.ClockIn.x, station.ClockIn.y, station.ClockIn.z)
        SetBlipSprite(blip, 61)
        SetBlipColour(blip, 2)
        SetBlipScale(blip, 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Config.DepartmentName .. ' - ' .. station.label)
        EndTextCommandSetBlipName(blip)
    end
end)

-- ---------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------

local function isAmbulanceOnDuty()
    local job = Bridge.GetLocalJob()
    if not job or not job.isAmbulance then return false end
    if not Config.RequireOnDuty then return true end
    if Config.Framework == 'qbcore' then
        return job.onDuty
    else
        return localOnDuty
    end
end

local function drawMarkerAt(coords)
    DrawMarker(2, coords.x, coords.y, coords.z - 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.4, 0.4, 0.4, 220, 30, 30, 150, false, true, 2, false, nil, nil, false)
end

-- ---------------------------------------------------------------
-- Proximity loop
-- ---------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 800
        local job = Bridge.GetLocalJob()

        if job and job.isAmbulance then
            local ped = PlayerPedId()
            local pcoords = GetEntityCoords(ped)

            for _, point in ipairs(interactionPoints) do
                local dist = #(pcoords - point.coords)
                if dist < 8.0 then
                    sleep = 0
                    if dist < 1.6 then
                        drawMarkerAt(point.coords)
                        -- Clock-in doesn't require duty; everything else does.
                        local usable = (point.kind == 'clockin') or isAmbulanceOnDuty()
                        if usable then
                            BeginTextCommandDisplayHelp('STRING')
                            AddTextComponentSubstringPlayerName(('[~INPUT_CONTEXT~] %s'):format(point.label))
                            EndTextCommandDisplayHelp(0, false, true, -1)

                            if IsControlJustReleased(0, INTERACT_KEY) then
                                handleInteraction(point.kind)
                            end
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- ---------------------------------------------------------------
-- Interaction dispatch
-- ---------------------------------------------------------------
function handleInteraction(kind)
    if kind == 'clockin' then
        TriggerServerEvent('ukhs:server:toggleDuty')
    elseif kind == 'armoury' then
        openMenu('armoury')
    elseif kind == 'garage' then
        openMenu('garage')
    end
end

RegisterNetEvent('ukhs:client:dutyChanged', function(onDuty)
    localOnDuty = onDuty
    Bridge.Notify(onDuty and 'You are now on duty.' or 'You are now off duty.', onDuty and 'success' or 'error')
    if not onDuty then
        TriggerServerEvent('ukhs:server:gpsOffDuty')
    end
end)

RegisterNetEvent('ukhs:client:notify', function(msg, kind)
    Bridge.Notify(msg, kind)
end)

-- ===================================================================
-- NUI menu (armoury / garage)
-- ===================================================================

function openMenu(tab)
    inMenu = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', tab = tab, department = Config.DepartmentName })
end

function closeMenu()
    inMenu = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb('ok')
end)

RegisterNUICallback('getLoadout', function(_, cb)
    Bridge.TriggerCallback('ukhs:server:getLoadout', function(result)
        cb(result)
    end)
end)

RegisterNUICallback('drawLoadout', function(_, cb)
    TriggerServerEvent('ukhs:server:drawLoadout')
    cb('ok')
end)

RegisterNUICallback('getGarageVehicles', function(_, cb)
    Bridge.TriggerCallback('ukhs:server:getGarageVehicles', function(result)
        cb(result or {})
    end)
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    Bridge.TriggerCallback('ukhs:server:requestVehicle', function(allowed)
        if not allowed then
            Bridge.Notify('You are not authorized to pull that vehicle.', 'error')
            return cb('denied')
        end
        spawnGarageVehicle(data.model)
        cb('ok')
    end, data.model)
end)

RegisterNUICallback('returnVehicle', function(_, cb)
    returnNearestJobVehicle()
    cb('ok')
end)

-- ===================================================================
-- Garage: spawn / return
-- ===================================================================

local function isGarageVehicleModel(model)
    for _, v in ipairs(Config.GarageVehicles) do
        if joaat(v.model) == model or v.model == model then return true end
    end
    return false
end

function spawnGarageVehicle(modelName)
    local hash = joaat(modelName)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 5000 do
        Wait(50)
        timeout = timeout + 50
    end
    if not HasModelLoaded(hash) then
        Bridge.Notify('Vehicle model failed to load.', 'error')
        return
    end

    -- Find the nearest station's garage to spawn from (whichever
    -- station the player is currently closest to).
    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    local bestStation, bestDist = nil, math.huge
    for _, station in ipairs(Config.Stations) do
        local d = #(pcoords - vector3(station.Garage.Trigger.x, station.Garage.Trigger.y, station.Garage.Trigger.z))
        if d < bestDist then
            bestDist = d
            bestStation = station
        end
    end
    if not bestStation then return end

    local spawnPoint = nil
    for _, sp in ipairs(bestStation.Garage.SpawnPoints) do
        local nearbyVeh = GetClosestVehicle(sp.x, sp.y, sp.z, 2.5, 0, 70)
        if nearbyVeh == 0 then
            spawnPoint = sp
            break
        end
    end
    spawnPoint = spawnPoint or bestStation.Garage.SpawnPoints[1]

    local veh = CreateVehicle(hash, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w, true, false)
    SetVehicleOnGroundProperly(veh)
    SetVehicleNumberPlateText(veh, Config.ShortName .. tostring(math.random(100, 999)))
    SetEntityAsMissionEntity(veh, true, true)
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    SetModelAsNoLongerNeeded(hash)
end

function returnNearestJobVehicle()
    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    local veh = GetClosestVehicle(pcoords.x, pcoords.y, pcoords.z, 6.0, 0, 70)

    if veh == 0 or not DoesEntityExist(veh) then
        Bridge.Notify('No nearby vehicle to return.', 'error')
        return
    end

    local model = GetEntityModel(veh)
    if not isGarageVehicleModel(model) then
        Bridge.Notify('That is not a department vehicle.', 'error')
        return
    end

    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)
    Bridge.Notify('Vehicle returned to the garage.', 'success')
end
