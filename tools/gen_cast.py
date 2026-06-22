#!/usr/bin/env python3
"""Teramor character generator — Eastward-style hand-authored pixel art, now
PARAMETRIZED so the whole cast shares one system (the foundation for rolling the
style across the game).

`draw_character(c, cx, opts)` builds a character from clean filled shapes, warm
colored outlines, dense 2-3 tone cel shading, and a detailed face — driven by
opts: skin tone, hair colour + style, beard, the outer cloak / tunic / trouser /
boot ramps, freckles, and age. Stdlib only (pixelforge Canvas).

Run:  python3 tools/gen_cast.py   ->  /tmp/cast.png  (a lineup)
"""

import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402

def rgb(r, g, b, a=255): return (r, g, b, a)

# ---- palettes (5 tones, 0=highlight .. 4=core shadow) ----
SKIN = {
    "fair": [rgb(252,222,190),rgb(240,200,164),rgb(222,176,138),rgb(188,140,106),rgb(150,104,80)],
    "tan":  [rgb(238,196,150),rgb(222,172,124),rgb(196,144,100),rgb(160,110,74),rgb(122,80,54)],
    "brown":[rgb(206,154,110),rgb(184,130,88),rgb(152,102,66),rgb(116,74,46),rgb(84,52,34)],
    "deep": [rgb(168,118,84),rgb(142,96,64),rgb(112,74,48),rgb(82,52,34),rgb(56,36,26)],
}
HAIR = {
    "brown":[rgb(170,122,74),rgb(142,100,58),rgb(114,78,44),rgb(88,58,32),rgb(64,42,24)],
    "black":[rgb(96,86,92),rgb(74,66,74),rgb(56,50,58),rgb(40,36,44),rgb(28,26,32)],
    "blond":[rgb(238,210,140),rgb(214,182,110),rgb(184,150,84),rgb(150,118,62),rgb(116,88,46)],
    "grey": [rgb(224,222,222),rgb(196,194,196),rgb(164,162,166),rgb(128,126,132),rgb(94,92,98)],
    "red":  [rgb(206,128,76),rgb(176,100,56),rgb(144,76,42),rgb(110,56,32),rgb(80,40,24)],
}
CLOTH = {
    "green": [rgb(150,172,116),rgb(122,146,92),rgb(98,122,72),rgb(74,98,55),rgb(54,74,42)],
    "rust":  [rgb(206,128,84),rgb(178,100,62),rgb(146,76,44),rgb(112,56,32),rgb(82,40,24)],
    "blue":  [rgb(120,150,176),rgb(94,124,152),rgb(72,100,128),rgb(54,78,104),rgb(40,58,80)],
    "plum":  [rgb(158,114,150),rgb(132,90,126),rgb(106,70,102),rgb(82,52,80),rgb(60,38,60)],
    "mustard":[rgb(214,176,96),rgb(188,148,72),rgb(156,118,54),rgb(122,90,40),rgb(90,66,30)],
    "cream": [rgb(238,224,192),rgb(214,196,160),rgb(184,166,128),rgb(150,132,100),rgb(118,102,78)],
    "slate": [rgb(136,130,146),rgb(112,106,124),rgb(88,82,102),rgb(64,60,78),rgb(46,44,58)],
    "brown": [rgb(150,116,80),rgb(124,92,60),rgb(98,70,44),rgb(72,50,30),rgb(50,34,22)],
}
LEA   = [rgb(192,148,98),rgb(162,120,74),rgb(130,94,54),rgb(100,70,40),rgb(74,50,30)]
GOLD  = [rgb(248,214,134),rgb(222,172,94),rgb(168,122,60)]
SILV  = [rgb(214,218,226),rgb(176,182,194),rgb(132,140,156)]
INK   = rgb(50,36,44)
WHITE = rgb(250,248,242)
BLUSH = rgb(230,156,136)

def ell(c,cx,cy,rx,ry,col): c.ellipse(cx,cy,rx,ry,col,fill=True)
def R(c,x0,y0,x1,y1,col): c.rect(x0,y0,x1,y1,col)

