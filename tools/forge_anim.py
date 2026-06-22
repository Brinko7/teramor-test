#!/usr/bin/env python3
"""Animated idle preview for the Hooded Child of Tera -> /tmp/ranger_idle.gif.

Renders the cel-shaded ranger sprite once (via forge_ranger), then composites an
atmospheric IDLE loop: a slow breathing bob, the Tera-gold gaze + rune and the
teal clasp-gem pulsing with light, a breathing moonlit back-halo, and drifting
gold/teal spores. Encoded as a looping GIF with a hand-written LZW encoder
(stdlib only).
"""

import math, os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import forge_ranger                       # noqa: E402
from pixelforge import Canvas, load_png   # noqa: E402

FRAMES = 14
CW, CH = 210, 238
SCALE = 2

def composite(t, sprite, spores):
    m = Canvas(CW, CH); cxf = CW / 2
    for y in range(CH):
        for x in range(CW):
            d = math.hypot((x-cxf)/(CW*0.62), (y-CH*0.40)/(CH*0.6)); v = max(0.0, 1-d)
            m.paint(x, y, (int(14+22*v), int(20+28*v), int(28+34*v), 255))
    def add(x, y, col, a):
        if not (0 <= x < CW and 0 <= y < CH): return
        p = m.at(int(x), int(y))
        m.paint(int(x), int(y), (min(255, int(p[0]+col[0]*a)), min(255, int(p[1]+col[1]*a)),
                                 min(255, int(p[2]+col[2]*a)), 255))
    def glow(cx, cy, rad, col, inten):
        for y in range(int(cy-rad), int(cy+rad)):
            for x in range(int(cx-rad), int(cx+rad)):
                dd = math.hypot(x-cx, y-cy)/rad
                if dd < 1: add(x, y, col, inten*(1-dd)*(1-dd))
    breath = math.sin(t*2*math.pi)
    pulse = 0.5 + 0.5*math.sin(t*2*math.pi)
    tpulse = 0.5 + 0.5*math.sin(t*2*math.pi + 2.1)
    # back halo (breathes) + ground pool
    glow(cxf+4, CH*0.34, 60+breath*4, (90,140,190), 0.42+0.10*pulse)
    glow(cxf, CH*0.30, 30, (255,196,110), 0.26+0.12*pulse)
    glow(cxf, CH-20, 54, (210,150,70), 0.32)
    # the sprite, bobbing with breath
    bob = round(-breath*1.5)
    rx = int(cxf - sprite.w/2); ry = CH - sprite.h - 14 + bob
    m.blit(sprite, rx, ry, mode="over")
    # pulsing accent lights (sprite coords: cx=55)
    glow(rx+51, ry+33, 6, (255,210,130), 0.30+0.45*pulse)     # left eye
    glow(rx+59, ry+33, 6, (255,210,130), 0.30+0.45*pulse)     # right eye
    glow(rx+55, ry+64, 7, (255,185,95), 0.25+0.40*pulse)      # rune-pendant
    glow(rx+55, ry+49, 5, (120,228,204), 0.25+0.45*tpulse)    # teal clasp-gem
    # drifting spores
    for (x0, y0, ph, sp, rad, teal) in spores:
        y = (y0 - t*sp*CH) % CH
        x = x0 + math.sin(t*2*math.pi + ph)*4
        col = (130,225,205) if teal else (255,205,120)
        glow(x, y, rad*2.2, col, 0.5)
        add(x, y, (255,235,180) if not teal else (200,245,230), 0.9)
    return m.scaled(SCALE)

# ---------- GIF (LZW) encoder, stdlib only ----------

