#!/usr/bin/env python3
"""High-fidelity procedural hero renderer for Teramor (no retro constraint).

A tiny software renderer that sculpts with METABALLS: every primitive writes a
front-surface height + coverage, blended with a smooth-union (smax) so forms
merge into one continuous body instead of disconnected blobs. Normals come from
the blended height field (so seams vanish), then it's lit with a key/fill/
hemispheric-ambient model + Fresnel rim + Blinn-Phong speculars, warm subsurface
on skin, and procedural fabric/leather/hair texture. Supersampled + box
downsampled for clean anti-aliasing. Stdlib only.

Run:  python3 tools/forge_hero.py   ->  /tmp/forge_hero.png (+ 2x)
"""

import math
import os
import random
import struct
import zlib

SS = 3
OW, OH = 160, 232
W, H = OW * SS, OH * SS

# ---------- math ----------

def vnorm(v):
    x, y, z = v
    m = math.sqrt(x * x + y * y + z * z) or 1.0
    return (x / m, y / m, z / m)

def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]

def mix(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)

def clamp(v, a, b):
    return a if v < a else (b if v > b else v)

def smoothstep(e0, e1, x):
    t = clamp((x - e0) / (e1 - e0) if e1 != e0 else 0.0, 0.0, 1.0)
    return t * t * (3 - 2 * t)

# ---------- procedural noise ----------

def _h(x, y, s):
    n = (x * 374761393 + y * 668265263 + s * 1442695040888963407) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0

def vnoise(x, y, s=0):
    xi, yi = int(math.floor(x)), int(math.floor(y))
    xf, yf = x - xi, y - yi
    u = xf * xf * (3 - 2 * xf); v = yf * yf * (3 - 2 * yf)
    a = _h(xi, yi, s); b = _h(xi + 1, yi, s)
    c = _h(xi, yi + 1, s); d = _h(xi + 1, yi + 1, s)
    return (a * (1 - u) + b * u) * (1 - v) + (c * (1 - u) + d * u) * v

def fbm(x, y, s=0, oct=3):
    t, amp, f, tot = 0.0, 1.0, 1.0, 0.0
    for _ in range(oct):
        t += amp * vnoise(x * f, y * f, s); tot += amp; amp *= 0.5; f *= 2.0
    return t / tot

# ---------- materials ----------
MATS = {
    "skin":    {"alb": (232, 184, 146), "rough": 0.6, "spec": 0.16, "sss": (206, 118, 92), "tex": "skin"},
    "tunic":   {"alb": (70, 92, 86),    "rough": 0.96, "spec": 0.04, "sss": None, "tex": "cloth"},
    "leather": {"alb": (110, 74, 46),   "rough": 0.5, "spec": 0.26, "sss": None, "tex": "leather"},
    "leather_d": {"alb": (78, 52, 33),  "rough": 0.5, "spec": 0.28, "sss": None, "tex": "leather"},
    "strap":   {"alb": (64, 44, 30),    "rough": 0.5, "spec": 0.28, "sss": None, "tex": "leather"},
    "trouser": {"alb": (80, 72, 58),    "rough": 0.96, "spec": 0.04, "sss": None, "tex": "cloth"},
    "boot":    {"alb": (58, 44, 33),    "rough": 0.42, "spec": 0.28, "sss": None, "tex": "leather"},
    "metal":   {"alb": (178, 184, 196), "rough": 0.1, "spec": 1.0, "sss": None, "tex": "metal"},
    "hair":    {"alb": (92, 60, 36),    "rough": 0.32, "spec": 0.4, "sss": None, "tex": "hair"},
}

# ---------- metaball height field ----------

R2 = 2.89          # metaball influence radius^2 (1.7x the core)
ISO = 0.45         # isosurface threshold


