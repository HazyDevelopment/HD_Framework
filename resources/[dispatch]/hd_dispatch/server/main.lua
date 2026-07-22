-- ═══════════════════════════════════════════════════════════════════
--  HD DISPATCH | SERVER
--  Owns the live call board. Every call — a 999 report, a recovery
--  request, or an automatic shots-fired/player-downed alert — lives
--  in `Calls` until closed. Eligibility is re-checked server-side on
--  every accept/close, never trusted from the client.
-- ═══════════════════════════════════════════════════════════════════

local Framework = nil
CreateThread(function()
    while GetResourceState('qb-core') ~= 'started' do Wait(100) end
    Framework = exports['qb-core']:GetCoreObject()
end)

local Calls = {}
local nextId = 1
local shotsCooldown = {} -- [src] = GetGameTimer() of last accepted shot report

local function ToVec(c)
    return { x = c.x, y = c.y, z = c.z }
end

local function PlayerName(Player)
    local ci = Player.PlayerData.charinfo
    return (ci.firstname or '?') .. ' ' .. (ci.lastname or '?')
end

-- ═══════════════════════════ ELIGIBILITY ═════════════════════════════
local function JobMatchesCallType(jobData, kind)
    local ct = Config.CallTypes[kind]
    if not ct or not jobData then return false end
    if ct.jobType and jobData.type == ct.jobType then return true end
    for _, j in ipairs(ct.jobs) do
        if j == jobData.name then return true end
    end
    return false
end

