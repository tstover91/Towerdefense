"""Render the original, seamless main-menu theme to a 16-bit stereo WAV.

The synth is deliberately dependency-light (NumPy only) so the source of the
music stays with the project and the track can be revised later.
"""

from __future__ import annotations

import math
import struct
from pathlib import Path

import numpy as np


SAMPLE_RATE = 44_100
TEMPO = 72.0
BEAT = 60.0 / TEMPO
BARS = 24
DURATION = BARS * 4 * BEAT
SAMPLES = round(DURATION * SAMPLE_RATE)
TAU = math.tau
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "audio" / "main_menu_loop.wav"

mix = np.zeros((SAMPLES, 2), dtype=np.float64)
rng = np.random.default_rng(2004)


def hz(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def place(signal: np.ndarray, start_seconds: float, pan: float = 0.0) -> None:
    """Add mono audio using circular indexing, making every tail loop cleanly."""
    start = round(start_seconds * SAMPLE_RATE) % SAMPLES
    indices = (start + np.arange(signal.size)) % SAMPLES
    left = math.cos((pan + 1.0) * math.pi / 4.0)
    right = math.sin((pan + 1.0) * math.pi / 4.0)
    np.add.at(mix[:, 0], indices, signal * left)
    np.add.at(mix[:, 1], indices, signal * right)


def envelope(length: int, attack: float, decay: float, sustain: float = 0.0) -> np.ndarray:
    attack_n = max(1, round(attack * SAMPLE_RATE))
    x = np.arange(length) / SAMPLE_RATE
    rise = np.minimum(x / attack, 1.0) if attack > 0 else np.ones(length)
    fall = np.exp(-np.maximum(x - attack, 0.0) / max(decay, 0.001))
    return rise * (sustain + (1.0 - sustain) * fall)


def pad_note(midi: float, seconds: float = 8.0) -> np.ndarray:
    n = round(seconds * SAMPLE_RATE)
    t = np.arange(n) / SAMPLE_RATE
    f = hz(midi)
    slow = 0.16 * np.sin(TAU * 0.085 * t + midi)
    tone = (
        np.sin(TAU * f * t + slow)
        + 0.34 * np.sin(TAU * f * 2.003 * t + 0.4)
        + 0.12 * np.sin(TAU * f * 3.997 * t + 1.2)
    )
    return 0.026 * tone * envelope(n, 1.4, 3.6, 0.08)


def mallet(midi: float, seconds: float = 2.7) -> np.ndarray:
    n = round(seconds * SAMPLE_RATE)
    t = np.arange(n) / SAMPLE_RATE
    f = hz(midi)
    wobble = 0.0035 * np.sin(TAU * 4.8 * t)
    phase = TAU * f * (t + wobble / 4.8)
    tone = np.sin(phase) + 0.48 * np.sin(2.01 * phase) + 0.20 * np.sin(3.98 * phase)
    knock = rng.normal(0.0, 1.0, n) * np.exp(-t / 0.018)
    return 0.083 * (tone + 0.16 * knock) * np.exp(-t / 0.78) * np.minimum(t / 0.008, 1.0)


def rubber_bass(midi: float, seconds: float = 2.2) -> np.ndarray:
    n = round(seconds * SAMPLE_RATE)
    t = np.arange(n) / SAMPLE_RATE
    f = hz(midi)
    scoop = 0.11 * np.exp(-t / 0.12)
    phase = TAU * f * (t + scoop)
    tone = np.sin(phase) + 0.27 * np.sin(2 * phase) + 0.08 * np.sin(3 * phase)
    return 0.105 * np.tanh(1.3 * tone) * envelope(n, 0.025, 0.72, 0.03)


def alien_whistle(start_midi: float, end_midi: float, seconds: float = 2.5) -> np.ndarray:
    n = round(seconds * SAMPLE_RATE)
    t = np.arange(n) / SAMPLE_RATE
    glide = start_midi + (end_midi - start_midi) * (3 * (t / seconds) ** 2 - 2 * (t / seconds) ** 3)
    freq = 440.0 * 2.0 ** ((glide - 69.0) / 12.0)
    phase = TAU * np.cumsum(freq) / SAMPLE_RATE
    vibrato = 0.10 * np.sin(TAU * 5.1 * t) * np.minimum(t / 0.7, 1.0)
    tone = np.sin(phase + vibrato) + 0.12 * np.sin(2 * phase + 0.3)
    return 0.040 * tone * envelope(n, 0.24, 1.0, 0.01)


def soft_tick(high: bool = False) -> np.ndarray:
    seconds = 0.18 if high else 0.28
    n = round(seconds * SAMPLE_RATE)
    t = np.arange(n) / SAMPLE_RATE
    noise = rng.normal(0.0, 1.0, n)
    if high:
        noise = np.concatenate(([0.0], np.diff(noise)))
    else:
        noise = np.convolve(noise, np.ones(11) / 11.0, mode="same")
    return (0.012 if high else 0.017) * noise * np.exp(-t / (0.025 if high else 0.07))


# Hazy two-bar chords. The harmony lives between D Dorian and cartoon-space
# chromaticism; the final chord naturally points back to the opening D minor.
chords = [
    [50, 57, 62, 64, 69],       # Dm 6/9 (open voicing)
    [48, 55, 59, 62, 66],       # Cmaj9 #11
    [43, 50, 57, 59, 64],       # G6/9
    [46, 53, 57, 62, 64],       # Bbmaj7 #11
    [51, 58, 62, 65, 69],       # Ebmaj9 #11
    [45, 52, 55, 61, 65],       # A7(b9, sus color)
] * 2

for chord_index, chord in enumerate(chords):
    start = chord_index * 8 * BEAT
    for voice, note in enumerate(chord):
        place(pad_note(note), start + voice * 0.035, pan=-0.65 + voice * 0.32)


# A bass part that leaves whole beats empty; the second half subtly changes its
# pickups so the repeated chord sequence does not read as a short repeating unit.
bass_roots = [38, 36, 31, 34, 39, 33] * 2
for section, root in enumerate(bass_roots):
    bar = section * 2
    pattern = [(0.0, root), (2.5, root + 7), (4.0, root), (6.75, root + (12 if section >= 6 else 5))]
    for beat_offset, note in pattern:
        place(rubber_bass(note), (bar * 4 + beat_offset) * BEAT, pan=-0.12)


# Sparse mallet statements. Motifs recur transformed or displaced, never as an
# identical ostinato. MIDI note 74 is D5.
motifs = {
    1: [(0.0, 74), (1.5, 77), (3.0, 76), (5.5, 69)],
    4: [(0.5, 67), (2.0, 71), (3.5, 74), (6.5, 72)],
    7: [(0.0, 70), (1.0, 74), (2.75, 76), (5.0, 69), (6.5, 73)],
    10: [(0.75, 76), (2.25, 72), (4.0, 67), (6.75, 70)],
    13: [(0.0, 74), (1.5, 77), (3.25, 81), (5.5, 76)],
    16: [(0.5, 67), (2.0, 71), (4.25, 72), (6.0, 66)],
    19: [(0.0, 70), (1.25, 69), (3.0, 74), (4.5, 76), (7.0, 73)],
    22: [(0.75, 76), (2.5, 72), (4.0, 67), (5.5, 70), (7.25, 69)],
}
for bar, notes in motifs.items():
    for event_index, (beat_offset, note) in enumerate(notes):
        pan = -0.48 if event_index % 2 == 0 else 0.42
        place(mallet(note), (bar * 4 + beat_offset) * BEAT, pan=pan)


# Four little character moments across the full 80-second loop.
whistles = [
    (5 * 4 + 1.0, 79, 76, -0.35),
    (11 * 4 + 2.0, 73, 74, 0.38),
    (17 * 4 + 1.5, 82, 77, 0.28),
    (23 * 4 + 0.5, 68, 69, -0.30),
]
for beat_pos, note_a, note_b, pan in whistles:
    place(alien_whistle(note_a, note_b), beat_pos * BEAT, pan=pan)


# Almost subliminal brushed timekeeping: accents move between bars and disappear
# for selected bars, keeping the pulse relaxed rather than metronomic.
for bar in range(BARS):
    if bar not in {3, 9, 15, 21}:
        place(soft_tick(False), (bar * 4 + 0.0) * BEAT, pan=-0.18)
    if bar % 3 != 2:
        place(soft_tick(True), (bar * 4 + 2.0) * BEAT, pan=0.28)
    if bar in {6, 14, 20}:
        place(soft_tick(True), (bar * 4 + 3.5) * BEAT, pan=-0.42)


# Circular ambience preserves sample-perfect looping. Cross-channel taps provide
# width without making the soft centre image wander around the menu.
dry = mix.copy()
for delay, gain, swap in [(0.137, 0.15, False), (0.229, 0.11, True), (0.373, 0.075, False), (0.611, 0.045, True)]:
    shifted = np.roll(dry, round(delay * SAMPLE_RATE), axis=0)
    if swap:
        shifted = shifted[:, ::-1]
    mix += gain * shifted

# Gentle bus compression, tiny fade guard at the exact wrap, and conservative
# mastering level suitable for UI music beneath button sounds.
mix = np.tanh(mix * 1.18)
peak = float(np.max(np.abs(mix)))
mix *= 0.74 / max(peak, 1e-9)
pcm = np.round(np.clip(mix, -1.0, 1.0) * 32767.0).astype("<i2")


def chunk(tag: bytes, payload: bytes) -> bytes:
    return tag + struct.pack("<I", len(payload)) + payload + (b"\0" if len(payload) % 2 else b"")


fmt = struct.pack("<HHIIHH", 1, 2, SAMPLE_RATE, SAMPLE_RATE * 4, 4, 16)
# Keep the source container deliberately plain for maximum importer
# compatibility. Godot's import settings provide the sample-accurate loop flag.
body = chunk(b"fmt ", fmt) + chunk(b"data", pcm.tobytes())
wav = b"RIFF" + struct.pack("<I", len(body) + 4) + b"WAVE" + body

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
OUTPUT.write_bytes(wav)
print(f"Rendered {OUTPUT.relative_to(ROOT)}: {DURATION:.1f}s, {OUTPUT.stat().st_size / 1_048_576:.1f} MiB")
