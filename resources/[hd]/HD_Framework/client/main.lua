-- ═══════════════════════════════════════════════════════════════════
--  HD_FRAMEWORK | CLIENT CORE
--  Holds the client's cached copy of PlayerData and exposes it via
--  Functions.GetPlayerData(), reached directly through
--  exports['HD_Framework']:GetCoreObject() — no bridge resource.
-- ═══════════════════════════════════════════════════════════════════

HD = {}
HD.PlayerData = {}
HD.Functions = {}
HD.Shared = { Jobs = Jobs, Items = Items } -- Jobs/Items are shared_scripts, so both globals already exist client-side too

function HD.Functions.GetPlayerData()
    return HD.PlayerData
end

-- ═══════════════════════════ CALLBACKS ═══════════════════════════════
-- Client half of the standard QBCore.Functions.CreateCallback/
-- TriggerCallback pattern — see server/main.lua for why this exists.
local PendingCallbacks = {}
local NextCallbackId = 0

function HD.Functions.TriggerCallback(name, cb, ...)
    NextCallbackId = NextCallbackId + 1
    local requestId = NextCallbackId
    PendingCallbacks[requestId] = cb
    TriggerServerEvent('QBCore:Server:TriggerCallback', name, requestId, ...)
end

RegisterNetEvent('QBCore:Client:TriggerCallback', function(requestId, ...)
    local cb = PendingCallbacks[requestId]
    if not cb then return end
    PendingCallbacks[requestId] = nil
    cb(...)
end)

exports('GetCoreObject', function() return HD end)

-- ═══════════════════════════ NO SPAWN BEFORE A CHARACTER EXISTS ═══════
-- Without this, basic-gamemode's own onClientMapStart handler calls
-- exports.spawnmanager:setAutoSpawn(true) and a connecting player can
-- be placed into the world before the character-select handshake
-- below has even landed — same race hd_ems documents for its own
-- setAutoSpawn(false) call, just at connect time instead of on death.
-- Asserted immediately and re-asserted for several seconds to win that
-- race unconditionally, and never re-enabled afterward: this framework
-- expects hd_ems to own respawn/revive entirely (see its README), so
-- there's no scenario where native auto-spawn should come back once a
-- character has loaded either.
exports.spawnmanager:setAutoSpawn(false)
CreateThread(function()
    for _ = 1, 100 do
        exports.spawnmanager:setAutoSpawn(false)
        Wait(100)
    end
end)

-- ═══════════════════════════ READY HANDSHAKE ═════════════════════════
local ready = false
local awaitingSelection = false
local listReceived = false -- flips true the moment ANY character-select payload arrives
local isNewCharacter = false -- set from hd:client:onPlayerLoaded, read once in ConfirmSpawn then left alone

-- Retries only cover a dropped/never-answered first request (the
-- "early-join" case the original comment describes) — it has to stop
-- the instant a response actually arrives, not just once `ready`
-- flips. `ready` only becomes true after a character is picked or
-- created, which can take the player a while (filling in the create
-- form, choosing a DOB/flat). Stopping on `ready` alone meant this
-- kept firing hd:server:playerReady every 2s the whole time, and the
-- server's own handler re-sends the character list on every one of
-- those (nothing yet in HD.Players[src] while creation is still in
-- flight) — which re-opens the NUI on the select screen mid-creation,
-- exactly the "keeps bouncing back to select" bug this fixes.
CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(50) end
    while not ready and not listReceived do
        TriggerServerEvent('hd:server:playerReady')
        Wait(2000)
    end
end)

-- Frozen + faded to black + NUI-focused on character select the whole
-- time a license has no character loaded yet — mirrors the same
-- freeze pattern hd_ems already uses for its downed state, just for a
-- different reason.
CreateThread(function()
    while true do
        local sleep = 500
        if awaitingSelection then
            sleep = 0
            local ped = PlayerPedId()
            DisableControlAction(0, 1, true)  -- look
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 30, true) -- move
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 24, true) -- attack
            DisableControlAction(0, 25, true) -- aim
            DisableControlAction(0, 37, true) -- weapon wheel
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('hd:client:showCharacterSelect', function(characters, maxSlots, nationalities)
    listReceived = true
    awaitingSelection = true
    DoScreenFadeOut(0)
    FreezeEntityPosition(PlayerPedId(), true)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'showSelect', characters = characters, maxSlots = maxSlots, nationalities = nationalities })
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    TriggerServerEvent('hd:server:selectCharacter', data.citizenid)
    cb({})
end)
RegisterNUICallback('deleteCharacter', function(data, cb)
    TriggerServerEvent('hd:server:deleteCharacter', data.citizenid)
    cb({})
end)
RegisterNUICallback('getStarterFlats', function(_, cb)
    TriggerServerEvent('hd:server:getStarterFlats')
    cb({})
end)
RegisterNUICallback('createCharacter', function(data, cb)
    TriggerServerEvent('hd:server:createCharacter', data)
    cb({})
end)
RegisterNetEvent('hd:client:starterFlats', function(flats)
    SendNUIMessage({ action = 'starterFlats', flats = flats })
end)

local FREEMODE_MALE = 'mp_m_freemode_01'
local FREEMODE_FEMALE = 'mp_f_freemode_01'

