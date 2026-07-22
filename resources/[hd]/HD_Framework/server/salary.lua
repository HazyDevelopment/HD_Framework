-- ═══════════════════════════════════════════════════════════════════
--  HD_FRAMEWORK | CIVILIAN SALARY
--  See Config.Salary in config.lua for exactly which jobs this pays,
--  which draw from a society fund vs a flat personal wage, and why.
-- ═══════════════════════════════════════════════════════════════════

if not Config.Salary.Enabled then return end

local function IsExcluded(jobName)
    for _, j in ipairs(Config.Salary.ExcludeJobs) do
        if j == jobName then return true end
    end
    return false
end

local function IsSocietyJob(jobName)
    for _, j in ipairs(Config.Salary.SocietyJobs) do
        if j == jobName then return true end
    end
    return false
end

local function PaySocietyWage(Player, job)
    if GetResourceState('hd_society') ~= 'started' then
        if Config.Salary.SocietyFallbackFlatPay[job.name] then
            Player.Functions.AddMoney('bank', job.payment, 'job-salary')
            TriggerClientEvent('HD:Client:Notify', Player.PlayerData.source, ('Wages paid: £%s'):format(job.payment), 'success')
        end
        return
    end

    local paid = exports['hd_society']:RemoveFunds(job.name, job.payment)
    if paid then
        Player.Functions.AddMoney('bank', job.payment, 'job-salary-society')
        TriggerClientEvent('HD:Client:Notify', Player.PlayerData.source, ('Wages paid: £%s'):format(job.payment), 'success')
    else
        TriggerClientEvent('HD:Client:Notify', Player.PlayerData.source, 'No wages this tick — society funds are empty.', 'error')
    end
end

CreateThread(function()
    while true do
        Wait(Config.Salary.IntervalMinutes * 60000)
        for _, Player in pairs(HD.Players) do
            local job = Player.PlayerData.job
            if job.onduty and job.payment and job.payment > 0 and not IsExcluded(job.name) then
                if IsSocietyJob(job.name) then
                    PaySocietyWage(Player, job)
                else
                    Player.Functions.AddMoney('bank', job.payment, 'job-salary')
                    TriggerClientEvent('HD:Client:Notify', Player.PlayerData.source, ('Wages paid: £%s'):format(job.payment), 'success')
                end
            end
        end
    end
end)
