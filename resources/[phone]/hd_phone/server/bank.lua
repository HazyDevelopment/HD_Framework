-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | BANK
--  Reads/writes HD_Framework's real cash/bank accounts directly
--  (Player.Functions.AddMoney/RemoveMoney) — no shadow balance lives
--  in this resource. Transfers only reach an ONLINE recipient
--  (resolved by phone number), same scope limit Calls already has.
-- ═══════════════════════════════════════════════════════════════════

local function LogBank(citizenid, kind, amount, otherParty)
    MySQL.insert.await(
        'INSERT INTO hd_phone_bank_log (citizenid, type, amount, other_party) VALUES (?, ?, ?, ?)',
        { citizenid, kind, amount, otherParty }
    )
end

RegisterNetEvent('hd_phone:server:getBankAccount', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end
    TriggerClientEvent('hd_phone:client:bankAccount', src, {
        cash = Player.PlayerData.money.cash or 0,
        bank = Player.PlayerData.money.bank or 0,
    })
end)

RegisterNetEvent('hd_phone:server:getBankLog', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end
    local rows = MySQL.query.await(
        'SELECT * FROM hd_phone_bank_log WHERE citizenid = ? ORDER BY created DESC LIMIT 30',
        { Player.PlayerData.citizenid }
    ) or {}
    TriggerClientEvent('hd_phone:client:bankLog', src, rows)
end)

local function ValidAmount(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount < Config.Bank.MinTransfer or amount > Config.Bank.MaxTransfer then return nil end
    return amount
end

RegisterNetEvent('hd_phone:server:bankDeposit', function(amount)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end
    amount = ValidAmount(amount)
    if not amount then return end

    if not Player.Functions.RemoveMoney('cash', amount, 'phone-bank-deposit') then
        return TriggerClientEvent('HD:Client:Notify', src, 'Not enough cash.', 'error')
    end
    Player.Functions.AddMoney('bank', amount, 'phone-bank-deposit')
    LogBank(Player.PlayerData.citizenid, 'deposit', amount, nil)
    TriggerClientEvent('hd_phone:client:bankAccount', src, { cash = Player.PlayerData.money.cash, bank = Player.PlayerData.money.bank })
end)

RegisterNetEvent('hd_phone:server:bankWithdraw', function(amount)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end
    amount = ValidAmount(amount)
    if not amount then return end

    if not Player.Functions.RemoveMoney('bank', amount, 'phone-bank-withdraw') then
        return TriggerClientEvent('HD:Client:Notify', src, 'Not enough in your bank account.', 'error')
    end
    Player.Functions.AddMoney('cash', amount, 'phone-bank-withdraw')
    LogBank(Player.PlayerData.citizenid, 'withdraw', amount, nil)
    TriggerClientEvent('hd_phone:client:bankAccount', src, { cash = Player.PlayerData.money.cash, bank = Player.PlayerData.money.bank })
end)

RegisterNetEvent('hd_phone:server:bankTransfer', function(data)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player or type(data) ~= 'table' then return end

    local toNumber = type(data.toNumber) == 'string' and data.toNumber:gsub('%D', '') or ''
    local amount = ValidAmount(data.amount)
    local myNumber = Player.PlayerData.charinfo.phone

    if toNumber == '' or not amount or toNumber == myNumber then
        return TriggerClientEvent('HD:Client:Notify', src, 'Invalid transfer.', 'error')
    end

    local targetSrc = GetSourceByPhone(toNumber)
    if not targetSrc then
        return TriggerClientEvent('HD:Client:Notify', src, "That number isn't currently reachable.", 'error')
    end
    local TargetPlayer = Framework.Functions.GetPlayer(targetSrc)
    if not TargetPlayer then return end

    if not Player.Functions.RemoveMoney('bank', amount, 'phone-bank-transfer') then
        return TriggerClientEvent('HD:Client:Notify', src, 'Not enough in your bank account.', 'error')
    end
    TargetPlayer.Functions.AddMoney('bank', amount, 'phone-bank-transfer')

    local myName, theirName = GetDisplayName(src), GetDisplayName(targetSrc)
    LogBank(Player.PlayerData.citizenid, 'transfer_out', amount, theirName)
    LogBank(TargetPlayer.PlayerData.citizenid, 'transfer_in', amount, myName)

    SendMail(Player.PlayerData.citizenid, 'HD Bank', 'Transfer sent',
        ('You sent £%d to %s.'):format(amount, theirName))
    SendMail(TargetPlayer.PlayerData.citizenid, 'HD Bank', 'Transfer received',
        ('You received £%d from %s.'):format(amount, myName))

    TriggerClientEvent('hd_phone:client:bankAccount', src, { cash = Player.PlayerData.money.cash, bank = Player.PlayerData.money.bank })
    TriggerClientEvent('hd_phone:client:bankAccount', targetSrc, { cash = TargetPlayer.PlayerData.money.cash, bank = TargetPlayer.PlayerData.money.bank })
    TriggerClientEvent('HD:Client:Notify', src, ('Sent £%d to %s.'):format(amount, theirName), 'success')
    TriggerClientEvent('HD:Client:Notify', targetSrc, ('Received £%d from %s.'):format(amount, myName), 'success')
end)
