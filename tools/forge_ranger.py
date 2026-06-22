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

SS = 2
OW, OH = 104, 148
W, H = OW * SS, OH * SS

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

# ---- punchy cel ramps (light -> dark), hand-tuned, hue-shifted by eye ----
RAMPS = {
    "cloak":   [(104,126,86),(74,100,62),(52,76,46),(34,54,34),(22,38,24)],
    "cloak_d": [(74,96,62),(52,74,46),(36,54,34),(24,40,26),(16,28,18)],
    "leather": [(158,110,64),(122,82,46),(92,58,34),(64,40,22),(42,26,15)],
    "leather_d":[(116,80,46),(88,58,34),(64,40,24),(44,28,16),(28,18,11)],
    "tunic":   [(96,128,114),(68,100,88),(48,76,66),(33,55,48),(22,38,33)],
    "skin":    [(236,194,156),(198,152,116),(156,112,82),(112,78,56),(76,50,36)],
    "wood":    [(168,124,74),(128,90,52),(92,62,34),(62,40,22),(40,26,14)],
    "metal":   [(206,212,222),(156,164,178),(110,118,134),(72,80,96),(48,54,68)],
    "string":  [(210,206,190),(150,146,132),(96,94,84),(60,58,52)],
}
EMIT = {  # emissive accents (ignore lighting; feed the bloom)
    "eye":  (255, 206, 120),
    "rune": (255, 178, 86),
}
SELOUT = (22, 17, 16)
RIM = (150, 186, 196)        # cool moonlight
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

KEY=vnorm((-0.5,-0.62,0.6)); FILL=vnorm((0.7,0.1,0.45))
NSTR=0.62/SS; AMB=0.28
cx_g = OW/2.0

def normal_at(f, x, y):
    w=f.w; i=y*w+x
    hl=f.hgt[i-1] if x>0 and f.cov[i-1]>0 else f.hgt[i]
    hr=f.hgt[i+1] if x<w-1 and f.cov[i+1]>0 else f.hgt[i]
    hu=f.hgt[i-w] if y>0 and f.cov[i-w]>0 else f.hgt[i]
    hd=f.hgt[i+w] if y<f.h-1 and f.cov[i+w]>0 else f.hgt[i]
    return vnorm((-(hr-hl)*0.5*NSTR, -(hd-hu)*0.5*NSTR, 1.0))

def cel_index(lum, n):
    # bold banding with a tighter highlight step
    lum = clamp(lum, 0.0, 1.12)
    if lum > 1.0: return 0
    return clamp(int((1.0 - lum/1.0) * (n - 0.001)), 0, n-1)

def shade(f, x, y):
    i=y*f.w+x; m=f.mat[i]
    if m in EMIT_MATS:
        return EMIT[m], True
    N=normal_at(f,x,y)
    ndl=max(0.0,dot(N,KEY)); ndf=max(0.0,dot(N,FILL))
    tex=0.0
    if m in ("cloak","leather","tunic","cloak_d","leather_d"):
        tex=(vnoise(x/SS*0.7,y/SS*0.7, 5)-0.5)*0.10
    lum=AMB + 0.82*ndl + 0.16*ndf + tex
    lum*=(1.0-f.aoc[i])
    ramp=RAMPS[m]
    col=ramp[cel_index(lum,len(ramp))]
    # crisp rim band on the moonlit edge
    fres=(1.0-max(0.0,N[2]))
    if fres>0.5 and (N[0]*KEY[0]+N[1]*KEY[1])>0.0 and ndl<0.6:
        col=RIM
    return col, False

