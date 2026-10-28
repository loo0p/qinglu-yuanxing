# lib5 compositor (python reference implementation for the gate)
import cv2, numpy as np, json, os, glob, random
from reg import register
D=os.environ.get('LIB5_DIR', os.path.dirname(os.path.abspath(__file__))); SRC=D+'/src'; PARTS=D+'/parts'
from anchors import REG
AN=json.load(open(D+'/anchors.json')); META=json.load(open(PARTS+'/parts.json'))
H,W=1152,864
F_BASES=['base_f','base_f2','base_f3','base_f4','base_f5']; M_BASES=['base_m','base_m2','base_m3','base_m4','base_m5']
ELDER={'base_fe':'f','base_me':'m'}
_cache={}
def img(p):
    if p not in _cache: _cache[p]=cv2.imread(p)
    return _cache[p]
def reg_edit(name):
    key='reg:'+name
    if key not in _cache:
        cp=f'{D}/cache/{name}.png'
        if os.path.exists(cp): _cache[key]=cv2.imread(cp)
        else:
            base=name.split('@')[1]; w,*_=register(img(f'{SRC}/{base}.jpg'),img(f'{SRC}/{name}.jpg'))
            os.makedirs(D+'/cache',exist_ok=True); cv2.imwrite(cp,w); _cache[key]=w
    return _cache[key]

# ---------- feature library ----------
def feature_lib():
    lib={'f':{r:[] for r in ('eyes','brows','nose','mouth')},'m':{r:[] for r in ('eyes','brows','nose','mouth')}}
    for b in F_BASES+M_BASES:
        sx=b[5]
        for r in lib[sx]: lib[sx][r].append(dict(id=f'{r}:{b}',src=('base',b),anchor=b))
    for p in sorted(glob.glob(SRC+'/fx_*@*.jpg'))+sorted(glob.glob(SRC+'/eyes_*@*.jpg'))+sorted(glob.glob(SRC+'/eyesC_*@*.jpg')):
        n=os.path.basename(p)[:-4]; base=n.split('@')[1]; sx=base[5]
        if base in ELDER: continue
        regs=('eyes',) if n.startswith('eyes_') or n.startswith('eyesC_') or n.startswith('fx_m2c') else ('eyes','brows','nose','mouth')
        if n.startswith('eyes_demon') or n.startswith('eyes_cold'): regs=('eyes','brows')
        for r in regs:
            lib[sx][r].append(dict(id=f'{r}:{n}',src=('edit',n),anchor=base))
    # closed partners (same source pair) -> enables closed + half-closed
    HALF={}
    CLOSED={'eyes:base_f':'eyes:eyes_closed@base_f','eyes:base_m':'eyes:eyes_closed@base_m','eyes:fx_m2@base_m':'eyes:fx_m2c@base_m'}
    for p in sorted(glob.glob(SRC+'/eyesC_*@*.jpg')):
        n=os.path.basename(p)[:-4]; src=n[len('eyesC_'):].split('@')[0]; base=n.split('@')[1]
        if base in ELDER:
            lib.setdefault('elder',{}).setdefault(base,{})['closed']=dict(id=f'eyes:{n}',src=('edit',n),anchor=base)
            continue
        CLOSED['eyes:'+src if src.startswith('base_') else f'eyes:{src}@{base}']=f'eyes:{n}'
    # real half-closed frames (eyesH_*): not pool entries, only blink frames for their open eye
    for p in sorted(glob.glob(SRC+'/eyesH_*@*.jpg')):
        n=os.path.basename(p)[:-4]; src=n[len('eyesH_'):].split('@')[0]; base=n.split('@')[1]
        ent=dict(id=f'eyes:{n}',src=('edit',n),anchor=base)
        if base in ELDER:
            lib.setdefault('elder',{}).setdefault(base,{})['half']=ent; continue
        HALF['eyes:'+src if src.startswith('base_') else f'eyes:{src}@{base}']=ent
    # elder feature variants (brows+mouth only, on their own head)
    for p in sorted(glob.glob(SRC+'/fx_*e*@base_*e.jpg')):
        n=os.path.basename(p)[:-4]; base=n.split('@')[1]
        if base not in ELDER: continue
        for r in ('brows','mouth'):
            lib.setdefault('elder',{}).setdefault(base,{}).setdefault(r,[]).append(dict(id=f'{r}:{n}',src=('edit',n),anchor=base))
    return lib,CLOSED,HALF
