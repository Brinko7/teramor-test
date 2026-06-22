#!/usr/bin/env python3
"""Player directional views — Eastward-style hand-pixel hero: SIDE profile + BACK,
to join the existing FRONT (gen_player_anim). Builds a 3-view turnaround so the
hero faces all four cardinals (side mirrors for left/right).

Run:  python3 tools/gen_player_dirs.py  ->  /tmp/player_turn.png
"""

import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelforge import Canvas  # noqa: E402
from gen_cast import SKIN, HAIR, CLOTH, LEA, GOLD, INK, WHITE, BLUSH  # noqa: E402
import gen_player_anim as fa  # noqa: E402  (front view)

SK = SKIN["tan"]; HR = HAIR["brown"]
GRN = CLOTH["green"]; TR = CLOTH["slate"]; BT = CLOTH["brown"]; CRM = CLOTH["cream"]
SK_HI = (255, 238, 214, 255)
EYE = (112, 146, 92, 255); MOUTH = (150, 86, 78, 255)
FW, FH = 84, 120

def E(c,cx,cy,rx,ry,col): c.ellipse(cx,cy,rx,ry,col,fill=True)
def R(c,x0,y0,x1,y1,col): c.rect(x0,y0,x1,y1,col)

# ============================ SIDE (facing right) ============================

