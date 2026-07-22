-- ═══════════════════════════════════════════════════════════════════
--  HD CIVJOBS | CLIENT
--  Pure rendering + input relay — every bit of actual state (which
--  stop you're on, what counts as "close enough", whether you get
--  paid) lives server-side in server/main.lua. This file just draws
--  blips/prompts for whatever the server says the current stop is.
-- ═══════════════════════════════════════════════════════════════════

CreateThread(function()
    while GetResourceState('qb-core') ~= 'started' do Wait(100) end
end)

local CurrentContract = nil
local Blips = {}

local function ClearBlips()
    for _, b in ipairs(Blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    Blips = {}
end

local function RenderStops(contract)
    ClearBlips()
    CurrentContract = contract
    local stop = contract.stops[contract.stopIndex]
    if not stop then return end

    local routeSet = false
    for i, point in ipairs(stop.points) do
        if not contract.visited[i] then
            local blip = AddBlipForCoord(point.x, point.y, point.z)
            SetBlipSprite(blip, 1)
            SetBlipColour(blip, 5)
            SetBlipScale(blip, 0.9)
            if not routeSet then
                SetBlipRoute(blip, true)
                SetBlipRouteColour(blip, 5)
                routeSet = true
            end
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(stop.label)
            EndTextCommandSetBlipName(blip)
            Blips[#Blips + 1] = blip
        end
    end
end

local function SpawnJobVehicle(model, spawn)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local waited = 0
    while not HasModelLoaded(hash) and waited < 5000 do Wait(50) waited = waited + 50 end
    if not HasModelLoaded(hash) then
        Config.Notify('Could not load the job vehicle model.', 'error')
        return
    end
    local veh = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetModelAsNoLongerNeeded(hash)
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
end

-- ═══════════════════════════ COMMANDS ═════════════════════════════════
RegisterCommand('startshift', function() TriggerServerEvent('hd_civjobs:server:startShift') end, false)
RegisterCommand('endshift', function() TriggerServerEvent('hd_civjobs:server:cancelShift') end, false)

RegisterKeyMapping('hd_civjobs_interact', 'HD Jobs: interact with current stop', 'keyboard', Config.Keybind)
RegisterCommand('hd_civjobs_interact', function() TriggerServerEvent('hd_civjobs:server:interact') end, false)

-- ═══════════════════════════ SERVER EVENTS ════════════════════════════
RegisterNetEvent('hd_civjobs:client:contractStarted', function(contract, vehicleModel, depot)
    if vehicleModel and depot then SpawnJobVehicle(vehicleModel, depot.spawn) end
    RenderStops(contract)
    Config.Notify('Shift started — follow the GPS route.', 'success')
end)

RegisterNetEvent('hd_civjobs:client:contractUpdate', function(contract)
    RenderStops(contract)
end)

RegisterNetEvent('hd_civjobs:client:contractEnded', function()
    ClearBlips()
    CurrentContract = nil
end)

-- ═══════════════════════════ ON-FOOT PROMPT ═══════════════════════════
local function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 220)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(sx, sy)
end

CreateThread(function()
    while true do
        local sleep = 500
        if CurrentContract then
            local stop = CurrentContract.stops[CurrentContract.stopIndex]
            if stop then
                local pcoords = GetEntityCoords(PlayerPedId())
                for i, point in ipairs(stop.points) do
                    if not CurrentContract.visited[i] then
                        local dist = #(pcoords - point)
                        if dist < 15.0 then
                            sleep = 0
                            if dist < Config.InteractRadius then
                                DrawText3D(point.x, point.y, point.z + 1.0, ('[%s] %s'):format(Config.Keybind, stop.label))
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