LIB,CLOSED,HALF=feature_lib()
CLOSED_IDS=set(CLOSED.values())
def src_img(e):
    t,n=e['src']; return img(f'{SRC}/{n}.jpg') if t=='base' else reg_edit(n)
def ellipse_mask(shape,cx,cy,rx,ry,feather=6):
    m=np.zeros(shape[:2],np.uint8); cv2.ellipse(m,(int(cx),int(cy)),(int(rx),int(ry)),0,0,360,255,-1)
    return m
def feat_union(base):
    m=np.zeros((H,W),np.uint8)
    for r in ('brows','eyes','nose','mouth'):
        x,y,s,_=AN[base][r]; x0,y0,x1,y1=REG[r]
        cv2.ellipse(m,(int(x),int(y)),(int((x1-x0)/2*s+10),int((y1-y0)/2*s+10)),0,0,360,255,-1)
    return m
def skin_low(im,mask,k=4):
    x0,y0,w,h=cv2.boundingRect(mask); pad=60
    X0,Y0=max(0,x0-pad),max(0,y0-pad); X1,Y1=min(W,x0+w+pad),min(H,y0+h+pad)
    sub=im[Y0:Y1,X0:X1]; ms=mask[Y0:Y1,X0:X1]
    sm=cv2.resize(sub,None,fx=1/k,fy=1/k,interpolation=cv2.INTER_AREA)
    mm=(cv2.resize(ms,(sm.shape[1],sm.shape[0]),interpolation=cv2.INTER_NEAREST)>0).astype(np.uint8)
    mm=cv2.dilate(mm,np.ones((3,3),np.uint8))
    f=cv2.inpaint(sm,mm*255,5,cv2.INPAINT_TELEA)
    f=cv2.GaussianBlur(f.astype(np.float32),(0,0),2.5)
    up=cv2.resize(f,(X1-X0,Y1-Y0),interpolation=cv2.INTER_CUBIC)
    out=cv2.GaussianBlur(im.astype(np.float32),(0,0),12); out[Y0:Y1,X0:X1]=up
    return out
def paste_feature(canvas, base, e, region, mix_with=None, mix=0.0, patch=False):
    S=src_img(e).astype(np.float32)
    if mix_with is not None: S=S*(1-mix)+src_img(mix_with).astype(np.float32)*mix
    sa=AN[e['anchor']][region]; ta=AN[base][region]
    s=ta[2]/sa[2]
    M=np.float32([[s,0,ta[0]-s*sa[0]],[0,s,ta[1]-s*sa[1]]])
    warped=cv2.warpAffine(S,M,(W,H),flags=cv2.INTER_CUBIC,borderMode=cv2.BORDER_REPLICATE).clip(0,255).astype(np.uint8)
    x0,y0,x1,y1=REG[region]; rx=(x1-x0)/2*ta[2]; ry=(y1-y0)/2*ta[2]
    cy_off=0
    if region=='brows': ry*=1.12; cy_off=-6
    if region=='eyes': ry*=0.92 if mix_with is None else 1.1  # closed/half: also cover the open upper lid line
    if region=='eyes' and mix_with is not None: rx*=1.04
    if region=='mouth': rx*=1.12; ry*=1.3
    hard=ellipse_mask(canvas.shape,ta[0],ta[1]+cy_off,rx,ry)
    m=cv2.GaussianBlur(hard.astype(np.float32)/255.,(0,0),5)[...,None]
    if region=='brows':
        # never let a brow patch repaint the eyes: its source's open eyes would show through blinks
        ea=AN[base]['eyes']; ex0,ey0,ex1,ey1=REG['eyes']
        em=ellipse_mask(canvas.shape,ea[0],ea[1],(ex1-ex0)/2*ea[2]*1.04,(ey1-ey0)/2*ea[2]*1.1)
        m=m*(1-cv2.GaussianBlur(em.astype(np.float32)/255.,(0,0),4)[...,None])
    Wf=warped.astype(np.float32); Cf=canvas.astype(np.float32)
    big=ellipse_mask(canvas.shape,ta[0],ta[1]+cy_off,rx+14,ry+14)
    # skin-only low frequency: fill the feature area from its surroundings, so neither
    # the target's own eyes nor the source's ink leak in as low-frequency ghosts
    fm=feat_union(base)
    out=Wf-skin_low(warped,big|fm)+skin_low(canvas,big|fm)
    if patch: return out.clip(0,255), m[...,0]
    return (Cf*(1-m)+out*m).clip(0,255).astype(np.uint8)

