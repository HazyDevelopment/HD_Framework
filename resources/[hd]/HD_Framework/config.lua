Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD_FRAMEWORK | HAZY DEVELOPMENT | v1.0.0
--  Standalone core — the sole source of truth for player data, money
--  and jobs. Every other HD resource in this server calls
--  exports['HD_Framework']:GetCoreObject() directly; there is no
--  qb-core (or any other framework-name) compatibility bridge, and
--  none should be added — that's a deliberate choice, not an
--  oversight. uk_policejob/uk_uhsjob are compiled/escrowed resources
--  hardcoded to call exports['HD_Framework'], so they will NOT run against
--  this framework (see README).
-- ═══════════════════════════════════════════════════════════════════

Config.ServerName = 'HD Framework'

-- ═══════════════════════════ STARTING BALANCE ══════════════════════
Config.StartingCash = 500
Config.StartingBank = 2500

-- ═══════════════════════════ DEFAULT SPAWN ═════════════════════════
-- Used the first time a character is created. Change to your MDT/
-- spawn resource's preferred coordinates.
Config.DefaultSpawn = vector4(-269.4, -955.3, 31.2, 205.8) -- Legion Square, London-reskinned Los Santos

-- ═══════════════════════════ CHARACTER DEFAULTS ════════════════════
-- HD_Framework auto-creates a single character per license on first
-- join (multi-character selection is a natural extension point for
-- the phone/UI phase — see server/main.lua CreatePlayer). These are
-- the placeholder details that character starts with; players are
-- expected to update them via a future "ID card" phone app or
-- /setcharinfo (see server/commands.lua).
Config.DefaultCharinfo = {
    nationality = 'British',
    phone = nil, -- generated per-player, see server/main.lua GeneratePhoneNumber
}

-- ═══════════════════════════ UK BENEFITS (UNIVERSAL CREDIT) ════════
-- Anyone still on the 'unemployed' job is paid a small standing-order
-- style payment on an interval, styled as UK Universal Credit. This
-- keeps brand-new characters afloat without inventing a fake "starter
-- job" — unemployed is a real, valid default job in the UK sense.
Config.Benefits = {
    Enabled = true,
    Job = 'unemployed',
    Amount = 85,          -- paid to bank
    IntervalMinutes = 45,
    NotifyMessage = 'Universal Credit payment received: £%s'
}

-- ═══════════════════════════ CIVILIAN SALARY ════════════════════════
-- Every civilian job's grades already have a `payment` value in
-- shared/jobs.lua — this is what actually pays it out. `unemployed`
-- has its own Universal Credit loop above, and taxi/hgv/postal/binman/
-- busdriver/reporter/realestate earn per hd_civjobs contract instead
-- (a passive salary on top would double-pay), so both are excluded
-- entirely. That leaves two payment paths for everyone else:
--   • SocietyJobs (police/ambulance/cardealer/mechanic) draw wages
--     from their hd_society business fund — an empty fund means no
--     wages that tick, not free money. `mechanic`'s fund is fed by
--     hd_mechanic's MOT/insurance/repair fees, same shape as fines
--     feeding police/ambulance. If hd_society isn't installed:
--     cardealer/mechanic fall back to a flat personal wage (their
--     pre-hd_society behaviour), police/ambulance get nothing (they
--     were never paid a flat personal wage — a real police force
--     isn't self-funded).
--   • Everyone else left in (solicitor, judiciary) gets the flat
--     personal wage every tick, same as always.
Config.Salary = {
    Enabled = true,
    IntervalMinutes = 20,
    ExcludeJobs = {
        'unemployed',
        'taxi', 'hgv', 'postal', 'binman', 'busdriver', 'reporter', 'realestate',
    },
    SocietyJobs = { 'police', 'ambulance', 'cardealer', 'mechanic' },
    SocietyFallbackFlatPay = { cardealer = true, mechanic = true }, -- see the note above
}

-- ═══════════════════════════ SAVE / PERFORMANCE ════════════════════
Config.AutoSaveIntervalMinutes = 5
Config.CitizenIdPrefix = '' -- e.g. 'HD' to make ids look like HD4F82A1 instead of 4F82A1

-- ═══════════════════════════ MONEY ACCOUNTS ════════════════════════
-- UK-flavoured account names. 'cash' and 'bank' are the two accounts
-- every job/inventory/dispatch script in this server expects to
-- exist; add more (e.g. 'crypto') here if you want them later.
Config.Accounts = {
    cash = { label = 'Cash' },
    bank = { label = 'Bank Account' }
}

-- ═══════════════════════════ DEBUG ═════════════════════════════════
Config.Debug = false
