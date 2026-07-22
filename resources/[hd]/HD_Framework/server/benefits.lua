-- ═══════════════════════════════════════════════════════════════════
--  HD_FRAMEWORK | UK BENEFITS (UNIVERSAL CREDIT)
--  Every character defaults to the 'unemployed' job (see
--  server/main.lua LoadOrCreatePlayer). Anyone still unemployed gets
--  a small standing-order style payment on an interval so new
--  civilians aren't stranded at zero, styled as UK Universal Credit
--  rather than an arbitrary "starter cash" hack.
-- ═══════════════════════════════════════════════════════════════════

if not Config.Benefits.Enabled then return end

CreateThread(function()
    while true do
        Wait(Config.Benefits.IntervalMinutes * 60000)
        for _, Player in pairs(HD.Players) do
            if Player.PlayerData.job.name == Config.Benefits.Job then
                Player.Functions.AddMoney('bank', Config.Benefits.Amount, 'universal-credit')
                TriggerClientEvent('HD:Client:Notify', Player.PlayerData.source,
                    Config.Benefits.NotifyMessage:format(Config.Benefits.Amount), 'success')
            end
        end
    end
end)