# ---------- layered parts ----------
def load_part(key):
    p=cv2.imread(f'{PARTS}/{key}.png',cv2.IMREAD_UNCHANGED).astype(np.float32); r=META[key]
    full=np.zeros((H,W,4),np.float32); x,y=r['pos']; h,w=p.shape[:2]; full[y:y+h,x:x+w]=p
    if r.get('kind')=='hair': full[...,3]*=1-eye_guard(full, key.split('@')[1])
    return full
def eye_guard(L, hb):
    """hair edits often redraw the eyes (liner, lashes, open eyes); those pixels ride on the hair
       layer and would hide the chosen eye type and every blink.  Mask the source head's eye band,
       keeping only dark strands that enter it from outside (bangs)."""
    ea=AN[hb]['eyes']; x0,y0,x1,y1=REG['eyes']; rx=(x1-x0)/2*ea[2]*1.12; ry=(y1-y0)/2*ea[2]*1.45
    band=np.zeros((H,W),np.uint8); cv2.ellipse(band,(int(ea[0]),int(ea[1])),(int(rx),int(ry)),0,0,360,255,-1)
    Lp=L[...,:3].mean(2); dark=((Lp<110)&(L[...,3]>80)).astype(np.uint8)
    n,lab,st,_=cv2.connectedComponentsWithStats(dark,8)
    inside=band>0; keep=np.zeros((H,W),np.float32)
    if n>1:
        out_cnt=np.bincount(lab[~inside].ravel(),minlength=n)
        ok=out_cnt>400; ok[0]=False
        keep=ok[lab].astype(np.float32)
        keep=cv2.GaussianBlur(cv2.dilate(keep,np.ones((3,3),np.uint8)),(0,0),1.0)
    g=cv2.GaussianBlur(band.astype(np.float32)/255.,(0,0),5)
    # the eyes themselves: always cleared, bangs or not (a strand over an eyeball is rarely wanted)
    s=ea[2]; hard=np.zeros((H,W),np.uint8)
    for dx in (-61,61): cv2.ellipse(hard,(int(ea[0]+dx*s),int(ea[1])),(int(44*s),int(21*s)),0,0,360,255,-1)
    hard=cv2.GaussianBlur(hard.astype(np.float32)/255.,(0,0),3)
    return np.maximum(g*(1-keep),hard)
def skull_M(src,dst):
    a=AN[src]['skull']; b=AN[dst]['skull']
    s=(b['right']-b['left'])/(a['right']-a['left']); cxa=(a['left']+a['right'])/2; cxb=(b['left']+b['right'])/2
    return np.float32([[s,0,cxb-s*cxa],[0,s,b['top']-s*a['top']]])
_skin={}
def skin_mask(base):
    if base not in _skin:
        B=img(f'{SRC}/{base}.jpg'); l=cv2.cvtColor(B,cv2.COLOR_BGR2LAB).astype(np.float32)
        s=((l[...,1]-128)+(l[...,2]-128)>=7).astype(np.uint8); s[int(0.62*H):]=0; s[:150]=0
        s=cv2.morphologyEx(s,cv2.MORPH_OPEN,np.ones((5,5),np.uint8)); s=cv2.morphologyEx(s,cv2.MORPH_CLOSE,np.ones((15,15),np.uint8))
        n,lab,st,_=cv2.connectedComponentsWithStats(s); k=1+np.argmax(st[1:,4]); s=(lab==k).astype(np.uint8)
        s=ndi_fill(s)
        _skin[base]=s
    return _skin[base]
