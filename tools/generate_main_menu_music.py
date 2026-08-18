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
TEMPO = 92.0
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


def rubber_bass(midi: float, seconds: float = 1.35) -> np.ndarray:
    n = round(seconds * SAMPLE_RATE)
    t = np.arange(n) / SAMPLE_RATE
    f = hz(midi)
    scoop = 0.065 * np.exp(-t / 0.10)
    phase = TAU * f * (t + scoop)
    tone = np.sin(phase) + 0.27 * np.sin(2 * phase) + 0.08 * np.sin(3 * phase)
    return 0.145 * np.tanh(1.45 * tone) * envelope(n, 0.018, 0.42, 0.015)


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


def soft_kick() -> np.ndarray:
    n = round(0.38 * SAMPLE_RATE)
    t = np.arange(n) / SAMPLE_RATE
    freq = 52.0 + 62.0 * np.exp(-t / 0.035)
    phase = TAU * np.cumsum(freq) / SAMPLE_RATE
    return 0.075 * np.sin(phase) * np.exp(-t / 0.105)


def bubble_lead(midi: float, seconds: float = 0.72) -> np.ndarray:
    """A rounded, toy-like lead that carries the hook without getting piercing."""
    n = round(seconds * SAMPLE_RATE)
    t = np.arange(n) / SAMPLE_RATE
    f = hz(midi)
    phase = TAU * f * t + 0.045 * np.sin(TAU * 5.4 * t)
    tone = np.sin(phase) + 0.24 * np.sin(2 * phase + 0.2) + 0.07 * np.sin(3 * phase)
    return 0.070 * np.tanh(1.2 * tone) * envelope(n, 0.018, 0.30, 0.025)


# A looping eight-bar progression in D minor/Dorian. Familiar tonic movement
# makes the hook easy to retain, while the G and altered A chords keep the
# harmony buoyant and slightly alien.
chords = [
    [50, 57, 62, 65, 69],       # Dm9
    [46, 53, 57, 62, 65],       # Bbmaj9
    [43, 50, 57, 59, 64],       # G6/9
    [45, 52, 55, 61, 65],       # A7(b9)
    [50, 57, 62, 64, 69],       # Dm6/9
    [41, 48, 53, 57, 60],       # Fmaj9
    [48, 55, 59, 62, 64],       # Cmaj9
    [45, 52, 55, 61, 67],       # A7(b9, 7)
] * 3

for chord_index, chord in enumerate(chords):
    start = chord_index * 4 * BEAT
    for voice, note in enumerate(chord):
        place(pad_note(note, 4.8), start + voice * 0.025, pan=-0.65 + voice * 0.32)


# The bass is a hook in its own right: root/fifth anchors, octave pops, and
# chromatic approaches. Every fourth bar changes its turnaround to propel the
# next phrase instead of feeling like a static accompaniment.
bass_patterns = [
    [(0.0, 38), (0.75, 45), (1.5, 50), (2.5, 45), (3.25, 48)],
    [(0.0, 34), (1.0, 41), (1.75, 45), (2.5, 41), (3.5, 37)],
    [(0.0, 31), (0.75, 38), (1.5, 43), (2.25, 45), (3.25, 46)],
    [(0.0, 33), (1.0, 40), (1.75, 43), (2.75, 37), (3.5, 49)],
    [(0.0, 38), (0.75, 45), (1.5, 48), (2.5, 50), (3.25, 45)],
    [(0.0, 41), (1.0, 48), (1.75, 53), (2.5, 48), (3.5, 40)],
    [(0.0, 36), (0.75, 43), (1.5, 48), (2.25, 50), (3.25, 43)],
    [(0.0, 33), (1.0, 40), (1.75, 43), (2.5, 49), (3.25, 45), (3.75, 37)],
]
for bar in range(BARS):
    pattern = bass_patterns[bar % 8]
    for beat_offset, note in pattern:
        place(rubber_bass(note), (bar * 4 + beat_offset) * BEAT, pan=-0.08)


# An eight-bar tune designed to be hummable: a four-note rising identity,
# question/answer phrasing, then a descending turnaround. It appears three times
# with octave, rhythmic, and ending variations rather than constant repetition.
hook = [
    [(0.0, 74), (0.75, 77), (1.5, 81), (2.5, 79), (3.25, 77)],
    [(0.0, 74), (1.0, 72), (2.0, 70), (2.75, 74), (3.5, 77)],
    [(0.0, 79), (0.75, 81), (1.5, 82), (2.5, 79), (3.25, 74)],
    [(0.0, 76), (0.75, 73), (1.5, 69), (2.5, 73), (3.25, 76)],
    [(0.0, 74), (0.75, 77), (1.5, 79), (2.25, 81), (3.25, 84)],
    [(0.0, 81), (0.75, 77), (1.5, 76), (2.5, 72), (3.25, 77)],
    [(0.0, 79), (0.75, 81), (1.5, 84), (2.5, 82), (3.25, 79)],
    [(0.0, 77), (0.75, 76), (1.5, 73), (2.25, 69), (3.0, 73), (3.5, 76)],
]
for pass_index in range(3):
    for phrase_bar, notes in enumerate(hook):
        bar = pass_index * 8 + phrase_bar
        for event_index, (beat_offset, base_note) in enumerate(notes):
            note = base_note
            if pass_index == 1 and phrase_bar in {2, 6}:
                note += 12
            if pass_index == 2 and phrase_bar == 7 and event_index >= len(notes) - 2:
                note += 2
            start = (bar * 4 + beat_offset) * BEAT
            place(bubble_lead(note), start, pan=0.16)
            # A quieter mallet doubles selected notes for the cartoony sparkle.
            if event_index in {0, 2}:
                place(mallet(note + 12, 1.25), start, pan=-0.38)


# Short alien replies fill the breaths between hook phrases.
whistles = [
    (3 * 4 + 2.0, 81, 76, -0.35),
    (7 * 4 + 3.0, 69, 73, 0.38),
    (11 * 4 + 2.0, 84, 79, 0.28),
    (15 * 4 + 3.0, 73, 76, -0.30),
    (19 * 4 + 2.0, 82, 77, 0.32),
    (23 * 4 + 3.0, 69, 74, -0.30),
]
for beat_pos, note_a, note_b, pan in whistles:
    place(alien_whistle(note_a, note_b), beat_pos * BEAT, pan=pan)


# A soft kick and brushed ticks add motion without competing with menu SFX.
for bar in range(BARS):
    for beat_offset in (0.0, 2.0):
        place(soft_kick(), (bar * 4 + beat_offset) * BEAT, pan=0.0)
    for beat_offset in (1.0, 3.0):
        place(soft_tick(False), (bar * 4 + beat_offset) * BEAT, pan=-0.18)
    for beat_offset in (0.5, 1.5, 2.5, 3.5):
        if not (bar % 8 == 7 and beat_offset == 3.5):
            place(soft_tick(True), (bar * 4 + beat_offset) * BEAT, pan=0.28)


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
