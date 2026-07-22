Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD FINES | HAZY DEVELOPMENT | v1.1.0
--  The revenue mechanic hd_society was missing — police issue Fines,
--  UHS issue Treatment Invoices (billing for a callout/treatment, the
--  fictional-UHS equivalent of a real ambulance trust's private
--  billing), both landing straight in that job's hd_society fund via
--  its AddFunds export. One command, one job-keyed config table,
--  same as hd_dispatch's Config.CallTypes / hd_radio's
--  Config.ReservedChannels pattern.
--
--  v1.1.0 adds cooldowns (stop one officer draining one target with
--  repeated fines) and a debt ledger for whatever a target genuinely
--  can't afford at the time — see Config.Debt below.
-- ═══════════════════════════════════════════════════════════════════

Config.Command = 'fine'
Config.RequireDuty = true
Config.TargetRadius = 5.0 -- how close the target has to be

Config.Jobs = {
    police = {
        label = 'Fine',
        verb = 'fined',
        minAmount = 50,
        maxAmount = 2500,
    },
    ambulance = {
        label = 'Treatment Invoice',
        verb = 'invoiced',
        minAmount = 50,
        maxAmount = 1500,
    },
}

-- ═══════════════════════════ COOLDOWNS ═══════════════════════════════
-- Both tracked in-memory per issuer (reset on restart — fine for an
-- abuse guard, no need to persist it).
Config.Cooldown = {
    PerTargetSeconds = 300, -- can't fine the SAME person again within this window
    GlobalSeconds = 5,      -- can't fine ANYONE again within this window — basic spam guard
}

-- ═══════════════════════════ DEBT / WARRANTS ═════════════════════════
-- If a target can't cover a fine in full, whatever they DO have is
-- collected immediately and the shortfall becomes a debt row against
-- their citizenid — not a silent failure, and not free money either.
Config.Debt = {
    Enabled = true,
    WarrantThreshold = 2000, -- total unpaid debt at which /checkdebt flags it, and AutoWarrant fires
    PayCommand = 'paydebt',
    CheckOwnCommand = 'debts',
    CheckOtherCommand = 'checkdebt', -- police/ambulance/admin only

    -- Fires exactly once per crossing — the instant a fine pushes
    -- someone's total debt from under WarrantThreshold to at-or-over
    -- it, not on every fine after they're already over (that would
    -- just spam the dispatch board). Paying back down below the
    -- threshold and crossing it again later fires it again, which is
    -- the correct behaviour, not a bug.
    AutoWarrant = {
        Enabled = true,
        Priority = 1, -- Grade 1 — Immediate, matches hd_dispatch's Config.PriorityGrades
    },
}

Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
