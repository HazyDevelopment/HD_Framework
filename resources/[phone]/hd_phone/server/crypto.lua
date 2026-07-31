-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | CRYPTO
--  Single server-authoritative coin, random-walked on a fixed tick,
--  clamped to a min/max band, persisted so it survives a restart.
-- ═══════════════════════════════════════════════════════════════════

local CurrentPrice = Config.Crypto.StartPrice

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    local row = MySQL.single.await('SELECT price FROM hd_phone_crypto_state WHERE id = 1')
    if row then CurrentPrice = tonumber(row.price) end

    while true do
        Wait(Config.Crypto.TickSeconds * 1000)
        local swing = (math.random() * 2 - 1) * (Config.Crypto.MaxSwingPercent / 100)
        CurrentPrice = CurrentPrice * (1 + swing)
        if CurrentPrice < Config.Crypto.MinPrice then CurrentPrice = Config.Crypto.MinPrice end
        if CurrentPrice > Config.Crypto.MaxPrice then CurrentPrice = Config.Crypto.MaxPrice end
        MySQL.update('UPDATE hd_phone_crypto_state SET price = ? WHERE id = 1', { CurrentPrice })
        TriggerClientEvent('hd_phone:client:cryptoPrice', -1, math.floor(CurrentPrice * 100) / 100)
    end
end)

local function GetHoldings(citizenid)
    local row = MySQL.single.await('SELECT amount FROM hd_phone_crypto_holdings WHERE citizenid = ?', { citizenid })
    return row and tonumber(row.amount) or 0
end

RegisterNetEvent('hd_phone:server:getCrypto', function()
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    TriggerClientEvent('hd_phone:client:crypto', src, {
        price = math.floor(CurrentPrice * 100) / 100,
        holdings = GetHoldings(Player.PlayerData.citizenid),
        coinName = Config.Crypto.CoinName,
        coinTicker = Config.Crypto.CoinTicker,
    })
end)

RegisterNetEvent('hd_phone:server:cryptoBuy', function(amountGbp)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    amountGbp = math.floor(tonumber(amountGbp) or 0)
    if amountGbp <= 0 then return end
    if not Player.Functions.RemoveMoney('bank', amountGbp, 'Crypto purchase') then
        Notify(src, "You don't have that much in the bank.", 'error')
        return
    end
    local coinAmount = amountGbp / CurrentPrice
    MySQL.query.await([[
        INSERT INTO hd_phone_crypto_holdings (citizenid, amount) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount)
    ]], { Player.PlayerData.citizenid, coinAmount })
    Notify(src, ('Bought %.4f %s.'):format(coinAmount, Config.Crypto.CoinTicker), 'success')
end)

RegisterNetEvent('hd_phone:server:cryptoSell', function(coinAmount)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    coinAmount = tonumber(coinAmount) or 0
    if coinAmount <= 0 then return end
    local holdings = GetHoldings(Player.PlayerData.citizenid)
    if coinAmount > holdings then
        Notify(src, ("You don't have that much %s."):format(Config.Crypto.CoinTicker), 'error')
        return
    end
    local gbp = math.floor(coinAmount * CurrentPrice)
    MySQL.update('UPDATE hd_phone_crypto_holdings SET amount = amount - ? WHERE citizenid = ?', { coinAmount, Player.PlayerData.citizenid })
    Player.Functions.AddMoney('bank', gbp, 'Crypto sale')
    Notify(src, ('Sold for £%d.'):format(gbp), 'success')
end)
