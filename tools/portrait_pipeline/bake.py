# bake lib5 into runtime assets for Godot: every blend that needs Python (feature frequency-split patches,
# per-head masks, hair face-protect aux, transforms) is precomputed here at half resolution.
import os, sys, json, cv2, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compose as c
OUT = sys.argv[1] if len(sys.argv) > 1 else os.environ.get('LIB5_OUT', os.path.join(os.environ.get('LIB5_DIR', '.'), 'out_portrait5'))
S = 0.5; CW, CH = int(c.W * S), int(c.H * S)
for d in ('heads', 'feat', 'parts', 'marks'): os.makedirs(f'{OUT}/{d}', exist_ok=True)

def crop_even(a, thr=0.01):
    ys, xs = np.where(a > thr)
    if len(xs) == 0: return None
    x0, y0 = (xs.min() // 2) * 2, (ys.min() // 2) * 2
    x1, y1 = min(c.W, ((xs.max() + 2) // 2) * 2), min(c.H, ((ys.max() + 2) // 2) * 2)
    return int(x0), int(y0), int(x1), int(y1)
def half(im): return cv2.resize(im, (im.shape[1] // 2, im.shape[0] // 2), interpolation=cv2.INTER_AREA)
def save_rgba(path, rgb, a, box):
    x0, y0, x1, y1 = box
    im = np.dstack([rgb[y0:y1, x0:x1].astype(np.float32), a[y0:y1, x0:x1].astype(np.float32) * 255])
    cv2.imwrite(path, half(im).clip(0, 255).round().astype(np.uint8))
    return [x0 // 2, y0 // 2]

lib = dict(canvas=[CW, CH], heads={}, feats={}, parts={}, marks={}, xf=dict(skull={}, mouth={}))
ALL_BASES = c.F_BASES + c.M_BASES + list(c.ELDER)
for b in ALL_BASES:
    B = c.img(f'{c.SRC}/{b}.jpg'); cv2.imwrite(f'{OUT}/heads/{b}.jpg', half(B), [cv2.IMWRITE_JPEG_QUALITY, 92])
    mk = np.dstack([np.zeros((c.H, c.W)), c.head_face(b) * 255, c.robe_cut(b) * 255])  # BGR: R=robe cut, G=face
    cv2.imwrite(f'{OUT}/heads/{b}.mask.png', half(mk).clip(0, 255).round().astype(np.uint8))
    an = {r: [v[0] * S, v[1] * S, v[2]] for r, v in c.AN[b].items() if r in ('brows', 'eyes', 'nose', 'mouth')}
    lib['heads'][b] = dict(sex=b[5], elder=b in c.ELDER, anchors=an)
# ---- features: (feature, head, state) patches
def bake_feat(base, e, region, state, mix_with=None, mix=0.0):
    canvas = c.img(f'{c.SRC}/{base}.jpg').copy()
    out, m = c.paste_feature(canvas, base, e, region, mix_with=mix_with, mix=mix, patch=True)
    box = crop_even(m, 0.004)
    key = f'{e["id"]}|{base}|{state}'
    fn = key.replace(':', '-').replace('|', '__').replace('@', '-') + '.png'
    pos = save_rgba(f'{OUT}/feat/{fn}', out, m, box)
    lib['feats'][key] = dict(tex='feat/' + fn, pos=pos)
n = 0
for b in c.F_BASES + c.M_BASES:
    sx = b[5]
    for r in ('nose', 'mouth', 'brows', 'eyes'):
        for e in c.LIB[sx][r]:
            if e['id'] in c.CLOSED_IDS: continue
            if e['src'] != ('base', b): bake_feat(b, e, r, 'open'); n += 1
            if r == 'eyes' and e['id'] in c.CLOSED:
                ce = c.feat_entry(sx, 'eyes', c.CLOSED[e['id']])
                hf = c.HALF.get(e['id'])
                bake_feat(b, e, r, 'half', hf or ce, 1.0 if hf else 0.55); bake_feat(b, e, r, 'closed', ce, 1.0); n += 2
    print('feats', b, n, flush=True)
for b, ev in c.LIB.get('elder', {}).items():
    e = dict(id=f'eyes:{b}', src=('base', b), anchor=b)
    if ev.get('closed'):
        bake_feat(b, e, 'eyes', 'half', ev.get('half') or ev['closed'], 1.0 if ev.get('half') else 0.55); bake_feat(b, e, 'eyes', 'closed', ev['closed'], 1.0)
    for r in ('brows', 'mouth'):
        for fe in ev.get(r, []): bake_feat(b, fe, r, 'open')
# ---- layered parts
for key, r in c.META.items():
    kind = r['kind']
    if kind not in ('hair', 'robe', 'outer', 'beard', 'acc'): continue
    L = c.load_part(key); box = crop_even(L[..., 3] / 255.)
    fn = key.replace('@', '-') + '.png'
    pos = save_rgba(f'{OUT}/parts/{fn}', L[..., :3], L[..., 3] / 255., box)
    ent = dict(tex='parts/' + fn, pos=pos, kind=kind, sway=key.split('@')[0] in c.SWAY)
    x0, y0, x1, y1 = box
    pp = f'{c.PARTS}/{key}.paper.png'
    if kind == 'robe' and os.path.exists(pp):
        pm = cv2.imread(pp, 0)[y0:y1, x0:x1]; cv2.imwrite(f'{OUT}/parts/{fn[:-4]}.paper.png', half(pm)); ent['paper'] = f'parts/{fn[:-4]}.paper.png'
    if kind == 'hair' and key not in c.NATIVE_WHITE:
        keep, sf = c.hair_aux(key)
        aux = np.dstack([np.zeros_like(keep), sf * 255, keep * 255])[y0:y1, x0:x1]   # BGR: R=keep, G=srcface
        cv2.imwrite(f'{OUT}/parts/{fn[:-4]}.aux.png', half(aux).clip(0, 255).round().astype(np.uint8)); ent['aux'] = f'parts/{fn[:-4]}.aux.png'
    lib['parts'][key] = ent
# ---- marks
for mk in c.mark_lib():
    rgba = mk['rgba']; box = crop_even(rgba[..., 3] / 255.)
    pos = save_rgba(f'{OUT}/marks/{mk["id"]}.png', rgba[..., :3], rgba[..., 3] / 255., box)
    lib['marks'][mk['id']] = dict(tex=f'marks/{mk["id"]}.png', pos=pos, base=mk['base'], anchor=mk['anchor'], sex=mk['sex'], forehead=bool(mk['forehead']))
# ---- transforms (half-res canvas)
def half_M(M): return [float(M[0, 0]), float(M[0, 2]) * S, float(M[1, 2]) * S]
for hb in {k.split('@')[1] for v in c.HAIR.values() for k in v}:
    lib['xf']['skull'][hb] = {b: half_M(c.skull_M(hb, b)) for b in ALL_BASES}
for bb in {k.split('@')[1] for v in c.BEARDS.values() for k in v}:
    lib['xf']['mouth'][bb] = {b: half_M(c.lin_M(c.AN[bb]['mouth'], c.AN[b]['mouth'])) for b in ALL_BASES}
# ---- pools / ids (so the game can roll characters itself)
lib['pools'] = dict(F_BASES=c.F_BASES, M_BASES=c.M_BASES, ELDER=c.ELDER,
    feats={sx: {r: [e['id'] for e in c.LIB[sx][r] if e['id'] not in c.CLOSED_IDS] for r in ('nose', 'mouth', 'eyes', 'brows')} for sx in 'fm'},
    elder_feats={b: {r: [e['id'] for e in v.get(r, [])] for r in ('brows', 'mouth')} for b, v in c.LIB.get('elder', {}).items()},
    closed=c.CLOSED, hair=c.HAIR, robes=c.ROBES, elder_robes=c.ELDER_ROBES, fixed=sorted(c.FIXED), outers=c.OUTERS,
    beards=c.BEARDS, acc=c.ACC, native_white=sorted(c.NATIVE_WHITE), pal_f=c.PAL_F, pal_m=c.PAL_M)
json.dump(lib, open(f'{OUT}/lib5.json', 'w'), ensure_ascii=False)
print('done', len(lib['feats']), 'feats', len(lib['parts']), 'parts', len(lib['marks']), 'marks')
