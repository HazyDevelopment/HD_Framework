-- ═══════════════════════════════════════════════════════════════════
--  hd_policejob | server/detain.lua
--  /detain [server id] — the enforcement mechanic hd_fines' auto-
--  warrant was missing: crossing Config.Debt.WarrantThreshold there
--  only ever raised a dispatch call and an MDT record, nothing acted
--  on it. This is that action. Everything is re-checked server-side —
--  on-duty status, distance, and the warrant itself — never trusted
--  from the client.
-- ═══════════════════════════════════════════════════════════════════

local Detained = {} -- [targetSrc] = true while held, just a re-entrancy guard

RegisterCommand('detain', function(source, args)
    local src = source
    local ok, Officer = HDPolice.IsOnDutyPolice(src)
    if not ok then
        TriggerClientEvent('HD:Client:Notify', src, 'You must be an on-duty officer to do this.', 'error')
        return
    end

    local targetId = tonumber(args[1])
    local Target = targetId and Framework.Functions.GetPlayer(targetId)
    if not Target then
        TriggerClientEvent('HD:Client:Notify', src, 'Usage: /detain [server id]', 'error')
        return
    end
    if targetId == src then
        TriggerClientEvent('HD:Client:Notify', src, "You can't detain yourself.", 'error')
        return
    end
    if Detained[targetId] then
        TriggerClientEvent('HD:Client:Notify', src, 'They are already detained.', 'error')
        return
    end

    local officerPed, targetPed = GetPlayerPed(src), GetPlayerPed(targetId)
    if officerPed == 0 or targetPed == 0 then return end
    if #(GetEntityCoords(officerPed) - GetEntityCoords(targetPed)) > Config.Detain.Distance then
        TriggerClientEvent('HD:Client:Notify', src, 'Get closer to detain them.', 'error')
        return
    end

    if GetResourceState('hazy_mdt') ~= 'started' then
        TriggerClientEvent('HD:Client:Notify', src, 'MDT is not running — cannot verify a warrant.', 'error')
        return
    end

    -- Claimed now, before the two awaited hazy_mdt export calls below —
    -- nothing yields between the Detained[targetId] check above and
    -- this assignment, so a second /detain on the same target landing
    -- in that window is rejected by the check instead of racing this
    -- one to spawn its own independent release timer. Rolled back if
    -- it turns out there's nothing to actually arrest for.
    Detained[targetId] = true

    local warrants = exports['hazy_mdt']:GetActiveWarrants(Target.PlayerData.citizenid)
    if not warrants or #warrants == 0 then
        Detained[targetId] = nil
        TriggerClientEvent('HD:Client:Notify', src, 'This citizen has no active warrant.', 'error')
        return
    end

    local officerName = (Officer.PlayerData.charinfo.firstname or '') .. ' ' .. (Officer.PlayerData.charinfo.lastname or '')
    exports['hazy_mdt']:ClearWarrantsForCitizen(Target.PlayerData.citizenid, officerName)

    TriggerClientEvent('hdpolice:client:detained', targetId, Config.Detain.HoldSeconds, Config.Detain.Cell)
    TriggerClientEvent('HD:Client:Notify', targetId,
        ('You have been detained on an outstanding warrant, held for %d minutes.'):format(math.floor(Config.Detain.HoldSeconds / 60)), 'error')
    TriggerClientEvent('HD:Client:Notify', src,
        ('Detained on an outstanding warrant. Holding for %d minutes.'):format(math.floor(Config.Detain.HoldSeconds / 60)), 'success')

    CreateThread(function()
        Wait(Config.Detain.HoldSeconds * 1000)
        if Detained[targetId] then
            Detained[targetId] = nil
            if GetPlayerPed(targetId) ~= 0 then
                TriggerClientEvent('hdpolice:client:released', targetId)
                TriggerClientEvent('HD:Client:Notify', targetId, 'You have been released.', 'success')
            end
        end
    end)
end, false)

AddEventHandler('playerDropped', function()
    Detained[source] = nil
end)
