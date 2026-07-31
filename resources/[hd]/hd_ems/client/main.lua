-- ═══════════════════════════════════════════════════════════════════
--  hd_ems | client/main.lua
--  On death: resurrect-in-place immediately (the ped is never
--  actually "fatally injured" from the game's point of view — this
--  is the standard ESX/QBCore fake-death pattern), then freeze it in
--  a writhe animation under script control. That's what stops
--  basic-gamemode's exports.spawnmanager:setAutoSpawn(true) from
--  force-respawning the player 2 seconds later — the native death
--  the auto-spawn watches for never actually happens. Frozen and
--  downed until an on-duty EMS revives them in person or staff run
--  /revive [id] (server/revive.lua) — no timer, no self-service respawn.
-- ═══════════════════════════════════════════════════════════════════

Framework = nil
CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

-- spawnmanager is a hard dependency (fxmanifest), so it's guaranteed
-- already loaded here — no need to wait on anything. basic-gamemode
-- turns autospawn ON inside its own onClientMapStart handler, and
-- since that event's exact firing time relative to this resource's
-- own startup isn't guaranteed, a single call here could still race
-- it. A short-lived watchdog re-asserts setAutoSpawn(false) for the
-- first few seconds of the session to win that race unconditionally,
-- however it plays out.
exports.spawnmanager:setAutoSpawn(false)
CreateThread(function()
    for _ = 1, 100 do
        exports.spawnmanager:setAutoSpawn(false)
        Wait(100)
    end
end)

local downed = false
local downedSince = 0
local downedRoster = {} -- from server, only populated for on-duty ambulance

local function IsAmbulanceOnDuty()
    if not Framework then return false end
    local pd = Framework.Functions.GetPlayerData()
    if not pd or not pd.job or pd.job.name ~= Config.AmbulanceJob then return false end
    if not Config.RequireOnDuty then return true end
    return pd.job.onduty
end

-- ═══════════════════════════════ ENTER DOWNED ═════════════════════════
RegisterNetEvent('baseevents:onPlayerDied', function(_, coords)
    if downed then return end
    downed = true
    downedSince = GetGameTimer()

    local ped = PlayerPedId()
    NetworkResurrectLocalPlayer(coords[1], coords[2], coords[3], GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, 1)
    SetPlayerInvincible(PlayerId(), true) -- can't be finished off while already down
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, true) -- stays exactly where they fell until revived

    RequestAnimDict(Config.DownedAnim.dict)
    while not HasAnimDictLoaded(Config.DownedAnim.dict) do Wait(10) end
    TaskPlayAnim(ped, Config.DownedAnim.dict, Config.DownedAnim.clip, 8.0, -8.0, -1, 1, 0, false, false, false)

    TriggerServerEvent('hd_ems:server:playerDowned')
    SendNUIMessage({ action = 'show' })
end)

CreateThread(function()
    while true do
        local sleep = 200
        if downed then
            sleep = 0
            DisableControlAction(0, 30, true)  -- move left/right
            DisableControlAction(0, 31, true)  -- move up/down
            DisableControlAction(0, 21, true)  -- sprint
            DisableControlAction(0, 22, true)  -- jump
            DisableControlAction(0, 24, true)  -- attack
            DisableControlAction(0, 25, true)  -- aim
            DisableControlAction(0, 44, true)  -- cover
            DisableControlAction(0, 37, true)  -- weapon wheel
            DisableControlAction(0, 23, true)  -- enter vehicle

            SendNUIMessage({ action = 'tick', elapsedMs = GetGameTimer() - downedSince })
        end
        Wait(sleep)
    end
end)

-- A believable few-second recovery instead of an instant pop-up-to-
-- standing. Still frozen/invincible during this window (it's an
-- extension of the downed state, not yet "up"), so nothing can go
-- wrong mid-transition.
local function StandUp(health)
    local ped = PlayerPedId()
    StopAnimTask(ped, Config.DownedAnim.dict, Config.DownedAnim.clip, 1.0)
    SendNUIMessage({ action = 'tick', elapsedMs = -1 }) -- -1 signals "recovering" to the NUI, see html/app.js

    -- TaskGetUp plays the game's own context-aware "lift yourself off
    -- the ground" animation (it picks the right one for however the
    -- ped is currently lying) rather than a hand-picked clip — pcall
    -- guarded so an unexpected native failure here can never block the
    -- actual revive (unfreeze/heal) a few lines down.
    if Config.PlayGetUpAnim then
        pcall(function() TaskGetUp(ped, false, -1, -1, false) end)
    end

    Wait(1800)

    NetworkResurrectLocalPlayer(GetEntityCoords(ped).x, GetEntityCoords(ped).y, GetEntityCoords(ped).z, GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, health or 200)
    ClearPedBloodDamage(ped)
    ResurrectPed(ped)
    ClearPedTasksImmediately(ped)
    SetPlayerInvincible(PlayerId(), false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    downed = false
    SendNUIMessage({ action = 'hide' })
end

-- Fired for both an in-person EMS revive (server/main.lua's
-- reviveRequest handler) and the staff /revive command
-- (server/revive.lua) — same resource now, so both paths just trigger
-- this one event once the server's already cleared its own downed
-- bookkeeping.
RegisterNetEvent('hd_ems:client:revived', function(health)
    StandUp(health)
    ClearPedTasksImmediately(PlayerPedId())
end)

-- ═══════════════════════════════ EMS REVIVE ════════════════════════════
RegisterNetEvent('hd_ems:client:downedRoster', function(roster)
    downedRoster = roster
end)

local function Draw3DText(coords, text)
    SetTextScale(0.32, 0.32) SetTextFont(4) SetTextCentre(true)
    SetTextColour(255, 255, 255, 215)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    BeginTextCommandDisplayText('STRING') AddTextComponentString(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local reviveHoldStart = nil

CreateThread(function()
    while true do
        local sleep = 800
        if not downed and IsAmbulanceOnDuty() and #downedRoster > 0 then
            local pc = GetEntityCoords(PlayerPedId())
            local nearest, nearestDist = nil, Config.ReviveDistance
            for _, u in ipairs(downedRoster) do
                local d = #(pc - vector3(u.x, u.y, u.z))
                if d <= nearestDist then nearest, nearestDist = u, d end
            end

            if nearest then
                sleep = 0
                Draw3DText(vector3(nearest.x, nearest.y, nearest.z + 1.0), ('[Hold E] Revive %s'):format(nearest.name))
                if IsControlPressed(0, 38) then
                    reviveHoldStart = reviveHoldStart or GetGameTimer()
                    local held = GetGameTimer() - reviveHoldStart
                    Draw3DText(vector3(nearest.x, nearest.y, nearest.z + 0.7),
                        ('%d%%'):format(math.min(100, math.floor(held / Config.RequiredHoldMs * 100))))
                    if held >= Config.RequiredHoldMs then
                        TriggerServerEvent('hd_ems:server:reviveRequest', nearest.id)
                        reviveHoldStart = nil
                    end
                else
                    reviveHoldStart = nil
                end
            else
                reviveHoldStart = nil
            end
        else
            reviveHoldStart = nil
        end
        Wait(sleep)
    end
end)
