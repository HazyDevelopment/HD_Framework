-- ═══════════════════════════════════════════════════════════════════
--  hd_ems | client/job.lua
--  Station blips + clock-in/armoury/garage proximity interactions and
--  the garage vehicle spawn/return. `Framework` is the same global
--  client/main.lua already waits on and assigns — no second wait loop
--  needed here since job.lua loads after main.lua (see fxmanifest.lua).
-- ═══════════════════════════════════════════════════════════════════

local INTERACT_KEY = 38 -- E
local inMenu = false

local interactionPoints = {}

local function addPoint(kind, stationLabel, vec4)
    interactionPoints[#interactionPoints + 1] = {
        kind = kind,
        station = stationLabel,
        coords = vector3(vec4.x, vec4.y, vec4.z),
        label = ({
            clockin = 'Clock In / Out',
            armoury = 'Open Equipment Store',
            garage  = 'Vehicle Garage',
        })[kind] or kind,
    }
end

CreateThread(function()
    for _, station in ipairs(Config.Stations) do
        addPoint('clockin', station.label, station.ClockIn)
        addPoint('armoury', station.label, station.Armoury)
        addPoint('garage', station.label, station.Garage.Trigger)
    end
end)

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

local function IsAmbulance()
    if not Framework then return false end
    local pd = Framework.Functions.GetPlayerData()
    return pd and pd.job and pd.job.name == Config.AmbulanceJob
end

local function IsAmbulanceOnDuty()
    if not IsAmbulance() then return false end
    if not Config.RequireOnDuty then return true end
    return Framework.Functions.GetPlayerData().job.onduty
end

local function drawMarkerAt(coords)
    DrawMarker(2, coords.x, coords.y, coords.z - 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.4, 0.4, 0.4, 220, 30, 30, 150, false, true, 2, false, nil, nil, false)
end

function handleInteraction(kind)
    if kind == 'clockin' then
        TriggerServerEvent('hd_ems:server:toggleDuty')
    elseif kind == 'armoury' then
        openMenu('armoury')
    elseif kind == 'garage' then
        openMenu('garage')
    end
end

CreateThread(function()
    while true do
        local sleep = 800
        if IsAmbulance() and not inMenu then
            local ped = PlayerPedId()
            local pcoords = GetEntityCoords(ped)

            for _, point in ipairs(interactionPoints) do
                local dist = #(pcoords - point.coords)
                if dist < Config.InteractDistance then
                    sleep = 0
                    if dist < Config.InteractPressDistance then
                        drawMarkerAt(point.coords)
                        -- Clock-in doesn't require duty; everything else does.
                        local usable = (point.kind == 'clockin') or IsAmbulanceOnDuty()
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

RegisterNetEvent('hd_ems:client:dutyChanged', function(onDuty)
    TriggerEvent('HD:Client:Notify', onDuty and 'You are now on duty.' or 'You are now off duty.', onDuty and 'success' or 'error')
    if not onDuty then
        TriggerServerEvent('ukhs:server:gpsOffDuty')
    end
end)

-- ═══════════════════════════════════════════════════════════════════
-- NUI menu (armoury / garage)
-- ═══════════════════════════════════════════════════════════════════

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
    Framework.Functions.TriggerCallback('hd_ems:server:getLoadout', function(result)
        cb(result)
    end)
end)

RegisterNUICallback('drawLoadout', function(_, cb)
    TriggerServerEvent('hd_ems:server:drawLoadout')
    cb('ok')
end)

RegisterNUICallback('getGarageVehicles', function(_, cb)
    Framework.Functions.TriggerCallback('hd_ems:server:getGarageVehicles', function(result)
        cb(result or {})
    end)
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    Framework.Functions.TriggerCallback('hd_ems:server:requestVehicle', function(allowed)
        if not allowed then
            TriggerEvent('HD:Client:Notify', 'You are not authorized to pull that vehicle.', 'error')
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

-- ═══════════════════════════════════════════════════════════════════
-- Garage: spawn / return
-- ═══════════════════════════════════════════════════════════════════

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
        TriggerEvent('HD:Client:Notify', 'Vehicle model failed to load.', 'error')
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
        TriggerEvent('HD:Client:Notify', 'No nearby vehicle to return.', 'error')
        return
    end

    local model = GetEntityModel(veh)
    if not isGarageVehicleModel(model) then
        TriggerEvent('HD:Client:Notify', 'That is not a department vehicle.', 'error')
        return
    end

    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)
    TriggerEvent('HD:Client:Notify', 'Vehicle returned to the garage.', 'success')
end