def ndi_fill(s):
    from scipy import ndimage as ndi
    return ndi.binary_fill_holes(s).astype(np.uint8)
def over(canvas, layer):
    a=layer[...,3:]/255.; return canvas*(1-a)+layer[...,:3]*a
def tint(layer, rgb, ref=0.80):
    bgr=np.float32(rgb[::-1])/255.; L=cv2.cvtColor(layer[...,:3].clip(0,255).astype(np.uint8),cv2.COLOR_BGR2GRAY)[...,None]/255.
    lo=bgr*L/ref; hi=bgr+(1-bgr)*((L-ref)/(1-ref)).clip(0,1)
    out=np.where(L<ref,lo,hi)*255; return np.dstack([out,layer[...,3:]])
PAL_F=[(96,140,132),(72,96,130),(200,214,226),(176,138,150),(140,110,150),(120,150,110),(210,190,170)]
PAL_M=[(70,92,120),(96,130,112),(120,120,124),(150,110,80),(60,62,70),(110,90,120),(190,200,210)]
ROBES={'f':[f'robe_f{i}@base_f' for i in range(1,10)],'m':[f'robe_m{i}@base_m' for i in range(1,10)]}
ELDER_ROBES={'f':['robe_f5@base_f','robe_f2@base_f','robe_f8@base_f','robe_f1@base_f','robe_f7@base_f'],'m':['robe_m5@base_m','robe_m1@base_m','robe_m8@base_m','robe_m7@base_m','robe_m4@base_m']}
FIXED={'robe_f3@base_f','robe_m3@base_m'}
# v0.9.3 新衣袍：不进 ROBES（旧人物的抽签不变），只给 pv>=10 的新人物按宗门加权另抽（Portrait5Lib.roll 的 robe_v）
ROBES_NEW={'f':[f'robe_f{i}@base_f' for i in range(10,18)],'m':[f'robe_m{i}@base_m' for i in range(10,18)]}
ELDER_ROBES_NEW={'f':['robe_f11@base_f','robe_f12@base_f','robe_f13@base_f','robe_f14@base_f'],'m':['robe_m11@base_m','robe_m12@base_m','robe_m13@base_m','robe_m14@base_m','robe_m17@base_m']}
# 宗门偏好的款式（权重 x4）；f10 剑修披肩 f11 药师围裙 f12 尼袍袈裟 f13 世家叠领 f14 纱衣 f15 魔门高领束腰 f16 蓑衣 f17 轻甲
# m10 剑修背带 m11 药师 m12 僧袍 m13 圆领袍 m14 魔门毛领 m15 蓑衣 m16 兽面轻甲 m17 鹤氅
SECT_ROBES={'青云宗':['robe_f10','robe_f13','robe_f14','robe_m10','robe_m13','robe_m17'],
 '玄霜谷':['robe_f14','robe_f10','robe_f13','robe_m17','robe_m10','robe_m14'],
 '落霞宫':['robe_f13','robe_f14','robe_m13','robe_m17'],
 '万剑门':['robe_f10','robe_f17','robe_m10','robe_m16'],
 '药王谷':['robe_f11','robe_m11'],
 '散修':['robe_f16','robe_f11','robe_f12','robe_m15','robe_m11','robe_m12'],
 '血煞门':['robe_f15','robe_f17','robe_m14','robe_m16'],
 '阴骨教':['robe_f15','robe_f12','robe_m14','robe_m12']}
NO_OUTER=['robe_f10@base_f','robe_f16@base_f','robe_f17@base_f','robe_m14@base_m','robe_m15@base_m','robe_m16@base_m']
OUTERS={'f':['outer_f2@base_f','outer_f1@base_f','outer_f3@base_f','outer_f4@base_f','outer_f5@base_f'],'m':['outer_m1@base_m','outer_m2@base_m','outer_m3@base_m','outer_m4@base_m']}
HAIR={'f':[f'hair_f{i}@base_f' for i in range(1,13)],'m':[f'hair_m{i}@base_m' for i in range(1,12)],
      'fe':['hair_fe1@base_fe','hair_fe2@base_fe','hair_fe3@base_fe'],'me':['hair_me1@base_me','hair_me2@base_me','hair_me3@base_me']}
