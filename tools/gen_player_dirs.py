#!/usr/bin/env python3
"""Player directional views + walk cycles — Eastward-style hand-pixel hero.

SIDE profile (facing right; mirrors for left) and BACK views, each LAYERED
(cloak / legs / upper) so they animate with a 4-phase walk: profile legs stride
fore-and-aft, back legs alternate, arms swing, the torso bobs, the cloak sways.
Joins the FRONT walk (gen_player_anim). Renders a directional turnaround + per
-direction walk GIFs (hand-written stdlib LZW).

Run:  python3 tools/gen_player_dirs.py
"""

import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402
from gen_cast import SKIN, HAIR, CLOTH, LEA, GOLD, INK, WHITE, BLUSH  # noqa: E402
import gen_player_anim as fa  # noqa: E402
import forge_anim  # noqa: E402

SK = SKIN["tan"]; HR = HAIR["brown"]
GRN = CLOTH["green"]; TR = CLOTH["slate"]; BT = CLOTH["brown"]; CRM = CLOTH["cream"]
SK_HI = (255, 238, 214, 255); EYE = (112, 146, 92, 255); MOUTH = (150, 86, 78, 255)
FW, FH = 84, 120

def E(c,cx,cy,rx,ry,col): c.ellipse(cx,cy,rx,ry,col,fill=True)
def R(c,x0,y0,x1,y1,col): c.rect(x0,y0,x1,y1,col)

# ============================ SIDE (facing right) ============================

def draw_cloak_side(c, cx, sway):
    E(c, cx-10, 72, 16, 40, GRN[4]); R(c, cx-22+sway, 50, cx-4, 104, GRN[4])
    R(c, cx-22+sway, 50, cx-19+sway, 104, GRN[3])
    for fx in (cx-16, cx-10): c.line(fx+sway, 56, fx, 102, GRN[3])
    for hx in range(cx-21, cx-3, 3): c.paint(hx+sway, 103, GRN[3])

def draw_legs_side(c, cx, phase):
    # near/far foot x-offset (stride) per phase
    near_dx, far_dx, bend = [(5,-5,0),(1,1,2),(-5,5,0),(1,1,2)][phase]
    # far leg (behind, darker)
    fx = cx + far_dx
    R(c, fx-3, 76, fx+3, 100-bend, TR[2]); R(c, fx-3, 96-bend, fx+3, 100-bend, TR[3])
    R(c, fx-4, 98-bend, fx+4, 112-bend, BT[2]); R(c, fx-5, 110-bend, fx+5, 112-bend, BT[3])
    # near leg (front, lit)
    nx = cx + near_dx
    R(c, nx-3, 76, nx+4, 100-bend, TR[1]); R(c, nx-3, 76, nx-2, 100-bend, TR[0]); R(c, nx+2, 76, nx+4, 100-bend, TR[2])
    R(c, nx-3, 96-bend, nx+4, 100-bend, TR[3])
    R(c, nx-3, 98-bend, nx+6, 112-bend, BT[1]); R(c, nx-3, 98-bend, nx-2, 112-bend, BT[0]); R(c, nx+4, 100-bend, nx+6, 112-bend, BT[2])
    R(c, nx-4, 110-bend, nx+7, 112-bend, BT[3]); c.line(nx-1, 104-bend, nx+4, 104-bend, BT[3])