class Field:
    def __init__(self, w, h):
        self.w, self.h = w, h
        n = w * h
        self.dens = [0.0] * n     # accumulated metaball density
        self.hsum = [0.0] * n     # density-weighted front height
        self.wsum = [0.0] * n
        self.mat = [None] * n     # material of strongest contributor
        self.mc = [0.0] * n
        self.hgt = [-1e9] * n     # resolved surface height (finalize)
        self.cov = [0.0] * n      # resolved coverage/alpha (finalize)
        self.aoc = [0.0] * n

    def ellipsoid(self, cx, cy, cz, rx, ry, rz, mat, k=0.0):
        cx *= SS; cy *= SS; cz *= SS; rx *= SS; ry *= SS; rz *= SS
        infx = rx * 1.7; infy = ry * 1.7
        x0 = max(0, int(cx - infx - 1)); x1 = min(self.w - 1, int(cx + infx + 1))
        y0 = max(0, int(cy - infy - 1)); y1 = min(self.h - 1, int(cy + infy + 1))
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                ux = (x + 0.5 - cx) / rx; uy = (y + 0.5 - cy) / ry
                d2 = ux * ux + uy * uy
                if d2 >= R2:
                    continue
                t = 1.0 - d2 / R2
                contrib = t * t
                hi = cz + rz * math.sqrt(max(0.0, 1.0 - min(1.0, d2)))
                i = y * self.w + x
                self.dens[i] += contrib
                self.hsum[i] += hi * contrib
                self.wsum[i] += contrib
                if contrib > self.mc[i]:
                    self.mc[i] = contrib; self.mat[i] = mat

    def capsule(self, p0, p1, r0, r1, mat, k=0.0):
        (ax, ay, az), (bx, by, bz) = p0, p1
        steps = int(max(abs(bx - ax), abs(by - ay)) * SS * 1.3) + 3
        for s in range(steps + 1):
            t = s / steps
            self.ellipsoid(ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t,
                           r0 + (r1 - r0) * t, r0 + (r1 - r0) * t, r0 + (r1 - r0) * t, mat, k)

    def finalize(self):
        for i in range(self.w * self.h):
            de = self.dens[i]
            if de <= 0:
                continue
            self.cov[i] = smoothstep(ISO - 0.12, ISO + 0.12, de)
            if self.wsum[i] > 0:
                self.hgt[i] = self.hsum[i] / self.wsum[i]

    def crease(self, x, y, r, amt):
        x *= SS; y *= SS; r *= SS
        for yy in range(max(0, int(y - r)), min(self.h, int(y + r) + 1)):
            for xx in range(max(0, int(x - r)), min(self.w, int(x + r) + 1)):
                i = yy * self.w + xx
                if self.cov[i] <= 0:
                    continue
                d = math.hypot(xx - x, yy - y) / r
                if d < 1.0:
                    self.aoc[i] = max(self.aoc[i], (1 - d) * amt)

# ---------- lighting ----------
KEY_DIR = vnorm((-0.46, -0.6, 0.66)); KEY_COL = (1.08, 1.0, 0.9)
FILL_DIR = vnorm((0.74, 0.0, 0.5)); FILL_COL = (0.42, 0.52, 0.68)
SKY = (0.44, 0.5, 0.6); GND = (0.3, 0.25, 0.21)
VIEW = (0.0, 0.0, 1.0)
RIM_COL = (1.0, 0.94, 0.84)
NSTR = 0.7 / SS            # height-field -> normal strength (roundness)

def mat_albedo(m, x, y):
    spec = MATS[m]; a = spec["alb"]; kind = spec["tex"]
    fx, fy = x / SS, y / SS
    if kind == "cloth":
        n = fbm(fx * 0.45, fy * 0.45, 11, 3) - 0.5
        return tuple(v * (1.0 + n * 0.18) for v in a)
    if kind == "leather":
        n = fbm(fx * 0.7, fy * 0.7, 5, 3) - 0.5
        cr = vnoise(fx * 1.5, fy * 1.5, 7) - 0.5
        return tuple(v * (1.0 + n * 0.2 + cr * 0.12) for v in a)
    if kind == "skin":
        n = fbm(fx * 0.8, fy * 0.8, 3, 2) - 0.5
        return tuple(v * (1.0 + n * 0.06) for v in a)
    if kind == "hair":
        # fine flowing strands + a soft sheen band catching the key light
        strand = math.sin(fx * 8.0 + fbm(fx * 0.35, fy * 0.22, 9) * 8) * 0.5 + 0.5
        sheen = smoothstep(0.0, 1.0, 1.0 - abs((fx - OW * 0.42) / 18.0))
        f = 0.72 + strand * 0.5 + sheen * 0.35
        return tuple(v * f for v in a)
    return a

