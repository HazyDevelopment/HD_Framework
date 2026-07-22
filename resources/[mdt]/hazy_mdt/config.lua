Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HAZY DEVELOPMENT | ADVANCED MDT | v2.1.0
--  This file is escrow_ignore'd — customise everything below freely.
-- ═══════════════════════════════════════════════════════════════════

-- Framework: 'auto' detects HD_Framework or ESX at runtime (checks for
-- a resource literally named HD_Framework). Force with 'hd' / 'esx'.
Config.Framework = 'auto'

-- How the MDT opens
Config.Command = 'mdt'            -- /mdt opens the MDT matching the player's job
Config.Keybind = 'F6'             -- default keybind (players can rebind in FiveM settings)
Config.UseKeybind = true

-- ═══════════════════════════ DEPARTMENTS ═══════════════════════════
-- Each department is fully isolated behind its own prefix. Events,
-- NUI callbacks and database tables never collide between the two.
Config.Departments = {

    police = {
        Prefix = 'mdtpolice',                 -- event + DB table prefix
        Brand = 'Police MDT',                 -- shown in the UI header
        BrandSub = 'Mobile Data Terminal',
        Jobs = { 'police', 'sheriff' },       -- jobs allowed to open this MDT
        -- BOSS (Command tab) DETECTION — works with the custom UK Police
        -- job AND stock qb-policejob / esx_policejob at the same time.
        -- A player is "boss" if ANY of these match (see notes at bottom):
        UseFrameworkBossFlag = true,          -- trust QBCore job.isboss (set on the top grade in shared/jobs.lua)
        BossGrades = {},                      -- explicit grade numbers. Empty by default — grade 4 is "Chief Inspector" on the UK job, so we DON'T hard-code 4 here.
        BossGradeNames = {                    -- grade names (case-insensitive). Covers UK + stock naming.
            'boss', 'chief',                  -- stock qb/esx police boss grade
            'commissioner',                   -- UK Police top grade (QB name & ESX name)
        },
        BossMinGrade = nil,                   -- optional ESX fallback: any grade >= this = boss. Leave nil to rely on names/flag.
        Theme = {                             -- base colours: navy blue & white
            header = '#0B2447',
            background = '#132B4D',
            surface = '#1B3A63',
            accent = '#3E7CB1',
            text = '#FFFFFF'
        },
        Tabs = {                              -- toggle sidebar tabs per server
            dashboard = true,
            civsearch = true,
            vehicles = true,
            newreport = true,
            reports = true,
            command = true,
            settings = true
        }
    },

    uhs = {
        Prefix = 'mdtuhs',
        Brand = 'UHS',                        -- United Kingdom Health Services
        BrandSub = 'United Kingdom Health Services',
        Jobs = { 'ambulance', 'ems' },        -- 'ambulance' (QB & UK job) + 'ems' (some ESX servers)
        UseFrameworkBossFlag = true,
        BossGrades = {},
        BossGradeNames = {
            'boss', 'chief',                  -- stock qb/esx ambulance boss grade
            'opsmanager', 'operations manager', -- UK UHS top grade (ESX name & QB label)
        },
        BossMinGrade = nil,
        Theme = {                             -- base colours: army green & white
            header = '#4B5320',
            background = '#3B421A',
            surface = '#556B2F',
            accent = '#8A9A5B',
            text = '#FFFFFF'
        },
        Tabs = {
            dashboard = true,
            civsearch = true,
            patients = true,
            newreport = true,
            reports = true,
            command = true,
            settings = true
        }
    }
}

-- ══════════════════════ BOSS DETECTION NOTES ══════════════════════
-- The MDT auto-fits both the custom UK jobs and stock QBCore/ESX:
--   • Custom UK Police  → boss = grade 15 "Commissioner" (isboss=true)
--   • Custom UK UHS      → boss = grade 9  "Operations Manager" (isboss=true)
--   • Stock qb-policejob → boss = grade 4  "boss" (isboss=true)
--   • Stock ambulance    → boss = grade 4  "boss" (isboss=true)
--   • Stock esx jobs      → boss = highest grade, name "boss"
-- Because QBCore fills job.isboss from the grade's isboss flag, leaving
-- UseFrameworkBossFlag = true makes every QBCore variant work with no
-- extra setup. ESX has no isboss flag, so ESX relies on BossGradeNames
-- (or set BossMinGrade to the top grade number for your server).

-- ═══════════════════════════ REPORT TYPES ══════════════════════════
Config.ReportTypes = {
    police = { 'Incident', 'Investigation', 'Arrest', 'Traffic Stop' },
    uhs    = { 'Medical Report', 'Patient Intake', 'Call Out', 'Follow Up' }
}

-- ═══════════════════════════ VEHICLE MARKERS ═══════════════════════
Config.VehicleMarkers = { 'Stolen', 'BOLO', 'Wanted Owner', 'Impounded', 'Flagged' }

-- ═══════════════════════════ BLOOD TYPES ═══════════════════════════
Config.BloodTypes = { 'O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-' }

-- ═══════════════════════════ DUTY TOGGLES ═════════════════════════
Config.Duty = {
    Enabled = true,           -- show the on/off-duty toggle in the MDT
    DefaultOnDuty = false,    -- are players on duty the moment they load in?
    RequireDutyToBroadcast = true, -- live feed / warrants only reach ON-DUTY staff
    SyncFramework = true      -- QBCore: also flip SetJobDuty. ESX: fires esx:setJobDuty event
}

-- ═══════════════════════════ DISCORD WEBHOOKS ═════════════════════
-- Paste your webhook URLs. Leave a field as '' to disable that log.
-- Each department logs independently so the two never mix channels.
Config.Webhooks = {
    police = {
        reports  = '',   -- fires when a police report is filed
        warrants = '',   -- fires when a warrant is issued or cleared
        duty     = ''    -- fires when an officer goes on/off duty
    },
    uhs = {
        reports  = '',   -- fires when a medical report is filed
        duty     = ''
    }
}

-- Appearance of the Discord embeds
Config.WebhookName = 'Hazy MDT'
Config.WebhookAvatar = ''  -- optional image URL for the webhook avatar
Config.WebhookColors = {   -- decimal colours matching each department
    police   = 741959,   -- navy blue (#0B2447)
    uhs      = 4936992,   -- army green (#4B5320)
    warrant  = 12862522, -- red (#C4453A)
    dutyOn   = 4098650,   -- green
    dutyOff  = 9079434    -- grey
}

-- ═══════════════════════════ MISC ══════════════════════════════════
Config.MaxSearchResults = 25      -- civilian / vehicle search result cap
Config.DashboardUpdateLimit = 15  -- updates shown on dashboard
Config.LiveFeedLimit = 30         -- live feed entries kept in the UI
Config.MugshotWhitelist = {       -- allowed image hosts for mugshot links ({} = allow all)
    'i.imgur.com', 'imgur.com', 'cdn.discordapp.com', 'media.discordapp.net', 'i.postimg.cc'
}

-- Notifications: replace with your own notify export if desired
Config.Notify = function(msg, ntype)
    -- ntype: 'success' | 'error' | 'info'
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
