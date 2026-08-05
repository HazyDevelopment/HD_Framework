Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD TARGET | v1.0.0
--  A reusable "hold to interact" targeting layer, same idea as
--  ox_target/qb-target: other resources register options against a
--  model or a specific entity via this resource's exports, this file
--  just does the raycasting/reticle/menu — it never decides what an
--  option actually DOES, that's whatever event name the registering
--  resource points it at (server-validated there, same as every other
--  interaction in this framework already is).
-- ═══════════════════════════════════════════════════════════════════

-- 'LMENU' is FiveM's own key-name for the physical Left Alt key — GTA
-- has no vanilla control bound to it, so this goes through
-- RegisterKeyMapping directly rather than a native control id (same
-- hold-to-show/release-to-hide +/- command convention hd_inventory's
-- hotbar toggle already uses).
Config.HoldKey = 'LMENU'

Config.MaxDistance = 4.0    -- metres — how far the raycast looks for something targetable
Config.PollMs = 150         -- how often to re-raycast while the key is held
Config.InteractKey = 38     -- E — confirms whichever option is currently shown