def normal_at(fld, x, y):
    w = fld.w
    i = y * w + x
    hl = fld.hgt[i - 1] if x > 0 and fld.cov[i - 1] > 0 else fld.hgt[i]
    hr = fld.hgt[i + 1] if x < w - 1 and fld.cov[i + 1] > 0 else fld.hgt[i]
    hu = fld.hgt[i - w] if y > 0 and fld.cov[i - w] > 0 else fld.hgt[i]
    hd = fld.hgt[i + w] if y < fld.h - 1 and fld.cov[i + w] > 0 else fld.hgt[i]
    return vnorm((-(hr - hl) * 0.5 * NSTR, -(hd - hu) * 0.5 * NSTR, 1.0))

def shade(fld, x, y, override):
    i = y * fld.w + x
    N = normal_at(fld, x, y)
    m = fld.mat[i]; spec = MATS[m]
    alb = override if override else mat_albedo(m, x, y)
    ndl = dot(N, KEY_DIR)
    diff = (ndl * 0.5 + 0.5) ** 1.5 if spec["tex"] == "skin" else max(0.0, ndl)
    ndf = max(0.0, dot(N, FILL_DIR))
    ao = (1.0 - fld.aoc[i])
    amb = mix(GND, SKY, (-(N[1]) * 0.5 + 0.5))
    out = [0.0, 0.0, 0.0]
    for c in range(3):
        out[c] = alb[c] * (diff * KEY_COL[c] + ndf * FILL_COL[c] * 0.85 + amb[c] * 0.85) * ao
    if spec["sss"] and ndl < 0.4:
        bleed = (0.4 - max(-0.25, ndl)) * 0.5 * ao
        for c in range(3):
            out[c] += spec["sss"][c] * bleed
    Hh = vnorm((KEY_DIR[0] + VIEW[0], KEY_DIR[1] + VIEW[1], KEY_DIR[2] + VIEW[2]))
    ndh = max(0.0, dot(N, Hh))
    s = (ndh ** (4 + (1 - spec["rough"]) * 140)) * spec["spec"]
    if spec["tex"] == "metal":
        s *= 1.7
    for c in range(3):
        out[c] += KEY_COL[c] * 255 * s
    # Fresnel rim: warm key-side edge light (pops the silhouette), faint cool
    # back-edge on the shadow side for separation from the background.
    fres = (1.0 - max(0.0, N[2])) ** 2.6
    warm = fres * max(0.0, dot(N, (-0.42, -0.55, 0.0))) * 1.35
    cool = fres * max(0.0, dot(N, (0.5, 0.45, 0.0))) * 0.5
    for c in range(3):
        out[c] += RIM_COL[c] * 205 * warm + (120, 140, 170)[c] * cool
    return out

# ---------- the figure ----------
cx_g = OW / 2.0