def draw_character(c, cx, opts):
    SK = SKIN[opts.get("skin","tan")]
    HR = HAIR[opts.get("hair","brown")]
    style = opts.get("hair_style","short")
    beard = opts.get("beard", False)
    OUT = CLOTH[opts["cloak"]] if opts.get("cloak") else None     # outer cloak (optional)
    TU = CLOTH[opts.get("tunic","green")]
    TR = CLOTH[opts.get("trouser","slate")]
    BT = CLOTH[opts.get("boots","brown")]
    BK = opts.get("buckle", GOLD)
    freckles = opts.get("freckles", False)
    SK_HI = rgb(min(255,SK[0][0]+8), min(255,SK[0][1]+12), min(255,SK[0][2]+14))

    # ---- cloak (optional, behind) ----
    if OUT:
        ell(c, cx, 70, 27, 42, OUT[3]); R(c, cx-25, 46, cx+25, 104, OUT[3])
        R(c, cx-25, 46, cx-22, 104, OUT[2]); R(c, cx+12, 46, cx+25, 104, OUT[4])
        for fx in (cx-17,cx-9,cx+3): c.line(fx,50,fx,102,OUT[2])
        for fx in (cx-13,cx-4,cx+8): c.line(fx,50,fx,104,OUT[4])
        for hx in range(cx-24,cx+25,3): c.paint(hx,103,OUT[2])

    # ---- legs ----
    for s in (-1,1):
        lx = cx+s*10
        R(c,lx-6,76,lx+5,100,TR[1]); R(c,lx-6,76,lx-4,100,TR[0]); R(c,lx+2,76,lx+5,100,TR[2])
        R(c,lx-6,96,lx+5,100,TR[3])
        for ky in (84,92): R(c,lx-5,ky,lx+4,ky,TR[2])
        R(c,lx-6,98,lx+5,112,BT[1]); R(c,lx-6,98,lx-4,112,BT[0]); R(c,lx+3,100,lx+5,112,BT[2])
        R(c,lx-6,98,lx+5,99,BT[0]); R(c,lx-7,110,lx+6,112,BT[3]); c.line(lx-3,104,lx+2,104,BT[3])
    R(c,cx-3,76,cx+2,100,TR[3])

    # ---- torso (tunic + belt) ----
    ell(c,cx,58,19,21,TU[1]); R(c,cx-18,44,cx+18,72,TU[1])
    R(c,cx-18,44,cx-15,72,TU[0]); R(c,cx+8,44,cx+18,74,TU[2]); R(c,cx+14,46,cx+18,72,TU[3])
    R(c,cx-18,68,cx+18,72,TU[3])
    c.line(cx-9,50,cx-5,60,TU[2]); c.line(cx+6,52,cx+3,62,TU[3]); c.line(cx-12,60,cx-9,66,TU[2])
    R(c,cx-5,42,cx+5,48,CLOTH["cream"][1]); R(c,cx-5,42,cx-3,48,CLOTH["cream"][0])
    c.line(cx-5,42,cx,48,TU[3]); c.line(cx+5,42,cx,48,TU[3])
    # satchel strap (clean, tucks under belt)
    i=0
    while True:
        sx=cx-13+i; sy=47+i
        if sy>=69: break
        c.paint(sx,sy,LEA[2]); c.paint(sx+1,sy,LEA[3])
        if i%5==0: c.paint(sx,sy,LEA[1])
        i+=1
    R(c,cx-18,70,cx+18,75,LEA[2]); R(c,cx-18,70,cx+18,70,LEA[1]); R(c,cx-18,74,cx+18,75,LEA[4])
    R(c,cx-3,69,cx+3,76,BK[1]); R(c,cx-3,69,cx+3,70,BK[0]); c.paint(cx+2,74,BK[2])

    # ---- arms (sleeves + gloves, hands below belt) ----
    for s in (-1,1):
        ax=cx+s*19
        R(c,ax-4,46,ax+4,76,TU[1]); R(c,ax-4,46,ax-2,76,TU[0]); R(c,ax+2,46,ax+4,76,TU[3])
        c.line(ax-2,54,ax-1,64,TU[2])
        R(c,ax-4,76,ax+4,79,LEA[2]); ell(c,ax,83,5,5,LEA[1]); R(c,ax-4,81,ax-2,86,LEA[0])
        c.paint(ax+3,86,LEA[3]); c.line(ax-1,81,ax-1,85,LEA[3]); c.line(ax+1,81,ax+1,85,LEA[3])

    # ---- neck + head ----
    R(c,cx-5,36,cx+4,42,SK[3]); R(c,cx-5,36,cx-3,42,SK[2])
    ell(c,cx,23,14,15,SK[2]); ell(c,cx-3,20,9,9,SK[1])
    R(c,cx-11,13,cx-3,22,SK[1]); c.paint(cx-9,15,SK[0]); c.paint(cx-8,14,SK_HI)
    R(c,cx+8,16,cx+13,32,SK[3]); R(c,cx+10,20,cx+13,30,SK[4])
    ell(c,cx,31,9,5,SK[2]); ell(c,cx,36,6,2,SK[3])
    for s in (-1,1):
        ex=cx+s*13; c.line(ex,24,ex+s*3,19,SK[2]); c.line(ex+s*1,24,ex+s*3,20,SK[3]); c.paint(ex+s*1,22,SK[1])
    for bx in (cx-9,cx-8,cx-7): c.paint(bx,28,BLUSH)
    for bx in (cx+7,cx+8,cx+9): c.paint(bx,28,BLUSH)
    if freckles:
        for fx,fy in ((cx-7,26),(cx-5,27),(cx+6,26),(cx+8,27),(cx,29)): c.paint(fx,fy,SK[3])

    # ---- face ----
    c.line(cx-9,18,cx-3,17,HR[2]); c.paint(cx-9,19,HR[3])
    c.line(cx+3,17,cx+9,18,HR[2]); c.paint(cx+9,19,HR[3])
    eyec = opts.get("eyes", rgb(112,146,92))
    for s in (-1,1):
        ox=cx+s*6
        R(c,ox-2,20,ox+1,20,SK[3]); R(c,ox-2,21,ox+1,23,WHITE)
        R(c,ox-1,21,ox+1,23,eyec); c.paint(ox,22,rgb(56,44,40)); c.paint(ox-1,21,WHITE)
        c.paint(ox-2,23,SK[3]); c.paint(ox+1,23,SK[3])
    c.paint(cx-1,24,SK[1]); c.paint(cx-1,26,SK[0]); c.paint(cx+1,26,SK[3]); c.paint(cx+1,27,SK[4]); c.paint(cx,28,SK[3])
    if beard:
        for yy in range(29,36):
            for xx in range(cx-9,cx+10):
                if (xx-cx)**2/81 + (yy-31)**2/16 <= 1.0: c.paint(xx,yy,HR[2])
        R(c,cx+5,30,cx+9,35,HR[3]); R(c,cx-2,33,cx+2,35,HR[3])
        c.line(cx-3,31,cx+3,31,rgb(150,86,78))           # mouth in the beard
    else:
        c.line(cx-3,31,cx+3,31,rgb(150,86,78)); c.paint(cx-4,30,rgb(150,86,78)); c.paint(cx+4,30,rgb(150,86,78))
        R(c,cx-2,32,cx+2,32,rgb(196,124,112))

    # ---- hair ----
    if style != "bald":
        ell(c,cx,12,15,10,HR[2])
        R(c,cx-15,12,cx-11,28,HR[2]); R(c,cx+11,12,cx+15,28,HR[3])
        ell(c,cx-8,13,5,4,HR[2]); ell(c,cx,14,5,4,HR[2]); ell(c,cx+8,13,5,4,HR[2])
        R(c,cx-10,16,cx+9,17,HR[3]); ell(c,cx+8,12,7,9,HR[3]); R(c,cx+11,11,cx+15,27,HR[4])
        ell(c,cx-5,8,8,3,HR[1]); c.line(cx-10,7,cx+1,6,HR[0]); ell(c,cx-6,8,3,2,HR[0])
        c.line(cx-4,7,cx-6,16,HR[4]); c.line(cx+4,8,cx+3,16,HR[4]); R(c,cx-15,12,cx-14,26,HR[1])
        if style == "long":
            R(c,cx-15,24,cx-11,40,HR[2]); R(c,cx+11,24,cx+15,40,HR[3])
            R(c,cx-15,24,cx-14,40,HR[1]); R(c,cx+14,24,cx+15,40,HR[4])
    else:
        R(c,cx-12,12,cx+12,15,HR[3])                     # bald: a thin ring of hair at the sides
        R(c,cx-13,15,cx-10,26,HR[2]); R(c,cx+10,15,cx+13,26,HR[3])
        c.paint(cx-6,12,SK[0]); c.paint(cx-2,11,SK_HI)   # pate catches light

    c.outline(INK, diagonal=False)


