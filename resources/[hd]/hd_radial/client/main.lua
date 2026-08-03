-- ═══════════════════════════════════════════════════════════════════
--  HD RADIAL | CLIENT
--  F1 opens the hub; picking a category sends its item list to the
--  NUI; picking an item runs it through RunAction below and closes
--  the menu. No server round-trip for the menu itself — only specific
--  actions (job duty toggles) talk to a server event.
-- ═══════════════════════════════════════════════════════════════════

Framework = nil
CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

local menuOpen = false

local function GetJob()
    if not Framework then return nil end
    local pd = Framework.Functions.GetPlayerData()
    return pd and pd.job or nil
end

-- ═══════════════════════════ WORK (dynamic per job) ═══════════════════
local function BuildWorkItems()
    local job = GetJob()
    local items = {}
    if job then
        items[#items + 1] = { id = 'jobinfo', label = 'Job Info', sub = job.grade and job.grade.name or job.name }
        if Config.WorkDutyEvents[job.name] then
            items[#items + 1] = { id = 'toggleduty', label = job.onduty and 'Go Off Duty' or 'Go On Duty' }
        end
    else
        items[#items + 1] = { id = 'jobinfo', label = 'Unemployed' }
    end
    return items
end

-- ═══════════════════════════ OPEN / CLOSE ════════════════════════════
local function OpenMenu()
    if menuOpen then return end
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        categories = Config.Categories,
        emotes = Config.Emotes,
        interactions = Config.Interactions,
        walkstyles = Config.Walkstyles,
        general = Config.General,
        gps = Config.GPS,
        work = BuildWorkItems(),
    })
end

local function CloseMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterCommand('hd_radial:toggle', function()
    if menuOpen then CloseMenu() else OpenMenu() end
end, false)
RegisterKeyMapping('hd_radial:toggle', 'Open interaction menu', 'keyboard', Config.OpenKey)

RegisterNUICallback('close', function(_, cb)
    CloseMenu()
    cb({})
end)

-- ═══════════════════════════ ACTIONS ═════════════════════════════════
local currentScenario = nil
local crouching = false

local function StopCurrentScenario()
    if not currentScenario then return end
    ClearPedTasks(PlayerPedId())
    currentScenario = nil
end

local function RunEmote(entry)
    local ped = PlayerPedId()
    if currentScenario == entry.scenario then
        StopCurrentScenario()
        return
    end
    StopCurrentScenario()
    TaskStartScenarioInPlace(ped, entry.scenario, 0, true)
    currentScenario = entry.scenario
end

-- Cancel the ambient scenario the moment the player actually moves —
-- TaskStartScenarioInPlace already breaks on input by itself for most
-- scenarios, this just keeps our own currentScenario bookkeeping in
-- sync so pressing the same emote again correctly restarts it instead
-- of looking like a no-op toggle-off.
CreateThread(function()
    while true do
        Wait(500)
        if currentScenario then
            local ped = PlayerPedId()
            if not IsPedUsingScenario(ped, currentScenario) then
                currentScenario = nil
            end
        end
    end
end)

local function RunInteraction(entry)
    if entry.type == 'handsup' then
        exports['HD_Framework']:ToggleHandsUp()
    elseif entry.type == 'crouch' then
        crouching = not crouching
        SetPedStealthMovement(PlayerPedId(), crouching, 0)
        Config.Notify(crouching and 'Crouching.' or 'Standing up.', 'info')
    end
end

local function RunWalkstyle(entry)
    local ped = PlayerPedId()
    if not entry.clipset then
        ResetPedMovementClipset(ped, 0.0)
        return
    end
    RequestClipSet(entry.clipset)
    local waited = 0
    while not HasClipSetLoaded(entry.clipset) and waited < 1000 do Wait(10) waited = waited + 10 end
    if HasClipSetLoaded(entry.clipset) then
        SetPedMovementClipset(ped, entry.clipset, 0.0)
    end
end

local function RunGeneral(entry)
    if entry.type == 'command' then
        ExecuteCommand(entry.command)
        return
    end

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        Config.Notify('You need to be in a vehicle for that.', 'error')
        return
    end

    if entry.type == 'engine' then
        SetVehicleEngineOn(veh, not GetIsVehicleEngineRunning(veh), false, true)
    elseif entry.type == 'lockvehicle' then
        if GetResourceState('HD_vehiclekeys') == 'started' then
            ExecuteCommand('lock')
        else
            Config.Notify('Vehicle locking is not installed.', 'error')
        end
    elseif entry.type == 'vehicledoor' then
        local isOpen = GetVehicleDoorAngleRatio(veh, entry.door) > 0.05
        if isOpen then SetVehicleDoorShut(veh, entry.door, false)
        else SetVehicleDoorOpen(veh, entry.door, false, false) end
    end
end

local function RunGps(entry)
    if entry.type == 'clearwaypoint' then
        SetWaypointOff()
        return
    end
    SetNewWaypoint(entry.coords.x, entry.coords.y)
    Config.Notify(('Waypoint set: %s'):format(entry.label), 'success')
end

local function RunWork(entry)
    local job = GetJob()
    if entry.id == 'toggleduty' and job and Config.WorkDutyEvents[job.name] then
        TriggerServerEvent(Config.WorkDutyEvents[job.name])
    elseif entry.id == 'jobinfo' then
        Config.Notify(job and ('%s — %s'):format(job.label, job.grade.name) or 'Unemployed', 'info')
    end
end

RegisterNUICallback('runAction', function(data, cb)
    local category, entry = data.category, data.item
    if category == 'emotes' then RunEmote(entry)
    elseif category == 'interactions' then RunInteraction(entry)
    elseif category == 'walkstyle' then RunWalkstyle(entry)
    elseif category == 'general' then RunGeneral(entry)
    elseif category == 'gps' then RunGps(entry)
    elseif category == 'work' then RunWork(entry)
    end
    CloseMenu()
    cb({})
end)