def build():
    f = Field(W, H)
    cx = cx_g
    K = 6.0
    # legs: thigh -> calf, tall boots, knees
    for s in (-1, 1):
        hx = cx + s * 11
        f.capsule((hx, 150, 0), (hx + s * 2, 188, 0), 10, 7.5, "trouser", K)
        f.capsule((hx + s * 2, 186, 0), (hx + s * 3, 210, 0), 8, 6, "boot", K)
        f.ellipsoid(hx + s * 3, 214, 6, 8, 5.5, 8, "boot", K)
    # pelvis + belt + buckle + pouch
    f.ellipsoid(cx, 150, 2, 19, 11, 12, "trouser", K)
    f.ellipsoid(cx, 145, 6, 20, 5, 11, "strap", 4.0)
    f.ellipsoid(cx, 145, 13, 5, 3.6, 4, "metal", 2.0)
    f.ellipsoid(cx - 13, 150, 9, 5.5, 7, 5, "leather_d", 4.0)
    # torso: chest -> waist (tapered), leather cuirass proud over a tunic
    f.ellipsoid(cx, 100, 0, 25, 18, 13, "tunic", K)        # tunic (sleeves/collar show)
    f.ellipsoid(cx, 98, 6, 22, 17, 12, "leather", K)       # one clean cuirass over the chest
    f.ellipsoid(cx, 122, 4, 18, 12, 10, "leather", K)      # ...continuing over the abdomen
    for s in (-1, 1):                                      # crossed shoulder straps
        f.capsule((cx + s * 8, 82, 10), (cx + s * 3, 106, 10), 2.4, 2.2, "strap", 1.5)
    # pauldrons + arms (upper -> bracer -> glove), held slightly out
    for s in (-1, 1):
        f.ellipsoid(cx + s * 23, 82, 4, 12, 10, 11, "leather", K)
        f.capsule((cx + s * 23, 88, 2), (cx + s * 27, 118, 1), 8, 6.5, "tunic", K)
        f.capsule((cx + s * 27, 116, 2), (cx + s * 30, 146, 2), 6.5, 5, "leather", K)
        f.ellipsoid(cx + s * 31, 150, 3, 5.5, 6, 5, "leather_d", 4.0)
    # neck + head, with brow / cheek / jaw / nose structure (all merged)
    f.ellipsoid(cx, 70, 4, 6.5, 7, 7, "skin", 5.0)
    f.ellipsoid(cx, 71, 9, 11, 5, 7, "leather", 4.0)       # collar
    f.ellipsoid(cx, 48, 2, 16, 19, 15, "skin", K)          # cranium
    f.ellipsoid(cx, 54, 9, 13, 13, 8, "skin", K)           # face plane
    f.ellipsoid(cx - 8, 53, 8, 5, 6, 5, "skin", 4.0)       # cheekbones
    f.ellipsoid(cx + 8, 53, 8, 5, 6, 5, "skin", 4.0)
    f.ellipsoid(cx, 60, 11, 5.5, 6, 5, "skin", 4.0)        # jaw/chin
    f.ellipsoid(cx, 53, 13, 2.6, 6, 4, "skin", 3.0)        # nose bridge
    f.ellipsoid(cx, 56.5, 14, 3.0, 2.4, 3, "skin", 2.5)    # nose tip
    return f


def creases(f):
    cx = cx_g
    f.crease(cx - 6.5, 52, 4, 0.5)        # eye sockets
    f.crease(cx + 6.5, 52, 4, 0.5)
    f.crease(cx, 53, 2.4, 0.25)           # nose sides
    f.crease(cx, 61.5, 4.5, 0.32)         # under lip
    f.crease(cx, 68, 6, 0.4)              # under jaw
    f.crease(cx - 15, 94, 7, 0.28); f.crease(cx + 15, 94, 7, 0.28)   # armpits
    for yy in range(88, 116):                # sternum seam down the cuirass
        f.crease(cx, yy, 1.8, 0.28)
    f.crease(cx - 9, 104, 5, 0.22); f.crease(cx + 9, 104, 5, 0.22)   # under-pec lines
    f.crease(cx, 112, 6, 0.2)                # waist cinch
    for s in (-1, 1):                        # pauldron under-edge shadow
        f.crease(cx + s * 22, 90, 6, 0.3)


def detail(f):
    cx = cx_g
    # hair: swept strands framing the face. Front strands stay SHORT so the
    # forehead + eyes read clearly (the muddy-face fix); side strands fall long.
    rnd = random.Random(7)
    for _ in range(170):
        a = rnd.uniform(-1.3, 1.3)
        ox = cx + math.sin(a) * 15
        oy = 33 + (1 - math.cos(a)) * 6
        front = abs(a) < 0.5
        length = rnd.uniform(4, 9) if front else rnd.uniform(16, 28)
        tipx = ox + math.sin(a) * 6 + rnd.uniform(-3, 6)
        f.capsule((ox, oy, 11 + math.cos(a) * 5), (tipx, oy + length, 5), 2.0, 0.9, "hair", 2.5)
    f.ellipsoid(cx, 35, 4, 17, 12, 13, "hair", 6.0)        # hair mass / back of head


# ---------- eyes / brows / lips as albedo overrides ----------

