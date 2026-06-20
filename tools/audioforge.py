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
_AUDIO = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
OUT_DIR = os.path.join(_AUDIO, "sfx")
MUSIC_DIR = os.path.join(_AUDIO, "music")
AMB_DIR = os.path.join(_AUDIO, "ambience")


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


def _write_wav(directory: str, name: str, sig: list) -> None:
	os.makedirs(directory, exist_ok=True)
	path = os.path.join(directory, name + ".wav")
	with wave.open(path, "w") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(RATE)
		frames = bytearray()
		for s in sig:
			v = int(max(-1.0, min(1.0, s)) * 32767)
			frames += struct.pack("<h", v)
		w.writeframes(bytes(frames))
	print("  baked %-14s %7d samples  (%.2fs)" % (name, len(sig), len(sig) / RATE))


def save_wav(name: str, sig: list) -> None:
	# One-shot SFX: peak-normalize and ramp the ends so a clip never clicks.
	_write_wav(OUT_DIR, name, soft_fade(normalize(sig)))


def make_loop(body: list, xfade: float = 0.5) -> list:
	"""Crossfade a clip's tail back over its head so it loops seamlessly. Returns a
	loop of length (len(body) - xfade): playing the last sample into the first is
	continuous, because the head is blended with what naturally followed it."""
	x = _n(xfade)
	n = len(body)
	if n <= 2 * x:
		return body
	out = list(body[: n - x])
	for i in range(x):
		a = i / x
		out[i] = body[i] * a + body[n - x + i] * (1.0 - a)
	return out


def save_loop(directory: str, name: str, sig: list, peak: float = 0.55) -> None:
	# Looping bed/track: normalize but DON'T soft-fade the ends (that would dip the
	# loop seam). The seam is made continuous by make_loop() before saving.
	_write_wav(directory, name, normalize(sig, peak))


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

	# Hoe dig: a soft earthy crunch into the soil.
	save_wav("dig", mix(
		env_exp(lowpass(noise(0.13, 0.9), 0.55), decay=30.0),
		env_exp(tone(90.0, 0.10, 0.5), decay=34.0),
	))

	# Watering can: a gentle falling splash.
	save_wav("water", mix(
		env_exp(sweep(900.0, 380.0, 0.16, 0.45), decay=12.0),
		env_exp(lowpass(noise(0.16, 0.5), 0.45), decay=16.0),
	))

	# Axe chop: a woody knock with a short crack.
	save_wav("chop", mix(
		env_exp(tone(185.0, 0.14, 0.9, "triangle"), decay=24.0),
		env_exp(lowpass(noise(0.06, 0.7), 0.35), decay=48.0),
	))

	# Fishing cast: a light, breathy whoosh.
	cast = lowpass(noise(0.22, 0.9), 0.72)
	cast = [s * math.sin(math.pi * i / len(cast)) for i, s in enumerate(cast)]
	save_wav("cast", gain(cast, 0.7))

	# UI click: a tiny dry tick.
	save_wav("ui_click", env_exp(tone(1500.0, 0.03, 0.5, "square"), decay=80.0))

	print("audioforge: done.")


# --- music & ambience (looping) ---------------------------------------------
#
# Longer, quieter, seamless loops on the same grounded palette — sparse and a
# little mournful, never busy. Music plays on the Music bus, beds on Ambience;
# MusicManager crossfades between them. Every track is wrapped with make_loop().

# A small note table (Hz), a couple of octaves around the mid register.
NOTE = {
	"A2": 110.00, "C3": 130.81, "D3": 146.83, "Eb3": 155.56, "E3": 164.81,
	"F3": 174.61, "G3": 196.00, "A3": 220.00, "Bb3": 233.08, "B3": 246.94,
	"C4": 261.63, "D4": 293.66, "Eb4": 311.13, "E4": 329.63, "F4": 349.23,
	"G4": 392.00, "A4": 440.00, "Bb4": 466.16, "C5": 523.25, "D5": 587.33,
	"E5": 659.25, "G5": 783.99,
}


