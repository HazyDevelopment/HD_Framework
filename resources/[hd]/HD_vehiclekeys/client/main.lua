-- ═══════════════════════════════════════════════════════════════════
--  HD VEHICLEKEYS | CLIENT
--  PlateCache holds what the server last told us about each plate we
--  encounter. Lock state is applied via the plain networked
--  SetVehicleDoorsLocked (4 = locked, 1 = unlocked) — every client
--  applying the same server-confirmed state to the same plate is what
--  keeps everyone's view consistent, no per-player native involved.
-- ═══════════════════════════════════════════════════════════════════

local PlateCache = {} -- [plate] = { owned, hasKeys, locked } | false (query pending)

local function TrimPlate(p)
    return (p or ''):gsub('%s+$', ''):gsub('^%s+', '')
end

local function GetClosestVehicle(coords, maxDistance)
    local closest, closestDist = nil, maxDistance
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local dist = #(GetEntityCoords(veh) - coords)
        if dist < closestDist then closest, closestDist = veh, dist end
    end
    return closest
end

local function GetTargetVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    return GetClosestVehicle(GetEntityCoords(ped), Config.LockRadius)
end

local function ApplyLock(veh, data)
    if not data or not data.owned then return end
    SetVehicleDoorsLocked(veh, data.locked and 4 or 1)
end

local function ApplyToAllWithPlate(plate, data)
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if TrimPlate(GetVehicleNumberPlateText(veh)) == plate then
            ApplyLock(veh, data)
        end
    end
end

-- ═══════════════════════════ DISCOVERY SCAN ═══════════════════════════
CreateThread(function()
    while true do
        Wait(2000)
        local pcoords = GetEntityCoords(PlayerPedId())
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if #(GetEntityCoords(veh) - pcoords) < 40.0 then
                local plate = TrimPlate(GetVehicleNumberPlateText(veh))
                if PlateCache[plate] == nil then
                    PlateCache[plate] = false -- pending, don't re-request every tick
                    TriggerServerEvent('hd_vehiclekeys:server:queryPlate', plate)
                elseif PlateCache[plate] then
                    ApplyLock(veh, PlateCache[plate])
                end
            end
        end
    end
end)

RegisterNetEvent('hd_vehiclekeys:client:plateStatus', function(plate, data)
    PlateCache[plate] = data
    ApplyToAllWithPlate(plate, data)
end)

RegisterNetEvent('hd_vehiclekeys:client:lockChanged', function(plate, locked)
    local data = PlateCache[plate]
    if not data then data = { owned = true, hasKeys = false, locked = locked } else data.locked = locked end
    PlateCache[plate] = data

    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if TrimPlate(GetVehicleNumberPlateText(veh)) == plate then
            ApplyLock(veh, data)
            if #(GetEntityCoords(veh) - GetEntityCoords(PlayerPedId())) < 15.0 then
                StartVehicleHorn(veh, 100, 'HELDDOWN', false)
                SetVehicleLights(veh, 2)
                Wait(120)
                SetVehicleLights(veh, 0)
            end
        end
    end
end)

-- ═══════════════════════════ COMMANDS ═════════════════════════════════
RegisterCommand(Config.Command, function()
    local veh = GetTargetVehicle()
    if not veh then
        Config.Notify('No vehicle nearby.', 'error')
        return
    end
    TriggerServerEvent('hd_vehiclekeys:server:toggleLock', TrimPlate(GetVehicleNumberPlateText(veh)))
end, false)

RegisterCommand(Config.GiveKeysCommand, function(_, args)
    local targetId = tonumber(args[1])
    if not targetId then
        Config.Notify(('Usage: /%s [id]'):format(Config.GiveKeysCommand), 'error')
        return
    end
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then
        Config.Notify('Get in the vehicle first.', 'error')
        return
    end
    TriggerServerEvent('hd_vehiclekeys:server:giveKeys', TrimPlate(GetVehicleNumberPlateText(veh)), targetId)
end, false)

RegisterCommand('revokekeys', function(_, args)
    local targetId = tonumber(args[1])
    if not targetId then
        Config.Notify('Usage: /revokekeys [id]', 'error')
        return
    end
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then
        Config.Notify('Get in the vehicle first.', 'error')
        return
    end
    TriggerServerEvent('hd_vehiclekeys:server:revokeKeys', TrimPlate(GetVehicleNumberPlateText(veh)), targetId)
end, false)

-- ═══════════════════════════ BREAKING IN ═════════════════════════════
-- A timing skill-check, not a flat wait: a marker sweeps a bar and you
-- press E to catch it inside the highlighted zone, across several
-- rounds. Winning (enough catches) meaningfully improves your odds
-- server-side but never guarantees the outcome — see the long note on
-- Config.BreakIn in config.lua for exactly why that split exists.
-- Plain native DrawRect, no NUI — keeps this resource exactly as
-- native-only as everything else in it.
local function DrawMinigameBar(zoneStart, zoneWidth, markerPos, flashColor)
    local barX, barY, barW, barH = 0.5, 0.94, 0.25, 0.032
    local x0 = barX - barW / 2

    DrawRect(barX, barY, barW, barH, 20, 20, 20, 190)
    DrawRect(x0 + zoneStart * barW + (zoneWidth * barW) / 2, barY, zoneWidth * barW, barH, 216, 168, 50, 200)

    local c = flashColor or { 255, 255, 255 }
    DrawRect(x0 + markerPos * barW, barY, 0.005, barH + 0.012, c[1], c[2], c[3], 255)
