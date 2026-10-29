"""make_portrait_web.py 用的个别修补（只改发布用的 WebP，不动烘焙原图）。"""
import numpy as np
from PIL import Image

# 随机池里去掉的嘴型：咧嘴露齿 / 张口，与大多数脸型不搭（看过 5 张脸 × 10 种嘴的对照表）
BAD_MOUTHS = {"f": ["mouth:fx_f5@base_f"], "m": ["mouth:fx_m1@base_m", "mouth:fx_m5@base_m"]}

def fix_lib(lib):
    for sex, bad in BAD_MOUTHS.items():
        pool = lib["pools"]["feats"][sex]["mouth"]
        lib["pools"]["feats"][sex]["mouth"] = [m for m in pool if m not in bad]
    return lib

def _clean_specks(im, y0):
    """裘（outer_f4）内侧残留的白块与碎丝（抠图时带进来的衣袍碎片）：
    ① 斗篷身（y>=y0）里偏白（L>212）的像素去掉 → 露出下面的衣袍；② 只保留左右两大片斗篷，孤立碎片全部透明。毛领本身是白的，只做第②步。"""
    import cv2
    a = np.array(im.convert("RGBA"))
    rgb = a[..., :3].astype(int); al = a[..., 3].astype(np.uint8)
    L = rgb.mean(-1)
    white = (L > 212); white[:y0] = False
    al[white] = 0
    m = (al > 60).astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(m, 8)
    keep = set(np.argsort(-st[1:, cv2.CC_STAT_AREA])[:2] + 1)
    body = np.isin(lab, list(keep)).astype(np.uint8)
    body = cv2.dilate(body, np.ones((5, 5), np.uint8))
    al[body == 0] = 0
    # ③ 两片斗篷内部的透明小洞（毛领下、斗篷身上的半透明斑）补实：颜色从周围修补
    solid = (al > 160).astype(np.uint8)
    solid = cv2.morphologyEx(solid, cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8))
    inv = (1 - solid).astype(np.uint8)
    ff = inv.copy(); h, w = ff.shape
    mask = np.zeros((h + 2, w + 2), np.uint8)
    for (x, y) in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (w // 2, 0), (w // 2, h - 1)]:
        if ff[y, x] == 1:
            cv2.floodFill(ff, mask, (x, y), 0)
    holes = ff.astype(bool)                     # 与外界不连通的透明区 = 洞
    fillm = (holes | ((al > 0) & (al <= 160) & (solid == 1))).astype(np.uint8)
    bgr = np.ascontiguousarray(a[..., 2::-1])
    bgr = cv2.inpaint(bgr, fillm, 6, cv2.INPAINT_TELEA)
    a[..., :3] = bgr[..., ::-1]
    al[fillm == 1] = 255
    a[..., 3] = al
    return Image.fromarray(a, "RGBA")

def fix(rel, im):
    if LIB is not None and rel.startswith("heads/") and rel.endswith(".jpg"):
        return fix_head(rel, im)
    # outer_f1 是半透明纱披，大部分 alpha 很低，不能按“成片衣料”清理
    if LIB is not None and rel.startswith(("parts/robe_", "parts/outer_")) and rel.count(".") == 1 and "outer_f1-" not in rel:
        im = fix_cloth(rel, im)
    if rel == "parts/outer_f4-base_f.png":
        return _clean_specks(im, 165)
    if rel == "marks/scar_nose.png":
        # 鼻梁上的疤原来是一道橙色折线，远看像鼻子上贴了个箭头：压成淡褐红、减淡
        a = np.array(im.convert("RGBA")).astype(np.float32)
        a[..., :3] = a[..., :3] * 0.45 + np.array([150, 112, 104], np.float32) * 0.55
        a[..., 3] *= 0.6
        return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")
    if rel.startswith("feat/") and LIB is not None:
        return fix_feat(rel, im)
    if LIB is not None and rel.startswith(("parts/hair_f", "parts/hair_m")) and not rel.startswith(("parts/hair_fe", "parts/hair_me")):
        if rel.count(".") == 1:
            im = fix_hair_ghost(rel, im)
        return fix_hair_face(rel, im)
    if LIB is not None and rel.startswith(("parts/hair_", "parts/acc_")) and rel.count(".") == 1:
        return fix_hair_ghost(rel, im)
    return im


# ---------------------------------------------------------------- v0.10.2：披发的鬓丝压进脸颊，脸被“挤窄”
# v0.10.3：只处理这四款散发——其余发型的鬓角、发际线、额发原样保留
WILD_HAIR = ("hair_m8", "hair_m6", "hair_m4", "hair_f9")


def fix_hair_face(rel, im):
    """散乱披发（hair_m8、hair_m6、hair_m4、hair_f9）有几缕发丝从鬓角斜着划过脸颊，
    配到窄长脸上就像脸被两边的头发夹窄、下巴变尖（玩家截图圈出的那位：base_m4 + hair_m8）。
    v0.10.2 清得太多（眉眼两侧、鬓角都清了），额头和太阳穴露出一大片光秃秃的底模，显得“额头长长的”。
    v0.10.3 只清**眼睛以下、脸颊内侧**的发丝：底模皮肤向内收约 8px（脸的外轮廓、鬓角、耳前的发丝都留着），
    从眼线下 4px 起 8px 内渐入；眼线以上（发际线、额发、太阳穴、鬓角）一根不动。
    同步去掉 aux 里该处的“保留发丝”标记，让换到别的脸型时那张脸自己的脸部保护生效。"""
    import cv2, os
    stem = os.path.basename(rel).split(".")[0]
    if stem.split("-")[0] not in WILD_HAIR:
        return im
    key = stem.replace("-base_", "@base_")
    e = LIB["parts"].get(key)
    if e is None:
        return im
    base = key.split("@")[1]
    mp = os.path.join(SRC, "heads", base + ".mask.png")
    if not os.path.exists(mp):
        return im
    skin = (np.array(Image.open(mp).convert("RGB"))[..., 0] > 128).astype(np.uint8)
    skin = cv2.erode(skin, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (17, 17)))
    ey = int(LIB["heads"][base]["anchors"]["eyes"][1])
    cut = cv2.GaussianBlur(skin.astype(np.float32), (0, 0), 1.5)
    t = np.clip((np.arange(cut.shape[0], dtype=np.float32) - (ey + 4)) / 8.0, 0, 1)
    cut *= (t * t * (3 - 2 * t))[:, None]
    a = np.array(im.convert("RGBA")).astype(np.float32)
    h, w = a.shape[:2]; x0, y0 = e["pos"]
    C = cut[y0:y0 + h, x0:x0 + w]
    C = np.pad(C, ((0, h - C.shape[0]), (0, w - C.shape[1])))
    if rel.endswith(".aux.png"):
        a[..., 0] *= (1.0 - C)          # R = 保留发丝；G（脸部保护）不变
    else:
        a[..., 3] *= (1.0 - C)
    out = Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")
    return out.convert("RGB") if im.mode == "RGB" else out


