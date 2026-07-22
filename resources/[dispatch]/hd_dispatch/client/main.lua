-- ═══════════════════════════════════════════════════════════════════
--  HD DISPATCH | CLIENT
--  Renders the live call board, handles the civilian 999/recovery
--  call menus, drops map blips for every call this player is
--  eligible to see, and reports shots-fired / player-downed to the
--  server for automatic call creation.
-- ═══════════════════════════════════════════════════════════════════

local Framework = nil
CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

local nuiOpen = false      -- dispatch board
local menuOpen = false     -- civilian call-menu modal
local blips = {}           -- [callId] = blip handle

-- ═══════════════════════════ HELPERS ═════════════════════════════════
local function GetJob()
    local pd = Framework.Functions.GetPlayerData()
    return pd and pd.job or nil
end

local function IsEligibleResponder()
    local job = GetJob()
    if not job then return false end
    for kind, ct in pairs(Config.CallTypes) do
        if ct.jobType and job.type == ct.jobType then return true end
        for _, j in ipairs(ct.jobs) do
            if j == job.name then return true end
        end
    end
    return false
end

local function ClearAllBlips()
    for _, blip in pairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    blips = {}
end

local function UpsertBlip(call)
    local ct = Config.CallTypes[call.kind]
    if not ct or not call.coords then return end

    if blips[call.id] and DoesBlipExist(blips[call.id]) then
        RemoveBlip(blips[call.id])
    end

    local blip = AddBlipForCoord(call.coords.x, call.coords.y, call.coords.z)
    SetBlipSprite(blip, ct.blipSprite)
    SetBlipColour(blip, ct.blipColor)
    SetBlipScale(blip, 0.9)
    SetBlipAsShortRange(blip, false)
    if call.status == 'open' then ShowNumberOnBlip(blip, 1) end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(('%s — %s'):format(ct.code, call.title))
    EndTextCommandSetBlipName(blip)
    blips[call.id] = blip
end

local function RemoveBlipFor(id)
    if blips[id] and DoesBlipExist(blips[id]) then RemoveBlip(blips[id]) end
    blips[id] = nil
end

-- ═══════════════════════════ DISPATCH BOARD ══════════════════════════
local function OpenBoard()
    if not IsEligibleResponder() then
        Config.Notify('You have no dispatch access on your current job.', 'error')
        return
    end
    nuiOpen = true
    SetNuiFocus(true, true)
    local job = GetJob()
    SendNUIMessage({ action = 'openBoard', callTypes = Config.CallTypes, grades = Config.PriorityGrades, job = job, mySrc = GetPlayerServerId(PlayerId()) })
    TriggerServerEvent('hd_dispatch:server:requestSync')
end

local function CloseBoard()
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeBoard' })
end

RegisterKeyMapping('hd_dispatch_board', 'HD Dispatch: toggle board', 'keyboard', Config.Keybind)
RegisterCommand('hd_dispatch_board', function()
    if menuOpen then return end
    if nuiOpen then CloseBoard() else OpenBoard() end
end, false)

-- ═══════════════════════════ CIVILIAN CALL MENUS ═════════════════════
RegisterCommand(Config.Commands.call999, function()
    if nuiOpen or menuOpen then return end
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openCallMenu', mode = '999', callTypes = Config.CallTypes })
end, false)

RegisterCommand(Config.Commands.recovery, function()
    if nuiOpen or menuOpen then return end
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        veh = GetVehiclePedIsIn(ped, true) -- last vehicle, covers "just got out to flag someone down"
    end
    local plate = veh ~= 0 and GetVehicleNumberPlateText(veh):gsub('%s+$', '') or nil
    if not plate then
        Config.Notify('You need to be in or right next to your vehicle to request recovery.', 'error')
        return
    end
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openCallMenu', mode = 'recovery', plate = plate })
end, false)