def quantize(frames):
    from collections import Counter
    cnt = Counter()
    for fr in frames:
        for i in range(0, len(fr.buf), 4):
            cnt[(fr.buf[i], fr.buf[i+1], fr.buf[i+2])] += 1
    pal = [c for c, _ in cnt.most_common(256)]
    while len(pal) < 256:
        pal.append((0, 0, 0))
    cache = {}
    def idx(c):
        j = cache.get(c)
        if j is not None: return j
        best, bd = 0, 1e18
        for k, pc in enumerate(pal):
            d = (c[0]-pc[0])**2 + (c[1]-pc[1])**2 + (c[2]-pc[2])**2
            if d < bd: bd = d; best = k
            if d == 0: break
        cache[c] = best; return best
    indexed = []
    for fr in frames:
        b = bytearray(fr.w*fr.h)
        for p in range(fr.w*fr.h):
            b[p] = idx((fr.buf[p*4], fr.buf[p*4+1], fr.buf[p*4+2]))
        indexed.append(b)
    return pal, indexed

def _lzw(data, mcs):
    clear = 1 << mcs; eoi = clear + 1
    out = bytearray(); buf = 0; nb = 0
    def wr(code, size):
        nonlocal buf, nb
        buf |= code << nb; nb += size
        while nb >= 8:
            out.append(buf & 0xFF); buf >>= 8; nb -= 8
    table = {}; cs = mcs + 1; nxt = eoi + 1
    wr(clear, cs)
    it = iter(data); cur = next(it)
    for k in it:
        key = (cur, k); c = table.get(key)
        if c is not None:
            cur = c
        else:
            wr(cur, cs); table[key] = nxt; nxt += 1
            if nxt == (1 << cs):
                if cs < 12:
                    cs += 1
            if nxt == 4096:
                wr(clear, cs); table = {}; cs = mcs + 1; nxt = eoi + 1
            cur = k
    wr(cur, cs); wr(eoi, cs)
    if nb > 0: out.append(buf & 0xFF)
    return out

def write_gif(path, pal, frames_idx, w, h, delay_cs):
    o = bytearray(b"GIF89a")
    o += w.to_bytes(2, "little") + h.to_bytes(2, "little")
    o += bytes([0xF7, 0, 0])                       # global table, 256 colors
    for c in pal:
        o += bytes(c)
    o += b"\x21\xFF\x0BNETSCAPE2.0\x03\x01\x00\x00\x00"   # loop forever
    for fr in frames_idx:
        o += bytes([0x21, 0xF9, 0x04, 0x04]) + delay_cs.to_bytes(2, "little") + b"\x00\x00"
        o += b"\x2C" + (0).to_bytes(2, "little") + (0).to_bytes(2, "little")
        o += w.to_bytes(2, "little") + h.to_bytes(2, "little") + bytes([0])
        mcs = 8
        o += bytes([mcs])
        comp = _lzw(fr, mcs)
        for i in range(0, len(comp), 255):
            chunk = comp[i:i+255]
            o += bytes([len(chunk)]) + chunk
        o += b"\x00"
    o += b"\x3B"
    open(path, "wb").write(o)

def main():
    forge_ranger.main()                      # (re)bake /tmp/ranger.png
    sprite = load_png("/tmp/ranger.png")
    rnd = random.Random(5)
    spores = [(rnd.uniform(12, CW-12), rnd.uniform(0, CH), rnd.uniform(0, 6.28),
               rnd.uniform(0.15, 0.4), rnd.choice([2, 2, 3]), rnd.random() < 0.18)
              for _ in range(22)]
    frames = [composite(i/FRAMES, sprite, spores) for i in range(FRAMES)]
    print("rendered %d frames, quantizing..." % FRAMES)
    pal, idx = quantize(frames)
    W, H = frames[0].w, frames[0].h
    write_gif("/tmp/ranger_idle.gif", pal, idx, W, H, 8)
    # a static filmstrip too (every other frame)
    strip = Canvas(frames[0].w*4 + 5*6, frames[0].h + 12)
    strip.rect(0, 0, strip.w-1, strip.h-1, (18, 22, 28, 255))
    for j, fi in enumerate((0, 3, 7, 10)):
        strip.blit(frames[fi], 6 + j*(frames[0].w+6), 6, mode="over")
    strip.save("/tmp/ranger_filmstrip.png")
    print("wrote /tmp/ranger_idle.gif (%dx%d, %d frames)" % (W, H, FRAMES))

if __name__ == "__main__":
    main()
