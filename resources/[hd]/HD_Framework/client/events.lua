-- ═══════════════════════════════════════════════════════════════════
--  HD_FRAMEWORK | CLIENT EVENTS
--  Placeholder notification renderer — native GTA notification for
--  now. The phone/UI build phase replaces this with a proper HUD
--  toast that matches the phone's styling; nothing else needs to
--  change since every resource just fires 'HD:Client:Notify'.
-- ═══════════════════════════════════════════════════════════════════

RegisterNetEvent('HD:Client:Notify', function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(('%s %s'):format(ntype == 'error' and '[!]' or ntype == 'success' and '[OK]' or '[i]', msg))
    DrawNotification(false, false)
end)

-- ═══════════════════════════ NO NATIVE EMERGENCY AI ══════════════════
-- This server's police/fire/EMS response is entirely player-run
-- (hd_policejob, hd_ems) — the native game engine still
-- wants to spawn its own AI police cars/riders/SWAT/fire trucks/
-- ambulances on top of that unless told not to. EnableDispatchService
-- covers every dispatch type the game defines (1-15: police cars,
-- helicopters, fire department, SWAT, ambulance, police riders,
-- vehicle/roadblock requests, army vehicles, and a couple of
-- wanted-specific variants) — doesn't touch the wanted level system
-- itself, just who's allowed to automatically respond to it.
-- Re-asserted on a slow loop rather than fired once: the flag isn't
-- guaranteed to survive every respawn/scenario edge case the game
-- engine can reset it on, and re-calling it every 30s is free.
CreateThread(function()
    while true do
        for dispatchType = 1, 15 do
            EnableDispatchService(dispatchType, false)
        end
        Wait(30000)
    end
end)

-- ═══════════════════════════ EAT / DRINK ANIMATIONS ════════════════════
-- Fired by server/needs.lua for whichever item was actually consumed
-- (Config.ConsumableRestores' `kind` field), so eating/drinking a real
-- item plays the matching native animation + held prop instead of just
-- vanishing with a notification. Best-effort prop placement (right
-- hand, a fixed offset/rotation) same as everywhere else in this build
-- that hand-places a prop — good enough to read clearly, not a
-- frame-perfect mocap match.
local ConsumeAnims = {
    eat = {
        dict = 'mp_player_inteat@burger',
        clip = 'mp_player_int_eat_burger',
        prop = 'prop_cs_burger_01',
        durationMs = 4500,
    },
    drink = {
        dict = 'mp_player_intdrink',
        clip = 'loop_bottle',
        prop = 'prop_ld_flow_bottle',
        durationMs = 3500,
    },
}

RegisterNetEvent('hd:client:playConsumeAnim', function(kind)
    local def = ConsumeAnims[kind]
    if not def then return end
    local ped = PlayerPedId()

    RequestAnimDict(def.dict)
    local propHash = GetHashKey(def.prop)
    RequestModel(propHash)
    local waited = 0
    while (not HasAnimDictLoaded(def.dict) or not HasModelLoaded(propHash)) and waited < 2000 do
        Wait(50)
        waited = waited + 50
    end
    if not HasAnimDictLoaded(def.dict) or not HasModelLoaded(propHash) then return end

    local propObj = CreateObject(propHash, 0.0, 0.0, 0.0, true, true, false)
    local boneIndex = GetPedBoneIndex(ped, 60309) -- SKEL_R_HAND
    AttachEntityToEntity(propObj, ped, boneIndex, 0.13, 0.06, 0.02, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(propHash)

    TaskPlayAnim(ped, def.dict, def.clip, 3.0, -3.0, def.durationMs, 49, 0, false, false, false)

    CreateThread(function()
        Wait(def.durationMs)
        if DoesEntityExist(propObj) then DeleteObject(propObj) end
        ClearPedTasks(ped)
    end)
end)
