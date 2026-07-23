-- ═══════════════════════════════════════════════════════════════════
--  HD SOCIETY | SERVER
--  Every write goes through AddFunds/RemoveFunds so there's exactly
--  one place balances change — the /boss menu, HD_Framework's salary
--  loop, and hd_cardealer's sale-cut deposit all call these same two
--  functions rather than touching the table directly.
-- ═══════════════════════════════════════════════════════════════════

local Framework = nil
CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

CreateThread(function()
    Wait(1500)
    local ok = pcall(function() MySQL.query.await('SELECT 1 FROM `hd_society_funds` LIMIT 1') end)
    if not ok then
        print('^1[hd_society] ============================================================^7')
        print('^1[hd_society] DATABASE NOT INSTALLED.^7')
        print('^1[hd_society] Import sql/hd_society_install.sql before using society funds.^7')
        print('^1[hd_society] ============================================================^7')
    else
        print('^2[hd_society]^7 Database verified. Ready.')
    end
end)

local function EnsureRow(society)
    MySQL.query.await('INSERT IGNORE INTO hd_society_funds (society, balance) VALUES (?, 0)', { society })
end

local function GetBalance(society)
    EnsureRow(society)
    return MySQL.scalar.await('SELECT balance FROM hd_society_funds WHERE society = ?', { society }) or 0
end

-- Every AddFunds/RemoveFunds call lands one row here — see the
-- top-level README's "Where to go from here" ("no transaction log for
-- hd_society"). `actor`/`reason` are both optional; a caller that
-- doesn't pass them just gets a row with NULLs instead of failing.
local function LogTransaction(society, ttype, amount, actor, reason)
    MySQL.insert('INSERT INTO hd_society_transactions (society, type, amount, actor, reason) VALUES (?, ?, ?, ?, ?)', {
        society, ttype, amount, actor, reason
    })
end

-- `reason`/`actor` are optional on both — existing external callers
-- that only ever passed (society, amount) keep working exactly as
-- before, they just log with a NULL reason/actor instead of a
-- meaningful one until updated to pass them.
local function AddFunds(society, amount, reason, actor)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    EnsureRow(society)
    MySQL.update('UPDATE hd_society_funds SET balance = balance + ? WHERE society = ?', { amount, society })
    LogTransaction(society, 'credit', amount, actor, reason)
    return true
end

-- Atomic — the balance check and the deduction are the SAME
-- statement, not a separate SELECT then UPDATE. MySQL evaluates the
-- WHERE clause against each row's current value as it locks it for
-- the write, so two withdrawals landing in the same instant can't
-- both succeed against a balance that only covers one of them: the
-- second one's WHERE simply no longer matches once the first has
-- applied, and MySQL.update.await returns the affected-row count
-- (0 = nothing matched, i.e. insufficient funds or unknown society).
-- This replaced an earlier read-check-write version that had exactly
-- that race.
local function RemoveFunds(society, amount, reason, actor)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    EnsureRow(society)
    local affected = MySQL.update.await(
        'UPDATE hd_society_funds SET balance = balance - ? WHERE society = ? AND balance >= ?',
        { amount, society, amount }
    )
    if affected > 0 then LogTransaction(society, 'debit', amount, actor, reason) end
    return affected > 0
end

exports('AddFunds', AddFunds)
exports('RemoveFunds', RemoveFunds)
exports('GetBalance', GetBalance)

-- ═══════════════════════════ BOSS MENU ════════════════════════════════
local function IsBoss(Player)
    return Player and Player.PlayerData.job.isboss and Config.Societies[Player.PlayerData.job.name]
end

RegisterNetEvent('hd_society:server:open', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not IsBoss(Player) then
        TriggerClientEvent('HD:Client:Notify', src, 'Boss access only.', 'error')
        return
    end
    TriggerClientEvent('hd_society:client:open', src, Player.PlayerData.job.name, Player.PlayerData.job.label, GetBalance(Player.PlayerData.job.name))
end)

