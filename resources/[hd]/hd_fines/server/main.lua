-- ═══════════════════════════════════════════════════════════════════
--  HD FINES | SERVER
--  Everything is re-validated here — job, duty, amount bounds, target
--  proximity, cooldowns, and that hd_society is actually installed
--  before a single penny moves. Whatever a target can't cover becomes
--  a debt row (hd_fines_debts) rather than the fine just failing.
-- ═══════════════════════════════════════════════════════════════════

local Framework = nil
CreateThread(function()
    while GetResourceState('qb-core') ~= 'started' do Wait(100) end
    Framework = exports['qb-core']:GetCoreObject()
end)

CreateThread(function()
    Wait(1500)
    local ok = pcall(function() MySQL.query.await('SELECT 1 FROM `hd_fines_debts` LIMIT 1') end)
    if not ok then
        print('^1[hd_fines] ============================================================^7')
        print('^1[hd_fines] DATABASE NOT INSTALLED.^7')
        print('^1[hd_fines] Import sql/hd_fines_install.sql before using debts/warrants.^7')
        print('^1[hd_fines] ============================================================^7')
    else
        print('^2[hd_fines]^7 Database verified. Ready.')
    end
end)

-- ═══════════════════════════ COOLDOWNS ═══════════════════════════════
-- In-memory, per issuer — resets on restart, which is fine for a spam
-- guard, no need to persist it.
local Cooldowns = {} -- [issuerSrc] = { global = unixTime, targets = { [citizenid] = unixTime } }

local function CheckCooldown(src, targetCitizenId)
    local c = Cooldowns[src]
    if not c then return true end
    local now = os.time()
    if c.global and (now - c.global) < Config.Cooldown.GlobalSeconds then
        return false, Config.Cooldown.GlobalSeconds - (now - c.global)
    end
    local last = c.targets[targetCitizenId]
    if last and (now - last) < Config.Cooldown.PerTargetSeconds then
        return false, Config.Cooldown.PerTargetSeconds - (now - last)
    end
    return true
end

local function RecordCooldown(src, targetCitizenId)
    local now = os.time()
    Cooldowns[src] = Cooldowns[src] or { targets = {} }
    Cooldowns[src].global = now
    Cooldowns[src].targets[targetCitizenId] = now
end

AddEventHandler('playerDropped', function()
    Cooldowns[source] = nil
end)

-- ═══════════════════════════ DEBT HELPERS ════════════════════════════
-- Awaited, not fire-and-forget — the /fine handler reads the total
-- back immediately after to check for a threshold crossing, so the
-- insert has to be guaranteed committed first, not just queued.
local function AddDebt(citizenid, society, amount, reason)
    MySQL.insert.await('INSERT INTO hd_fines_debts (citizenid, society, amount, reason) VALUES (?, ?, ?, ?)', {
        citizenid, society, amount, reason
    })
end

local function GetTotalDebt(citizenid)
    return MySQL.scalar.await('SELECT SUM(amount) FROM hd_fines_debts WHERE citizenid = ?', { citizenid }) or 0
end