def pad(names: list, seconds: float, amp: float = 0.5, wave_kind: str = "triangle") -> list:
	"""A sustained chord with a slow swell in and out — soft, organ-like."""
	layers = [tone(NOTE[n], seconds, amp / max(1, len(names)), wave_kind) for n in names]
	sig = mix(*layers)
	n = len(sig)
	for i in range(n):
		sig[i] *= math.sin(math.pi * i / n) ** 0.6      # gentle swell
	return lowpass(sig, 0.3)


def pluck(name: str, seconds: float, amp: float = 0.5) -> list:
	"""A soft plucked melody note (triangle, exp decay)."""
	return env_exp(tone(NOTE[name], seconds, amp, "triangle"), decay=6.0)


def drone(freq: float, seconds: float, amp: float = 0.5, detune: float = 0.0) -> list:
	"""A low sustained drone, optionally with a slow detuned beat for unease."""
	a = tone(freq, seconds, amp, "sine")
	if detune > 0.0:
		a = mix(a, tone(freq * (1.0 + detune), seconds, amp * 0.7, "sine"))
	return lowpass(a, 0.2)


def place(bed: list, ev: list, at_seconds: float, gain_: float = 1.0) -> list:
	"""Mix a short event into a bed at a time offset (in place)."""
	i0 = _n(at_seconds)
	for j, v in enumerate(ev):
		k = i0 + j
		if 0 <= k < len(bed):
			bed[k] += v * gain_
	return bed


def wind(seconds: float, amp: float = 0.4, cutoff: float = 0.9) -> list:
	"""Filtered noise with slow gusting — the open-air bed."""
	bed = lowpass(lowpass(noise(seconds, amp), cutoff), cutoff)
	for i in range(len(bed)):
		gust = 0.6 + 0.4 * math.sin(2 * math.pi * 0.06 * i / RATE) * math.sin(2 * math.pi * 0.017 * i / RATE)
		bed[i] *= gust
	return bed


def chirp(freq: float) -> list:
	"""A little two-note bird call."""
	return env_exp(concat(
		sweep(freq, freq * 1.3, 0.05, 0.5),
		sweep(freq * 1.3, freq * 0.95, 0.04, 0.4),
	), decay=24.0)


def cricket(freq: float = 4200.0) -> list:
	return env_exp(lowpass(tone(freq, 0.012, 0.4, "square"), 0.2), decay=110.0)


def drip(freq: float = 1300.0) -> list:
	return env_exp(sweep(freq, freq * 0.5, 0.10, 0.6), decay=20.0)


def chord_progression(prog: list, bar: float, amp: float, melody: list = None) -> list:
	"""Concatenate chord bars; optionally mix a sparse pluck melody over them.
	melody is a list of (bar_index, note, dur) tuples."""
	bars = [pad(ch, bar, amp) for ch in prog]
	track = concat(*bars)
	if melody:
		for (bi, note, dur) in melody:
			place(track, pluck(note, dur, amp * 0.8), bi * bar + 0.15)
	return track


