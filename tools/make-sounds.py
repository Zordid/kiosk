"""Make WAWIS's start and end sounds, INTRO.WAV and TERMINAT.WAV.

usage: python3 -I tools/make-sounds.py OUTDIR

The original samples (from some multimedia CD of the time) are not in this
repository. These two were made in 2026 instead, with two-operator FM
synthesis as the Sound Blaster's OPL2 chip did it: a sine carrier,
modulated by a second sine whose depth fades, gives a bell. INTRO.WAV is a
rising C major arpeggio that ends on a chord, TERMINAT.WAV a short falling
phrase. 8-bit mono, 11,025 Hz, like the originals. Every sample is
computed, so the same script always writes the same files.
"""
import math, sys, wave
from pathlib import Path

RATE = 11025


def bell(freq, length, ratio=3.5, index=4.0, decay=2.2):
    """One FM bell note: carrier freq, modulator freq*ratio."""
    out = []
    for n in range(int(length * RATE)):
        t = n / RATE
        env = math.exp(-decay * t) * min(1.0, t * 200)        # 5 ms attack
        mod = index * math.exp(-3.0 * t) * math.sin(2 * math.pi * freq * ratio * t)
        out.append(env * math.sin(2 * math.pi * freq * t + mod))
    return out


def mix(length, notes):
    """notes: (start in seconds, frequency, length, volume)."""
    buf = [0.0] * int(length * RATE)
    for start, freq, ln, vol in notes:
        s = int(start * RATE)
        for i, v in enumerate(bell(freq, ln)):
            if s + i < len(buf):
                buf[s + i] += vol * v
    peak = max(abs(v) for v in buf)
    return [v / peak * 0.85 for v in buf]


def save(path, samples):
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(1)                                     # 8-bit unsigned
        w.setframerate(RATE)
        w.writeframes(bytes(max(0, min(255, round(128 + 127 * v))) for v in samples))


C5, E5, G5, C6, E6, G4 = 523.25, 659.26, 783.99, 1046.50, 1318.51, 392.00

intro = mix(3.6, [(0.00, C5, 1.6, 0.8), (0.22, E5, 1.6, 0.8), (0.44, G5, 1.6, 0.8),
                  (0.66, C6, 2.9, 0.9), (1.10, C5, 2.5, 0.5), (1.10, E5, 2.5, 0.5),
                  (1.10, G5, 2.5, 0.5), (1.10, E6, 2.5, 0.35)])
terminate = mix(1.1, [(0.00, G5, 0.5, 0.8), (0.16, E5, 0.5, 0.8), (0.32, C5, 0.8, 0.9),
                      (0.32, G4, 0.8, 0.5)])

out = Path(sys.argv[1])
save(out / 'INTRO.WAV', intro)
save(out / 'TERMINAT.WAV', terminate)
print('INTRO.WAV', len(intro) / RATE, 's; TERMINAT.WAV', len(terminate) / RATE, 's')
