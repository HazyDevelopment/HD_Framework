-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | CRYPTO
--  One simulated coin, server-authoritative random-walk price ticked
--  on a timer and persisted so it survives a restart. Like the social
--  feeds, price isn't pushed live to open clients — the NUI just
--  re-polls periodically while the app is open (see html/js/app.js).
--  That's a deliberate match to this resource's existing "pull, don't
--  track who has what open" pattern (see server/social.lua's header).
-- ═══════════════════════════════════════════════════════════════════

local CurrentPrice = 100.00
local PriceHistory = {}

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    local row = MySQL.single.await('SELECT price FROM hd_phone_crypto_state WHERE id = 1')
    CurrentPrice = row and tonumber(row.price) or 100.00
    PriceHistory = { CurrentPrice }
end)

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    while true do
        Wait(Config.Crypto.TickIntervalMs)

        local swingPercent = (math.random() * 2 - 1) * Config.Crypto.VolatilityPercent -- -V..+V
        local newPrice = CurrentPrice * (1 + swingPercent / 100)
        newPrice = math.max(Config.Crypto.MinPrice, math.min(Config.Crypto.MaxPrice, newPrice))
        CurrentPrice = math.floor(newPrice * 100 + 0.5) / 100

        table.insert(PriceHistory, CurrentPrice)
        while #PriceHistory > Config.Crypto.PriceHistoryLength do table.remove(PriceHistory, 1) end

        MySQL.update('UPDATE hd_phone_crypto_state SET price = ? WHERE id = 1', { CurrentPrice })
    end
end)

local function GetHoldings(citizenid)
    local row = MySQL.single.await('SELECT amount FROM hd_phone_crypto_holdings WHERE citizenid = ?', { citizenid })
    return row and tonumber(row.amount) or 0
end

local function SetHoldings(citizenid, amount)
    MySQL.query.await([[
        INSERT INTO hd_phone_crypto_holdings (citizenid, amount) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE amount = VALUES(amount)
    ]], { citizenid, amount })
end

RegisterNetEvent('hd_phone:server:getCrypto', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end
    TriggerClientEvent('hd_phone:client:crypto', src, {
        coinName = Config.Crypto.CoinName,
        ticker = Config.Crypto.CoinTicker,
        price = CurrentPrice,
        history = PriceHistory,
        holdings = GetHoldings(Player.PlayerData.citizenid),
    })
end)

RegisterNetEvent('hd_phone:server:cryptoBuy', function(spendAmount)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end
    spendAmount = math.floor(tonumber(spendAmount) or 0)
    if spendAmount <= 0 then return end

    if not Player.Functions.RemoveMoney('bank', spendAmount, 'crypto-buy') then
        return TriggerClientEvent('HD:Client:Notify', src, 'Not enough in your bank account.', 'error')
    end

    local coinsBought = spendAmount / CurrentPrice
    local citizenid = Player.PlayerData.citizenid
    SetHoldings(citizenid, GetHoldings(citizenid) + coinsBought)

    TriggerClientEvent('HD:Client:Notify', src, ('Bought %.4f %s.'):format(coinsBought, Config.Crypto.CoinTicker), 'success')
    TriggerClientEvent('hd_phone:client:crypto', src, {
        coinName = Config.Crypto.CoinName, ticker = Config.Crypto.CoinTicker,
        price = CurrentPrice, history = PriceHistory, holdings = GetHoldings(citizenid),
    })
end)

RegisterNetEvent('hd_phone:server:cryptoSell', function(coinAmount)
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end
    coinAmount = tonumber(coinAmount) or 0
    if coinAmount <= 0 then return end

    local citizenid = Player.PlayerData.citizenid
    local holdings = GetHoldings(citizenid)
    if coinAmount > holdings then
        return TriggerClientEvent('HD:Client:Notify', src, ('You only hold %.4f %s.'):format(holdings, Config.Crypto.CoinTicker), 'error')
    end

    local proceeds = math.floor(coinAmount * CurrentPrice)
    SetHoldings(citizenid, holdings - coinAmount)
    Player.Functions.AddMoney('bank', proceeds, 'crypto-sell')

    TriggerClientEvent('HD:Client:Notify', src, ('Sold for £%d.'):format(proceeds), 'success')
    TriggerClientEvent('hd_phone:client:crypto', src, {
        coinName = Config.Crypto.CoinName, ticker = Config.Crypto.CoinTicker,
        price = CurrentPrice, history = PriceHistory, holdings = GetHoldings(citizenid),
    })
end)