def bake_music() -> None:
	random.seed(11)
	print("audioforge: baking music -> %s" % os.path.normpath(MUSIC_DIR))

	# Camp / home / title — warm, hopeful-melancholy (vi-IV-I-V), a soft melody.
	camp = chord_progression(
		[["A3", "C4", "E4"], ["F3", "A3", "C4"], ["C4", "E4", "G4"], ["G3", "B3", "D4"]],
		bar=3.0, amp=0.5,
		melody=[(0, "E4", 1.2), (1, "C4", 1.2), (2, "G4", 1.4), (3, "D4", 1.0), (3, "B3", 0.8)],
	)
	camp = mix(camp, gain(concat(*[drone(NOTE[n], 3.0, 0.28) for n in ["A2", "F3", "C3", "G3"]]), 1.0))
	save_loop(MUSIC_DIR, "theme_camp", make_loop(camp, 0.6), peak=0.5)

	# Town — lighter and a touch brighter (I-V-vi-IV), more melodic movement.
	town = chord_progression(
		[["C4", "E4", "G4"], ["G3", "B3", "D4"], ["A3", "C4", "E4"], ["F3", "A3", "C4"]],
		bar=2.6, amp=0.46,
		melody=[(0, "G4", 0.9), (0, "E4", 0.7), (1, "D4", 0.9), (2, "E4", 0.9),
			(2, "C5", 0.8), (3, "A4", 1.0)],
	)
	save_loop(MUSIC_DIR, "theme_town", make_loop(town, 0.5), peak=0.5)

	# Wild — sparse, lonely exploration. A low Dm drone and a far-off high note.
	wild = concat(*[drone(NOTE[n], 3.5, 0.4) for n in ["D3", "D3", "A2", "D3"]])
	wild = mix(wild, gain(pad(["D4", "F4", "A4"], 14.0, 0.18), 1.0))
	place(wild, pluck("A4", 1.6, 0.3), 2.2)
	place(wild, pluck("F4", 1.8, 0.28), 7.0)
	place(wild, pluck("D5", 1.4, 0.24), 10.6)
	save_loop(MUSIC_DIR, "theme_wild", make_loop(wild, 0.7), peak=0.45)

	# Cursed — ominous, dissonant low drone (root + a beating tritone-ish detune).
	cursed = drone(NOTE["D3"], 14.0, 0.5, detune=0.03)
	cursed = mix(cursed, gain(drone(NOTE["Eb3"], 14.0, 0.22), 1.0))      # minor-second grind
	cursed = mix(cursed, gain(pad(["D4", "Eb4", "A4"], 14.0, 0.14), 1.0))
	place(cursed, env_exp(sweep(180.0, 60.0, 2.0, 0.5), decay=2.0), 4.0)  # slow groan
	place(cursed, env_exp(sweep(170.0, 55.0, 2.2, 0.45), decay=2.0), 9.5)
	save_loop(MUSIC_DIR, "theme_cursed", make_loop(cursed, 0.8), peak=0.5)

	print("audioforge: music done.")


def bake_ambience() -> None:
	random.seed(23)
	print("audioforge: baking ambience -> %s" % os.path.normpath(AMB_DIR))

	# Day — gentle wind with a few birds (kept clear of the loop seam).
	day = wind(10.0, 0.34)
	for t in [1.1, 3.6, 5.2, 7.3]:
		place(day, chirp(random.uniform(2200.0, 3000.0)), t, 0.7)
	save_loop(AMB_DIR, "amb_day", make_loop(day, 0.6), peak=0.4)

	# Night — lower wind and a steady bed of crickets.
	night = wind(10.0, 0.26, cutoff=0.95)
	t = 0.4
	while t < 9.0:
		place(night, cricket(random.uniform(3900.0, 4500.0)), t, 0.5)
		t += random.uniform(0.22, 0.4)
	save_loop(AMB_DIR, "amb_night", make_loop(night, 0.6), peak=0.4)

	# Cave — a low rumble with sparse water drips.
	cave = lowpass(noise(12.0, 0.3), 0.97)
	cave = mix(cave, drone(55.0, 12.0, 0.3))
	for t in [1.5, 4.1, 6.0, 8.7, 10.2]:
		place(cave, drip(random.uniform(1100.0, 1600.0)), t, 0.6)
	save_loop(AMB_DIR, "amb_cave", make_loop(cave, 0.7), peak=0.4)

	# Cursed — a dark wind drone with occasional low groans (the Vast breathing).
	curse = mix(wind(12.0, 0.3, cutoff=0.97), drone(70.0, 12.0, 0.3, detune=0.02))
	place(curse, env_exp(sweep(150.0, 50.0, 2.4, 0.5), decay=1.6), 3.0, 0.8)
	place(curse, env_exp(sweep(140.0, 48.0, 2.6, 0.45), decay=1.6), 8.5, 0.8)
	save_loop(AMB_DIR, "amb_cursed", make_loop(curse, 0.7), peak=0.4)

	print("audioforge: ambience done.")


if __name__ == "__main__":
	bake_all()
	bake_music()
	bake_ambience()