-- ═══════════════════════════ AUTO WARRANT ═════════════════════════════
-- The target is guaranteed online here — /fine already required them
-- to be within Config.TargetRadius of the issuing officer to reach
-- this point, so "last known location" is always a real, current
-- position, not a stale one. Two independent targets, each checked on
-- its own — either can be missing without breaking the other:
--   • hd_dispatch  — a live call on the board right now (Grade 1),
--     drops off once closed, same as any other call.
--   • hazy_mdt     — a real, persistent row in its own
--     mdtpolice_warrants table via IssueSystemWarrant (added
--     specifically for this — see that resource's fxmanifest.lua),
--     the same table the Command tab and civilian search already use,
--     so it's still there and searchable long after the dispatch call
--     is gone.
local function IssueAutoWarrant(Target, totalDebt)
    local targetPed = GetPlayerPed(Target.PlayerData.source)
    if not targetPed or targetPed == 0 then return end

    local name = Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname
    local reason = ('Unpaid fines total £%d, exceeding the warrant threshold.'):format(totalDebt)

    if GetResourceState('hd_dispatch') == 'started' then
        local coords = GetEntityCoords(targetPed)
        exports['hd_dispatch']:CreateCall('police', {
            title = 'Warrant Issued',
            description = ('%s has an outstanding warrant — %s Last known location shown.'):format(name, reason),
            coords = { x = coords.x, y = coords.y, z = coords.z },
            priority = Config.Debt.AutoWarrant.Priority,
            autoType = 'warrant',
        })
    end

    if GetResourceState('hazy_mdt') == 'started' then
        exports['hazy_mdt']:IssueSystemWarrant(Target.PlayerData.citizenid, name, reason, 'HD Fines (Automatic)')
    end
end

-- ═══════════════════════════ ISSUE A FINE ═════════════════════════════
RegisterCommand(Config.Command, function(source, args)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end

    local jobCfg = Config.Jobs[Player.PlayerData.job.name]
    if not jobCfg then
        TriggerClientEvent('HD:Client:Notify', src, 'Your job cannot issue fines.', 'error')
        return
    end
    if Config.RequireDuty and not Player.PlayerData.job.onduty then
        TriggerClientEvent('HD:Client:Notify', src, 'Go on duty first (/duty).', 'error')
        return
    end

    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    local reason = table.concat(args, ' ', 3)

    if not targetId or not amount then
        TriggerClientEvent('HD:Client:Notify', src, ('Usage: /%s [id] [amount] [reason]'):format(Config.Command), 'error')
        return
    end
    if targetId == src then
        TriggerClientEvent('HD:Client:Notify', src, "You can't fine yourself.", 'error')
        return
    end

    amount = math.floor(amount)
    if amount < jobCfg.minAmount or amount > jobCfg.maxAmount then
        TriggerClientEvent('HD:Client:Notify', src, ('Amount must be between £%d and £%d.'):format(jobCfg.minAmount, jobCfg.maxAmount), 'error')
        return
    end

    local Target = Framework.Functions.GetPlayer(targetId)
    if not Target then
        TriggerClientEvent('HD:Client:Notify', src, 'Player not found.', 'error')
        return
    end

    local srcPed, targetPed = GetPlayerPed(src), GetPlayerPed(targetId)
    if srcPed == 0 or targetPed == 0 or #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed)) > Config.TargetRadius then
        TriggerClientEvent('HD:Client:Notify', src, 'They need to be closer.', 'error')
        return
    end

    if GetResourceState('hd_society') ~= 'started' then
        TriggerClientEvent('HD:Client:Notify', src, 'Society funds system not installed.', 'error')
        return
    end

    local ok, waitSeconds = CheckCooldown(src, Target.PlayerData.citizenid)
    if not ok then
        TriggerClientEvent('HD:Client:Notify', src, ('Wait %ds before issuing another fine.'):format(math.ceil(waitSeconds)), 'error')
        return
    end

    local reasonText = (reason ~= '' and reason) or 'no reason given'
    local available = Target.Functions.GetMoney('bank')
    local toCollect = math.min(available, amount)
    local debtAmount = amount - toCollect

    if toCollect > 0 then
        Target.Functions.RemoveMoney('bank', toCollect, 'hd-fines')
        exports['hd_society']:AddFunds(Player.PlayerData.job.name, toCollect)
    end

    if debtAmount > 0 and Config.Debt.Enabled then
        local totalBefore = GetTotalDebt(Target.PlayerData.citizenid)
        AddDebt(Target.PlayerData.citizenid, Player.PlayerData.job.name, debtAmount, reasonText)

        if Config.Debt.AutoWarrant.Enabled and totalBefore < Config.Debt.WarrantThreshold then
            local totalAfter = GetTotalDebt(Target.PlayerData.citizenid)
            if totalAfter >= Config.Debt.WarrantThreshold then
                IssueAutoWarrant(Target, totalAfter)
            end
        end
    end

    RecordCooldown(src, Target.PlayerData.citizenid)

    if debtAmount <= 0 then
        TriggerClientEvent('HD:Client:Notify', src, ('You %s them £%d — %s'):format(jobCfg.verb, amount, reasonText), 'success')
        TriggerClientEvent('HD:Client:Notify', targetId, ('You were %s £%d (%s) — %s'):format(jobCfg.verb, amount, jobCfg.label, reasonText), 'error')
    else
        TriggerClientEvent('HD:Client:Notify', src, ('%s them £%d — %s collected now, £%d recorded as debt (they can\'t cover it in full).'):format(jobCfg.verb:gsub('^%l', string.upper), amount, toCollect, debtAmount), 'success')
        TriggerClientEvent('HD:Client:Notify', targetId, ('You were %s £%d (%s) — %s. £%d taken now, £%d added to your debt (%s [id] [amount] to pay it off).'):format(jobCfg.verb, amount, jobCfg.label, reasonText, toCollect, debtAmount, Config.Debt.PayCommand), 'error')
    end
end, false)

-- ═══════════════════════════ PAY OFF DEBT ═════════════════════════════
-- Oldest debt first, split across societies as needed — a citizen can
-- owe more than one job at once and this just works through them in
-- order until the payment runs out.
RegisterCommand(Config.Debt.PayCommand, function(source, args)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end

    local amount = tonumber(args[1])
    if not amount or amount <= 0 then
        TriggerClientEvent('HD:Client:Notify', src, ('Usage: /%s [amount]'):format(Config.Debt.PayCommand), 'error')
        return
    end
    amount = math.floor(amount)

    if not Player.Functions.RemoveMoney('bank', amount, 'hd-fines-debt-payment') then
        TriggerClientEvent('HD:Client:Notify', src, 'Insufficient bank funds.', 'error')
        return
    end

    local remaining = amount
    local debts = MySQL.query.await('SELECT * FROM hd_fines_debts WHERE citizenid = ? ORDER BY created ASC', {
        Player.PlayerData.citizenid
    }) or {}

    for _, debt in ipairs(debts) do
        if remaining <= 0 then break end
        local pay = math.min(remaining, debt.amount)
        remaining = remaining - pay

        if GetResourceState('hd_society') == 'started' then
            exports['hd_society']:AddFunds(debt.society, pay)
        end

        if pay >= debt.amount then
            MySQL.query('DELETE FROM hd_fines_debts WHERE id = ?', { debt.id })
        else
            MySQL.update('UPDATE hd_fines_debts SET amount = amount - ? WHERE id = ?', { pay, debt.id })
        end
    end

    if remaining > 0 then
        -- paid more than they actually owed — refund the excess rather than let it vanish
        Player.Functions.AddMoney('bank', remaining, 'hd-fines-debt-overpayment-refund')
    end

    local newTotal = GetTotalDebt(Player.PlayerData.citizenid)
    TriggerClientEvent('HD:Client:Notify', src, ('Paid £%d off your debt. Remaining: £%d'):format(amount - remaining, newTotal), 'success')
end, false)

-- ═══════════════════════════ CHECK DEBT ═══════════════════════════════
RegisterCommand(Config.Debt.CheckOwnCommand, function(source)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end
    local total = GetTotalDebt(Player.PlayerData.citizenid)
    TriggerClientEvent('HD:Client:Notify', src, ('You owe £%d in unpaid fines.'):format(total), total > 0 and 'error' or 'info')
end, false)

RegisterCommand(Config.Debt.CheckOtherCommand, function(source, args)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end

    local isOfficer = Config.Jobs[Player.PlayerData.job.name] ~= nil
    if not isOfficer and not IsPlayerAceAllowed(src, 'hd.admin') then
        TriggerClientEvent('HD:Client:Notify', src, 'No permission.', 'error')
        return
    end

    local targetId = tonumber(args[1])
    local Target = targetId and Framework.Functions.GetPlayer(targetId)
    if not Target then
        TriggerClientEvent('HD:Client:Notify', src, 'Player not found.', 'error')
        return
    end

    local total = GetTotalDebt(Target.PlayerData.citizenid)
    local warrant = total >= Config.Debt.WarrantThreshold
    TriggerClientEvent('HD:Client:Notify', src, ('%s owes £%d in unpaid fines.%s'):format(
        Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname,
        total,
        warrant and ' ⚠ Exceeds the warrant threshold.' or ''
    ), warrant and 'error' or 'info')
end, false)
