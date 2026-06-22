#!/usr/bin/env python3
"""Teramor enemies — Eastward-style hand-pixel.

Humanoid foes reuse the character rig (gen_cast.draw_character) with rougher
options + meaner faces (hoods, scars, angled brows, the blight-corrupted Withered
with hollow glowing eyes). The beasts — wolf and bear — are fresh side-view
quadruped drawings. Stdlib only.

Run:  python3 tools/gen_enemies.py  ->  /tmp/enemies.png
"""

import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402
from gen_cast import draw_character, INK  # noqa: E402

def rgb(r,g,b,a=255): return (r,g,b,a)
def E(c,cx,cy,rx,ry,col): c.ellipse(cx,cy,rx,ry,col,fill=True)
def R(c,x0,y0,x1,y1,col): c.rect(x0,y0,x1,y1,col)

# fur ramps (0=highlight..4=shadow)
WOLF = [rgb(156,156,162),rgb(126,128,136),rgb(100,102,112),rgb(76,78,90),rgb(54,56,68)]
BEAR = [rgb(132,98,66),rgb(108,78,50),rgb(84,60,38),rgb(62,44,28),rgb(44,30,20)]
GLOW = rgb(150,235,150)

# ============================ BEASTS (side, facing right) ============================

def draw_wolf(c, cx, cy, fur=WOLF, glow=None):
    # tail (bushy, back-left)
    E(c, cx-19, cy+1, 6, 4, fur[3]); E(c, cx-22, cy+3, 4, 3, fur[4])
    # far legs (behind, darker)
    for lxr in (cx-9, cx+11):
        R(c, lxr-2, cy+5, lxr+1, cy+22, fur[3]); R(c, lxr-2, cy+20, lxr+2, cy+24, fur[4])
    # body
    E(c, cx, cy, 19, 9, fur[2]); E(c, cx, cy-2, 18, 7, fur[1])     # back lit
    E(c, cx-8, cy+2, 9, 7, fur[2]); E(c, cx+10, cy+1, 8, 7, fur[2])  # haunch + chest
    R(c, cx-16, cy+3, cx+15, cy+7, fur[3])                          # belly shadow
    # near legs (front, lit)
    for lxr in (cx-12, cx+13):
        R(c, lxr-2, cy+5, lxr+2, cy+23, fur[2]); R(c, lxr-2, cy+5, lxr-1, cy+23, fur[1])
        R(c, lxr-3, cy+21, lxr+3, cy+25, fur[3])                    # paw
    # neck + head (front-right)
    E(c, cx+15, cy-4, 6, 7, fur[2])
    E(c, cx+22, cy-7, 7, 6, fur[1])                                 # head
    R(c, cx+27, cy-6, cx+33, cy-2, fur[2])                          # snout
    c.paint(cx+33, cy-4, INK); c.paint(cx+33, cy-3, fur[4])         # nose
    # ears
    c.line(cx+18, cy-12, cx+20, cy-7, fur[2]); c.line(cx+24, cy-12, cx+25, cy-7, fur[3])
    # eye
    if glow:
        c.paint(cx+24, cy-6, glow); c.paint(cx+25, cy-6, rgb(220,255,200))
    else:
        c.paint(cx+24, cy-6, INK); c.paint(cx+23, cy-6, rgb(220,210,160))
    # fur tufts along the back
    for tx in range(cx-12, cx+10, 4): c.paint(tx, cy-9, fur[3])
    c.outline(INK)

def draw_bear(c, cx, cy, fur=BEAR, glow=None):
    for lxr in (cx-10, cx+12):                                      # far legs
        R(c, lxr-3, cy+6, lxr+2, cy+26, fur[3]); R(c, lxr-4, cy+24, lxr+3, cy+29, fur[4])
    # bulky body
    E(c, cx, cy, 23, 13, fur[2]); E(c, cx-2, cy-3, 20, 9, fur[1])
    E(c, cx-12, cy+3, 11, 10, fur[2]); E(c, cx+13, cy+1, 11, 11, fur[2])
    R(c, cx-19, cy+5, cx+18, cy+10, fur[3])
    for lxr in (cx-14, cx+15):                                      # near legs (thick)
        R(c, lxr-3, cy+7, lxr+3, cy+27, fur[2]); R(c, lxr-3, cy+7, lxr-2, cy+27, fur[1])
        R(c, lxr-4, cy+25, lxr+4, cy+30, fur[3])
        for px in range(lxr-3, lxr+3, 2): c.paint(px, cy+29, fur[4])  # claws
    # head (lower, big)
    E(c, cx+20, cy-2, 9, 8, fur[1]); R(c, cx+27, cy, cx+33, cy+5, fur[2])   # snout
    c.paint(cx+33, cy+2, INK)
    E(c, cx+15, cy-9, 3, 3, fur[2]); E(c, cx+24, cy-9, 3, 3, fur[2])        # round ears
    if glow:
        c.paint(cx+22, cy-1, glow); c.paint(cx+19, cy-1, glow)
    else:
        c.paint(cx+22, cy-1, INK); c.paint(cx+19, cy-1, INK)
    c.outline(INK)

# ============================ humanoid enemies ============================

ENEMIES = [
    {"name":"Bandit","skin":"tan","hair":"black","cloak":"brown","hood":True,"tunic":"brown",
     "trouser":"slate","menace":True,"scar":True,"eyes":rgb(80,60,46)},
    {"name":"Brute","skin":"tan","hair":"black","hair_style":"bald","build":"stout","tunic":"rust",
     "trouser":"slate","menace":True,"scar":True,"beard":True,"eyes":rgb(80,60,46)},
    {"name":"Archer","skin":"fair","hair":"brown","cloak":"green","hood":True,"tunic":"brown",
     "trouser":"brown","menace":True,"eyes":rgb(90,110,80)},
    {"name":"Withered","skin":"ashen","hair":"matted","hair_style":"long","tunic":"slate",
     "trouser":"slate","glow_eyes":GLOW,"menace":True,"eyes":GLOW},
]

def main():
    cols = 6; cw, ch = 92, 128
    m = Canvas(cw*cols, ch); m.rect(0,0,m.w-1,m.h-1,(120,150,116,255))
    for i,opts in enumerate(ENEMIES):
        sub = Canvas(84,120); draw_character(sub, 42, opts)
        m.blit(sub, i*cw+(cw-84)//2, (ch-120)-2, mode="over")
    # beasts in the last two cells
    wolf = Canvas(84,120); draw_wolf(wolf, 38, 64); m.blit(wolf, 4*cw+(cw-84)//2, (ch-120)-2, mode="over")
    bear = Canvas(84,120); draw_bear(bear, 36, 60); m.blit(bear, 5*cw+(cw-84)//2, (ch-120)-2, mode="over")
    m.save("/tmp/enemies.png"); m.scaled(3).save("/tmp/enemies_3x.png")
    print("wrote /tmp/enemies.png")

if __name__ == "__main__":
    main()