def build():
    f=Field(W,H); cx=cx_g
    # --- cape BEHIND only (narrower than the body, so the silhouette reads as a
    # person with a cape, not a teardrop): a clasp-at-the-neck mantle falling back ---
    f.ellipsoid(cx, 70, -16, 15, 38, 6, "cloak_d")
    f.ellipsoid(cx, 108, -16, 21, 26, 6, "cloak_d")
    # --- legs ---
    for s in (-1,1):
        hx=cx+s*9
        f.capsule((hx,96,0),(hx+s*1,128,0), 8, 6, "leather_d")     # trouser/wrap
        f.capsule((hx+s*1,126,0),(hx+s*2,144,0), 6.5, 5, "leather")# boot
        f.ellipsoid(hx+s*2,147,4, 6.5,4.5,6, "leather")            # foot
    # --- torso: tunic + a leather chest harness, belt ---
    f.ellipsoid(cx, 66, 0, 17, 14, 10, "tunic")
    f.ellipsoid(cx, 64, 5, 15, 12, 10, "leather")                  # chest piece
    f.ellipsoid(cx, 82, 3, 14, 8, 9, "leather_d")                  # belt/abdomen
    f.ellipsoid(cx, 86, 7, 4, 2.6, 3, "metal")                     # buckle
    # --- shoulders + cloak clasp + arms ---
    for s in (-1,1):
        f.ellipsoid(cx+s*16, 54, 2, 9, 8, 8, "cloak")              # cloak over shoulders
        f.capsule((cx+s*16,58,1),(cx+s*19,82,1), 6, 5, "tunic")    # upper arm
        f.capsule((cx+s*19,80,1),(cx+s*21,100,2), 5, 4, "leather") # bracer
        f.ellipsoid(cx+s*22,103,3, 4.5,4.5,4, "skin")              # hand
    f.ellipsoid(cx, 50, 8, 4, 3, 3, "metal")                       # leaf clasp (metal)
    # --- neck + head, recessed so the hood shadows it ---
    f.ellipsoid(cx, 44, 3, 4.5, 4, 4, "skin")
    f.ellipsoid(cx, 33, 6, 9, 11, 7, "skin")                       # face (sits inside hood)
    f.ellipsoid(cx, 36, 8, 7, 7, 5, "skin")                        # face front plane
    # --- the HOOD: a tighter cowl framing the shadowed face ---
    f.ellipsoid(cx, 29, 2, 11.5, 13, 8, "cloak")                   # hood mass
    f.ellipsoid(cx-1, 18, 0, 6, 9, 7, "cloak_d")                  # peaked crown
    f.ellipsoid(cx-11, 37, 3, 4.5, 10, 6, "cloak")                # hood side falls
    f.ellipsoid(cx+11, 37, 3, 4.5, 10, 6, "cloak")
    # --- a longbow of living wood, held at the left, tall vertical silhouette ---
    for k in range(0, 70):
        t=k/69.0; yy=34+t*80
        bend=math.sin(t*math.pi)*6.5
        f.ellipsoid(cx-24-bend, yy, 4, 1.5, 1.9, 1.7, "wood")
    f.capsule((cx-24, 36, 6), (cx-24, 112, 6), 0.7, 0.7, "string")   # bowstring
    return f

def detail(f):
    cx=cx_g
    # the hood throws the face into deep shadow so the gold gaze blazes out of it
    f.crease(cx, 31, 10, 0.72)
    f.crease(cx-4, 33, 4, 0.6); f.crease(cx+4, 33, 4, 0.6)
    f.crease(cx, 40, 4, 0.45)
    f.crease(cx-13, 70, 6, 0.3); f.crease(cx+13, 70, 6, 0.3)

def _stamp(f, cx, cy, r, mat):
    for yy in range(int((cy-r)*SS), int((cy+r)*SS)+1):
        for xx in range(int((cx-r)*SS), int((cx+r)*SS)+1):
            if not (0<=xx<f.w and 0<=yy<f.h) or f.cov[yy*f.w+xx]<=0: continue
            if math.hypot(xx-cx*SS, yy-cy*SS) <= r*SS:
                f.mat[yy*f.w+xx]=mat

def emissive(f):
    cx=cx_g
    # the Tera-sap eyes: two distinct gold lamps under the cowl
    for s in (-1,1):
        _stamp(f, cx+s*4.2, 33, 1.0, "eye")
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