def draw_upper_side(c, cx, dy, swing):
    def r(x0,y0,x1,y1,col): R(c,x0,y0+dy,x1,y1+dy,col)
    def e(x,y,rx,ry,col): E(c,x,y+dy,rx,ry,col)
    def p(x,y,col): c.paint(x,y+dy,col)
    def l(x0,y0,x1,y1,col): c.line(x0,y0+dy,x1,y1+dy,col)
    # far arm (behind) — swings opposite the near arm
    fa_v = -swing
    r(cx-3,46,cx+2,74+fa_v,GRN[3]); e(cx-1,79+fa_v,4,5,LEA[3])
    # torso (slim)
    e(cx,58,12,21,GRN[1]); r(cx-7,44,cx+8,72,GRN[1])
    r(cx-7,44,cx-5,72,GRN[3]); r(cx+5,44,cx+8,72,GRN[0]); r(cx-7,68,cx+8,72,GRN[3])
    l(cx+2,50,cx+1,62,GRN[2])
    # satchel: strap over the shoulder + bag on the back
    for i in range(20): p(cx+5-i//2,46+i,LEA[2])
    e(cx-9,60,5,7,LEA[2]); r(cx-12,56,cx-6,66,LEA[3]); p(cx-10,58,LEA[1])
    # belt
    r(cx-7,70,cx+8,75,LEA[2]); r(cx-7,70,cx+8,70,LEA[1]); r(cx-7,74,cx+8,75,LEA[4])
    r(cx+3,69,cx+7,76,GOLD[1]); p(cx+6,74,GOLD[2])
    # near arm (front) — swings
    na_v = swing
    r(cx+3,46,cx+9,72+na_v,GRN[1]); r(cx+3,46,cx+4,72+na_v,GRN[0]); r(cx+7,46,cx+9,72+na_v,GRN[2])
    r(cx+3,72+na_v,cx+9,75+na_v,LEA[2]); e(cx+6,79+na_v,5,5,LEA[1]); r(cx+3,77+na_v,cx+5,82+na_v,LEA[0])
    # ---- head (profile, facing right) ----
    r(cx+1,36,cx+6,42,SK[3])
    e(cx-1,22,11,13,SK[2]); e(cx+3,23,8,10,SK[1])              # skull + face mass
    r(cx+9,20,cx+11,30,SK[1])                                  # forward face plane (lit)
    p(cx+12,25,SK[1]); p(cx+12,26,SK[2]); p(cx+11,27,SK[3])    # nose bump
    p(cx+10,28,SK[2]); p(cx+9,29,SK[3])                        # under-nose
    e(cx+5,33,5,3,SK[2]); p(cx+8,33,SK[3])                     # jaw/chin
    l(cx-2,22,cx-5,17,SK[2]); p(cx-3,21,SK[3])                 # pointed ear (up-back)
    p(cx+8,28,BLUSH); p(cx+9,28,BLUSH)
    # eye + brow + mouth
    l(cx+6,21,cx+9,20,HR[2])                                   # brow
    r(cx+7,23,cx+9,24,WHITE); p(cx+9,23,EYE); p(cx+8,23,(56,44,40,255)); p(cx+7,23,WHITE)
    l(cx+8,30,cx+11,30,MOUTH); p(cx+9,31,(196,124,112,255))    # mouth + lit lip
    # ---- hair (crown + back fall + forward sweep + sheen) ----
    e(cx-1,12,12,9,HR[2]); r(cx-12,12,cx-8,30,HR[3])           # crown + back fall
    e(cx+6,12,6,5,HR[2]); p(cx+10,16,HR[3]); p(cx+11,17,HR[4]) # fringe sweeping forward
    e(cx-4,8,7,3,HR[1]); l(cx-9,7,cx+2,6,HR[0])                # sheen
    r(cx-12,12,cx-11,26,HR[1]); l(cx-9,14,cx-11,24,HR[4])
    l(cx+2,9,cx+6,8,HR[1])

def side_frame(phase):
    c = Canvas(FW, FH); cx = 40
    ll = [(0,0,0,0),(0,0,1,2),(0,0,0,0),(0,0,1,-2)][phase]      # (_,_,bob,swing)
    sway = [0,1,0,-1][phase]
    draw_cloak_side(c, cx, sway)
    draw_legs_side(c, cx, phase)
    draw_upper_side(c, cx, dy=-ll[2], swing=ll[3])
    c.outline(INK)
    return c

# ============================ BACK (facing away) ============================

def draw_upper_back(c, cx, dy, swing):
    def r(x0,y0,x1,y1,col): R(c,x0,y0+dy,x1,y1+dy,col)
    def e(x,y,rx,ry,col): E(c,x,y+dy,rx,ry,col)
    def p(x,y,col): c.paint(x,y+dy,col)
    e(cx,58,19,21,GRN[1]); r(cx-18,44,cx+18,72,GRN[1])
    r(cx-18,44,cx-15,72,GRN[0]); r(cx+8,44,cx+18,74,GRN[2]); r(cx+14,46,cx+18,72,GRN[3])
    r(cx-18,68,cx+18,72,GRN[3]); c.line(cx,44+dy,cx,68+dy,GRN[2])
    r(cx-18,70,cx+18,75,LEA[2]); r(cx-18,70,cx+18,70,LEA[1]); r(cx-18,74,cx+18,75,LEA[4]); r(cx-3,69,cx+3,76,GOLD[1])
    for s in (-1,1):
        ax=cx+s*19; hv=swing*s
        r(ax-4,46,ax+4,76+hv,GRN[1]); r(ax-4,46,ax-2,76+hv,GRN[0]); r(ax+2,46,ax+4,76+hv,GRN[3])
        r(ax-4,76+hv,ax+4,79+hv,LEA[2]); e(ax,83+hv,5,5,LEA[1]); r(ax-4,81+hv,ax-2,86+hv,LEA[0])
    r(cx-5,36,cx+4,42,SK[3])
    e(cx,22,14,15,HR[2]); e(cx,14,15,11,HR[2]); r(cx-15,14,cx-11,30,HR[2]); r(cx+11,14,cx+15,30,HR[3])
    r(cx-13,28,cx+12,33,HR[3])
    e(cx-5,10,9,4,HR[1]); c.line(cx-11,9+dy,cx+2,7+dy,HR[0])
    r(cx+9,14,cx+15,30,HR[4]); r(cx-15,14,cx-14,28,HR[1])
    for hx in (cx-8,cx-3,cx+2,cx+7): c.line(hx,14+dy,hx,30+dy,HR[3])

def back_frame(phase):
    c = Canvas(FW, FH); cx = 42
    ll, rl, bob, swing = fa.PHASES[phase]
    fa.draw_cloak(c, cx, hemsway=(-1 if phase==1 else (1 if phase==3 else 0)))
    fa.draw_legs(c, cx, (ll, rl))
    draw_upper_back(c, cx, dy=-bob, swing=swing)
    c.outline(INK)
    return c

# ============================ output ============================

def _walk_gif(path, frame_fn):
    comps = []
    for p in [0,1,2,3]:
        m = Canvas(60,124); m.rect(0,0,m.w-1,m.h-1,(126,160,120,255))
        m.blit(frame_fn(p), (60-FW)//2, 124-FH-2, mode="over")
        comps.append(m.scaled(3))
    pal, idx = forge_anim.quantize(comps)
    forge_anim.write_gif(path, pal, idx, comps[0].w, comps[0].h, 12)

def main():
    # turnaround (mid-stride, phase 1) across all four cardinals
    views = [fa.frame(1), side_frame(1), back_frame(1)]
    gap = 8
    m = Canvas(FW*3 + gap*4, FH + 16); m.rect(0,0,m.w-1,m.h-1,(126,160,120,255))
    for i,v in enumerate(views): m.blit(v, gap+i*(FW+gap), 8, mode="over")
    m.scaled(3).save("/tmp/player_turn.png")
    _walk_gif("/tmp/walk_side.gif", side_frame)
    _walk_gif("/tmp/walk_back.gif", back_frame)
    _walk_gif("/tmp/walk_front.gif", fa.frame)
    print("wrote turnaround + walk GIFs (front/side/back)")

if __name__ == "__main__":
    main()