# ---------------------------------------------------------------- v0.9.3：发髻里夹带的“底模衣袍幽灵线”
def _body_fill(base):
    """底头（烘焙原图，未抹纸色）下巴以下的白衣身子：连成片后填实，返回 0/1 掩码。"""
    import cv2, os
    rgb = np.array(Image.open(os.path.join(SRC, "heads", base + ".jpg")).convert("RGB")).astype(np.float32)
    y0 = int(LIB["heads"][base]["anchors"]["mouth"][1] + 28)
    bg = np.concatenate([rgb[:150, :50].reshape(-1, 3), rgb[:150, -50:].reshape(-1, 3)]).mean(0)
    body = (np.abs(rgb - bg).max(-1) > 14).astype(np.uint8)
    body[:y0] = 0
    body = cv2.morphologyEx(body, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(body, 8)
    big = np.isin(lab, [i for i in range(1, n) if st[i, cv2.CC_STAT_AREA] > 3000]).astype(np.uint8)
    ff = big.copy(); h, w = ff.shape; m = np.zeros((h + 2, w + 2), np.uint8)
    for p in [(0, 0), (w - 1, 0), (0, min(h - 1, y0 + 40)), (w - 1, min(h - 1, y0 + 40))]:
        if ff[p[1], p[0]] == 0:
            cv2.floodFill(ff, m, p, 2)
    filled = (ff != 2).astype(np.uint8)
    filled[:y0] = 0
    return filled


def fix_hair_ghost(rel, im):
    """发髻/发饰是在穿白衣的底模上改画、再与底图做差抠出来的；AI 改画时把整件白衣的墨线也轻轻重描了一遍，
    抠出来就成了一层淡淡的黑线（领口、肩线、衣褶）压在任何衣袍上面——新画的窄肩衣袍外面能看到一道“第二条肩线”。
    这里把底模衣身范围内、不属于成缕头发的淡线去掉（成片的发丝和单缕实心发丝都保留，边缘羽化）。"""
    import cv2, os
    stem = os.path.basename(rel)[:-4]
    key = stem.replace("-base_", "@base_")
    e = LIB["parts"].get(key)
    if e is None:
        return im
    base = key.split("@")[1]
    a = np.array(im.convert("RGBA"))
    h, w = a.shape[:2]; x0, y0 = e["pos"]
    F = _body_fill(base)[y0:y0 + h, x0:x0 + w]
    F = np.pad(F, ((0, h - F.shape[0]), (0, w - F.shape[1])))
    region = cv2.dilate(F, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15))) > 0
    al = a[..., 3]
    mass = cv2.morphologyEx((al > 120).astype(np.uint8), cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)))
    n, lab, st, _ = cv2.connectedComponentsWithStats((al > 150).astype(np.uint8), 8)
    strands = np.isin(lab, [i for i in range(1, n) if st[i, cv2.CC_STAT_AREA] >= 60])
    keep = cv2.dilate(((mass > 0) | strands).astype(np.uint8), np.ones((5, 5), np.uint8)).astype(np.float32)
    keep = cv2.GaussianBlur(keep, (0, 0), 1.2)
    k = np.where(region, np.clip(keep * 1.4, 0, 1), 1.0)
    a[..., 3] = (al.astype(np.float32) * k).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


