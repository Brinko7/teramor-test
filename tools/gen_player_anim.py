#!/usr/bin/env python3
"""Animated player rig — Eastward-style hand-pixel hero, front-facing WALK cycle.

The foundation for the remaster's character animation: the figure is drawn in
LAYERS (cloak / legs / upper body) so a walk phase can move the legs + arms and
bob the torso independently. 4-phase cycle ([0,1,0,2] like the engine). Renders a
walk sheet + a looping GIF (hand-written stdlib LZW, reused from forge_anim).

Run:  python3 tools/gen_player_anim.py  ->  /tmp/player_walk.gif (+ sheet)
"""

import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402
from gen_cast import SKIN, HAIR, CLOTH, LEA, GOLD, INK, WHITE, BLUSH  # noqa: E402
import forge_anim  # noqa: E402  (GIF encoder)

SK = SKIN["tan"]; HR = HAIR["brown"]
GRN = CLOTH["green"]; TR = CLOTH["slate"]; BT = CLOTH["brown"]
SK_HI = (255, 238, 214, 255)
FW, FH = 84, 120

def _R(c): return lambda x0,y0,x1,y1,col: c.rect(x0,y0,x1,y1,col)
def _E(c): return lambda cx,cy,rx,ry,col: c.ellipse(cx,cy,rx,ry,col,fill=True)

# ---------- layers ----------

def draw_cloak(c, cx, hemsway):
    R=_R(c); E=_E(c)
    E(cx,70,27,42,GRN[3]); R(cx-25,46,cx+25,104,GRN[3])
    R(cx-25,46,cx-22,104,GRN[2]); R(cx+12,46,cx+25,104,GRN[4])
    for fx in (cx-17,cx-9,cx+3): c.line(fx,50,fx,102,GRN[2])
    for fx in (cx-13,cx-4,cx+8): c.line(fx,50,fx,104+min(0,hemsway),GRN[4])
    for hx in range(cx-24,cx+25,3): c.paint(hx+hemsway,103,GRN[2])   # hem sways

def draw_legs(c, cx, lifts):
    R=_R(c)
    for s, lift in ((-1, lifts[0]), (1, lifts[1])):
        lx = cx + s*10
        bot = 100 - lift
        R(lx-6,76,lx+5,bot,TR[1]); R(lx-6,76,lx-4,bot,TR[0]); R(lx+2,76,lx+5,bot,TR[2])
        R(lx-6,bot-4,lx+5,bot,TR[3])
        for ky in (84,92):
            if ky < bot-2: R(lx-5,ky-lift,lx+4,ky-lift,TR[2])
        fb = 112 - lift
        R(lx-6,bot,lx+5,fb,BT[1]); R(lx-6,bot,lx-4,fb,BT[0]); R(lx+3,bot+2,lx+5,fb,BT[2])
        R(lx-6,bot,lx+5,bot+1,BT[0]); R(lx-7,fb-2,lx+6,fb,BT[3]); c.line(lx-3,fb-8,lx+2,fb-8,BT[3])
    R(cx-3,76,cx+2,98,TR[3])