-- ═══════════════════════════ NUI CALLBACKS ════════════════════════════
RegisterNUICallback('closeUI', function(_, cb)
    nuiOpen = false
    menuOpen = false
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNUICallback('submit999', function(data, cb)
    TriggerServerEvent('hd_dispatch:server:call999', { type = data.type, description = data.description })
    menuOpen = false
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNUICallback('submitRecovery', function(data, cb)
    TriggerServerEvent('hd_dispatch:server:requestRecovery', { plate = data.plate, description = data.description })
    menuOpen = false
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNUICallback('acceptCall', function(data, cb)
    TriggerServerEvent('hd_dispatch:server:acceptCall', data.id)
    cb({})
end)

RegisterNUICallback('setStatus', function(data, cb)
    TriggerServerEvent('hd_dispatch:server:setStatus', data.id, data.status)
    cb({})
end)

RegisterNUICallback('closeCall', function(data, cb)
    TriggerServerEvent('hd_dispatch:server:closeCall', data.id)
    cb({})
end)

RegisterNUICallback('setWaypoint', function(data, cb)
    if data.coords then
        SetNewWaypoint(data.coords.x + 0.0, data.coords.y + 0.0)
    end
    cb({})
end)

-- ═══════════════════════════ SERVER → CLIENT ══════════════════════════
RegisterNetEvent('hd_dispatch:client:newCall', function(call)
    UpsertBlip(call)
    SendNUIMessage({ action = 'newCall', call = call })
    if Config.Sound.Enabled then SendNUIMessage({ action = 'alertSound' }) end
end)

RegisterNetEvent('hd_dispatch:client:updateCall', function(call)
    UpsertBlip(call)
    SendNUIMessage({ action = 'updateCall', call = call })
end)

RegisterNetEvent('hd_dispatch:client:removeCall', function(id)
    RemoveBlipFor(id)
    SendNUIMessage({ action = 'removeCall', id = id })
end)

RegisterNetEvent('hd_dispatch:client:syncCalls', function(calls)
    ClearAllBlips()
    for _, call in ipairs(calls) do UpsertBlip(call) end
    SendNUIMessage({ action = 'sync', calls = calls })
end)

RegisterNetEvent('hd_dispatch:client:callConfirmed', function(_, label)
    Config.Notify(('Your call has been logged with %s dispatch.'):format(label), 'success')
end)

-- Re-sync whenever job/duty changes (HD_Framework's own event, fired
-- directly — no bridge in between) so going on duty picks up existing
-- calls and going off duty / changing job clears ones you're no
-- longer eligible for.
AddEventHandler('HD:Client:OnPlayerDataUpdate', function()
    if IsEligibleResponder() then
        TriggerServerEvent('hd_dispatch:server:requestSync')
    else
        ClearAllBlips()
        if nuiOpen then CloseBoard() end
    end
end)

-- ═══════════════════════════ AUTOMATIC TRIGGERS ═══════════════════════
if Config.AutoTriggers.ShotsFired.Enabled then
    CreateThread(function()
        local lastSent = 0
        while true do
            Wait(0)
            local ped = PlayerPedId()
            if IsPedShooting(ped) then
                local now = GetGameTimer()
                if (now - lastSent) > 3000 then -- local throttle; server enforces the real cooldown/merge
                    lastSent = now
                    TriggerServerEvent('hd_dispatch:server:shotsFired', GetEntityCoords(ped))
                end
            else
                Wait(200)
            end
        end
    end)
end

if Config.AutoTriggers.PlayerDowned.Enabled then
    -- baseevents (a default cfx resource, ensured in server.cfg) fires
    -- this on vanilla death. If a dedicated medical/revive system is
    -- added later (uk_uhsjob ships its own client/revive.lua), point
    -- its "player is now downed" moment at
    -- TriggerServerEvent('hd_dispatch:server:playerDowned') instead —
    -- that'll be more accurate than the vanilla death event.
    AddEventHandler('baseevents:onPlayerDied', function()
        TriggerServerEvent('hd_dispatch:server:playerDowned')
    end)
end
