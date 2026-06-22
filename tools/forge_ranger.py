#!/usr/bin/env python3
"""Teramor hero key-art: the Hooded Child of Tera. Bold cel-shaded pixel art.

Art direction (story-rooted): a half-elf ranger of the Greenward, face shadowed
under a deep hood save for eyes lit with warm Tera-sap GOLD -- the one warm glow
against the cold-green Blight. Grounded earth palette, one emissive accent.

Pipeline: sculpt with metaballs (continuous body), light it, then QUANTIZE to a
tight punchy ramp per material (hard cel bands), ink SELOUT the silhouette, a cool
moonlit RIM, and an additive BLOOM on the emissive gold. Stdlib only.

Run:  python3 tools/forge_ranger.py   ->  /tmp/ranger.png (+ 4x)
"""

import math
import random
import struct
import zlib

SS = 3
OW, OH = 110, 166
W, H = OW * SS, OH * SS
BAYER = [[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]]

def vnorm(v):
    x, y, z = v; m = math.sqrt(x*x+y*y+z*z) or 1.0; return (x/m, y/m, z/m)
def dot(a, b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
def clamp(v, a, b): return a if v < a else (b if v > b else v)
def smoothstep(e0, e1, x):
    t = clamp((x-e0)/(e1-e0) if e1 != e0 else 0.0, 0, 1); return t*t*(3-2*t)

def _h(x, y, s):
    n = (x*374761393 + y*668265263 + s*1442695040888963407) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0
def vnoise(x, y, s=0):
    xi, yi = int(math.floor(x)), int(math.floor(y)); xf, yf = x-xi, y-yi
    u = xf*xf*(3-2*xf); v = yf*yf*(3-2*yf)
    a=_h(xi,yi,s); b=_h(xi+1,yi,s); c=_h(xi,yi+1,s); d=_h(xi+1,yi+1,s)
    return (a*(1-u)+b*u)*(1-v)+(c*(1-u)+d*u)*v

# ---- cel ramps (light -> dark): warm, saturated lights -> COOL desaturated
# shadows (deliberate hue-shift), high contrast for a moody, carved read. ----
RAMPS = {
    "cloak":   [(132,152,100),(88,116,76),(54,84,60),(33,57,48),(19,35,36)],
    "cloak_d": [(100,120,78),(66,92,60),(42,66,50),(26,46,40),(14,28,30)],
    "leather": [(182,128,74),(134,90,50),(92,58,34),(57,38,28),(31,24,26)],
    "leather_d":[(132,90,52),(96,62,36),(64,41,26),(41,28,22),(22,18,22)],
    "tunic":   [(108,144,128),(72,108,96),(46,80,74),(29,54,54),(16,34,40)],
    "skin":    [(242,200,160),(204,154,116),(150,103,78),(101,68,58),(58,42,48)],
    "wood":    [(184,136,82),(136,94,54),(92,60,34),(58,39,26),(33,25,24)],
    "metal":   [(216,224,236),(162,172,190),(108,120,144),(68,80,106),(40,50,76)],
    "string":  [(224,220,204),(150,148,138),(90,92,90),(50,54,58)],
    "fletch":  [(156,214,200),(108,168,154),(72,122,112),(46,84,78)],   # teal feathers (cool 2nd accent)
}
EMIT = {  # emissive accents (ignore lighting; feed the bloom)
    "eye":  (255, 214, 132),
    "rune": (255, 182, 92),
    "gemt": (118, 228, 204),     # cool teal gem in the leaf-clasp (secondary accent)
}
HILIGHT = (236, 240, 224)    # crisp lit-edge lip
SELOUT = (20, 17, 24)        # cool-dark ink
RIM = (150, 190, 220)        # cool moonlight back-rim
EYE_GLOW = (255, 206, 120)   # warm light the eyes cast on the face
EMIT_MATS = set(EMIT)

R2 = 2.89; ISO = 0.45

class Field:
    def __init__(s, w, h):
        s.w, s.h = w, h; n = w*h
        s.dens=[0.0]*n; s.hsum=[0.0]*n; s.wsum=[0.0]*n
        s.mat=[None]*n; s.mc=[0.0]*n
        s.hgt=[-1e9]*n; s.cov=[0.0]*n; s.aoc=[0.0]*n
    def ellipsoid(s, cx, cy, cz, rx, ry, rz, mat):
        cx*=SS; cy*=SS; cz*=SS; rx*=SS; ry*=SS; rz*=SS
        infx=rx*1.7; infy=ry*1.7
        x0=max(0,int(cx-infx-1)); x1=min(s.w-1,int(cx+infx+1))
        y0=max(0,int(cy-infy-1)); y1=min(s.h-1,int(cy+infy+1))
        for y in range(y0, y1+1):
            for x in range(x0, x1+1):
                ux=(x+0.5-cx)/rx; uy=(y+0.5-cy)/ry; d2=ux*ux+uy*uy
                if d2>=R2: continue
                t=1.0-d2/R2; contrib=t*t
                hi=cz+rz*math.sqrt(max(0.0,1.0-min(1.0,d2)))
                i=y*s.w+x
                s.dens[i]+=contrib; s.hsum[i]+=hi*contrib; s.wsum[i]+=contrib
                if contrib>s.mc[i]: s.mc[i]=contrib; s.mat[i]=mat
    def capsule(s, p0, p1, r0, r1, mat):
        (ax,ay,az),(bx,by,bz)=p0,p1
        steps=int(max(abs(bx-ax),abs(by-ay))*SS*1.3)+3
        for k in range(steps+1):
            t=k/steps
            s.ellipsoid(ax+(bx-ax)*t, ay+(by-ay)*t, az+(bz-az)*t,
                        r0+(r1-r0)*t, r0+(r1-r0)*t, r0+(r1-r0)*t, mat)
    def finalize(s):
        for i in range(s.w*s.h):
            if s.dens[i]<=0: continue
            s.cov[i]=smoothstep(ISO-0.1, ISO+0.1, s.dens[i])
            if s.wsum[i]>0: s.hgt[i]=s.hsum[i]/s.wsum[i]
    def crease(s, x, y, r, amt):
        x*=SS; y*=SS; r*=SS
        for yy in range(max(0,int(y-r)),min(s.h,int(y+r)+1)):
            for xx in range(max(0,int(x-r)),min(s.w,int(x+r)+1)):
                i=yy*s.w+xx
                if s.cov[i]<=0: continue
                d=math.hypot(xx-x,yy-y)/r
                if d<1: s.aoc[i]=max(s.aoc[i],(1-d)*amt)

KEY=vnorm((-0.5,-0.62,0.6)); FILL=vnorm((0.66,0.12,0.5))
BACK=vnorm((0.18,-0.55,-0.4))      # cool moon, high and behind -> rim
NSTR=0.62/SS; AMB=0.19
cx_g = OW/2.0

def normal_at(f, x, y):
    w=f.w; i=y*w+x
    hl=f.hgt[i-1] if x>0 and f.cov[i-1]>0 else f.hgt[i]
    hr=f.hgt[i+1] if x<w-1 and f.cov[i+1]>0 else f.hgt[i]
    hu=f.hgt[i-w] if y>0 and f.cov[i-w]>0 else f.hgt[i]
    hd=f.hgt[i+w] if y<f.h-1 and f.cov[i+w]>0 else f.hgt[i]
    return vnorm((-(hr-hl)*0.5*NSTR, -(hd-hu)*0.5*NSTR, 1.0))

def _cel(lum, n, x, y):
    """Map luminance to a band, Bayer-dithering the boundary between the two
    nearest bands for that hand-made pixel-art gradient."""
    cont = (1.0 - clamp(lum, 0.0, 1.0)) * (n - 1)
    lo = int(cont); frac = cont - lo
    thr = BAYER[y & 3][x & 3] / 16.0
    idx = lo + (1 if frac > thr else 0)
    return clamp(idx, 0, n - 1)

def shade(f, x, y):
    i=y*f.w+x; m=f.mat[i]
    if m in EMIT_MATS:
        return EMIT[m], True
    N=normal_at(f,x,y)
    ndl=max(0.0,dot(N,KEY)); ndf=max(0.0,dot(N,FILL))
    tex=0.0
    if m in ("cloak","leather","tunic","cloak_d","leather_d"):
        tex=(vnoise(x/SS*0.7,y/SS*0.7, 5)-0.5)*0.07
    lum=AMB + 0.86*ndl + 0.14*ndf + tex
    lum*=(1.0-f.aoc[i])
    ramp=RAMPS[m]
    col=ramp[_cel(lum,len(ramp),x,y)]
    # crisp lit-edge lip where a strongly key-facing surface meets the silhouette
    fres=(1.0-max(0.0,N[2]))
    if ndl>0.82 and fres>0.34:
        col=HILIGHT
    # cool moonlit back-rim along the shadow-side silhouette (pops off the dark)
    rim=fres*max(0.0,dot(N,BACK))
    if rim>0.30 and ndl<0.7:
        col=RIM
    # the gold gaze casts warm light onto the upper face below it
    if m=="skin" and getattr(f,"eyes",None):
        for (ex,ey) in f.eyes:
            d=math.hypot((x-ex*SS), (y-ey*SS))/(7.0*SS)
            if d<1.0 and y>=ey*SS-2:
                g=(1.0-d)*0.55
                col=(clamp(col[0]+EYE_GLOW[0]*g*0.5,0,255),
                     clamp(col[1]+EYE_GLOW[1]*g*0.45,0,255),
                     clamp(col[2]+EYE_GLOW[2]*g*0.3,0,255))
    return col, False

def build():
    f=Field(W,H); cx=cx_g
    # --- cape BEHIND, wind-swept to one side: a clasp-at-the-neck mantle that
    # billows out and flicks a lit tail (drama + a person-shaped silhouette) ---
    f.ellipsoid(cx+2, 72, -16, 14, 40, 6, "cloak_d")
    f.ellipsoid(cx+8, 118, -15, 14, 32, 6, "cloak_d")
    f.ellipsoid(cx+18, 150, -13, 9, 16, 6, "cloak")               # flicked tail (catches light)
    # --- quiver of arrows slung over the right shoulder (teal fletching) ---
    f.capsule((cx+12, 86, -7), (cx+16, 58, -7), 4.0, 3.4, "leather_d")   # quiver body (behind)
    for ai in range(3):
        ax=cx+12+ai*2.4
        f.capsule((ax, 56, -3), (ax+6, 28, -3), 0.9, 0.8, "wood")        # arrow shaft
        f.ellipsoid(ax+6, 28, -1, 1.7, 2.8, 1.4, "fletch")              # fletching
        f.ellipsoid(ax+6.5, 23, -1, 1.1, 1.8, 1.2, "fletch")
    # --- legs (longer, heroic stance) ---
    for s in (-1,1):
        hx=cx+s*9
        f.capsule((hx,96,0),(hx+s*2,134,0), 7.5, 5.5, "leather_d")  # thigh/wrap
        f.capsule((hx+s*2,132,0),(hx+s*3,154,0), 6, 4.5, "leather") # boot
        f.ellipsoid(hx+s*3,157,4, 6.5,4.5,6, "leather")            # foot
    # --- torso: tunic + a leather chest harness, belt ---
    f.ellipsoid(cx, 66, 0, 17, 14, 10, "tunic")
    f.ellipsoid(cx, 64, 5, 15, 12, 10, "leather")                  # chest piece
    f.ellipsoid(cx, 82, 3, 14, 8, 9, "leather_d")                  # belt/abdomen
    f.ellipsoid(cx, 86, 7, 4, 2.6, 3, "metal")                     # buckle
    f.ellipsoid(cx-11, 88, 6, 3.6, 4.2, 3, "leather_d")            # belt pouch (left hip)
    # --- shoulders + cloak clasp + arms ---
    for s in (-1,1):
        f.ellipsoid(cx+s*16, 54, 2, 9, 8, 8, "cloak")              # cloak over shoulders
        f.capsule((cx+s*16,58,1),(cx+s*19,82,1), 6, 5, "tunic")    # upper arm
        f.capsule((cx+s*19,80,1),(cx+s*21,100,2), 5, 4, "leather") # bracer
        f.ellipsoid(cx+s*20, 90, 5, 1.1, 1.1, 1.1, "metal")        # bracer stud
        f.ellipsoid(cx+s*22,103,3, 4.5,4.5,4, "skin")              # hand
    # leaf-shaped cloak clasp (two leaf halves + a teal gem set in emissive)
    f.ellipsoid(cx-2, 50, 8, 2.4, 3.4, 2, "metal")
    f.ellipsoid(cx+2, 50, 8, 2.4, 3.4, 2, "metal")
    f.ellipsoid(cx, 49, 9, 1.5, 1.7, 1.4, "metal")
    # --- neck + head, recessed so the hood shadows it ---
    f.ellipsoid(cx, 44, 3, 4.5, 4, 4, "skin")
    f.ellipsoid(cx, 33, 6, 9, 11, 7, "skin")                       # face (sits inside hood)
    f.ellipsoid(cx, 36, 8, 7, 7, 5, "skin")                        # face front plane
    # pointed half-elf ears at the hood's edge (catch the cool rim)
    for s in (-1,1):
        f.ellipsoid(cx+s*9, 35, 7, 1.8, 3.2, 2.0, "skin")
        f.ellipsoid(cx+s*10, 31, 7, 1.0, 2.2, 1.4, "skin")         # pointed tip
    # --- the HOOD: a tighter cowl framing the shadowed face ---
    f.ellipsoid(cx, 29, 2, 11.5, 13, 8, "cloak")                   # hood mass
    f.ellipsoid(cx-1, 18, 0, 6, 9, 7, "cloak_d")                  # peaked crown
    f.ellipsoid(cx-11, 37, 3, 4.5, 10, 6, "cloak")                # hood side falls
    f.ellipsoid(cx+11, 37, 3, 4.5, 10, 6, "cloak")
    # --- a longbow of living wood, held at the left, tall vertical silhouette ---
    for k in range(0, 80):
        t=k/79.0; yy=32+t*106
        bend=math.sin(t*math.pi)*2.6
        f.ellipsoid(cx-23-bend, yy, 4, 1.3, 1.9, 1.6, "wood")
    f.capsule((cx-23, 33, 6), (cx-23, 138, 6), 0.6, 0.6, "string")   # bowstring
    return f

def detail(f):
    cx=cx_g
    # the hood throws the face into near-black so the gold gaze is the only light
    f.crease(cx, 30, 9.5, 0.88)
    f.crease(cx, 34, 7, 0.82)
    f.crease(cx, 40, 4, 0.55)
    f.crease(cx-13, 70, 6, 0.3); f.crease(cx+13, 70, 6, 0.3)
    # cloak drape folds + bracer straps (fabric/leather detail)
    f.crease(cx+7, 104, 4, 0.24); f.crease(cx+13, 134, 5, 0.26)
    f.crease(cx-3, 116, 4, 0.2); f.crease(cx+2, 150, 5, 0.22)
    f.crease(cx-21, 92, 3, 0.26); f.crease(cx+21, 92, 3, 0.26)

def _stamp(f, cx, cy, r, mat):
    for yy in range(int((cy-r)*SS), int((cy+r)*SS)+1):
        for xx in range(int((cx-r)*SS), int((cx+r)*SS)+1):
            if not (0<=xx<f.w and 0<=yy<f.h) or f.cov[yy*f.w+xx]<=0: continue
            if math.hypot(xx-cx*SS, yy-cy*SS) <= r*SS:
                f.mat[yy*f.w+xx]=mat

def emissive(f):
    cx=cx_g
    # the Tera-sap eyes: two distinct gold lamps under the cowl
    f.eyes=[(cx-4.0,33),(cx+4.0,33)]
    for s in (-1,1):
        _stamp(f, cx+s*4.0, 33, 1.3, "eye")
    _stamp(f, cx, 49.5, 1.1, "gemt")            # teal gem in the leaf-clasp
    # a rune-pendant at the chest
    _stamp(f, cx, 64, 1.8, "rune")
    # glowing sap veins running up the living-wood bow
    for k in range(6):
        t=k/5.0; yy=46+t*64
        bend=math.sin(t*math.pi)*6.0
        _stamp(f, cx-24-bend, yy, 0.8, "rune")

# ---------- render: cel base + selout + bloom ----------

def render(f):
    base=[None]*(f.w*f.h); emit=[False]*(f.w*f.h)
    for y in range(f.h):
        for x in range(f.w):
            i=y*f.w+x
            if f.cov[i]<=0: continue
            c,e=shade(f,x,y); base[i]=c; emit[i]=e
    # downsample to OW/OH (coverage-weighted) into float buffers
    accl=[0.0]*(OW*OH*4); glow=[0.0]*(OW*OH*3)
    for y in range(f.h):
        oy=y//SS
        for x in range(f.w):
            i=y*f.w+x
            if base[i] is None: continue
            a=f.cov[i]; j=(oy*OW+x//SS)*4
            c=base[i]
            accl[j]+=c[0]*a; accl[j+1]+=c[1]*a; accl[j+2]+=c[2]*a; accl[j+3]+=a
            if emit[i]:
                g=(oy*OW+x//SS)*3
                glow[g]+=c[0]; glow[g+1]+=c[1]; glow[g+2]+=c[2]
    px=bytearray(OW*OH*4); samp=SS*SS
    for k in range(OW*OH):
        wsum=accl[k*4+3]
        if wsum<=0: continue
        px[k*4]=int(clamp(accl[k*4]/wsum,0,255))
        px[k*4+1]=int(clamp(accl[k*4+1]/wsum,0,255))
        px[k*4+2]=int(clamp(accl[k*4+2]/wsum,0,255))
        px[k*4+3]=int(clamp(wsum/samp*255,0,255))
    _selout(px)
    _bloom(px, glow)
    return px

def _selout(px):
    def op(x,y): return 0<=x<OW and 0<=y<OH and px[(y*OW+x)*4+3]>40
    snap=[px[(y*OW+x)*4+3] for y in range(OH) for x in range(OW)]
    def opS(x,y): return 0<=x<OW and 0<=y<OH and snap[y*OW+x]>40
    for y in range(OH):
        for x in range(OW):
            if opS(x,y): continue
            if opS(x-1,y) or opS(x+1,y) or opS(x,y-1) or opS(x,y+1):
                k=(y*OW+x)*4
                px[k]=SELOUT[0]; px[k+1]=SELOUT[1]; px[k+2]=SELOUT[2]; px[k+3]=255

def _bloom(px, glow):
    # blur the emissive buffer (separable box, a few px) and screen-add
    tmp=[0.0]*(OW*OH*3)
    rad=3
    for c in range(3):
        for y in range(OH):
            for x in range(OW):
                acc=0.0; n=0
                for dx in range(-rad,rad+1):
                    xx=x+dx
                    if 0<=xx<OW: acc+=glow[(y*OW+xx)*3+c]; n+=1
                tmp[(y*OW+x)*3+c]=acc/max(1,n)
    glow2=[0.0]*(OW*OH*3)
    for c in range(3):
        for y in range(OH):
            for x in range(OW):
                acc=0.0; n=0
                for dy in range(-rad,rad+1):
                    yy=y+dy
                    if 0<=yy<OH: acc+=tmp[(yy*OW+x)*3+c]; n+=1
                glow2[(y*OW+x)*3+c]=acc/max(1,n)
    for k in range(OW*OH):
        a=px[k*4+3]
        for c in range(3):
            g=glow2[k*3+c]*1.55
            base=px[k*4+c]
            v=255-(255-base)*(255-min(255,g))/255.0     # screen blend
            px[k*4+c]=int(clamp(v,0,255))
        gs=glow2[k*3]+glow2[k*3+1]+glow2[k*3+2]
        if a<=40 and gs>18:
            px[k*4]=int(clamp(255*0.55+px[k*4]*0.45,0,255))
            px[k*4+1]=int(clamp(190*0.55+px[k*4+1]*0.45,0,255))
            px[k*4+2]=int(clamp(110*0.55+px[k*4+2]*0.45,0,255))
            px[k*4+3]=int(clamp(gs/3*2.0,0,210))

def save_png(path, px, w, h):
    raw=bytearray()
    for y in range(h): raw.append(0); raw+=px[y*w*4:(y+1)*w*4]
    comp=zlib.compress(bytes(raw),9)
    def ch(t,d): return struct.pack(">I",len(d))+t+d+struct.pack(">I",zlib.crc32(t+d)&0xffffffff)
    out=b"\x89PNG\r\n\x1a\n"+ch(b"IHDR",struct.pack(">IIBBBBB",w,h,8,6,0,0,0))+ch(b"IDAT",comp)+ch(b"IEND",b"")
    open(path,"wb").write(out)

def upscale(px,w,h,n):
    out=bytearray(w*n*h*n*4)
    for y in range(h):
        for x in range(w):
            p=px[(y*w+x)*4:(y*w+x)*4+4]
            for yy in range(n):
                row=((y*n+yy)*w*n+x*n)*4
                for xx in range(n): out[row+xx*4:row+xx*4+4]=p
    return out

def main():
    f=build(); detail(f); f.finalize(); emissive(f)
    px=render(f)
    save_png("/tmp/ranger.png", px, OW, OH)
    save_png("/tmp/ranger_4x.png", upscale(px,OW,OH,4), OW*4, OH*4)
    print("wrote /tmp/ranger.png (%dx%d)"%(OW,OH))

if __name__=="__main__":
    main()
