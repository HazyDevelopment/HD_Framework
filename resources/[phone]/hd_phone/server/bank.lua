-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | BANK
--  Reads/writes HD_Framework's real cash/bank balances — no separate
--  balance table, hd_phone_bank_log is just the statement lines.
-- ═══════════════════════════════════════════════════════════════════

local function GetSourceByPhone(number)
    for _, srcStr in ipairs(GetPlayers()) do
        local candidate = tonumber(srcStr)
        local Player = GetPlayerOrNil(candidate)
        if Player and Player.PlayerData.charinfo.phone == number then return candidate end
    end
    return nil
end

local function LogLine(citizenid, kind, amount, otherParty)
    MySQL.insert('INSERT INTO hd_phone_bank_log (citizenid, type, amount, other_party) VALUES (?, ?, ?, ?)', {
        citizenid, kind, amount, otherParty
    })
end

local function SendBank(src, Player)
    local log = MySQL.query.await('SELECT * FROM hd_phone_bank_log WHERE citizenid = ? ORDER BY id DESC LIMIT 40', {
        Player.PlayerData.citizenid
    }) or {}
    TriggerClientEvent('hd_phone:client:bank', src, {
        cash = Player.Functions.GetMoney('cash'),
        bank = Player.Functions.GetMoney('bank'),
        log = log,
    })
end

RegisterNetEvent('hd_phone:server:getBank', function()
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    SendBank(src, Player)
end)

RegisterNetEvent('hd_phone:server:bankDeposit', function(amount)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    if not Player.Functions.RemoveMoney('cash', amount, 'Bank deposit') then
        Notify(src, "You don't have that much cash.", 'error')
        return
    end
    Player.Functions.AddMoney('bank', amount, 'Bank deposit')
    LogLine(Player.PlayerData.citizenid, 'deposit', amount, nil)
    SendBank(src, Player)
end)

RegisterNetEvent('hd_phone:server:bankWithdraw', function(amount)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    if not Player.Functions.RemoveMoney('bank', amount, 'Bank withdrawal') then
        Notify(src, "You don't have that much in the bank.", 'error')
        return
    end
    Player.Functions.AddMoney('cash', amount, 'Bank withdrawal')
    LogLine(Player.PlayerData.citizenid, 'withdraw', amount, nil)
    SendBank(src, Player)
end)

RegisterNetEvent('hd_phone:server:bankTransfer', function(toNumber, amount)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    amount = math.floor(tonumber(amount) or 0)
    toNumber = type(toNumber) == 'string' and toNumber or ''
    if amount <= 0 or toNumber == '' or toNumber == Player.PlayerData.charinfo.phone then return end

    local targetSrc = GetSourceByPhone(toNumber)
    if not targetSrc then
        Notify(src, "That number isn't online.", 'error')
        return
    end
    local TargetPlayer = GetPlayerOrNil(targetSrc)
    if not Player.Functions.RemoveMoney('bank', amount, 'Bank transfer') then
        Notify(src, "You don't have that much in the bank.", 'error')
        return
    end
    TargetPlayer.Functions.AddMoney('bank', amount, 'Bank transfer')
    LogLine(Player.PlayerData.citizenid, 'transfer_out', amount, toNumber)
    LogLine(TargetPlayer.PlayerData.citizenid, 'transfer_in', amount, Player.PlayerData.charinfo.phone)

    if GetResourceState('hd_phone') == 'started' then
        exports['hd_phone']:SendSystemMessage(toNumber, 'HD Bank', ('£%d received from %s.'):format(amount, Player.PlayerData.charinfo.phone))
    end
    Notify(src, ('Sent £%d.'):format(amount), 'success')
    Notify(targetSrc, ('£%d received from %s.'):format(amount, Player.PlayerData.charinfo.phone), 'success')
    SendBank(src, Player)
    SendBank(targetSrc, TargetPlayer)
end)