local function GetEligibleSources(kind)
    local list = {}
    for src, Player in pairs(Framework.Players) do
        local job = Player.PlayerData.job
        if JobMatchesCallType(job, kind) and (not Config.RequireDuty or job.onduty) then
            list[#list + 1] = src
        end
    end
    return list
end

-- ═══════════════════════════ CALL LIFECYCLE ══════════════════════════
local function CreateCall(kind, opts)
    if not Config.CallTypes[kind] then return nil end
    local id = nextId
    nextId = nextId + 1

    local call = {
        id = id,
        kind = kind,
        priority = opts.priority or Config.DefaultPriority,
        title = opts.title or Config.CallTypes[kind].label,
        description = opts.description or '',
        coords = opts.coords,
        caller = opts.caller, -- { name, src } or nil for anonymous/automatic calls
        autoType = opts.autoType,
        created = os.time(),
        assigned = {}, -- { { src, name }, ... }
        status = 'open', -- open | enroute | onscene | closed
    }
    Calls[id] = call

    local targets = GetEligibleSources(kind)
    for _, src in ipairs(targets) do
        TriggerClientEvent('hd_dispatch:client:newCall', src, call)
    end
    return call, targets
end

-- For other resources to raise an incident without going through a
-- client-facing call flow — e.g. HD_vehiclekeys reporting a vehicle
-- break-in. Same `opts` shape as everywhere else in this file
-- (title/description/coords/priority/autoType); `coords` should
-- already be a plain {x,y,z} table (see the local ToVec helper above
-- if you have a vector3 instead).
exports('CreateCall', function(kind, opts)
    return CreateCall(kind, opts or {})
end)

local function BroadcastUpdate(call)
    for _, src in ipairs(GetEligibleSources(call.kind)) do
        TriggerClientEvent('hd_dispatch:client:updateCall', src, call)
    end
end

local function CloseCall(id)
    local call = Calls[id]
    if not call then return end
    call.status = 'closed'
    for _, src in ipairs(GetEligibleSources(call.kind)) do
        TriggerClientEvent('hd_dispatch:client:removeCall', src, id)
    end
    Calls[id] = nil
end

-- ═══════════════════════════ CIVILIAN-INITIATED CALLS ════════════════
-- 999: police or ambulance.
RegisterNetEvent('hd_dispatch:server:call999', function(payload)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end
    if payload.type ~= 'police' and payload.type ~= 'ems' then return end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local desc = (type(payload.description) == 'string' and payload.description ~= '') and payload.description:sub(1, 200) or 'No further details given.'

    local call = CreateCall(payload.type, {
        description = desc,
        coords = ToVec(coords),
        caller = { name = PlayerName(Player), src = src },
    })
    if call then
        TriggerClientEvent('hd_dispatch:client:callConfirmed', src, call.id, Config.CallTypes[payload.type].label)
    end
end)

-- Recovery: request a mechanic (any job.type == 'mechanic') to their location.
RegisterNetEvent('hd_dispatch:server:requestRecovery', function(payload)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local plate = type(payload.plate) == 'string' and payload.plate:sub(1, 15) or 'Unknown plate'
    local desc = (type(payload.description) == 'string' and payload.description ~= '') and payload.description:sub(1, 200) or 'Vehicle broken down.'

    local call = CreateCall('recovery', {
        title = ('Vehicle Recovery — %s'):format(plate),
        description = desc,
        coords = ToVec(coords),
        priority = 3,
        caller = { name = PlayerName(Player), src = src },
    })
    if call then
        TriggerClientEvent('hd_dispatch:client:callConfirmed', src, call.id, 'Vehicle Recovery')
    end
end)

-- ═══════════════════════════ RESPONDER ACTIONS ═══════════════════════
RegisterNetEvent('hd_dispatch:server:acceptCall', function(id)
    local src = source
    local call = Calls[id]
    local Player = Framework.Functions.GetPlayer(src)
    if not call or call.status == 'closed' or not Player then return end
    if not JobMatchesCallType(Player.PlayerData.job, call.kind) then return end
    if Config.RequireDuty and not Player.PlayerData.job.onduty then return end

    for _, u in ipairs(call.assigned) do
        if u.src == src then return end -- already assigned
    end

    table.insert(call.assigned, { src = src, name = PlayerName(Player) })
    if call.status == 'open' then call.status = 'enroute' end
    BroadcastUpdate(call)

    if call.caller and call.caller.src then
        TriggerClientEvent('HD:Client:Notify', call.caller.src, ('%s is responding to your call.'):format(PlayerName(Player)), 'success')
    end
end)

RegisterNetEvent('hd_dispatch:server:setStatus', function(id, status)
    if status ~= 'enroute' and status ~= 'onscene' then return end
    local src = source
    local call = Calls[id]
    if not call or call.status == 'closed' then return end

    local isAssigned = false
    for _, u in ipairs(call.assigned) do
        if u.src == src then isAssigned = true break end
    end
    if not isAssigned then return end

    call.status = status
    BroadcastUpdate(call)
end)

RegisterNetEvent('hd_dispatch:server:closeCall', function(id)
    local src = source
    local call = Calls[id]
    if not call then return end

    local isAssigned = false
    for _, u in ipairs(call.assigned) do
        if u.src == src then isAssigned = true break end
    end
    if not isAssigned and not IsPlayerAceAllowed(src, 'hd.admin') then return end

    CloseCall(id)
end)

-- ═══════════════════════════ SYNC ON OPEN / GOING ON DUTY ════════════
RegisterNetEvent('hd_dispatch:server:requestSync', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end
    local job = Player.PlayerData.job
    if Config.RequireDuty and not job.onduty then
        TriggerClientEvent('hd_dispatch:client:syncCalls', src, {})
        return
    end

    local relevant = {}
    for _, call in pairs(Calls) do
        if JobMatchesCallType(job, call.kind) then
            relevant[#relevant + 1] = call
        end
    end
    TriggerClientEvent('hd_dispatch:client:syncCalls', src, relevant)
end)

-- ═══════════════════════════ AUTOMATIC CALLS ══════════════════════════
RegisterNetEvent('hd_dispatch:server:shotsFired', function(coords)
    if not Config.AutoTriggers.ShotsFired.Enabled then return end
    local src = source
    local now = GetGameTimer()
    if shotsCooldown[src] and (now - shotsCooldown[src]) < (Config.AutoTriggers.ShotsFired.CooldownSeconds * 1000) then return end
    shotsCooldown[src] = now

    local vec = ToVec(coords)
    for _, call in pairs(Calls) do
        if call.kind == 'police' and call.autoType == 'shots' and call.status ~= 'closed' then
            local dx, dy, dz = call.coords.x - vec.x, call.coords.y - vec.y, call.coords.z - vec.z
            if math.sqrt(dx * dx + dy * dy + dz * dz) <= Config.AutoTriggers.ShotsFired.MergeRadius then
                return -- folded into the existing nearby call, no new card
            end
        end
    end

    CreateCall('police', {
        title = 'Shots Fired',
        description = 'Gunfire reported in the area. Caller identity withheld.',
        coords = vec,
        priority = Config.AutoTriggers.ShotsFired.Priority,
        autoType = 'shots',
    })
end)

RegisterNetEvent('hd_dispatch:server:playerDowned', function()
    if not Config.AutoTriggers.PlayerDowned.Enabled then return end
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)

    CreateCall('ems', {
        title = 'Medical Emergency',
        description = ('%s has gone down and needs urgent medical attention.'):format(PlayerName(Player)),
        coords = ToVec(coords),
        priority = Config.AutoTriggers.PlayerDowned.Priority,
        caller = { name = PlayerName(Player), src = src },
        autoType = 'downed',
    })
end)

AddEventHandler('playerDropped', function()
    local src = source
    shotsCooldown[src] = nil
end)
