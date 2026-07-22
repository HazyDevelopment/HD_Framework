Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD SOCIETY | HAZY DEVELOPMENT | v1.0.0
--  A shared business fund per job. `/boss` opens the menu for whoever
--  currently holds the top (isboss) grade of a listed job — deposit
--  personal bank money in, withdraw fund money out. HD_Framework's
--  on-duty salary loop (server/salary.lua) now draws police/ambulance/
--  cardealer wages from this fund instead of conjuring money, so an
--  empty fund really does mean nobody on that job gets paid until a
--  boss (or an admin via /addfunds) puts money in.
-- ═══════════════════════════════════════════════════════════════════

-- Which jobs have a fund at all — `solicitor`/`judiciary` stay off
-- personal flat wages (see HD_Framework's Config.Salary), and the
-- seven hd_civjobs jobs earn per contract, so neither belongs here.
-- `mechanic` was added alongside hd_mechanic (MOT/insurance/repair
-- fees deposit here, same shape as hd_fines feeding police/ambulance).
Config.Societies = {
    police = true,
    ambulance = true,
    cardealer = true,
    mechanic = true,
}

Config.Command = 'boss'

Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
