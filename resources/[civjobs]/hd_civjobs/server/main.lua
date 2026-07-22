-- ═══════════════════════════════════════════════════════════════════
--  HD CIVJOBS | SERVER
--  Contract progress is tracked here only — the client just renders
--  whatever this file says is true and asks to interact; every
--  interact is re-validated against real player-ped distance before
--  anything advances or pays out.
-- ═══════════════════════════════════════════════════════════════════

local Framework = nil
CreateThread(function()
    while GetResourceState('qb-core') ~= 'started' do Wait(100) end
    Framework = exports['qb-core']:GetCoreObject()
end)

local ActiveContracts = {} -- [src] = { job, stops, stopIndex, visited = {[pointIndex]=true}, payMin, payMax }

RegisterNetEvent('hd_civjobs:server:startShift', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end

    local jobKey = Player.PlayerData.job.name
    local jobCfg = Config.Jobs[jobKey]
    if not jobCfg then
        TriggerClientEvent('HD:Client:Notify', src, 'This job has no shift contracts.', 'error')
        return
    end
    if not Player.PlayerData.job.onduty then
        TriggerClientEvent('HD:Client:Notify', src, 'Go on duty first (/duty).', 'error')
        return
    end
    if ActiveContracts[src] then
        TriggerClientEvent('HD:Client:Notify', src, 'You already have an active contract.', 'error')
        return
    end

    local stops = jobCfg.stops(jobCfg)
    ActiveContracts[src] = { job = jobKey, stops = stops, stopIndex = 1, visited = {}, payMin = jobCfg.payMin, payMax = jobCfg.payMax }

    TriggerClientEvent('hd_civjobs:client:contractStarted', src, ActiveContracts[src], jobCfg.vehicle, jobCfg.depot)
end)

RegisterNetEvent('hd_civjobs:server:cancelShift', function()
    local src = source
    if ActiveContracts[src] then
        ActiveContracts[src] = nil
        TriggerClientEvent('hd_civjobs:client:contractEnded', src)
        TriggerClientEvent('HD:Client:Notify', src, 'Shift cancelled.', 'info')
    end
end)

RegisterNetEvent('hd_civjobs:server:interact', function()
    local src = source
    local contract = ActiveContracts[src]
    if not contract then return end

    local stop = contract.stops[contract.stopIndex]
    if not stop then return end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)

    for i, point in ipairs(stop.points) do
        if not contract.visited[i] and #(coords - point) <= Config.InteractRadius then
            contract.visited[i] = true

            local allDone = true
            for j = 1, #stop.points do
                if not contract.visited[j] then allDone = false break end
            end

            if allDone then
                contract.stopIndex = contract.stopIndex + 1
                contract.visited = {}

                if contract.stopIndex > #contract.stops then
                    local Player = Framework.Functions.GetPlayer(src)
                    local pay = math.random(contract.payMin, contract.payMax)
                    if Player then Player.Functions.AddMoney('bank', pay, 'job-contract') end
                    TriggerClientEvent('HD:Client:Notify', src, ('Contract complete — £%d paid.'):format(pay), 'success')
                    TriggerClientEvent('hd_civjobs:client:contractEnded', src)
                    ActiveContracts[src] = nil
                    return
                end

                TriggerClientEvent('HD:Client:Notify', src, 'Stop complete — next stop.', 'success')
            end

            TriggerClientEvent('hd_civjobs:client:contractUpdate', src, contract)
            return
        end
    end

    TriggerClientEvent('HD:Client:Notify', src, "You're not close enough to anything here.", 'error')
end)

AddEventHandler('playerDropped', function()
    ActiveContracts[source] = nil
end)
