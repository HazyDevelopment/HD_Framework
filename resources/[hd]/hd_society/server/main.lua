-- ═══════════════════════════════════════════════════════════════════
--  HD SOCIETY | SERVER
--  Every write goes through AddFunds/RemoveFunds so there's exactly
--  one place balances change — the /boss menu, HD_Framework's salary
--  loop, and hd_cardealer's sale-cut deposit all call these same two
--  functions rather than touching the table directly.
-- ═══════════════════════════════════════════════════════════════════

local Framework = nil
CreateThread(function()
    while GetResourceState('qb-core') ~= 'started' do Wait(100) end
    Framework = exports['qb-core']:GetCoreObject()
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

local function AddFunds(society, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    EnsureRow(society)
    MySQL.update('UPDATE hd_society_funds SET balance = balance + ? WHERE society = ?', { amount, society })
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
local function RemoveFunds(society, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    EnsureRow(society)
    local affected = MySQL.update.await(
        'UPDATE hd_society_funds SET balance = balance - ? WHERE society = ? AND balance >= ?',
        { amount, society, amount }
    )
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

    AddFunds(Player.PlayerData.job.name, amount)
    TriggerClientEvent('HD:Client:Notify', src, ('Deposited £%d.'):format(amount), 'success')
    TriggerClientEvent('hd_society:client:balance', src, GetBalance(Player.PlayerData.job.name))
end)

RegisterNetEvent('hd_society:server:withdraw', function(amount)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not IsBoss(Player) then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    if not RemoveFunds(Player.PlayerData.job.name, amount) then
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

    AddFunds(society, amount)
    TriggerClientEvent('HD:Client:Notify', src, ('Added £%d to %s. New balance: £%d'):format(amount, society, GetBalance(society)), 'success')
end, false)