NATIVE_WHITE={'hair_fe1@base_fe','hair_me1@base_me','hair_fe2@base_fe','hair_me2@base_me','hair_me3@base_me','hair_fe3@base_fe'}
ACC={'hair_f8@base_f':['acc_f1@base_f','acc_f2@base_f'],'hair_f5@base_f':['acc_f3@base_f'],'hair_f11@base_f':['acc_f4@base_f'],'hair_m5@base_m':['acc_m1@base_m']}
BEARDS={'m':['beard_m1@base_m','beard_m2@base_m','beard_m3@base_m','beard_m4@base_m','beard_m5@base_m5'],'me':['beard_me1@base_me','beard_me2@base_me']}
SWAY={'hair_f6','hair_f9','hair_m8','hair_m10','hair_f1','hair_fe2','hair_me3','acc_f1','acc_m1','outer_f1','outer_f5'}

# marks: connected components of mark edits, anchored to brows/eyes
MARK_BOXES={  # curated (x0,y0,x1,y1) in the mark edit's base canvas
 'mark_f@base_f':{'huadian_plum':(405,222,462,280),'mole_eye':(510,296,536,322)},
 'mark_f2@base_f':{'huadian_flame':(410,198,462,290),'mole_eye2':(506,302,532,328)},
 'mark_f3@base_f':{'huadian_dots':(415,225,467,270),'mole_lip':(449,371,475,397)},
 'mark_f5@base_f':{'huadian_moon':(410,217,455,263),'mole_cheek':(384,406,404,426)},
 'mark_f6@base_f':{'huadian_drop':(414,218,452,277)},
 'mark_f4@base_f':{'demon_slit':(415,185,445,285),'demon_veins':(480,240,560,385)},
 'mark_m@base_m':{'demon_crest':(390,185,470,272),'scar_cheek':(485,305,530,380)},
 'mark_m2@base_m':{'scar_brow':(478,205,525,322)},
 'mark_m3@base_m':{'sect_flame':(400,185,460,272),'scar_nose':(405,320,455,356)},
}
def mark_lib():
    out=[]
    for n,boxes in MARK_BOXES.items():
        base=n.split('@')[1]; E=reg_edit(n).astype(np.float32); B=img(f'{SRC}/{base}.jpg').astype(np.float32)
        d=cv2.GaussianBlur(np.abs(E-B).sum(2),(0,0),1.0)
        for nm,(x0,y0,x1,y1) in boxes.items():
            box=np.zeros((H,W),np.float32); box[y0:y1,x0:x1]=1; box=cv2.GaussianBlur(box,(0,0),2)
            al=box*np.clip((d-18)/50,0,1); al=cv2.GaussianBlur(al,(0,0),0.6)
            a3=np.maximum(al,1e-3)[...,None]; C=np.where(al[...,None]>0.02,(E-(1-a3)*B)/a3,E).clip(0,255)
            cy=(y0+y1)/2
            anchor=min(('brows','eyes','nose','mouth'),key=lambda r:abs(AN[base][r][1]-cy))
            out.append(dict(id=nm,sex=base[5],rgba=np.dstack([C,al*255]),base=base,anchor=anchor,box=[x0,y0,x1,y1],forehead=y1<300))
    return out
MARKS=None


def hair_aux(hk):
    """per-hair masks in the hair part's own canvas (source base space):
       keep = thick dark strands that may cross a face; srcface = the source base's lower face"""
    key='aux:'+hk
    if key not in _cache:
        L=load_part(hk); hb=hk.split('@')[1]
        Lp=L[...,:3].mean(2); dark=((Lp<120)&(L[...,3]>80)).astype(np.uint8)
        thick=cv2.morphologyEx(dark,cv2.MORPH_OPEN,np.ones((5,5),np.uint8)).astype(np.float32)
        thick=cv2.GaussianBlur(thick,(0,0),1.5)
        keep=np.clip((95-Lp)/30,0,1)*thick
        yy=np.arange(H)[:,None]
        sf=((skin_mask(hb)>0)&(yy>AN[hb]['eyes'][1]+12)).astype(np.uint8)
        sf=cv2.dilate(sf,np.ones((9,9),np.uint8)).astype(np.float32)
        sf=cv2.GaussianBlur(sf,(0,0),2)
        _cache[key]=(keep,sf)
    return _cache[key]
