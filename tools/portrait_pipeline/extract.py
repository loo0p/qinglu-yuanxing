# lib5 in-situ extraction: edit image -> register to its base -> diff/unmix -> RGBA part on the base canvas
import cv2, numpy as np, json, os, glob, sys
from scipy import ndimage as ndi
sys.path.insert(0, os.path.dirname(__file__))
from reg import register
D = os.environ.get('LIB5_DIR', os.path.dirname(os.path.abspath(__file__))); SRC = D + '/src'; OUT = D + '/parts'
WHITE = {'hair_fe1', 'hair_me1', 'hair_fe2', 'hair_me2', 'hair_me3', 'beard_me1', 'beard_me2'}  # light-coloured parts: no dark-unmix
WIDE = {'hair_fe2', 'hair_me3'}  # long loose light hair over the shoulders
OUTER_HOLE = {'outer_f4': [(352, 560), (515, 560), (545, 1152), (322, 1152)],
              'outer_f3': [(360, 640), (505, 640), (520, 1152), (345, 1152)]}
LONG_BEARD = {'beard_m3', 'beard_me2'}

def lab_diff(a, b):
    la = cv2.cvtColor(a, cv2.COLOR_BGR2LAB).astype(np.float32); lb = cv2.cvtColor(b, cv2.COLOR_BGR2LAB).astype(np.float32)
    d = np.sqrt(((la - lb) ** 2).sum(2))
    return cv2.GaussianBlur(d, (0, 0), 1.2), la[..., 0], lb[..., 0]

def clean(mask, min_area):
    lab, n = ndi.label(mask)
    if n == 0: return mask
    s = ndi.sum(mask, lab, range(1, n + 1))
    keep = np.zeros(n + 1, bool); keep[1:] = s >= min_area
    return keep[lab]

def fill_small_holes(m, max_area):
    holes = ndi.binary_fill_holes(m) & ~m
    lab, n = ndi.label(holes)
    if n == 0: return m
    s = ndi.sum(holes, lab, range(1, n + 1))
    small = np.zeros(n + 1, bool); small[1:] = s <= max_area
    return m | small[lab]

def feather(m, r):
    return cv2.GaussianBlur(m.astype(np.float32), (0, 0), r).clip(0, 1)

