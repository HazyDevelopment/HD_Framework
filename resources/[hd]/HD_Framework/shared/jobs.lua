-- ═══════════════════════════════════════════════════════════════════
--  HD_FRAMEWORK | SHARED JOBS
--  Every job on the server, UK-themed end to end. Structure matches
--  the QBCore convention exactly (label / type / defaultDuty /
--  offDutyPay / grades[n] = { name, isboss, payment }) so every
--  QBCore-ecosystem resource (uk_policejob, uk_uhsjob, hazy_mdt,
--  anything installed later) reads it with zero changes.
--
--  job.type is the important extension point beyond stock QBCore:
--    'leo'      -> United Kingdom Police. Boss/armed-response gating
--                  in uk_policejob keys off this.
--    'ems'      -> United Kingdom Health Service.
--    'mechanic' -> ANY job with type = 'mechanic' automatically
--                  qualifies for recovery calls in the dispatch
--                  system, not just the stock 'mechanic' job below.
--                  Add a second garage's job here later (e.g.
--                  ["leroys"] = { type = 'mechanic', ... }) and it
--                  picks up recovery dispatch access for free — no
--                  dispatch code needs touching.
-- ═══════════════════════════════════════════════════════════════════

Jobs = {}

-- ═══════════════════════════ EMERGENCY SERVICES ═════════════════════

-- Ranks match uk_policejob/config.lua's Config.Ranks exactly (0 = PCSO
-- ... 15 = Commissioner) — copied verbatim from
-- uk_policejob/qbcore_job.txt so armoury/garage/GPS grade gates and
-- hazy_mdt's boss detection all line up automatically.
Jobs['police'] = {
    label = 'United Kingdom Police',
    type = 'leo',
    defaultDuty = false,
    offDutyPay = false,
    grades = {
        [0]  = { name = 'PCSO' },
        [1]  = { name = 'Police Constable' },
        [2]  = { name = 'Sergeant' },
        [3]  = { name = 'Inspector' },
        [4]  = { name = 'Chief Inspector' },
        [5]  = { name = 'Armed Response Officer' },
        [6]  = { name = 'ARV Sergeant' },
        [7]  = { name = 'ARV Inspector' },
        [8]  = { name = 'ARV Commander' },
        [9]  = { name = 'Superintendent' },
        [10] = { name = 'Chief Superintendent' },
        [11] = { name = 'Commander' },
        [12] = { name = 'Deputy Assistant Commissioner' },
        [13] = { name = 'Assistant Commissioner' },
        [14] = { name = 'Deputy Commissioner' },
        [15] = { name = 'Commissioner', isboss = true },
    },
}

-- Ranks match uk_uhsjob/config.lua's Config.Ranks exactly (0 = Student
-- Paramedic ... 9 = Operations Manager) — copied verbatim from
-- uk_uhsjob/qbcore_job.txt.
Jobs['ambulance'] = {
    label = 'United Kingdom Health Service',
    type = 'ems',
    defaultDuty = false,
    offDutyPay = false,
    grades = {
        [0] = { name = 'Student Paramedic' },
        [1] = { name = 'Newly Qualified Paramedic' },
        [2] = { name = 'Paramedic' },
        [3] = { name = 'Specialist Paramedic' },
        [4] = { name = 'Advanced Paramedic' },
        [5] = { name = 'Clinical Team Leader' },
        [6] = { name = 'Duty Manager' },
        [7] = { name = 'Senior Duty Manager' },
        [8] = { name = 'Deputy Operations Manager' },
        [9] = { name = 'Operations Manager', isboss = true },
    },
}

-- ═══════════════════════════ CIVILIAN — UK REPLACEMENTS ═════════════
-- These replace QBCore's stock civilian jobs (unemployed, mechanic,
-- taxi, cardealer, realestate, reporter, lawyer, judge, bus, garbage,
-- trucker, postal) with realistic UK equivalents. Every job here is
-- an original setup, not a reproduction of any real company's name,
-- livery or branding.

-- Default job for every new character. Standing-order style payments
-- ("Universal Credit") are handled in server/benefits.lua, not here.
Jobs['unemployed'] = {
    label = 'Unemployed',
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        [0] = { name = 'Universal Credit Claimant', isboss = false },
    },
}