def head_face(base):
    yy=np.arange(H)[:,None]
    f=((skin_mask(base)>0)&(yy>AN[base]['eyes'][1]+12)).astype(np.float32)
    return cv2.GaussianBlur(f,(0,0),2)
def robe_cut(base):
    return cv2.GaussianBlur(cv2.erode(skin_mask(base),np.ones((5,5),np.uint8)).astype(np.float32),(0,0),1.5)
def lin_M(src_anchor, dst_anchor):
    s=dst_anchor[2]/src_anchor[2]
    return np.float32([[s,0,dst_anchor[0]-s*src_anchor[0]],[0,s,dst_anchor[1]-s*src_anchor[1]]])

def choose_spec(seed, sex=None, base=None, elder=None):
    """random character spec (what the game stores); render() and Godot both consume it"""
    global MARKS
    if MARKS is None: MARKS=mark_lib()
    R=random.Random(seed)
    if base is None:
        sex=sex or R.choice('fm')
        if elder is None: elder=R.random()<0.2
        base=('base_fe' if sex=='f' else 'base_me') if elder else R.choice(F_BASES if sex=='f' else M_BASES)
    sex=base[5]; elder=base in ELDER
    sp=dict(base=base,feats={},eye_state='open')
    if not elder:
        for r in ('nose','mouth','eyes','brows'):
            pool=[e for e in LIB[sex][r] if e['id'] not in CLOSED_IDS]
            sp['feats'][r]=R.choice(pool)['id']
    else:
        ev=LIB.get('elder',{}).get(base,{})
        for r in ('brows','mouth'):
            if ev.get(r) and R.random()<0.5: sp['feats'][r]=R.choice(ev[r])['id']
    sp['marks']=[]
    if R.random()<0.35:
        ms=[m for m in MARKS if m['sex']==sex]; a=R.choice(ms); sp['marks'].append(a['id'])
        if R.random()<0.3:
            b=[m for m in ms if m['forehead']!=a['forehead']]
            if b: sp['marks'].append(R.choice(b)['id'])
    pal=PAL_F if sex=='f' else PAL_M
    pool=[k for k in (ELDER_ROBES[sex] if elder else ROBES[sex]) if k not in FIXED]
    sp['robe']=sorted(FIXED)[0 if sex=='f' else 1] if R.random()<0.06 else R.choice(pool); sp['robe_tint']=R.choice(pal)
    sp['outer']=R.choice(OUTERS[sex]) if (R.random()<0.35 and sp['robe'] not in FIXED) else None
    sp['outer_tint']=R.choice(pal)
    hk=R.choice(HAIR[('fe' if sex=='f' else 'me') if elder else sex]); sp['hair']=hk
    sp['acc']=[a for a in ACC.get(hk,[]) if R.random()<0.6]
    sp['beard']=None
    if sex=='m':
        if elder and hk!='hair_me1@base_me' and R.random()<0.75: sp['beard']=R.choice(BEARDS['me'])
        elif not elder and R.random()<0.3: sp['beard']=R.choice([k for k in BEARDS['m'] if k!='beard_m5@base_m5' or base in ('base_m4','base_m5')])
    return sp

def feat_entry(sex, r, fid):
    return next(x for x in LIB[sex][r] if x['id']==fid)
def eye_pair(base, sp):
    """(open entry, closed entry) for the eyes shown on this head"""
    sex=base[5]
    if base in ELDER:
        c=LIB.get('elder',{}).get(base,{}).get('closed')
        return dict(id=f'eyes:{base}',src=('base',base),anchor=base), c
    e=feat_entry(sex,'eyes',sp['feats']['eyes'])
    c=CLOSED.get(e['id']); return e,(feat_entry(sex,'eyes',c) if c else None)

def half_of(base, sp):
    if base in ELDER: return LIB.get('elder',{}).get(base,{}).get('half')
    return HALF.get(sp['feats'].get('eyes',''))