# ---------------------------------------------------------------- v0.7.9：脸不“变形”、衣袍不露底
# 由 make_portrait_web.py 设置：LIB = 烘焙目录的 lib5.json（dict），SRC = 烘焙目录
LIB = None
SRC = None
_feat_ix = None
_head_cache = {}


def _feat_index():
    global _feat_ix
    if _feat_ix is None:
        _feat_ix = {}
        for k, e in LIB["feats"].items():
            fid, base, st = k.split("|")
            _feat_ix[e["tex"]] = (fid.split(":")[0], base, st, e["pos"], fid)
    return _feat_ix


def _ink(L):
    """深色线条的强度：局部亮度上限（7×7 闭运算）减本身。"""
    import cv2
    return np.clip(cv2.morphologyEx(L, cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8)).astype(float) - L, 0, None)


def _head(base):
    if base not in _head_cache:
        import os
        h = np.array(Image.open(os.path.join(SRC, "heads", base + ".jpg")).convert("RGB")).astype(float)
        _head_cache[base] = h
    return _head_cache[base]


def _gap_row(a, base, pos, y0, y1):
    """两处五官之间最“空”的一行（画布坐标）：贴片合成后的墨 + 底头原生的墨，按行求和取最小。"""
    import cv2
    h = _head(base)
    ph, pw = a.shape[:2]
    x, y = pos
    crop = h[y:y + ph, x:x + pw]
    al = a[..., 3:4].astype(float) / 255.0
    comp = a[..., :3].astype(float) * al + crop * (1 - al)
    lum = lambda c: (c @ np.array([0.299, 0.587, 0.114])).astype(np.uint8)
    ink = _ink(lum(comp)) + _ink(lum(crop))
    prof = ink.sum(1)
    prof = np.convolve(prof, np.ones(3) / 3, mode="same")
    r0, r1 = max(0, int(round(y0 - y))), min(ph - 1, int(round(y1 - y)))
    if r1 <= r0:
        return None
    return y + r0 + int(np.argmin(prof[r0:r1 + 1]))


def _ramp(a, pos, cut, keep_below, soft=5.0):
    ys = np.arange(a.shape[0])[:, None] + pos[1]
    w = np.clip((ys - (cut - soft / 2)) / soft, 0, 1) if keep_below else np.clip(((cut + soft / 2) - ys) / soft, 0, 1)
    a = a.copy()
    a[..., 3] = (a[..., 3].astype(float) * w).astype(np.uint8)
    return a


_cuts = {}


