#!/usr/bin/env python3
"""Teramor world art + scene mockup — Eastward-style hand-pixel.

Warm environment pieces (textured grass, dirt path, a timber-framed cottage with
a thatch roof + glowing windows, lush layered trees, fence, barrels, a signpost,
flowers) composed into a cozy Teramor clearing with the cast standing in it — the
full remastered look in one shot. Stdlib only.

Run:  python3 tools/gen_world.py  ->  /tmp/scene.png
"""

import os, sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402
from gen_cast import draw_character  # noqa: E402

def rgb(r,g,b,a=255): return (r,g,b,a)
def E(c,cx,cy,rx,ry,col): c.ellipse(cx,cy,rx,ry,col,fill=True)
def R(c,x0,y0,x1,y1,col): c.rect(x0,y0,x1,y1,col)
def L(c,x0,y0,x1,y1,col): c.line(x0,y0,x1,y1,col)

# ---- warm Eastward environment palette ----
GRASS = [rgb(148,170,108),rgb(122,148,88),rgb(100,126,70),rgb(80,104,56),rgb(60,84,44)]
DIRT  = [rgb(190,162,120),rgb(166,138,98),rgb(140,112,76),rgb(112,88,58),rgb(88,66,42)]
WOOD  = [rgb(156,116,74),rgb(128,92,56),rgb(100,70,42),rgb(74,50,30),rgb(52,34,20)]
PLAS  = [rgb(228,210,174),rgb(202,184,148),rgb(172,154,120),rgb(140,122,92)]
THAT  = [rgb(196,158,96),rgb(168,132,76),rgb(138,104,58),rgb(108,80,44),rgb(82,58,32)]
STONE = [rgb(176,170,160),rgb(146,140,130),rgb(116,110,102),rgb(88,82,76),rgb(62,58,54)]
LEAF  = [rgb(140,168,96),rgb(112,144,78),rgb(88,120,62),rgb(66,96,48),rgb(48,74,38)]
BARK  = [rgb(140,104,68),rgb(112,82,52),rgb(86,62,38),rgb(62,44,26),rgb(42,30,18)]
GLASS = [rgb(252,224,150),rgb(236,196,108),rgb(196,150,78)]   # warm lit window
FLOW  = [rgb(244,238,210),rgb(244,206,108),rgb(220,108,96),rgb(170,134,206)]
INK   = rgb(48,36,40)

