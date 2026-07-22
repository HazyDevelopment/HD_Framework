Config = {}

-- ═══════════════════════════════════════════════════════════════════
--  HD RADIO | HAZY DEVELOPMENT | v1.0.0
--  Thin layer on top of pma-voice's own radio channels: this resource
--  decides WHO can tune a channel (must be carrying the 'radio' item)
--  and gives the PTT a synthesised UK-style confirmation tone instead
--  of pma-voice's stock click. pma-voice itself already handles the
--  actual channel audio and the PTT key (default LMENU, its own
--  'voice_defaultRadio' convar) — this resource never re-implements
--  either of those.
-- ═══════════════════════════════════════════════════════════════════

Config.Item = 'radio' -- see shared/items.lua in HD_Framework — already issued to on-duty police/UHS by uk_policejob/uk_uhsjob
Config.MinChannel = 1
Config.MaxChannel = 999
Config.Command = 'radio' -- /radio <channel> to tune, /radio 0 to switch off, /radio with no argument to check your current channel

-- ═══════════════════════════ RESERVED CHANNELS ═══════════════════════
-- Anyone can tune any channel NOT listed here (open civilian chatter).
-- A listed channel is gated on job — `jobs` matches exact job names,
-- `jobType` matches the same job.type extension point hd_dispatch
-- uses (so any future type='mechanic' job gets channel 3 for free,
-- same idea as recovery calls). Both server/main.lua's own check (for
-- a clear error message) AND pma-voice's own addChannelCheck (real
-- enforcement at the audio layer) use this same table — see the
-- header note on why both exist.
Config.ReservedChannels = {
    [1] = { label = 'Police Ops', jobs = { 'police' } },
    [2] = { label = 'UHS Ops', jobs = { 'ambulance' } },
    [3] = { label = 'Recovery', jobType = 'mechanic' },
}
Config.RequireDutyOnReserved = true -- must also be on-duty to use a reserved channel, not just the right job

-- ═══════════════════════════ PTT TONE ════════════════════════════════
-- Real bundled .wav files (html/audio/ptt_on.wav, ptt_off.wav) — not
-- runtime Web Audio synthesis. The tone itself is a synthesised
-- two-tone pip run through actual signal processing to sound more
-- like it came out of a real radio speaker rather than a browser beep:
-- band-limited to ~300Hz-3000Hz (the same narrow bandwidth a real
-- analogue/PMR voice channel is constrained to — this alone is most of
-- why radio audio sounds "radio"), soft-clip saturated for a bit of
-- speaker crunch, and (on key-up only) a short decaying burst of
-- band-limited static standing in for a squelch tail. Still not a
-- recording of real Airwave/TETRA equipment — I have no way to obtain
-- or license that — but a lot closer than a plain oscillator beep.
-- Regenerate both files any time with the script referenced in the
-- main README's Voice & Radio section, or replace them outright with
-- real recorded UK radio audio — nothing else needs to change. You
-- can also drop equivalent files into pma-voice's own ui/ folder to
-- change its native click too.
Config.Tone = {
    Enabled = true,
    MuteStockClick = true, -- zero out pma-voice's own mic_click_on/off.ogg volume so it doesn't play alongside this
}

Config.Notify = function(msg, ntype)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end