def fix_feat(rel, im):
    """五官贴片只留自己那一段：原位编辑时连带画进来的相邻五官（眼片里的眉、嘴片里的鼻底、眉片里的眼皮）
    叠在另一张脸上就是“双眉/双鼻孔/双眼皮线”——脸看着变形的主要原因。在两处五官之间最空的一行处羽化切掉。
    同一贴片的睁/半闭/闭三帧用睁眼帧算出的切线，免得眨眼时眉毛跳动。"""
    ix = _feat_index()
    if rel not in ix:
        return im
    reg, base, st, pos, fid = ix[rel]
    A = LIB["heads"][base]["anchors"]
    by, ey, ny, my = A["brows"][1], A["eyes"][1], A["nose"][1], A["mouth"][1]
    a = np.array(im.convert("RGBA"))
    key = (reg, fid, base)
    if key not in _cuts:
        src = a
        if st != "open":
            ok = "%s|%s|open" % (fid, base)
            if ok in LIB["feats"]:
                import os
                src = np.array(Image.open(os.path.join(SRC, LIB["feats"][ok]["tex"])).convert("RGBA"))
                pos_o = LIB["feats"][ok]["pos"]
            else:
                pos_o = pos
        else:
            pos_o = pos
        c = {}
        if reg in ("eyes", "brows"):
            c["be"] = _gap_row(src, base, pos_o, by + 3, ey - 6)
        if reg in ("mouth", "nose"):
            c["nm"] = _gap_row(src, base, pos_o, ny + 7, my - 6)
        if reg == "nose":
            c["en"] = _gap_row(src, base, pos_o, ey + 6, ny - 13)
        _cuts[key] = c
    c = _cuts[key]
    if reg == "eyes" and c.get("be") is not None:
        a = _ramp(a, pos, c["be"], True)
    if reg == "brows" and c.get("be") is not None:
        a = _ramp(a, pos, c["be"], False)
    if reg == "mouth" and c.get("nm") is not None:
        a = _ramp(a, pos, c["nm"], True)
    if reg == "nose":
        if c.get("nm") is not None:
            a = _ramp(a, pos, c["nm"], False)
        if c.get("en") is not None:
            a = _ramp(a, pos, c["en"], True, soft=8.0)
    return Image.fromarray(a, "RGBA")


def fix_head(rel, im):
    """底头的白衣身子（下巴以下、颈部皮肤以外）抹成纸色：衣袍是在 base_f / base_m 上画的，
    换到肩更宽的脸型（f5、m2 等）时，底头自己的肩线会从衣袍外面露出一道白边（“衣服像贴上去的”）。
    抹掉后衣袍外面只剩纸，衣袍边缘也不再叠着底头的线。"""
    import cv2, os
    base = os.path.basename(rel).split(".")[0]
    A = LIB["heads"][base]["anchors"]
    y0 = int(A["mouth"][1] + 28)
    rgb = np.array(im.convert("RGB")).astype(float)
    m = np.array(Image.open(os.path.join(SRC, "heads", base + ".mask.png")).convert("RGBA"))
    skin = (m[..., 0] > 100).astype(np.uint8)
    skin = cv2.dilate(skin, np.ones((9, 9), np.uint8))
    body = np.zeros(skin.shape, np.float32)
    body[y0:] = 1.0
    body[skin > 0] = 0.0
    ramp = np.clip((np.arange(rgb.shape[0]) - y0) / 10.0, 0, 1)[:, None]
    body = cv2.GaussianBlur(body, (0, 0), 1.5) * ramp
    bg = np.concatenate([rgb[:150, :50].reshape(-1, 3), rgb[:150, -50:].reshape(-1, 3)]).mean(0)
    rs = np.random.RandomState(7)
    paper = bg[None, None, :] + rs.normal(0, 1.0, rgb.shape)
    out = rgb * (1 - body[..., None]) + paper * body[..., None]
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), "RGB")