def grass_fill(c, x0, y0, x1, y1, seed=1):
    rnd = random.Random(seed)
    for y in range(y0, y1):
        for x in range(x0, x1):
            t = (rnd.random()*0.6 + 0.4*((x*7+y*13) % 5)/5)
            c.paint(x, y, GRASS[1] if t < 0.5 else GRASS[2])
    for _ in range((x1-x0)*(y1-y0)//26):                       # blades + tufts
        bx = rnd.randrange(x0, x1); by = rnd.randrange(y0, y1)
        col = GRASS[0] if rnd.random()<0.5 else GRASS[3]
        c.paint(bx, by, col);
        if rnd.random()<0.4: c.paint(bx, by-1, GRASS[0])
    for _ in range((x1-x0)//14):                               # wildflowers
        fx = rnd.randrange(x0, x1); fy = rnd.randrange(y0+10, y1)
        c.paint(fx, fy, FLOW[rnd.randrange(len(FLOW))])

def dirt_path(c, cx, y0, y1, halfw, seed=4):
    rnd = random.Random(seed)
    for y in range(y0, y1):
        w = halfw + int(3*((y*5) % 4)/4) - 1
        for x in range(cx-w, cx+w):
            c.paint(x, y, DIRT[1] if (x*3+y*7)%5 else DIRT[2])
        c.paint(cx-w, y, DIRT[3]); c.paint(cx+w-1, y, DIRT[3])    # worn edges
    for _ in range((y1-y0)//3):                                 # pebbles + ruts
        px = rnd.randrange(cx-halfw+2, cx+halfw-2); py = rnd.randrange(y0, y1)
        c.paint(px, py, DIRT[0] if rnd.random()<0.5 else DIRT[3])

def tree(c, bx, by):
    # trunk with root flare
    R(c, bx-5, by-46, bx+4, by, BARK[2]); R(c, bx-5, by-46, bx-3, by, BARK[1])
    R(c, bx+2, by-46, bx+4, by, BARK[3])
    for ry in range(by-46, by, 6): L(c, bx-4, ry, bx+3, ry+2, BARK[3])   # bark grain
    R(c, bx-8, by-3, bx+7, by, BARK[3]); E(c, bx, by, 10, 3, BARK[3])    # root flare
    # layered canopy clumps (lit upper-left)
    clumps = [(bx,by-92,30,26),(bx-22,by-74,20,18),(bx+22,by-74,20,18),
              (bx-12,by-100,18,15),(bx+14,by-98,17,14),(bx,by-58,24,16)]
    for (ex,ey,rx,ry) in clumps: E(c, ex, ey, rx, ry, LEAF[3])
    for (ex,ey,rx,ry) in clumps: E(c, ex-rx//4, ey-ry//4, rx*3//4, ry*3//4, LEAF[2])
    for (ex,ey,rx,ry) in clumps: E(c, ex-rx//3, ey-ry//3, rx//2, ry//2, LEAF[1])
    rnd = random.Random(bx)
    for _ in range(70):                                         # leaf speckle + highlights
        a = rnd.uniform(0,6.28); rr = rnd.uniform(0,30)
        lx = int(bx-6 + rr*0.9*__import__('math').cos(a)); ly = int(by-86 + rr*0.7*__import__('math').sin(a))
        c.paint(lx, ly, LEAF[0] if rnd.random()<0.4 else LEAF[4])

def cottage(c, x, y):
    """x,y = bottom-left of the footprint."""
    w, wallh = 120, 86
    # stone footing
    R(c, x, y-10, x+w, y, STONE[2]); R(c, x, y-10, x+w, y-9, STONE[1]); R(c, x, y-2, x+w, y, STONE[3])
    for sx in range(x, x+w, 12): L(c, sx, y-9, sx, y-2, STONE[3])
    # plaster wall
    R(c, x, y-10-wallh, x+w, y-10, PLAS[1]); R(c, x, y-10-wallh, x+3, y-10, PLAS[0])
    R(c, x+w-3, y-10-wallh, x+w, y-10, PLAS[3])
    # timber framing (corner posts, a sill, cross-braces)
    for px in (x, x+w-5, x+w//2-2): R(c, px, y-10-wallh, px+4, y-10, WOOD[2])
    R(c, x, y-10-wallh, x+w, y-10-wallh+4, WOOD[2]); R(c, x, y-44, x+w, y-40, WOOD[2])
    L(c, x+8, y-44, x+w//2-4, y-10-wallh+4, WOOD[3]); L(c, x+w//2+6, y-10-wallh+4, x+w-10, y-44, WOOD[3])
    # door (arched, planked)
    R(c, x+14, y-46, x+34, y-10, WOOD[3]); R(c, x+14, y-46, x+34, y-44, WOOD[1])
    for dx in range(x+16, x+34, 5): L(c, dx, y-44, dx, y-12, WOOD[4])
    c.paint(x+30, y-28, rgb(40,30,22))                          # handle
    # windows (lit, framed, with cross mullions)
    for wx in (x+46, x+86):
        R(c, wx, y-40, wx+20, y-18, GLASS[1]); R(c, wx, y-40, wx+20, y-38, GLASS[0])
        R(c, wx-2, y-42, wx+22, y-40, WOOD[2]); R(c, wx-2, y-18, wx+22, y-16, WOOD[2])
        R(c, wx-2, y-42, wx, y-16, WOOD[2]); R(c, wx+20, y-42, wx+22, y-16, WOOD[2])
        L(c, wx+10, y-40, wx+10, y-18, WOOD[3]); L(c, wx, y-29, wx+20, y-29, WOOD[3])
    # thatch roof (steep, overhanging, with ridge + texture)
    ry = y-10-wallh
    for i in range(40):
        rw = (w//2+14) - i*(w//2+14)//40
        R(c, x+w//2-rw, ry-i, x+w//2+rw, ry-i, THAT[1] if i%3 else THAT[2])
    R(c, x+w//2-6, ry-40, x+w//2+6, ry-40, THAT[3])             # ridge
    rnd = random.Random(7)
    for _ in range(120):
        tx = rnd.randrange(x-12, x+w+12); ty = rnd.randrange(ry-40, ry)
        if abs(tx-(x+w//2)) < (w//2+14)-(ry-ty)*(w//2+14)//40:
            c.paint(tx, ty, THAT[0] if rnd.random()<0.4 else THAT[3])
    R(c, x-14, ry-2, x+w+14, ry+1, THAT[3])                     # eave shadow
    # chimney + smoke
    R(c, x+w-26, ry-52, x+w-16, ry-30, STONE[2]); R(c, x+w-27, ry-54, x+w-15, ry-50, STONE[3])
    for i,(sx,sy,r) in enumerate([(x+w-21,ry-60,4),(x+w-19,ry-68,5),(x+w-23,ry-76,6)]):
        E(c, sx, sy, r, r, rgb(214,210,202,170))

def barrel(c, x, y):
    R(c, x, y-18, x+12, y, WOOD[2]); R(c, x, y-18, x+2, y, WOOD[1]); R(c, x+10, y-18, x+12, y, WOOD[3])
    R(c, x, y-16, x+12, y-14, WOOD[4]); R(c, x, y-5, x+12, y-3, WOOD[4]); E(c, x+6, y-18, 6, 2, WOOD[1])

def fence(c, x0, x1, y):
    for px in range(x0, x1, 16):
        R(c, px, y-16, px+3, y, WOOD[2]); R(c, px, y-16, px+1, y, WOOD[1]); c.paint(px+1, y-16, WOOD[1])
    R(c, x0, y-13, x1, y-11, WOOD[2]); R(c, x0, y-7, x1, y-5, WOOD[2])

def signpost(c, x, y):
    R(c, x, y-30, x+3, y, WOOD[3]); R(c, x-8, y-30, x+12, y-22, WOOD[2]); R(c, x-8, y-30, x+12, y-29, WOOD[1])
    L(c, x-5, y-26, x+9, y-26, WOOD[4])

def shadow(c, cx, cy, rx, ry=None):
    ry = ry or max(2, rx//3)
    for y in range(int(cy-ry), int(cy+ry)+1):
        for x in range(int(cx-rx), int(cx+rx)+1):
            dx=(x-cx)/rx; dy=(y-cy)/ry
            if dx*dx+dy*dy <= 1.0: c.over(x, y, rgb(28,36,26,70))

def scene():
    W, H = 460, 300
    c = Canvas(W, H)
    grass_fill(c, 0, 0, W, H, seed=3)
    dirt_path(c, 250, 150, H, 34)                              # path down to the foreground
    dirt_path(c, 250, 150, 152, 60)
    for yy in range(150, 153):                                 # path bend toward the cottage
        for x in range(120, 250): c.paint(x, yy + (250-x)//20, DIRT[1])
    # back trees (with ground shadows)
    shadow(c, 70, 150, 14); tree(c, 70, 150)
    shadow(c, 410, 165, 14); tree(c, 410, 165)
    shadow(c, 170, 196, 60, 12); cottage(c, 110, 196)
    fence(c, 280, 440, 250)
    shadow(c, 242, 211, 9); barrel(c, 236, 210); barrel(c, 250, 212)
    signpost(c, 300, 260)
    shadow(c, 430, 270, 16); tree(c, 430, 270)                 # foreground tree (right)
    # characters standing in the clearing
    casts = [
        ({"skin":"tan","hair":"brown","hair_style":"short","cloak":"green","tunic":"green",
          "trouser":"slate","freckles":True}, 250, 250),
        ({"skin":"fair","hair":"red","hair_style":"long","cloak":"green","tunic":"green",
          "trouser":"brown","freckles":True}, 330, 268),
        ({"skin":"brown","hair":"black","hair_style":"short","build":"stout","tunic":"rust",
          "apron":"cream","trouser":"slate"}, 180, 240),
    ]
    for opts, px, py in casts:
        shadow(c, px, py-2, 18, 6)
        sub = Canvas(84, 120); draw_character(sub, 42, opts)
        c.blit(sub, px-42, py-112, mode="over")
    return c

def main():
    s = scene()
    s.save("/tmp/scene.png"); s.scaled(2).save("/tmp/scene_2x.png")
    print("wrote /tmp/scene.png")

if __name__ == "__main__":
    main()