def paint_face(f, override):
    cx = cx_g
    for s in (-1, 1):
        ex, ey = cx + s * 6.2, 52.5
        exs, eys = int(ex * SS), int(ey * SS)
        rx, ry = 3.4 * SS, 2.5 * SS
        for yy in range(int(eys - ry), int(eys + ry) + 1):
            for xx in range(int(exs - rx), int(exs + rx) + 1):
                if not (0 <= xx < f.w and 0 <= yy < f.h) or f.cov[yy * f.w + xx] <= 0:
                    continue
                dx = (xx - exs) / rx; dy = (yy - eys) / ry
                d = dx * dx + dy * dy
                if d > 1.0:
                    continue
                i = yy * f.w + xx
                if d > 0.66:
                    override[i] = (150, 116, 92)               # lid / socket rim
                elif abs((xx - exs) / SS) < 1.7 and dy * dy < 0.55:
                    override[i] = (58, 78, 70)                 # iris (hazel-green)
                    if abs((xx - exs) / SS) < 0.7:
                        override[i] = (26, 22, 26)             # pupil
                else:
                    override[i] = (236, 230, 220)              # sclera
        cxp, cyp = exs - int(1.2 * SS), eys - int(1.0 * SS)
        if 0 <= cxp < f.w and 0 <= cyp < f.h:
            override[cyp * f.w + cxp] = (252, 248, 242)        # catchlight
    # brows (a touch above the eyes, angled)
    for s in (-1, 1):
        for t in range(int(-4.5 * SS), int(4.5 * SS)):
            bx = int((cx + s * 6.2) * SS + t * s); by = int(48.6 * SS - abs(t) * 0.16)
            if 0 <= bx < f.w and 0 <= by < f.h and f.cov[by * f.w + bx] > 0:
                override[by * f.w + bx] = (78, 52, 38)
    # lips
    for t in range(int(-4 * SS), int(4 * SS)):
        lx = int(cx * SS + t)
        for ly in (int(60.5 * SS), int(61 * SS)):
            if 0 <= lx < f.w and 0 <= ly < f.h and f.cov[ly * f.w + lx] > 0:
                override[ly * f.w + lx] = (176, 104, 88)

# ---------- render + downsample ----------

def render(f):
    override = [None] * (f.w * f.h)
    paint_face(f, override)
    accl = [0.0] * (OW * OH * 4)
    for y in range(f.h):
        oy = y // SS; base = oy * OW
        for x in range(f.w):
            i = y * f.w + x
            if f.cov[i] <= 0:
                continue
            col = shade(f, x, y, override[i])
            a = f.cov[i]
            j = (base + x // SS) * 4
            accl[j] += clamp(col[0], 0, 255) * a
            accl[j + 1] += clamp(col[1], 0, 255) * a
            accl[j + 2] += clamp(col[2], 0, 255) * a
            accl[j + 3] += a
    px = bytearray(OW * OH * 4)
    samples = SS * SS
    for k in range(OW * OH):
        wsum = accl[k * 4 + 3]
        if wsum <= 0:
            continue
        px[k * 4] = int(clamp(accl[k * 4] / wsum, 0, 255))
        px[k * 4 + 1] = int(clamp(accl[k * 4 + 1] / wsum, 0, 255))
        px[k * 4 + 2] = int(clamp(accl[k * 4 + 2] / wsum, 0, 255))
        px[k * 4 + 3] = int(clamp(wsum / samples * 255, 0, 255))
    return px

def save_png(path, px, w, h):
    raw = bytearray()
    for y in range(h):
        raw.append(0); raw += px[y * w * 4:(y + 1) * w * 4]
    comp = zlib.compress(bytes(raw), 9)
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    out = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    out += chunk(b"IDAT", comp) + chunk(b"IEND", b"")
    with open(path, "wb") as fp:
        fp.write(out)

def upscale(px, w, h, n):
    out = bytearray(w * n * h * n * 4)
    for y in range(h):
        for x in range(w):
            p = px[(y * w + x) * 4:(y * w + x) * 4 + 4]
            for yy in range(n):
                row = ((y * n + yy) * w * n + x * n) * 4
                for xx in range(n):
                    out[row + xx * 4:row + xx * 4 + 4] = p
    return out

def main():
    f = build()
    detail(f)          # hair forms accumulate into the field
    f.finalize()       # resolve isosurface coverage + height
    creases(f)         # crease darkening uses resolved coverage
    px = render(f)
    save_png("/tmp/forge_hero.png", px, OW, OH)
    save_png("/tmp/forge_hero_2x.png", upscale(px, OW, OH, 2), OW * 2, OH * 2)
    print("wrote /tmp/forge_hero.png (%dx%d)" % (OW, OH))


if __name__ == "__main__":
    main()