def fix_cloth(rel, im):
    """衣袍/外氅抠图时在两侧背景里留下的碎点（半透明小斑，配合纸色重绘会显成一块块发白的斑纹）：
    只保留连成大片的部分。"""
    import cv2
    a = np.array(im.convert("RGBA"))
    al = a[..., 3]
    solid = (al > 40).astype(np.uint8)
    op = cv2.morphologyEx(solid, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(op, 8)
    keep = np.zeros(al.shape, np.uint8)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] >= 1500:
            keep[lab == i] = 1
    keep = cv2.dilate(keep, np.ones((7, 7), np.uint8))
    keep = cv2.GaussianBlur(keep.astype(np.float32), (0, 0), 1.0)
    al = al.astype(np.float32) * np.clip(keep * 1.5, 0, 1)
    # 纸色重绘带（.paper.png）本来是盖住底头露出来的白肩线的；底头的身子已抹成纸色（fix_head），
    # 这里改成：纸带与外缘发白的一圈不算衣料——取剩下的衣料轮廓，闭运算抹平缺口当新的边，
    # 边内原来是纸带/白边的像素用周围衣料的颜色补（不挖洞，外侧那道线成了衣袍的轮廓线）
    import os
    pp = os.path.join(SRC, rel.replace(".png", ".paper.png"))
    paper = np.zeros(al.shape, np.float32)
    if os.path.exists(pp):
        pa = np.array(Image.open(pp).convert("L")).astype(np.float32) / 255.0
        if pa.shape == al.shape:
            paper = pa
    inside = (al > 40).astype(np.uint8)
    dist = cv2.distanceTransform(inside, cv2.DIST_L2, 3)
    L = a[..., :3].astype(np.float32) @ np.array([0.299, 0.587, 0.114], np.float32)
    light = ((dist > 0) & (dist <= 4) & (L > 214)) | (paper > 0.3)
    cloth = (inside > 0) & ~light
    ell = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    sil = cv2.morphologyEx(cloth.astype(np.uint8), cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7)))
    n2, lab2, st2, _ = cv2.connectedComponentsWithStats(sil, 8)
    sil = np.isin(lab2, [i for i in range(1, n2) if st2[i, cv2.CC_STAT_AREA] >= 1500]).astype(np.uint8)
    sil = cv2.morphologyEx(sil, cv2.MORPH_CLOSE, ell)
    silf = cv2.GaussianBlur(sil.astype(np.float32), (0, 0), 0.7)
    a[..., 3] = np.minimum(al, silf * 255.0).astype(np.uint8)
    fillm = ((light | (inside == 0)) & (sil > 0)).astype(np.uint8)
    if fillm.any():
        bgr = np.ascontiguousarray(a[..., 2::-1])
        bgr = cv2.inpaint(bgr, cv2.dilate(fillm, np.ones((3, 3), np.uint8)), 4, cv2.INPAINT_TELEA)
        a[..., :3] = bgr[..., ::-1]
        a[..., 3] = np.maximum(a[..., 3], (fillm * silf * 255.0).astype(np.uint8))
    return Image.fromarray(a, "RGBA")


# ---------------------------------------------------------------- v0.14.3：抠边去白（衣袍/外披/头发/饰品）
# 根因：部件是“重绘图 − 人台”差分抠出来的，半透明边缘像素的 RGB 仍是合成色（≈ 纸色 235,231,224），
# alpha=0 处也是纸色。游戏里按直通 alpha 双线性放大、再做袍色 tint（亮于 ref 的往白里推），
# 这一圈纸色就成了衣服外缘的白边，头发边缘发灰。
# 做法：① 用 pymatting 的多级前景估计（Germer et al. 2020，MIT）把半透明像素的颜色还原成布料/墨色本身，
#       并把前景色平滑地延伸进透明区（等于 Godot 导入时的 fix_alpha_border，运行期 put() 没有这一步）；
#       ② 布料（袍/披，纱披 outer_f1 除外）把墨线外那圈很淡的差分噪声收掉一点（alpha 收边）。
# 保存 WebP 时用 exact=True，透明区的颜色不被编码器改回去。
def defringe(rel, im):
    if im.mode != "RGBA":
        return im
    from pymatting import estimate_foreground_ml
    a = np.array(im).astype(np.float64) / 255.0
    al = a[..., 3].copy()
    cloth = rel.startswith(("parts/robe_", "parts/outer_")) and "outer_f1-" not in rel
    if cloth:
        al = np.clip((al - 0.12) / 0.76, 0.0, 1.0)
    if al.max() <= 0:
        return im
    fg = estimate_foreground_ml(a[..., :3], al)
    out = np.dstack([np.clip(fg, 0, 1), al])
    return Image.fromarray((out * 255.0 + 0.5).astype(np.uint8), "RGBA")


def needs_defringe(rel):
    if rel.endswith((".mask.png", ".aux.png", ".paper.png")) or ".jpg" in rel:
        return False
    # 胡须、花钿/痣/疤画在脸上（底下是皮肤不是纸），不做
    return rel.startswith(("parts/robe_", "parts/outer_", "parts/hair_", "parts/acc_"))
