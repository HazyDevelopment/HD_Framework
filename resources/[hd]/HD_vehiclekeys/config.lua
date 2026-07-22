Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD VEHICLEKEYS | HAZY DEVELOPMENT | v1.0.0
--  Lock state is server-authoritative and identical for everyone
--  looking at a given plate (SetVehicleDoorsLocked is a networked
--  vehicle property, not per-player) — the owner doesn't get a
--  special bypass, they have to unlock their own car with /lock same
--  as a real key fob. "Keys" only ever gate WHO is allowed to toggle
--  the lock and who hd_inventory lets into the glovebox/trunk.
--
--  Ownership itself is never duplicated here — it's read live from
--  player_vehicles.citizenid every time. Buy a car from hd_cardealer
--  or get one via HD_Framework's /givevehicle and it's automatically
--  keyed to that owner with zero extra wiring.
-- ═══════════════════════════════════════════════════════════════════

Config.Command = 'lock'          -- toggles the lock on the vehicle you're in, or the nearest one you hold keys to
Config.GiveKeysCommand = 'givekeys'
Config.LockRadius = 8.0          -- how far from a vehicle /lock still works when you're not inside it (real key fobs work at a distance too)
Config.GiveKeysRadius = 5.0      -- how close the recipient needs to be for /givekeys

-- New vehicles default UNLOCKED (nothing has ever called /lock on
-- that plate yet) — matches driving off the dealership forecourt with
-- keys already in hand, not finding your brand new car locked.
Config.DefaultLocked = false

-- ═══════════════════════════ BREAKING IN ═════════════════════════════
-- The only way past a locked door with no keys. A timing minigame
-- (catch a moving marker in a zone, several rounds) decides your odds,
-- not the outcome directly — the server still rolls the actual result,
-- just weighted a lot more favourably if you won it. That's the same
-- trust boundary every skill-check minigame in the FiveM ecosystem
-- accepts: the server can't verify YOUR reaction timing, only the
-- consequence of it, so winning meaningfully helps rather than
-- guarantees, and a spoofed "I won" client still only gets
-- FailedMinigameChance's worse odds if the server-side roll goes
-- against it. Every attempt — won or lost — can also set the alarm
-- off independently, which is what actually calls it in to police via
-- hd_dispatch if that's installed.
Config.BreakIn = {
    Enabled = true,
    Command = 'breakin',
    SuccessChance = 0.85,          -- 0-1, odds when you WIN the minigame
    FailedMinigameChance = 0.20,   -- 0-1, odds when you LOSE or skip it — still a real chance, not zero
    AlarmChance = 0.4,             -- 0-1, rolled independently of success — smashing a window risks the alarm either way
    NotifyPoliceOnAlarm = true,
    PoliceCallPriority = 2,        -- Grade 2 — Priority, matches hd_dispatch's Config.PriorityGrades

    Minigame = {
        Attempts = 5,       -- rounds
        RequiredHits = 3,   -- catches needed out of Attempts to "win"
        ZoneWidth = 0.16,   -- catch-zone width, fraction of the bar (0-1)
        MarkerSpeed = 0.018, -- fraction of the bar the marker moves per frame
        TimeoutMs = 2500,   -- per round — no press in time counts as a miss for that round
    },
}

Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
