#!/usr/bin/env python3
"""Audioforge — Teramor's bespoke, dependency-free SFX synth.

The audio twin of tools/pixelforge.py: no pip, no samples, no DAW — every sound
effect is synthesized from math with the Python stdlib (wave + struct + math +
random) and baked to assets/audio/sfx/*.wav. The pipeline being *ours* is part of
the story, same as the pixel art.

The palette is the grounded mood: short, muted, slightly soft — wooden/earthy
thuds and whooshes, not bright arcade blips. Tune a sound by editing its recipe in
bake_all() and re-running:  python3 tools/audioforge.py

Sounds are mono 16-bit PCM at 22050 Hz. AudioManager plays them on the SFX bus,
with a little random pitch per shot so repeats don't machine-gun.
"""

import math
import os
import random
import struct
import wave

RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")


# --- core synth -------------------------------------------------------------

def _n(seconds: float) -> int:
	return max(1, int(seconds * RATE))


def silence(seconds: float) -> list:
	return [0.0] * _n(seconds)


def tone(freq: float, seconds: float, amp: float = 1.0, wave_kind: str = "sine") -> list:
	"""A single-frequency wave. wave_kind: sine | square | saw | triangle."""
	out = []
	for i in range(_n(seconds)):
		ph = (i * freq / RATE) % 1.0
		if wave_kind == "square":
			v = 1.0 if ph < 0.5 else -1.0
		elif wave_kind == "saw":
			v = 2.0 * ph - 1.0
		elif wave_kind == "triangle":
			v = 4.0 * abs(ph - 0.5) - 1.0
		else:
			v = math.sin(2.0 * math.pi * ph)
		out.append(v * amp)
	return out


def sweep(f0: float, f1: float, seconds: float, amp: float = 1.0, wave_kind: str = "sine") -> list:
	"""A glide from f0 to f1 (exponential, so pitch reads musically)."""
	out = []
	count = _n(seconds)
	phase = 0.0
	for i in range(count):
		t = i / count
		freq = f0 * ((f1 / f0) ** t) if f0 > 0 and f1 > 0 else f0 + (f1 - f0) * t
		phase += freq / RATE
		ph = phase % 1.0
		if wave_kind == "square":
			v = 1.0 if ph < 0.5 else -1.0
		elif wave_kind == "saw":
			v = 2.0 * ph - 1.0
		else:
			v = math.sin(2.0 * math.pi * ph)
		out.append(v * amp)
	return out


def noise(seconds: float, amp: float = 1.0) -> list:
	return [random.uniform(-1.0, 1.0) * amp for _ in range(_n(seconds))]


def lowpass(sig: list, strength: float = 0.5) -> list:
	"""One-pole smoothing — knocks the harsh top off noise so it reads earthy."""
	out = []
	prev = 0.0
	a = max(0.0, min(0.99, strength))
	for s in sig:
		prev = prev * a + s * (1.0 - a)
		out.append(prev)
	return out


def env_exp(sig: list, decay: float = 8.0, attack: float = 0.005) -> list:
	"""Fast attack, exponential decay — the shape of a struck/plucked sound."""
	out = []
	n = len(sig)
	atk = max(1, int(attack * RATE))
	for i, s in enumerate(sig):
		a = i / atk if i < atk else 1.0
		t = i / RATE
		out.append(s * a * math.exp(-decay * t))
	return out


def mix(*sigs: list) -> list:
	n = max((len(s) for s in sigs), default=0)
	out = [0.0] * n
	for s in sigs:
		for i, v in enumerate(s):
			out[i] += v
	return out


def concat(*sigs: list) -> list:
	out = []
	for s in sigs:
		out.extend(s)
	return out


def gain(sig: list, g: float) -> list:
	return [s * g for s in sig]


def normalize(sig: list, peak: float = 0.85) -> list:
	hi = max((abs(s) for s in sig), default=0.0)
	if hi <= 1e-6:
		return sig
	k = peak / hi
	return [s * k for s in sig]


def soft_fade(sig: list, ms: float = 4.0) -> list:
	"""Tiny in/out ramps so a clip never starts or ends on a click."""
	f = max(1, int(ms / 1000.0 * RATE))
	out = list(sig)
	n = len(out)
	for i in range(min(f, n)):
		out[i] *= i / f
		out[n - 1 - i] *= i / f
	return out


