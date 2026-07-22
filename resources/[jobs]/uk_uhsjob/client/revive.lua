-- ===================================================================
-- client/revive.lua
-- Receives the revive trigger and restores the local player using
-- native resurrect, so it works with or without a medical/death
-- script. Optionally fires the framework's own ambulance revive
-- events to clear any downed state those scripts track.
-- ===================================================================

if not Config.Revive or not Config.Revive.Enabled then return end

RegisterNetEvent('ukhs:client:revive', function(opts)
    opts = opts or {}
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    -- Core native revive: works whether the player is dead, downed or alive
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ResurrectPed(ped)
    ClearPedTasksImmediately(ped)
    SetPlayerInvincible(PlayerId(), false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)

    if opts.restoreArmor then SetPedArmour(ped, 100) end
    if opts.clearWanted then
        ClearPlayerWantedLevel(PlayerId())
        SetPlayerWantedLevel(PlayerId(), 0, false)
        SetPlayerWantedLevelNow(PlayerId(), false)
    end

    -- Let the framework's ambulance script clear its own death/downed state
    if opts.fireFrameworkEvents then
        if Config.Framework == 'qbcore' then
            TriggerEvent('hospital:client:Revive')          -- qb-ambulancejob
            TriggerEvent('qb-ambulancejob:client:Revive')   -- some forks
        else
            TriggerEvent('esx_ambulancejob:revive')         -- esx_ambulancejob
        end
    end

    if Config.Revive.Notify and Bridge and Bridge.Notify then
        Bridge.Notify('You have been revived.', 'success')
    end
end)