RegisterNetEvent('hd_society:server:deposit', function(amount)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not IsBoss(Player) then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    if not Player.Functions.RemoveMoney('bank', amount, 'society-deposit') then
        TriggerClientEvent('HD:Client:Notify', src, 'Insufficient bank funds.', 'error')
        return
    end

    AddFunds(Player.PlayerData.job.name, amount, 'boss-deposit', Player.PlayerData.citizenid)
    TriggerClientEvent('HD:Client:Notify', src, ('Deposited £%d.'):format(amount), 'success')
    TriggerClientEvent('hd_society:client:balance', src, GetBalance(Player.PlayerData.job.name))
end)

RegisterNetEvent('hd_society:server:withdraw', function(amount)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not IsBoss(Player) then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    if not RemoveFunds(Player.PlayerData.job.name, amount, 'boss-withdraw', Player.PlayerData.citizenid) then
        TriggerClientEvent('HD:Client:Notify', src, 'Insufficient society funds.', 'error')
        return
    end

    Player.Functions.AddMoney('bank', amount, 'society-withdraw')
    TriggerClientEvent('HD:Client:Notify', src, ('Withdrew £%d.'):format(amount), 'success')
    TriggerClientEvent('hd_society:client:balance', src, GetBalance(Player.PlayerData.job.name))
end)

-- ═══════════════════════════ ADMIN SEEDING ════════════════════════════
-- police/ambulance have no in-world revenue mechanic in this
-- framework (no fines/tickets system) — this is how their funds get
-- seeded until one exists. cardealer earns organically from
-- hd_cardealer's own sale-cut deposit.
RegisterCommand('addfunds', function(source, args)
    local src = source
    if src ~= 0 and not IsPlayerAceAllowed(src, 'hd.admin') then
        TriggerClientEvent('HD:Client:Notify', src, 'No permission.', 'error')
        return
    end

    local society = args[1]
    local amount = tonumber(args[2])
    if not society or not amount then
        TriggerClientEvent('HD:Client:Notify', src, 'Usage: /addfunds [society] [amount]', 'error')
        return
    end

    local AdminPlayer = src ~= 0 and Framework.Functions.GetPlayer(src)
    AddFunds(society, amount, 'admin-seed', AdminPlayer and AdminPlayer.PlayerData.citizenid or 'console')
    TriggerClientEvent('HD:Client:Notify', src, ('Added £%d to %s. New balance: £%d'):format(amount, society, GetBalance(society)), 'success')
end, false)

-- ═══════════════════════════ TRANSACTION HISTORY ═══════════════════════
-- No NUI for this — the boss menu stays deposit/withdraw-only, this is
-- a quick admin/boss lookup tool. Boss sees only their own society;
-- hd.admin can check any of them (or the caller's own if omitted).
RegisterCommand('societyhistory', function(source, args)
    local src = source
    local Player = src ~= 0 and Framework.Functions.GetPlayer(src)
    local isAdmin = src == 0 or IsPlayerAceAllowed(src, 'hd.admin')

    local society = args[1]
    if not society then
        if IsBoss(Player) then
            society = Player.PlayerData.job.name
        else
            TriggerClientEvent('HD:Client:Notify', src, 'Usage: /societyhistory [society]', 'error')
            return
        end
    elseif not isAdmin and not (IsBoss(Player) and Player.PlayerData.job.name == society) then
        TriggerClientEvent('HD:Client:Notify', src, 'No permission.', 'error')
        return
    end

    local rows = MySQL.query.await(
        'SELECT type, amount, actor, reason, created FROM hd_society_transactions WHERE society = ? ORDER BY created DESC LIMIT 10',
        { society }
    ) or {}

    if #rows == 0 then
        TriggerClientEvent('HD:Client:Notify', src, ('No recorded transactions for %s yet.'):format(society), 'info')
        return
    end

    TriggerClientEvent('HD:Client:Notify', src, ('Last %d transactions for %s (newest first):'):format(#rows, society), 'info')
    for _, row in ipairs(rows) do
        local sign = row.type == 'credit' and '+' or '-'
        TriggerClientEvent('HD:Client:Notify', src,
            ('%s£%d — %s%s'):format(sign, row.amount, row.reason or 'unspecified', row.actor and (' (' .. row.actor .. ')') or ''),
            row.type == 'credit' and 'success' or 'error')
    end
end, false)