def save_wav(name: str, sig: list) -> None:
	sig = soft_fade(normalize(sig))
	os.makedirs(OUT_DIR, exist_ok=True)
	path = os.path.join(OUT_DIR, name + ".wav")
	with wave.open(path, "w") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(RATE)
		frames = bytearray()
		for s in sig:
			v = int(max(-1.0, min(1.0, s)) * 32767)
			frames += struct.pack("<h", v)
		w.writeframes(bytes(frames))
	print("  baked %-12s %5d samples  (%.2fs)" % (name, len(sig), len(sig) / RATE))


# --- the sound set ----------------------------------------------------------

def bake_all() -> None:
	random.seed(7)  # deterministic bakes, like a seeded pixel gen
	print("audioforge: baking SFX -> %s" % os.path.normpath(OUT_DIR))

	# A muffled footfall: a soft low thud of filtered noise.
	save_wav("step", env_exp(lowpass(noise(0.10, 0.8), 0.82), decay=34.0))

	# Melee whoosh: filtered noise that swells then cuts.
	swing = lowpass(noise(0.16, 1.0), 0.6)
	swing = [s * math.sin(math.pi * i / len(swing)) for i, s in enumerate(swing)]
	save_wav("swing", gain(swing, 0.9))

	# Bowstring: a short, dry pluck plus a string tick.
	save_wav("bow", mix(
		env_exp(tone(420.0, 0.18, 0.7, "triangle"), decay=22.0),
		env_exp(noise(0.05, 0.5), decay=40.0),
	))

	# Landing a hit on a foe: a punchy wooden thwack (thud + bright crack).
	save_wav("hit_enemy", mix(
		env_exp(tone(150.0, 0.16, 1.0), decay=26.0),
		env_exp(lowpass(noise(0.08, 0.7), 0.4), decay=45.0),
	))

	# Taking a hit: lower, duller, heavier.
	save_wav("hit_player", mix(
		env_exp(tone(95.0, 0.20, 1.0), decay=18.0),
		env_exp(lowpass(noise(0.10, 0.5), 0.7), decay=30.0),
	))

	# A death: a downward groan into a noise collapse.
	save_wav("death", mix(
		env_exp(sweep(280.0, 70.0, 0.38, 0.9), decay=7.0),
		env_exp(lowpass(noise(0.30, 0.5), 0.6), decay=11.0),
	))

	# Pickup: a small, pleasant two-step rise.
	save_wav("pickup", concat(
		env_exp(tone(660.0, 0.07, 0.7, "triangle"), decay=30.0),
		env_exp(tone(990.0, 0.10, 0.7, "triangle"), decay=26.0),
	))

	# Craft/forge: two metallic anvil clinks.
	clink = lambda f: env_exp(mix(tone(f, 0.14, 0.8), tone(f * 2.01, 0.14, 0.3)), decay=30.0)
	save_wav("craft", concat(clink(1180.0), silence(0.04), clink(1480.0)))

	# Gather (mine/chop): a blunt crack with a low thump under it.
	save_wav("gather", mix(
		env_exp(tone(110.0, 0.18, 0.9), decay=22.0),
		env_exp(lowpass(noise(0.12, 0.9), 0.3), decay=33.0),
	))

	# Level-up sting: a rising triad, a little triumphant but still soft.
	notes = [523.25, 659.25, 783.99, 1046.5]
	parts = [env_exp(tone(f, 0.16, 0.6, "triangle"), decay=12.0) for f in notes]
	# Let the last note ring; stagger the rest.
	save_wav("levelup", concat(parts[0][: _n(0.10)], parts[1][: _n(0.10)],
		parts[2][: _n(0.10)], parts[3]))

	# Dodge: a short airy whoosh — softer and breathier than a sword swing.
	dodge = lowpass(noise(0.20, 1.0), 0.78)
	dodge = [s * math.sin(math.pi * i / len(dodge)) ** 1.5 for i, s in enumerate(dodge)]
	save_wav("dodge", gain(dodge, 0.8))

	# UI click: a tiny dry tick.
	save_wav("ui_click", env_exp(tone(1500.0, 0.03, 0.5, "square"), decay=80.0))

	print("audioforge: done.")


if __name__ == "__main__":
	bake_all()
