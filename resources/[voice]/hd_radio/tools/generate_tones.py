# Regenerates hd_radio's ptt_on.wav / ptt_off.wav (../html/audio/).
# Pure Python stdlib — no numpy, no external audio encoder. Run with
# any Python 3: `python generate_tones.py` from this folder. Tweak the
# frequencies/durations/filter cutoffs below and re-run to taste, or
# just replace the two .wav files this writes with real recorded audio
# and delete this script entirely — nothing else in hd_radio cares how
# those two files were made.

import wave
import struct
import math
import random
import os

SAMPLE_RATE = 44100
AUDIO_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'html', 'audio')

def lowpass(samples, cutoff_hz):
    rc = 1.0 / (2 * math.pi * cutoff_hz)
    dt = 1.0 / SAMPLE_RATE
    alpha = dt / (rc + dt)
    out = [0.0] * len(samples)
    prev = 0.0
    for i, x in enumerate(samples):
        prev = prev + alpha * (x - prev)
        out[i] = prev
    return out

def highpass(samples, cutoff_hz):
    rc = 1.0 / (2 * math.pi * cutoff_hz)
    dt = 1.0 / SAMPLE_RATE
    alpha = rc / (rc + dt)
    out = [0.0] * len(samples)
    prev_y = 0.0
    prev_x = samples[0] if samples else 0.0
    for i, x in enumerate(samples):
        prev_y = alpha * (prev_y + x - prev_x)
        prev_x = x
        out[i] = prev_y
    return out

def radio_bandlimit(samples):
    # crude telephone/PMR-bandwidth emulation — real radio voice
    # channels are roughly 300Hz-3000Hz, which is exactly what gives
    # radio audio its recognisable "narrow, tinny" character
    return highpass(lowpass(samples, 3000), 300)

def soft_clip(x, drive=2.2):
    return math.tanh(x * drive) / math.tanh(drive)

def envelope(i, n, attack, release):
    if i < attack:
        return i / attack
    if i > n - release:
        return max(0.0, (n - i) / release)
    return 1.0

def tone_segment(freq, duration_s, amp=0.6, sine_mix=0.85):
    n = int(SAMPLE_RATE * duration_s)
    attack = int(SAMPLE_RATE * 0.004)
    release = int(SAMPLE_RATE * 0.012)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        sine = math.sin(2 * math.pi * freq * t)
        square = 1.0 if sine >= 0 else -1.0
        raw = sine_mix * sine + (1 - sine_mix) * square
        env = envelope(i, n, attack, release)
        samples.append(raw * env * amp)
    return samples

def squelch_tail(duration_s=0.09, amp=0.22):
    # the burst of static right as a real radio's squelch opens/closes
    # — arguably more recognisably "radio" than the tone itself
    n = int(SAMPLE_RATE * duration_s)
    out = []
    for i in range(n):
        env = max(0.0, 1.0 - (i / n)) ** 1.6  # fast decay
        out.append((random.uniform(-1.0, 1.0)) * env * amp)
    return out

def build_pip(freqs, seg_s=0.075, gap_s=0.012, with_tail=True):
    out = []
    for idx, f in enumerate(freqs):
        out.extend(tone_segment(f, seg_s))
        if idx < len(freqs) - 1:
            out.extend([0.0] * int(SAMPLE_RATE * gap_s))
    out = radio_bandlimit(out)
    out = [soft_clip(s) for s in out]
    if with_tail:
        tail = radio_bandlimit(squelch_tail())
        out.extend(tail)
    return out

def write_wav(path, samples):
    with wave.open(path, 'w') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s))
            frames.extend(struct.pack('<h', int(v * 32000)))
        f.writeframes(bytes(frames))

random.seed(42)  # deterministic output — re-running this script gives the same file

# PTT pressed — rising two-tone pip (low -> high) + squelch tail.
on_samples = build_pip([1100, 1500])
write_wav(os.path.join(AUDIO_DIR, 'ptt_on.wav'), on_samples)

# PTT released — falling two-tone pip (high -> low), shorter tail (mic cutting off, not opening)
off_samples = build_pip([1500, 1100], with_tail=False)
write_wav(os.path.join(AUDIO_DIR, 'ptt_off.wav'), off_samples)

print('on:', len(on_samples), 'samples /', len(on_samples) / SAMPLE_RATE, 's')
print('off:', len(off_samples), 'samples /', len(off_samples) / SAMPLE_RATE, 's')
