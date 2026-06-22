#!/usr/bin/env python3
"""Tiny stdlib GIF encoder for animation previews: quantize RGBA Canvas frames to
a shared 256-colour palette and write a looping GIF with a hand-rolled LZW coder
(round-trip verified). Used by the animated sprite previews. No dependencies.
"""

def quantize(frames):
    """frames: Canvas-likes with .buf (RGBA bytes), .w, .h -> (palette, [indices])."""
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
        if j is not None:
            return j
        best, bd = 0, 1e18
        for k, pc in enumerate(pal):
            d = (c[0]-pc[0])**2 + (c[1]-pc[1])**2 + (c[2]-pc[2])**2
            if d < bd:
                bd = d; best = k
            if d == 0:
                break
        cache[c] = best
        return best
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
    if nb > 0:
        out.append(buf & 0xFF)
    return out

def write_gif(path, pal, frames_idx, w, h, delay_cs):
    o = bytearray(b"GIF89a")
    o += w.to_bytes(2, "little") + h.to_bytes(2, "little") + bytes([0xF7, 0, 0])
    for c in pal:
        o += bytes(c)
    o += b"\x21\xFF\x0BNETSCAPE2.0\x03\x01\x00\x00\x00"
    for fr in frames_idx:
        o += bytes([0x21, 0xF9, 0x04, 0x04]) + delay_cs.to_bytes(2, "little") + b"\x00\x00"
        o += b"\x2C" + (0).to_bytes(2, "little") + (0).to_bytes(2, "little")
        o += w.to_bytes(2, "little") + h.to_bytes(2, "little") + bytes([0, 8])
        comp = _lzw(fr, 8)
        for i in range(0, len(comp), 255):
            chunk = comp[i:i+255]
            o += bytes([len(chunk)]) + chunk
        o += b"\x00"
    o += b"\x3B"
    open(path, "wb").write(o)
