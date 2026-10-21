# per-base feature anchors via multi-scale template matching against the sex reference base
import cv2, numpy as np, json, glob, os
D=os.environ.get('LIB5_DIR', os.path.dirname(os.path.abspath(__file__))); SRC=D+'/src'
# canonical regions on base_f / base_m (x0,y0,x1,y1)
REG={'brows':(325,238,550,284),'eyes':(322,270,552,320),'nose':(392,305,482,382),'mouth':(372,378,502,430),
     'head':(300,180,575,470)}
def gray(im): return cv2.GaussianBlur(cv2.cvtColor(im,cv2.COLOR_BGR2GRAY),(0,0),1.5)
def match(ref, tgt, box, search=60, scales=np.linspace(0.86,1.16,11)):
    x0,y0,x1,y1=box; T=gray(ref)[y0:y1,x0:x1]; G=gray(tgt); best=(-2,None)
    cx,cy=(x0+x1)/2,(y0+y1)/2
    for s in scales:
        t=cv2.resize(T,None,fx=s,fy=s); h,w=t.shape
        sx0=int(max(0,cx-w/2-search)); sy0=int(max(0,cy-h/2-search))
        win=G[sy0:int(cy+h/2+search),sx0:int(cx+w/2+search)]
        if win.shape[0]<h or win.shape[1]<w: continue
        r=cv2.matchTemplate(win,t,cv2.TM_CCOEFF_NORMED); _,v,_,loc=cv2.minMaxLoc(r)
        if v>best[0]: best=(v,(sx0+loc[0]+w/2, sy0+loc[1]+h/2, s))
    return best
def head_box(im):
    # skull top + forehead width (above brows, no ears)
    bg=np.array([230,237,240],np.float32)
    nb=(np.abs(im.astype(np.float32)-bg).sum(2)>25)
    nb=cv2.morphologyEx(nb.astype(np.uint8),cv2.MORPH_OPEN,np.ones((5,5),np.uint8))>0
    cols=slice(250,620)
    rows=np.where(nb[:400,cols].sum(1)>8)[0]; top=int(rows[0])
    yw=top+110; xs=np.where(nb[yw,cols])[0]+250
    return dict(top=top,left=int(xs.min()),right=int(xs.max()),yw=yw)
if __name__=='__main__':
    out={}
    for p in sorted(glob.glob(SRC+'/base_*.jpg')):
        b=os.path.basename(p)[:-4]; im=cv2.imread(p)
        ref=cv2.imread(SRC+('/base_m.jpg' if b.startswith('base_m') else '/base_f.jpg'))
        a={'skull':head_box(im)}
        _,(hx,hy,hs)=match(ref,im,REG['head'],search=50)
        a['head']=[hx,hy,hs]
        for r in ('brows','eyes','nose','mouth'):
            v,(x,y,s)=match(ref,im,REG[r],search=40,scales=[hs*k for k in (0.94,0.97,1,1.03,1.06)])
            a[r]=[round(x,1),round(y,1),round(s,3),round(v,3)]
        out[b]=a; print(b,a)
    json.dump(out,open(D+'/anchors.json','w'),indent=1)
    # debug
    tiles=[]
    for b,a in out.items():
        im=cv2.imread(f'{SRC}/{b}.jpg')
        for r,c in zip(('brows','eyes','nose','mouth'),[(0,0,255),(0,200,0),(255,0,0),(200,0,200)]):
            x,y,s,_=a[r]; x0,y0,x1,y1=REG[r]; w=(x1-x0)*s/2; h=(y1-y0)*s/2
            cv2.rectangle(im,(int(x-w),int(y-h)),(int(x+w),int(y+h)),c,2)
        k=a['skull']; cv2.line(im,(k['left'],k['yw']),(k['right'],k['yw']),(0,128,255),2); cv2.line(im,(250,k['top']),(620,k['top']),(0,128,255),2)
        t=im[150:520,230:640]; cv2.putText(t,b,(5,20),0,0.6,(0,0,0),2); tiles.append(t)
    while len(tiles)%6: tiles.append(np.zeros_like(tiles[0])+255)
    cv2.imwrite('/tmp/anchors.jpg',np.vstack([np.hstack(tiles[i:i+6]) for i in range(0,len(tiles),6)]))