-- Every character-customization system in this framework (hd_clothing's
-- full drawable/prop variation range) only actually works against the
-- two real multiplayer freemode models — story-mode ped models don't
-- support anywhere near the same range. Forced once per session,
-- gender-derived from charinfo (set at character creation, "Female"
-- gets the female model, everything else — "Male" or "Not specified" —
-- gets the male one) so hd_clothing is customizing the model that's
-- actually right for that character, not whatever random default the
-- game handed out. Skips the whole RequestModel round-trip if the ped
-- is already the right model (true on every reconnect after the first).
local function EnsureFreemodeModel(gender)
    local wanted = (gender == 'Female') and FREEMODE_FEMALE or FREEMODE_MALE
    local hash = GetHashKey(wanted)
    if GetEntityModel(PlayerPedId()) == hash then return end

    RequestModel(hash)
    local waited = 0
    while not HasModelLoaded(hash) and waited < 5000 do Wait(50) waited = waited + 50 end
    if not HasModelLoaded(hash) then return end

    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)
    SetPedDefaultComponentVariation(PlayerPedId())
end

exports('GetDefaultSpawn', function() return Config.DefaultSpawn end)

RegisterNetEvent('hd:client:onPlayerLoaded', function(playerData, isNew)
    ready = true
    HD.PlayerData = playerData
    isNewCharacter = isNew or false

    -- Character-select NUI is dismissed here, but the ped stays frozen
    -- and the screen stays faded to black — hd_spawn (if installed)
    -- takes over from here with its own "choose where to spawn" screen
    -- and calls HD:Client:ConfirmSpawn below once the player hits Play.
    if awaitingSelection then
        awaitingSelection = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'hide' })
    end
    FreezeEntityPosition(PlayerPedId(), true)

    -- Model swap happens before position is ever (re)applied below —
    -- SetPlayerModel can reset the ped's transform, so this has to run
    -- before hd_spawn (or the fallback below) places the ped.
    EnsureFreemodeModel(playerData.charinfo and playerData.charinfo.gender)

    TriggerEvent('HD:Client:ShowSpawnSelect', playerData)

    -- Graceful fallback if hd_spawn isn't installed/running: spawn at
    -- the saved position immediately, same behaviour this framework had
    -- before hd_spawn existed, rather than leaving the player frozen on
    -- a black screen forever with nothing listening for a Play click.
    if GetResourceState('hd_spawn') ~= 'started' then
        TriggerEvent('HD:Client:ConfirmSpawn', playerData.position)
    end
end)

-- hd_spawn (or any equivalent spawn-selection resource) fires this once
-- the player has picked where to spawn and clicked Play. Centralised
-- here — not duplicated in hd_spawn — so there's exactly one place that
-- places the ped, unfreezes/fades the player in, and fires the
-- OnPlayerLoaded broadcast every other resource (hd_clothing, hd_hud,
-- hd_ems, ...) already relies on.
RegisterNetEvent('HD:Client:ConfirmSpawn', function(coords)
    local ped = PlayerPedId()
    if coords and coords.x then
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
        SetEntityHeading(ped, coords.w or 0.0)
    end
    FreezeEntityPosition(ped, false)
    DoScreenFadeIn(500)

    -- Other resources (hd_clothing re-applying saved clothing) react to
    -- this broadcast — firing it only after the model swap in
    -- hd:client:onPlayerLoaded means they're always customizing the
    -- correct, already-set model.
    TriggerEvent('HD:Client:OnPlayerLoaded', HD.PlayerData)

    -- Brand-new character, now actually standing in the world (not just
    -- loaded) — hd_clothing forces its free wardrobe open on this so a
    -- new citizen customises their look before doing anything else.
    -- Only fires once per character ever, not on every relog.
    if isNewCharacter then
        isNewCharacter = false
        TriggerEvent('HD:Client:NewCharacterSpawned')
    end
end)

RegisterNetEvent('hd:client:onPlayerDataUpdate', function(playerData)
    HD.PlayerData = playerData
    TriggerEvent('HD:Client:OnPlayerDataUpdate', HD.PlayerData)
end)

-- ═══════════════════════════ HANDS UP (X) ════════════════════════════
-- Core keybind, not tucked away in some other resource — every job/
-- interaction script (hd_policejob's /detain, hd_radial's Interactions
-- category, a future robbery script) can reuse the exact same toggle
-- via exports['HD_Framework']:ToggleHandsUp() rather than each
-- reimplementing the anim itself.
local HANDSUP_DICT = 'random@mugging3'
local HANDSUP_CLIP = 'handsup_standing_base'
local handsUp = false

function HD.Functions.IsHandsUp()
    return handsUp
end

function ToggleHandsUp(state)
    local ped = PlayerPedId()
    local newState = state
    if newState == nil then newState = not handsUp end
    if newState == handsUp then return end
    handsUp = newState

    if handsUp then
        RequestAnimDict(HANDSUP_DICT)
        local waited = 0
        while not HasAnimDictLoaded(HANDSUP_DICT) and waited < 1000 do Wait(10) waited = waited + 10 end
        if not HasAnimDictLoaded(HANDSUP_DICT) then handsUp = false return end
        TaskPlayAnim(ped, HANDSUP_DICT, HANDSUP_CLIP, 3.0, -3.0, -1, 49, 0, false, false, false) -- flag 49: upper-body + looping, so movement still works
    else
        StopAnimTask(ped, HANDSUP_DICT, HANDSUP_CLIP, 1.0)
    end
    TriggerEvent('HD:Client:HandsUpChanged', handsUp)
end
exports('ToggleHandsUp', ToggleHandsUp)

-- Cancel automatically on anything that shouldn't coexist with "hands
-- up" — drawing a weapon, entering a vehicle, or going down — rather
-- than leaving the ped stuck playing the anim through all of those.
CreateThread(function()
    while true do
        Wait(250)
        if handsUp then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) or IsPedArmed(ped, 6) or IsEntityDead(ped) then
                ToggleHandsUp(false)
            end
        end
    end
end)

RegisterCommand('handsup', function() ToggleHandsUp() end, false)
RegisterKeyMapping('handsup', 'Hands Up', 'keyboard', 'X')