end

-- Returns 'hit' | 'miss' | 'cancel'.
local function RunMinigameRound(anchorCoords)
    local cfg = Config.BreakIn.Minigame
    local zoneWidth = cfg.ZoneWidth
    local zoneStart = math.random() * (1.0 - zoneWidth)
    local pos, dir = 0.0, 1
    local start = GetGameTimer()

    while GetGameTimer() - start < cfg.TimeoutMs do
        Wait(0)
        pos = pos + dir * cfg.MarkerSpeed
        if pos >= 1.0 then pos, dir = 1.0, -1 end
        if pos <= 0.0 then pos, dir = 0.0, 1 end

        DrawMinigameBar(zoneStart, zoneWidth, pos)
        SetTextFont(4)
        SetTextScale(0.3, 0.3)
        SetTextColour(255, 255, 255, 255)
        SetTextEntry('STRING')
        SetTextCentre(true)
        AddTextComponentString('[E] Catch the marker in the zone')
        DrawText(0.5, 0.905)

        DisableControlAction(0, 24, true)  -- attack
        DisableControlAction(0, 25, true)  -- aim
        DisableControlAction(0, 142, true) -- melee

        if IsControlJustPressed(0, 202) then return 'cancel' end -- Backspace
        if IsPedInAnyVehicle(PlayerPedId(), false) then return 'cancel' end
        if #(GetEntityCoords(PlayerPedId()) - anchorCoords) > 3.0 then return 'cancel' end

        if IsControlJustPressed(0, 51) then -- INPUT_CONTEXT ('E')
            local hit = pos >= zoneStart and pos <= zoneStart + zoneWidth
            DrawMinigameBar(zoneStart, zoneWidth, pos, hit and { 80, 200, 120 } or { 200, 80, 80 })
            Wait(200) -- let the hit/miss flash actually register visually
            return hit and 'hit' or 'miss'
        end
    end
    return 'miss' -- ran out of time this round
end

-- Returns true (won), false (lost), or nil (whole attempt cancelled).
local function RunBreakInMinigame(anchorCoords)
    local cfg = Config.BreakIn.Minigame
    local hits = 0
    for _ = 1, cfg.Attempts do
        local result = RunMinigameRound(anchorCoords)
        if result == 'cancel' then return nil end
        if result == 'hit' then hits = hits + 1 end
        Wait(150) -- brief breather between rounds
    end
    return hits >= cfg.RequiredHits
end

RegisterCommand(Config.BreakIn.Command, function()
    if not Config.BreakIn.Enabled then return end
    local ped = PlayerPedId()
    local veh = GetTargetVehicle()
    if not veh then
        Config.Notify('No vehicle nearby.', 'error')
        return
    end

    local plate = TrimPlate(GetVehicleNumberPlateText(veh))
    local data = PlateCache[plate]
    if not data or not data.owned or not data.locked or data.hasKeys then
        Config.Notify("That vehicle isn't locked against you.", 'error')
        return
    end

    local coords = GetEntityCoords(ped)
    Config.Notify('Breaking in...', 'info')
    local passed = RunBreakInMinigame(coords)
    if passed == nil then
        Config.Notify('Cancelled.', 'error')
        return
    end

    TriggerServerEvent('hd_vehiclekeys:server:attemptBreakIn', plate, { x = coords.x, y = coords.y, z = coords.z }, passed)
end, false)

RegisterNetEvent('hd_vehiclekeys:client:triggerAlarm', function(plate)
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if TrimPlate(GetVehicleNumberPlateText(veh)) == plate then
            SetVehicleAlarm(veh, true)
            StartVehicleAlarm(veh)
        end
    end
end)

-- ═══════════════════════════ STUCK-AT-DOOR HANDLING ═══════════════════
-- Matches real key-fob behaviour: nobody can just open a locked door,
-- not even the owner, until they unlock it — so this only interrupts
-- the pointless "tugging the handle" animation loop and tells them why.
CreateThread(function()
    local lastWarn = 0
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if IsPedTryingToEnterALockedVehicle(ped) then
            local veh = GetVehiclePedIsTryingToEnter(ped)
            if veh and veh ~= 0 then
                local data = PlateCache[TrimPlate(GetVehicleNumberPlateText(veh))]
                if data and data.owned then
                    ClearPedTasks(ped)
                    local now = GetGameTimer()
                    if now - lastWarn > 3000 then
                        lastWarn = now
                        Config.Notify('This vehicle is locked.', 'error')
                    end
                end
            end
        end
    end
end)

-- ═══════════════════════════ EXPORT ═══════════════════════════════════
exports('IsLocked', function(plate)
    local data = PlateCache[plate]
    return data and data.owned and data.locked or false
end)