def side():
    c = Canvas(FW, FH); cx = 40
    # cloak streaming behind (to the left)
    E(c, cx-10, 72, 16, 40, GRN[4]); R(c, cx-22, 50, cx-4, 104, GRN[4])
    R(c, cx-22, 50, cx-19, 104, GRN[3])
    for fx in (cx-16, cx-10): c.line(fx, 56, fx, 102, GRN[3])
    for hx in range(cx-21, cx-3, 3): c.paint(hx, 103, GRN[3])
    # ---- legs (profile: near leg front, far leg back) ----
    # far leg (behind, darker)
    R(c, cx-5, 76, cx+1, 100, TR[2]); R(c, cx-5, 96, cx+1, 100, TR[3])
    R(c, cx-6, 98, cx+2, 112, BT[2]); R(c, cx-7, 110, cx+3, 112, BT[3])
    # near leg (front)
    R(c, cx+1, 76, cx+7, 100, TR[1]); R(c, cx+1, 76, cx+2, 100, TR[0]); R(c, cx+5, 76, cx+7, 100, TR[2])
    R(c, cx+1, 96, cx+7, 100, TR[3])
    R(c, cx+1, 98, cx+9, 112, BT[1]); R(c, cx+1, 98, cx+2, 112, BT[0]); R(c, cx+7, 100, cx+9, 112, BT[2])
    R(c, cx, 110, cx+10, 112, BT[3]); c.line(cx+2, 104, cx+7, 104, BT[3])   # toe forward
    # ---- torso (slim profile, chest toward the right) ----
    E(c, cx, 58, 12, 21, GRN[1]); R(c, cx-7, 44, cx+8, 72, GRN[1])
    R(c, cx-7, 44, cx-5, 72, GRN[3]); R(c, cx+5, 44, cx+8, 72, GRN[0])   # back dark, chest lit
    R(c, cx-7, 68, cx+8, 72, GRN[3])
    c.line(cx+2, 50, cx+1, 62, GRN[2])                                   # chest fold
    # belt
    R(c, cx-7, 70, cx+8, 75, LEA[2]); R(c, cx-7, 70, cx+8, 70, LEA[1]); R(c, cx-7, 74, cx+8, 75, LEA[4])
    R(c, cx+3, 69, cx+7, 76, GOLD[1]); c.paint(cx+6, 74, GOLD[2])
    # satchel strap over the shoulder + the bag on the back
    for i in range(20): c.paint(cx+5-i//2, 46+i, LEA[2]);
    E(c, cx-9, 60, 5, 7, LEA[2]); R(c, cx-12, 56, cx-6, 66, LEA[3]); c.paint(cx-10, 58, LEA[1])  # satchel bag
    # ---- far arm (behind, darker) ----
    R(c, cx-3, 46, cx+2, 74, GRN[3]); E(c, cx-1, 80, 4, 5, LEA[3])
    # ---- near arm (front, swinging forward) ----
    R(c, cx+3, 46, cx+9, 72, GRN[1]); R(c, cx+3, 46, cx+4, 72, GRN[0]); R(c, cx+7, 46, cx+9, 72, GRN[2])
    R(c, cx+3, 72, cx+9, 75, LEA[2]); E(c, cx+6, 79, 5, 5, LEA[1]); R(c, cx+3, 77, cx+5, 82, LEA[0])
    # ---- neck + head (profile, face right) ----
    R(c, cx+1, 36, cx+6, 42, SK[3])
    E(c, cx-1, 22, 11, 13, SK[2])                       # skull (back-shifted)
    E(c, cx+3, 24, 8, 10, SK[1])                        # face/cheek toward the right
    R(c, cx+9, 22, cx+11, 30, SK[1])                    # forward face plane
    c.paint(cx+12, 25, SK[1]); c.paint(cx+12, 26, SK[2]); c.paint(cx+11, 27, SK[3])  # nose bump
    E(c, cx+5, 33, 5, 3, SK[2])                         # chin/jaw
    # pointed ear (mid-head, up-back)
    c.line(cx-2, 22, cx-5, 17, SK[2]); c.paint(cx-3, 21, SK[3])
    c.paint(cx+8, 28, BLUSH); c.paint(cx+9, 28, BLUSH)  # cheek blush
    # eye (one, looking right) + brow + mouth
    R(c, cx+6, 21, cx+8, 21, HR[2])                     # brow
    R(c, cx+7, 23, cx+9, 24, WHITE); c.paint(cx+9, 23, EYE); c.paint(cx+8, 23, (56,44,40,255))
    c.line(cx+8, 30, cx+11, 30, MOUTH)                  # mouth
    # ---- hair (covers crown + back, sweeps right over the brow) ----
    E(c, cx-1, 12, 12, 9, HR[2]); R(c, cx-12, 12, cx-8, 30, HR[3])      # back fall
    E(c, cx+5, 11, 6, 5, HR[2])                         # fringe sweeping forward
    c.paint(cx+9, 17, HR[3])                            # tuft over the brow
    E(c, cx-4, 8, 7, 3, HR[1]); c.line(cx-9, 7, cx, 6, HR[0])           # sheen
    R(c, cx-12, 12, cx-11, 26, HR[1]); c.line(cx-9, 14, cx-11, 24, HR[4])
    c.outline(INK)
    return c

# ============================ BACK (facing away) ============================

def back():
    c = Canvas(FW, FH); cx = 42
    fa.draw_cloak(c, cx, 0)
    fa.draw_legs(c, cx, (0, 0))
    # upper body from behind: tunic back (no collar V / face), arms, belt
    R(c, cx-18, 44, cx+18, 72, GRN[1]); E(c, cx, 58, 19, 21, GRN[1])
    R(c, cx-18, 44, cx-15, 72, GRN[0]); R(c, cx+8, 44, cx+18, 74, GRN[2]); R(c, cx+14, 46, cx+18, 72, GRN[3])
    R(c, cx-18, 68, cx+18, 72, GRN[3]); c.line(cx, 45, cx, 68, GRN[2])   # back seam
    R(c, cx-18, 70, cx+18, 75, LEA[2]); R(c, cx-18, 70, cx+18, 70, LEA[1]); R(c, cx-18, 74, cx+18, 75, LEA[4])
    R(c, cx-3, 69, cx+3, 76, GOLD[1])
    for s in (-1, 1):
        ax = cx + s*19
        R(c, ax-4, 46, ax+4, 76, GRN[1]); R(c, ax-4, 46, ax-2, 76, GRN[0]); R(c, ax+2, 46, ax+4, 76, GRN[3])
        R(c, ax-4, 76, ax+4, 79, LEA[2]); E(c, ax, 83, 5, 5, LEA[1]); R(c, ax-4, 81, ax-2, 86, LEA[0])
    # neck + back of head (all hair, no face)
    R(c, cx-5, 36, cx+4, 42, SK[3])
    E(c, cx, 22, 14, 15, HR[2])                         # back of head = hair
    E(c, cx, 14, 15, 11, HR[2]); R(c, cx-15, 14, cx-11, 30, HR[2]); R(c, cx+11, 14, cx+15, 30, HR[3])
    R(c, cx-13, 28, cx+12, 33, HR[3])                   # nape hairline
    E(c, cx-5, 10, 9, 4, HR[1]); c.line(cx-11, 9, cx+2, 7, HR[0])       # crown sheen
    R(c, cx+9, 14, cx+15, 30, HR[4]); R(c, cx-15, 14, cx-14, 28, HR[1])
    for hx in (cx-8, cx-3, cx+2, cx+7): c.line(hx, 14, hx, 30, HR[3])   # strand seams
    c.outline(INK)
    return c

def main():
    front = fa.frame(0)
    views = [("front", front), ("side", side()), ("back", back())]
    gap = 8
    m = Canvas(FW*3 + gap*4, FH + 16)
    m.rect(0, 0, m.w-1, m.h-1, (126, 160, 120, 255))
    for i, (_, v) in enumerate(views):
        m.blit(v, gap + i*(FW+gap), 8, mode="over")
    m.scaled(3).save("/tmp/player_turn.png")
    print("wrote /tmp/player_turn.png")

if __name__ == "__main__":
    main()