# ----------------- cast lineup -----------------
CAST = [
    {"name":"ranger", "skin":"tan",  "hair":"brown","hair_style":"short","cloak":"green",
     "tunic":"green","trouser":"slate","boots":"brown","freckles":True,"eyes":rgb(112,146,92)},
    {"name":"elder",  "skin":"fair", "hair":"grey", "hair_style":"bald", "beard":True,
     "tunic":"plum", "trouser":"brown","boots":"brown","buckle":SILV,"eyes":rgb(120,120,140)},
    {"name":"villager","skin":"brown","hair":"black","hair_style":"long","cloak":None,
     "tunic":"rust", "trouser":"slate","boots":"brown","freckles":False,"eyes":rgb(90,70,50)},
]

def main():
    cellw, cellh = 96, 130
    m = Canvas(cellw*len(CAST), cellh)
    m.rect(0,0,m.w-1,m.h-1,rgb(126,160,120))
    for i, opts in enumerate(CAST):
        sub = Canvas(84,120)
        draw_character(sub, 42, opts)
        m.blit(sub, i*cellw + (cellw-84)//2, cellh-120-4, mode="over")
    m.save("/tmp/cast.png")
    m.scaled(4).save("/tmp/cast_4x.png")
    print("wrote /tmp/cast.png (%d chars)" % len(CAST))

if __name__ == "__main__":
    main()
