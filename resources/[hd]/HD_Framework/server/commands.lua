-- ═══════════════════════════════════════════════════════════════════
--  HD_FRAMEWORK | ADMIN COMMANDS
--  Gated behind the 'hd.admin' ACE permission. Grant it in
--  server.cfg, e.g.:
--    add_ace group.admin hd.admin allow
--    add_principal identifier.license:YOURLICENSE group.admin
-- ═══════════════════════════════════════════════════════════════════

local function IsAdmin(src)
    return IsPlayerAceAllowed(src, 'hd.admin')
end

local function Notify(src, msg, ntype)
    TriggerClientEvent('HD:Client:Notify', src, msg, ntype or 'info')
end

RegisterCommand('setjob', function(source, args)
    local src = source
    if src ~= 0 and not IsAdmin(src) then Notify(src, 'No permission.', 'error') return end

    local targetId = tonumber(args[1])
    local jobName = args[2]
    local grade = tonumber(args[3]) or 0
    local Target = targetId and HD.Functions.GetPlayer(targetId)

    if not Target then Notify(src, 'Player not found.', 'error') return end
    if not jobName or not Jobs[jobName] then Notify(src, 'Unknown job. Check shared/jobs.lua for valid keys.', 'error') return end

    if Target.Functions.SetJob(jobName, grade) then
        Notify(src, ('Set %s to %s (grade %s).'):format(Target.PlayerData.citizenid, jobName, grade), 'success')
        Notify(targetId, ('Your job is now %s.'):format(Jobs[jobName].label), 'info')
    else
        Notify(src, 'Invalid grade for that job.', 'error')
    end
end, false)

RegisterCommand('addmoney', function(source, args)
    local src = source
    if src ~= 0 and not IsAdmin(src) then Notify(src, 'No permission.', 'error') return end

    local targetId = tonumber(args[1])
    local account = args[2]
    local amount = tonumber(args[3])
    local Target = targetId and HD.Functions.GetPlayer(targetId)

    if not Target or not account or not amount then Notify(src, 'Usage: /addmoney [id] [cash|bank] [amount]', 'error') return end

    if Target.Functions.AddMoney(account, amount, 'admin-give') then
        Notify(src, ('Added £%s %s to %s.'):format(amount, account, Target.PlayerData.citizenid), 'success')
    else
        Notify(src, 'Failed — check the account name.', 'error')
    end
end, false)

RegisterCommand('removemoney', function(source, args)
    local src = source
    if src ~= 0 and not IsAdmin(src) then Notify(src, 'No permission.', 'error') return end

    local targetId = tonumber(args[1])
    local account = args[2]
    local amount = tonumber(args[3])
    local Target = targetId and HD.Functions.GetPlayer(targetId)

    if not Target or not account or not amount then Notify(src, 'Usage: /removemoney [id] [cash|bank] [amount]', 'error') return end

    if Target.Functions.RemoveMoney(account, amount, 'admin-take') then
        Notify(src, ('Removed £%s %s from %s.'):format(amount, account, Target.PlayerData.citizenid), 'success')
    else
        Notify(src, 'Failed — insufficient funds or bad account.', 'error')
    end
end, false)

RegisterCommand('myjob', function(source)
    local src = source
    local Player = HD.Functions.GetPlayer(src)
    if not Player then return end
    local j = Player.PlayerData.job
    Notify(src, ('%s — %s (grade %s%s)'):format(j.label, j.grade.name, j.grade.level, j.isboss and ', BOSS' or ''), 'info')
end, false)

-- Self-service duty toggle for jobs with no dedicated duty UI of their
-- own (mechanic, taxi, cardealer, etc.). Police/UHS already have one
-- built into hazy_mdt (which calls this same Functions.SetJobDuty
-- under the hood via Config.Duty.SyncFramework), so this is just the
-- generic fallback everyone else uses — hd_dispatch reads
-- job.onduty to decide who receives recovery calls.
RegisterCommand('duty', function(source)
    local src = source
    local Player = HD.Functions.GetPlayer(src)
    if not Player then return end
    local newState = not Player.PlayerData.job.onduty
    Player.Functions.SetJobDuty(newState)
    Notify(src, newState and 'You are now on duty.' or 'You are now off duty.', newState and 'success' or 'info')
end, false)

-- Admin-only: register a vehicle to a player. There's no car dealer
-- purchase flow yet (see README "what's next"), so this is the only
-- way a player_vehicles row exists right now — useful for testing the
-- hd_phone Garages app, and as a stand-in for "spawn me a car" until
-- a real dealership resource lands.
RegisterCommand('givevehicle', function(source, args)
    local src = source
    if src ~= 0 and not IsAdmin(src) then Notify(src, 'No permission.', 'error') return end

    local targetId = tonumber(args[1])
    local model = args[2]
    local plate = args[3]
    -- Must match a Config.Garages[].key in hd_phone/config.lua — 'legion'
    -- is that resource's first default garage. Pass a 4th arg if you've
    -- renamed/added garages there.
    local garageKey = args[4] or 'legion'
    local Target = targetId and HD.Functions.GetPlayer(targetId)

    if not Target or not model or not plate then Notify(src, 'Usage: /givevehicle [id] [model] [plate] [garageKey]', 'error') return end
    plate = plate:sub(1, 15)

    local exists = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { plate })
    if exists then Notify(src, 'That plate is already in use.', 'error') return end

    MySQL.insert.await(
        'INSERT INTO player_vehicles (license, citizenid, vehicle, plate, garage, state, fuel, engine, body) VALUES (?, ?, ?, ?, ?, 1, 100, 1000, 1000)',
        { Target.PlayerData.license, Target.PlayerData.citizenid, model:lower(), plate, garageKey }
    )
    Notify(src, ('Gave %s a %s (%s), stored at garage "%s".'):format(Target.PlayerData.citizenid, model, plate, garageKey), 'success')
end, false)