-- Recovery-eligible by type — see the header note. This is the
-- default garage job; more mechanic-type jobs can be added freely.
Jobs['mechanic'] = {
    label = 'Vehicle Technician',
    type = 'mechanic',
    defaultDuty = false,
    offDutyPay = true,
    grades = {
        [0] = { name = 'Apprentice Technician', payment = 60 },
        [1] = { name = 'Vehicle Technician', payment = 75 },
        [2] = { name = 'Senior Technician', payment = 90 },
        [3] = { name = 'Recovery Operator', payment = 100 },
        [4] = { name = 'Garage Manager', payment = 120, isboss = true },
    },
}

Jobs['taxi'] = {
    label = 'Private Hire Driver',
    defaultDuty = false,
    offDutyPay = true,
    grades = {
        [0] = { name = 'Trainee Driver', payment = 55 },
        [1] = { name = 'Private Hire Driver', payment = 70 },
        [2] = { name = 'Senior Driver', payment = 85 },
        [3] = { name = 'Fleet Manager', payment = 105, isboss = true },
    },
}

Jobs['cardealer'] = {
    label = 'Car Sales Executive',
    defaultDuty = false,
    offDutyPay = true,
    grades = {
        [0] = { name = 'Trainee Salesperson', payment = 55 },
        [1] = { name = 'Sales Executive', payment = 75 },
        [2] = { name = 'Senior Sales Executive', payment = 95 },
        [3] = { name = 'Dealership Manager', payment = 115, isboss = true },
    },
}

Jobs['realestate'] = {
    label = 'Estate Agent',
    defaultDuty = false,
    offDutyPay = true,
    grades = {
        [0] = { name = 'Trainee Negotiator', payment = 55 },
        [1] = { name = 'Estate Agent', payment = 75 },
        [2] = { name = 'Senior Negotiator', payment = 95 },
        [3] = { name = 'Branch Manager', payment = 120, isboss = true },
    },
}

Jobs['busdriver'] = {
    label = 'Bus Driver',
    defaultDuty = false,
    offDutyPay = true,
    grades = {
        [0] = { name = 'Trainee Driver', payment = 55 },
        [1] = { name = 'Bus Driver', payment = 70 },
        [2] = { name = 'Senior Driver', payment = 85 },
        [3] = { name = 'Depot Supervisor', payment = 100, isboss = true },
    },
}

Jobs['hgv'] = {
    label = 'HGV Driver',
    defaultDuty = false,
    offDutyPay = true,
    grades = {
        [0] = { name = 'Class 2 Driver', payment = 65 },
        [1] = { name = 'Class 1 Driver', payment = 85 },
        [2] = { name = 'Senior HGV Driver', payment = 100 },
        [3] = { name = 'Transport Manager', payment = 120, isboss = true },
    },
}

Jobs['binman'] = {
    label = 'Waste Collector',
    defaultDuty = false,
    offDutyPay = true,
    grades = {
        [0] = { name = 'Waste Collector', payment = 55 },
        [1] = { name = 'Senior Loader', payment = 65 },
        [2] = { name = 'Crew Supervisor', payment = 80 },
        [3] = { name = 'Depot Manager', payment = 100, isboss = true },
    },
}

Jobs['postal'] = {
    label = 'National Mail Service',
    defaultDuty = false,
    offDutyPay = true,
    grades = {
        [0] = { name = 'Postal Worker', payment = 55 },
        [1] = { name = 'Senior Postal Worker', payment = 70 },
        [2] = { name = 'Round Supervisor', payment = 85 },
        [3] = { name = 'Depot Manager', payment = 105, isboss = true },
    },
}

Jobs['reporter'] = {
    label = 'City News Network',
    defaultDuty = false,
    offDutyPay = true,
    grades = {
        [0] = { name = 'Trainee Reporter', payment = 55 },
        [1] = { name = 'Journalist', payment = 75 },
        [2] = { name = 'Senior Correspondent', payment = 95 },
        [3] = { name = 'Editor', payment = 120, isboss = true },
    },
}

Jobs['solicitor'] = {
    label = 'Solicitor',
    defaultDuty = false,
    offDutyPay = true,
    grades = {
        [0] = { name = 'Trainee Solicitor', payment = 70 },
        [1] = { name = 'Solicitor', payment = 95 },
        [2] = { name = 'Senior Solicitor', payment = 120 },
        [3] = { name = 'Partner', payment = 150, isboss = true },
    },
}

Jobs['judiciary'] = {
    label = 'Judiciary',
    defaultDuty = false,
    offDutyPay = true,
    grades = {
        [0] = { name = 'Judge', payment = 160, isboss = true },
    },
}