def extract(path):
    name, base = os.path.basename(path)[:-4].split('@')
    kind = name.split('_')[0]
    E0 = cv2.imread(path)
    hair_of = None
    if kind == 'acc':  # accessory edited on top of a hair edit: register to the true base, diff vs the registered hair
        hk = os.path.basename(glob.glob(f'{SRC}/{base}@*.jpg')[0])[:-4]; hair_of = hk; base = hk.split('@')[1]
        Bt = cv2.imread(f'{SRC}/{base}.jpg'); Hs = cv2.imread(f'{SRC}/{hk}.jpg')
        _, Mh, _, _ = register(Bt, Hs)
        E1, M1, inl, good = register(Hs, E0)
        A3 = np.vstack([Mh, [0, 0, 1]]); B3 = np.vstack([M1, [0, 0, 1]]); M = (A3 @ B3)[:2]
        B = cv2.warpAffine(Hs, Mh, (Bt.shape[1], Bt.shape[0]), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)
        E = cv2.warpAffine(E1, Mh, (Bt.shape[1], Bt.shape[0]), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)
    else:
        B = cv2.imread(f'{SRC}/{base}.jpg')
        E, M, inl, good = register(B, E0)
    H, W = B.shape[:2]
    d, Le, Lb = lab_diff(E, B)
    yy, xx = np.mgrid[0:H, 0:W] / np.array([H, W])[:, None, None]
    Ef = E.astype(np.float32); Bf = B.astype(np.float32)
    if kind == 'hair':
        m = d > 14
        m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8)) > 0
        m = clean(m, 1500); m = fill_small_holes(m, 4000)
        m = cv2.dilate(m.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
        soft = feather(m, 2.0) * np.clip((d - 6) / 14, 0, 1) ** 0.5
        if name in WHITE:
            a = soft
            core = feather(cv2.erode(m.astype(np.uint8), np.ones((9, 9), np.uint8)) > 0, 3)
            a = np.maximum(a, core) * feather(m, 1.5)
        else:
            adark = np.clip((Lb - Le) / np.maximum(Lb - 40, 20), 0, 1)
            core = feather(cv2.erode(m.astype(np.uint8), np.ones((11, 11), np.uint8)) > 0, 3)
            a = np.maximum(adark, core) * soft
            a = np.maximum(a, soft * (Le > Lb + 8))  # light ornaments (jade, ties)
        # never carry the base's own face (eyes/brows/mouth redraws) inside the hair layer
        labB_ = cv2.cvtColor(B, cv2.COLOR_BGR2LAB).astype(np.float32)
        sk = (((labB_[..., 1] - 128) + (labB_[..., 2] - 128)) >= 7).astype(np.uint8); sk[int(0.62 * H):] = 0; sk[:150] = 0
        sk = cv2.morphologyEx(sk, cv2.MORPH_CLOSE, np.ones((15, 15), np.uint8))
        nl, lab_, st_, _ = cv2.connectedComponentsWithStats(sk); sk = (lab_ == 1 + np.argmax(st_[1:, 4]))
        sk = ndi.binary_fill_holes(sk) & (yy < 0.42)
        sk = cv2.erode(sk.astype(np.uint8), np.ones((9, 9), np.uint8)) > 0
        skf = feather(sk, 3)
        if name in WHITE:
            beardzone = (yy > 0.295) & (xx > 0.36) & (xx < 0.64)
            a = a * (1 - skf * (~beardzone))
        else:
            strand = np.maximum(np.clip((90 - Le) / 30, 0, 1), np.clip((125 - Le) / 30, 0, 1) * np.clip((d - 14) / 12, 0, 1))
            a = a * (1 - skf * (1 - strand))
        neck = yy > 0.41
        if name in WHITE:
            keep = ((xx > 0.38) & (xx < 0.625) & (yy < 0.80)) if name not in WIDE else ((xx > 0.20) & (xx < 0.80) & (yy < 0.78))
            a = np.where(neck & ~keep, 0, a)
        else:
            adark2 = np.clip((Lb - Le - 6) / np.maximum(Lb - 40, 20), 0, 1)
            a = np.where(neck, np.minimum(a, adark2 * feather(m, 1.5)), a)
    elif kind == 'robe':
        neck_y = 0.50
        m = d > 10
        m = clean(m, 3000)
        m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((15, 15), np.uint8)) > 0
        m = ndi.binary_fill_holes(m)
        bg = np.array([230, 237, 240], np.float32)
        nonbg = np.abs(Ef - bg).sum(2) > 18
        nb2 = cv2.morphologyEx(nonbg.astype(np.uint8), cv2.MORPH_OPEN, np.ones((7, 7), np.uint8)) > 0
        lower = (yy > neck_y + 0.04) & clean(nb2, 5000)
        m = (m & (yy > 0.34)) | lower
        m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8)) > 0
        m = clean(m, 5000)
        m = fill_small_holes(m, 20000)
        # never cover skin: pixels that are skin in the base and unchanged in the edit
        labB = cv2.cvtColor(B, cv2.COLOR_BGR2LAB).astype(np.float32)
        labE = cv2.cvtColor(E, cv2.COLOR_BGR2LAB).astype(np.float32)
        sc = lambda l: (l[..., 1] - 128) + (l[..., 2] - 128)
        skin = (sc(labB) >= 7) & (sc(labE) >= 7) & (yy < 0.62) & (np.abs(labE[..., 0] - labB[..., 0]) < 18)
        skin = cv2.morphologyEx(skin.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8)) > 0
        # also erase the base robe outside the new silhouette (paint paper there)
        nonbgB = np.abs(Bf - bg).sum(2) > 18
        bgc = ~nonbg
        lab_, n_ = ndi.label(bgc)
        border = set(np.unique(np.r_[lab_[:, 0], lab_[:, -1], lab_[0, :]])) - {0}
        paper = (yy > 0.56) & np.isin(lab_, list(border))
        paper = paper & cv2.dilate(nonbgB.astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool)
        m = (m | paper) & ~skin
        a = feather(m, 1.5)
        Ef = Ef.copy(); Ef[paper] = bg
        cv2.imwrite(f'{OUT}/{name}@{base}.paper.png', (feather(paper, 1.0) * 255).astype(np.uint8))
    elif kind == 'outer':
        m = d > 9
        m = clean(m, 3000) & (yy > 0.33)
        m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8)) > 0
        m = fill_small_holes(m, 6000)
        m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_OPEN, np.ones((9, 9), np.uint8)) > 0
        m = clean(m, 4000)
        a = feather(m, 2.0) * np.clip((d - 3) / 12, 0.0, 1) ** 0.7
        hole = OUTER_HOLE.get(name)
        if hole is not None:
            hm = np.zeros((H, W), np.uint8); cv2.fillPoly(hm, [np.int32(hole)], 1)
            a = a * (1 - feather(hm > 0, 2.0))
        hd = cv2.dilate((yy < 0.42).astype(np.uint8) * 0, np.ones((3, 3), np.uint8))
        light = (Le > 228) & m
        solid = cv2.morphologyEx(light.astype(np.uint8), cv2.MORPH_OPEN, np.ones((17, 17), np.uint8))
        solid = cv2.dilate(solid, np.ones((9, 9), np.uint8)) > 0
        a = a * (1 - feather(light & ~solid, 1.0))
    elif kind == 'eyes':
        box = ((yy > 0.17) & (yy < 0.30) & (xx > 0.30) & (xx < 0.70)).astype(np.float32)
        box = cv2.GaussianBlur(box, (0, 0), 10)
        m = cv2.dilate((d > 6).astype(np.uint8), np.ones((15, 15), np.uint8))
        a = box * feather(m > 0, 6)
    elif kind == 'beard':
        ymax = (0.70 if name in WHITE else 0.80) if name in LONG_BEARD else 0.46
        x0b, x1b = (0.37, 0.63) if name in LONG_BEARD else (0.30, 0.70)
        box = ((yy > 0.24) & (yy < ymax) & (xx > x0b) & (xx < x1b)).astype(np.float32)
        m = (d > 8).astype(np.uint8) * (box > 0)
        m = clean(m > 0, 300)
        m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8)) > 0
        nl, lab_, st_, _ = cv2.connectedComponentsWithStats(m.astype(np.uint8))
        if nl > 1:
            big = st_[1:, 4].max(); m = np.isin(lab_, [i for i in range(1, nl) if st_[i, 4] >= 0.15 * big])
        m = cv2.dilate(m.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
        if name in WHITE:
            a = feather(m, 1.5) * np.clip((d - 4) / 16, 0, 1) ** 0.6
        else:
            adark = np.clip((Lb - Le) / np.maximum(Lb - 40, 20), 0, 1)
            a = feather(m, 1.5) * np.clip(adark * 1.3, 0, 1)
    elif kind == 'acc':
        k5 = np.ones((7, 7), np.uint8)
        lo = cv2.erode(B, k5).astype(np.float32); hi = cv2.dilate(B, k5).astype(np.float32)
        rd = (np.maximum(Ef - hi, 0) + np.maximum(lo - Ef, 0)).sum(2)  # change beyond local misalignment range
        d = cv2.GaussianBlur(rd, (0, 0), 1.0) / 2.0
        m = d > 12
        m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)) > 0
        seed = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
        nl, lab_, _, _ = cv2.connectedComponentsWithStats(m.astype(np.uint8))
        m = np.isin(lab_, np.unique(lab_[seed > 0])) & (lab_ > 0)
        m = clean(m, 120) & (yy < {'acc_f3': 0.24}.get(name, 0.55))
        m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8)) > 0
        m = cv2.dilate(m.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
        a = feather(m, 1.0) * np.clip((d - 6) / 22, 0, 1) ** 0.5
    else:
        raise ValueError(kind)
    a = a.clip(0, 1)
    # un-mix colour so the part carries no base pixels where semi-transparent
    a3 = np.maximum(a, 1e-3)[..., None]
    C = np.where(a[..., None] > 0.02, (Ef - (1 - a3) * Bf) / a3, Ef).clip(0, 255)
    if kind in ('eyes', 'robe'):
        C = Ef
    if kind == 'robe':
        open(OUT + '/.robe_paper', 'a').close()  # same-base patch: keep exact edit pixels
    rgba = np.dstack([C, a * 255]).astype(np.uint8)
    ys, xs = np.where(a > 0.01)
    bbox = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
    x0, y0, x1, y1 = bbox
    cv2.imwrite(f'{OUT}/{name}@{base}.png', rgba[y0:y1, x0:x1])
    return dict(id=name, base=base, kind=kind, pos=[x0, y0], size=[x1 - x0, y1 - y0], inliers=inl,
                scale=round(float(np.hypot(M[0, 0], M[0, 1])), 4), white=name in WHITE, hair=hair_of)

if __name__ == '__main__':
    files = sorted(glob.glob(SRC + '/*@*.jpg'))
    if len(sys.argv) > 1: files = [f for f in files if any(k in f for k in sys.argv[1:])]
    meta = {}
    mp = OUT + '/parts.json'
    if os.path.exists(mp): meta = json.load(open(mp))
    for f in files:
        if os.path.basename(f).startswith(('fx_', 'eyes', 'eyesC_', 'mark_')): continue  # handled by compose feature/mark libs
        r = extract(f); meta[r['id'] + '@' + r['base']] = r
        print(r['id'], r['base'], r['pos'], r['size'], 'inl', r['inliers'], 'scale', r['scale'])
    json.dump(meta, open(mp, 'w'), indent=1)
