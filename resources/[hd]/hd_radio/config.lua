Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD RADIO | HAZY DEVELOPMENT | v2.0.0
--  Thin layer on top of pma-voice's own radio channels: this resource
--  decides WHO can tune a channel (must be carrying the 'radio' item)
--  and gives the player a full handheld radio UI (styled after a
--  TETRA/PMR handheld like the Sepura SC20 — screen, keypad, power
--  button, panic button) instead of a bare frequency box. pma-voice
--  itself still owns the actual channel audio and the PTT key (default
--  LMENU, its own 'voice_defaultRadio' convar) — this resource never
--  re-implements either of those, it only decides eligibility and
--  drives the UI on top.
-- ═══════════════════════════════════════════════════════════════════

Config.Item = 'radio' -- see shared/items.lua in HD_Framework — already issued to on-duty police/UHS by hd_ems/hd_policejob
Config.Command = 'radio' -- /radio <freq> to tune (e.g. /radio 45.20), /radio 0 to switch off, /radio with no argument to check your current frequency
Config.OpenKey = 'U' -- opens the handheld radio UI

-- ═══════════════════════════ FREQUENCY RANGE ═════════════════════════
-- Players tune a decimal frequency from 0.00 to 99.99 (two players on
-- the same frequency hear each other, same idea as a real PMR/CB set).
-- pma-voice's setPlayerRadio/addChannelCheck key channels as plain
-- numbers, and comparing floats for equality is asking for trouble
-- (45.2 vs 45.20 vs 45.199999999996), so every frequency is stored and
-- compared internally as an INTEGER "channel" = round(freq * 100) —
-- 45.20 becomes channel 4520. FreqToChannel/ChannelToFreq below do the
-- conversion; nothing outside config.lua should do this maths itself.
Config.MinFreq = 0.00
Config.MaxFreq = 99.99
Config.MinChannel = 0
Config.MaxChannel = 9999

function Config.FreqToChannel(freq)
    freq = tonumber(freq)
    if not freq then return nil end
    return math.floor((freq * 100) + 0.5)
end

function Config.ChannelToFreq(channel)
    return string.format('%.2f', channel / 100)
end

-- ═══════════════════════════ RESERVED CHANNELS ═══════════════════════
-- Anyone can tune any frequency NOT listed here (open civilian
-- chatter). A listed frequency is gated on job — `jobs` matches exact
-- job names, `jobType` matches the same job.type extension point
-- hd_dispatch uses (so any future type='mechanic' job gets 3.00 for
-- free, same idea as recovery calls). Keyed by CHANNEL (freq * 100),
-- not raw frequency — 1.00 -> 100, 2.00 -> 200, 3.00 -> 300. Both
-- server/main.lua's own check (for a clear error message) AND
-- pma-voice's own addChannelCheck (real enforcement at the audio
-- layer) use this same table — see the header note on why both exist.
Config.ReservedChannels = {
    [100] = { label = 'Police Ops', jobs = { 'police' } },
    [200] = { label = 'UHS Ops', jobs = { 'ambulance' } },
    [300] = { label = 'Recovery', jobType = 'mechanic' },
}
Config.RequireDutyOnReserved = true -- must also be on-duty to use a reserved frequency, not just the right job

-- ═══════════════════════════ VOLUME ══════════════════════════════════
-- 0-100, shown on the handheld's own volume slider. Saved into a
-- per-client resource KVP (survives relogs on the same PC, same idea
-- as pma-voice's own F9 settings menu) and pushed straight into
-- pma-voice's client export `setRadioVolume(volume)` — that export is
-- what actually controls how loud OTHER people's radio voice comes
-- through, same as pma-voice's own settings panel would. This resource
-- also uses the 0-100 value to scale the four local UI sounds below.
Config.DefaultVolume = 65

-- ═══════════════════════════ SOUNDS ══════════════════════════════════
-- Real bundled .ogg files (html/audio/) — not runtime-synthesised
-- tones. All four are self-confirmation/alert sounds played on the
-- LOCAL player's own handheld, same as a real Airwave/TETRA set's
-- built-in tones; none of this is the other side's actual voice audio,
-- that's still pma-voice/mumble entirely.
Config.Sounds = {
    ptt = 'audio/PTT.ogg', -- keys up on PTT press (pma-voice 'radioActive' event)
    bleep = 'audio/SingleBleep.ogg', -- confirms a channel change / power on
    panic = 'audio/Panic.ogg', -- plays for the panic button, both presser and channel listeners
    p2p = 'audio/P2P.ogg', -- plays for the green call button's direct/individual call ring
}

-- ═══════════════════════════ PANIC BUTTON ════════════════════════════
-- Real TETRA handhelds have a dedicated emergency button that alerts
-- the control room. Here that's routed into hd_dispatch as a real
-- police call (same board on-duty officers already watch for 999s) if
-- hd_dispatch is running; if it isn't installed, it silently no-ops.
Config.Panic = {
    Enabled = true,
    DispatchKind = 'police',
    Cooldown = 30, -- seconds between panic presses per player, stops spam
}

Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