def draw_upper(c, cx, dy, swing):
    """Torso + belt + arms + head + face + hair, shifted up by `dy`; arms swing."""
    def R(x0,y0,x1,y1,col): c.rect(x0,y0+dy,x1,y1+dy,col)
    def E(cx2,cy,rx,ry,col): c.ellipse(cx2,cy+dy,rx,ry,col,fill=True)
    def P(x,y,col): c.paint(x,y+dy,col)
    def L(x0,y0,x1,y1,col): c.line(x0,y0+dy,x1,y1+dy,col)
    # torso
    E(cx,58,19,21,GRN[1]); R(cx-18,44,cx+18,72,GRN[1])
    R(cx-18,44,cx-15,72,GRN[0]); R(cx+8,44,cx+18,74,GRN[2]); R(cx+14,46,cx+18,72,GRN[3])
    R(cx-18,68,cx+18,72,GRN[3])
    L(cx-9,50,cx-5,60,GRN[2]); L(cx+6,52,cx+3,62,GRN[3]); L(cx-12,60,cx-9,66,GRN[2])
    R(cx-5,42,cx+5,48,CLOTH["cream"][1]); R(cx-5,42,cx-3,48,CLOTH["cream"][0])
    L(cx-5,42,cx,48,GRN[3]); L(cx+5,42,cx,48,GRN[3])
    i=0
    while True:
        sx=cx-13+i; sy=47+i
        if sy>=69: break
        P(sx,sy,LEA[2]); P(sx+1,sy,LEA[3])
        if i%5==0: P(sx,sy,LEA[1])
        i+=1
    R(cx-18,70,cx+18,75,LEA[2]); R(cx-18,70,cx+18,70,LEA[1]); R(cx-18,74,cx+18,75,LEA[4])
    R(cx-3,69,cx+3,76,GOLD[1]); R(cx-3,69,cx+3,70,GOLD[0]); P(cx+2,74,GOLD[2])
    # arms (swing: each hand shifts by ±swing)
    for s in (-1,1):
        ax=cx+s*19; hv = swing*s
        R(ax-4,46,ax+4,76+hv,GRN[1]); R(ax-4,46,ax-2,76+hv,GRN[0]); R(ax+2,46,ax+4,76+hv,GRN[3])
        L(ax-2,54,ax-1,64,GRN[2])
        R(ax-4,76+hv,ax+4,79+hv,LEA[2]); E(ax,83+hv,5,5,LEA[1]); R(ax-4,81+hv,ax-2,86+hv,LEA[0])
        P(ax+3,86+hv,LEA[3]); L(ax-1,81+hv,ax-1,85+hv,LEA[3]); L(ax+1,81+hv,ax+1,85+hv,LEA[3])
    # neck + head
    R(cx-5,36,cx+4,42,SK[3]); R(cx-5,36,cx-3,42,SK[2])
    E(cx,23,14,15,SK[2]); E(cx-3,20,9,9,SK[1])
    R(cx-11,13,cx-3,22,SK[1]); P(cx-9,15,SK[0]); P(cx-8,14,SK_HI)
    R(cx+8,16,cx+13,32,SK[3]); R(cx+10,20,cx+13,30,SK[4])
    E(cx,31,9,5,SK[2]); E(cx,36,6,2,SK[3])
    for s in (-1,1):
        ex=cx+s*13; L(ex,24,ex+s*3,19,SK[2]); L(ex+s*1,24,ex+s*3,20,SK[3]); P(ex+s*1,22,SK[1])
    for bx in (cx-9,cx-8,cx-7): P(bx,28,BLUSH)
    for bx in (cx+7,cx+8,cx+9): P(bx,28,BLUSH)
    for fx,fy in ((cx-7,26),(cx-5,27),(cx+6,26),(cx+8,27),(cx,29)): P(fx,fy,SK[3])
    # face
    L(cx-9,18,cx-3,17,HR[2]); P(cx-9,19,HR[3]); L(cx+3,17,cx+9,18,HR[2]); P(cx+9,19,HR[3])
    for s in (-1,1):
        ox=cx+s*6
        R(ox-2,20,ox+1,20,SK[3]); R(ox-2,21,ox+1,23,WHITE)
        R(ox-1,21,ox+1,23,(112,146,92,255)); P(ox,22,(56,44,40,255)); P(ox-1,21,WHITE)
        P(ox-2,23,SK[3]); P(ox+1,23,SK[3])
    P(cx-1,24,SK[1]); P(cx-1,26,SK[0]); P(cx+1,26,SK[3]); P(cx+1,27,SK[4]); P(cx,28,SK[3])
    L(cx-3,31,cx+3,31,(150,86,78,255)); P(cx-4,30,(150,86,78,255)); P(cx+4,30,(150,86,78,255))
    R(cx-2,32,cx+2,32,(196,124,112,255))
    # hair
    E(cx,12,15,10,HR[2]); R(cx-15,12,cx-11,28,HR[2]); R(cx+11,12,cx+15,28,HR[3])
    E(cx-8,13,5,4,HR[2]); E(cx,14,5,4,HR[2]); E(cx+8,13,5,4,HR[2])
    R(cx-10,16,cx+9,17,HR[3]); E(cx+8,12,7,9,HR[3]); R(cx+11,11,cx+15,27,HR[4])
    E(cx-5,8,8,3,HR[1]); L(cx-10,7,cx+1,6,HR[0]); E(cx-6,8,3,2,HR[0])
    L(cx-4,7,cx-6,16,HR[4]); L(cx+4,8,cx+3,16,HR[4]); R(cx-15,12,cx-14,26,HR[1])

# 4-phase walk: (left_lift, right_lift, body_bob, arm_swing)
PHASES = [
    (0, 0, 0,  0),    # contact
    (0, 3, 1, -1),    # passing (right leg up, body rises)
    (0, 0, 0,  0),    # contact
    (3, 0, 1,  1),    # passing (left leg up)
]

def frame(phase):
    c = Canvas(FW, FH); cx = 42
    ll, rl, bob, swing = PHASES[phase]
    draw_cloak(c, cx, hemsway=(-1 if phase==1 else (1 if phase==3 else 0)))
    draw_legs(c, cx, (ll, rl))
    draw_upper(c, cx, dy=-bob, swing=swing)
    c.outline(INK, diagonal=False)
    return c

def main():
    seq = [0, 1, 2, 3]
    frames = [frame(p) for p in seq]
    # static sheet
    sheet = Canvas(FW*4 + 5*4, FH + 8)
    sheet.rect(0,0,sheet.w-1,sheet.h-1,(126,160,120,255))
    for i,f in enumerate(frames):
        sheet.blit(f, 4 + i*(FW+4), 4, mode="over")
    sheet.scaled(3).save("/tmp/player_walk_sheet.png")
    # animated GIF (composite each frame on the green bg, scaled)
    comps = []
    for p in [0,1,2,3]:
        m = Canvas(60, 124); m.rect(0,0,m.w-1,m.h-1,(126,160,120,255))
        m.blit(frame(p), (60-FW)//2, 124-FH-2, mode="over")
        comps.append(m.scaled(3))
    pal, idx = forge_anim.quantize(comps)
    forge_anim.write_gif("/tmp/player_walk.gif", pal, idx, comps[0].w, comps[0].h, 12)
    print("wrote /tmp/player_walk.gif + sheet")

if __name__ == "__main__":
    main()