def render(sp, eye_state=None, layers=False):
    global MARKS
    if MARKS is None: MARKS=mark_lib()
    base=sp['base']; sex=base[5]; elder=base in ELDER
    eye_state=eye_state or sp.get('eye_state','open')
    canvas=img(f'{SRC}/{base}.jpg').copy()
    for r in ('nose','mouth','eyes','brows'):
        fid=sp['feats'].get(r)
        if r=='eyes':
            e,c=eye_pair(base,sp)
            hf=half_of(base,sp)
            if eye_state=='half' and hf is not None:
                canvas=paste_feature(canvas,base,e,r,mix_with=hf,mix=1.0)
            elif eye_state!='open' and c is not None:
                canvas=paste_feature(canvas,base,e,r,mix_with=c,mix=1.0 if eye_state=='closed' else 0.55)
            elif e['src']!=('base',base): canvas=paste_feature(canvas,base,e,r)
            continue
        if not fid: continue
        e=next(x for x in LIB['elder'][base][r] if x['id']==fid) if elder else feat_entry(sex,r,fid)
        if e['src']!=('base',base): canvas=paste_feature(canvas,base,e,r)
    canvas=canvas.astype(np.float32)
    for mid in sp.get('marks',[]):
        mk=next(m for m in MARKS if m['id']==mid)
        sa=AN[mk['base']][mk['anchor']]; ta=AN[base][mk['anchor']]
        M=np.float32([[1,0,ta[0]-sa[0]],[0,1,ta[1]-sa[1]]])
        canvas=over(canvas,cv2.warpAffine(mk['rgba'],M,(W,H)))
    robe=sp['robe']; L=load_part(robe)
    if robe not in FIXED:
        L=tint(L,sp['robe_tint'])
        pp=f'{PARTS}/{robe}.paper.png'
        if os.path.exists(pp):
            pm=cv2.imread(pp,0).astype(np.float32)[...,None]/255.; L[...,:3]=L[...,:3]*(1-pm)+np.float32([230,237,240])*pm
    L[...,3]*=(1-robe_cut(base)); canvas=over(canvas,L)
    if sp.get('outer'):
        canvas=over(canvas,tint(load_part(sp['outer']),sp['outer_tint'],ref=0.7))
    if sp.get('beard'):
        bk=sp['beard']; bb=bk.split('@')[1]; L=load_part(bk)
        if bb!=base: L=cv2.warpAffine(L,lin_M(AN[bb]['mouth'],AN[base]['mouth']),(W,H),flags=cv2.INTER_LINEAR)
        canvas=over(canvas,L)
    hk=sp['hair']; hb=hk.split('@')[1]; Mh=skull_M(hb,base) if hb!=base else None
    L=load_part(hk)
    if Mh is not None: L=cv2.warpAffine(L,Mh,(W,H),flags=cv2.INTER_LINEAR)
    if hk not in NATIVE_WHITE and hb!=base:
        keep,sf=hair_aux(hk)
        keep_w=cv2.warpAffine(keep,Mh,(W,H)); sf_w=cv2.warpAffine(sf,Mh,(W,H))
        prot=np.maximum(head_face(base),sf_w)
        L[...,3]*=(1-prot*(1-keep_w))
    canvas=over(canvas,L)
    for ak in sp.get('acc',[]):
        A=load_part(ak)
        if Mh is not None: A=cv2.warpAffine(A,Mh,(W,H),flags=cv2.INTER_LINEAR)
        canvas=over(canvas,A)
    return canvas.clip(0,255).astype(np.uint8)

def assemble(seed, sex=None, base=None, hair=None, robe=None, robe_tint=None, outer='rand', feats=None, eye_state='open', beard='rand', mark='rand'):
    """back-compat wrapper used by make_compare.py"""
    sp=choose_spec(seed,sex=sex,base=base)
    if base is not None and base not in ELDER and feats:
        for r,v in feats.items(): sp['feats'][r]=v if isinstance(v,str) else v['id']
    if hair: sp['hair']=hair; sp['acc']=[]
    if robe: sp['robe']=robe
    if robe_tint: sp['robe_tint']=robe_tint
    if outer!='rand': sp['outer']=outer
    if beard is False: sp['beard']=None
    if mark is False: sp['marks']=[]
    sp['eye_state']=eye_state
    return render(sp), sp
