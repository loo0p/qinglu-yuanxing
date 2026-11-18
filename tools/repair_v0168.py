#!/usr/bin/env python3
"""v0.16.8 立绘修补（直接改发布用的 web_portrait，可重复跑）。

根因：
- 底脸已经画了淡眉，眉贴片又用羽化椭圆叠上去。贴片上沿是一条发灰、发毛的暗边，
  和底眉错开半截，看起来每只眼睛上有两层眉。这里把眉贴片改成「底眉那一带用肤色盖住，
  只留一道眉线」，羽化落在肤色上，不再带出第二道毛边。
- outer_f4 毛领两侧各竖起一根白毛尖，像牛角。把高出肩线的尖角削平，领口贴着肩。
- 长发内部有大量半透明像素，袍色会从头发里透出来。发束内部改为不透明，只留外缘一圈抗锯齿。
- 换到别的脸上时，头部遮罩 G 通道是一块硬边梯形，压在脸颈上像一块矩形补丁。
  把这条边羽化开。下颌到锁骨的肤色若有一块突兀的色阶，顺着周围肤色抹平，墨线留下。
- base_f3 底脸的眉是一道又细又浅的描边，放大后中段发白、像上下两道。眉区先用周围肤色软补，
  再按 base_f 的实心墨眉重画。男女十二张底脸都对过，只有这一张是描边眉。
- 长发在画布 y≈237（下颌到颈）前后两层硬接，接缝下方发色突然变黑。耳旁另有一块几乎没有纹理的
  深色长方形（hair_f6 最明显）。平掉这块，并把接缝处的发色顺着上面那一层软接上。

用法：python3 tools/repair_v0168.py apply | sheets
"""
import os, sys, json
import numpy as np
import cv2
from PIL import Image, ImageDraw

R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WP = os.path.join(R, "web_portrait")
LIBP = os.path.join(R, "data/lib5.json")
DOCS = os.path.join(R, "docs/art/v0168")
LUM = np.array([0.299, 0.587, 0.114], np.float32)


def webp(rel):
    return os.path.join(WP, os.path.splitext(rel)[0] + ".webp")


def load_rgba(rel):
    return np.array(Image.open(webp(rel)).convert("RGBA"))


def save_webp(rel, im, lossless=False):
    p = webp(rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img = Image.fromarray(im)
    if lossless or rel.endswith((".mask.png", ".aux.png")):
        img.save(p, "WEBP", lossless=True, quality=100, method=6)
    else:
        img.save(p, "WEBP", quality=90, method=6, exact=True)


def Lof(rgb):
    return rgb[..., :3].astype(np.float32) @ LUM


def repair_brow(head, patch, pos):
    """眉贴片盖住底脸眉区，只留一道眉。返回 RGBA。"""
    x, y = int(pos[0]), int(pos[1])
    ph, pw = patch.shape[:2]
    H, W = head.shape[:2]
    if y < 0 or x < 0 or y + ph > H or x + pw > W:
        return patch
    src = head[y:y + ph, x:x + pw].astype(np.float32)
    Ls = Lof(src)
    ker = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 7))
    bg = cv2.dilate(Ls.astype(np.uint8), ker).astype(np.float32)
    native = ((bg - Ls) > 12) & (Ls < 190)
    native[:2] = False
    native[-3:] = False
    ink = (native.astype(np.uint8) * 255)
    if int(ink.sum()) > 40:
        bgr = cv2.cvtColor(np.clip(src, 0, 255).astype(np.uint8), cv2.COLOR_RGB2BGR)
        hole = cv2.dilate(ink, np.ones((3, 3), np.uint8))
        skin = cv2.cvtColor(cv2.inpaint(bgr, hole, 3, cv2.INPAINT_TELEA), cv2.COLOR_BGR2RGB).astype(np.float32)
    else:
        skin = src.copy()
    pa = patch[..., 3].astype(np.float32)
    pr = patch[..., :3].astype(np.float32)
    pL = Lof(pr)
    core = (pa > 160) & (pL < 118)
    n, lab, st, _ = cv2.connectedComponentsWithStats(core.astype(np.uint8), 8)
    keep = np.zeros(core.shape, bool)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] >= 8:
            keep |= lab == i
    core = keep
    if not core.any() and not native.any():
        return patch
    ring = (cv2.dilate(core.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0) & ~core
    rgb = skin.copy()
    if core.any():
        rgb[core] = pr[core]
        rgb[ring] = skin[ring] * 0.42 + pr[ring] * 0.58
    rows = np.where((native | core).any(1))[0]
    xs = np.where((native | core).any(0))[0]
    cover = np.zeros((ph, pw), np.float32)
    if len(rows) and len(xs):
        yA = max(0, int(rows.min()) - 3)
        yB = min(ph, int(rows.max()) + 2)
        # 贴片最底下几行靠近眼皮，不要用肤色盖住
        yB = min(yB, ph - 3)
        xA = max(0, int(xs.min()) - 2)
        xB = min(pw, int(xs.max()) + 3)
        if yB > yA:
            cover[yA:yB, xA:xB] = 1
    if core.any():
        cover = np.maximum(cover, cv2.dilate(core.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(np.float32))
    blur = cv2.GaussianBlur(cover, (0, 0), 1.15)
    af = np.where(cover > 0.5, 1.0, np.clip(blur * 1.15, 0, 1))
    # 羽化区用肤色，避免黑边
    out = np.zeros_like(patch)
    out[..., :3] = np.clip(rgb, 0, 255)
    out[..., 3] = np.clip(af * 255.0, 0, 255).astype(np.uint8)
    return out


def repair_outer_horns(im):
    """削掉领口两侧竖起的毛尖。只动比左右肩线高出一截的尖角，肩线本身不动。"""
    a = im[..., 3]
    tops = np.full(im.shape[1], -1, np.int32)
    for x in range(im.shape[1]):
        ys = np.where(a[:, x] > 40)[0]
        if len(ys):
            tops[x] = int(ys[0])
    peaks = []
    for x in range(28, im.shape[1] - 28):
        if tops[x] < 0:
            continue
        neigh = [tops[x + k] for k in (-28, -20, -14, 14, 20, 28) if tops[x + k] >= 0]
        if len(neigh) < 4:
            continue
        if tops[x] < np.median(neigh) - 16:
            peaks.append(x)
    if not peaks:
        return im
    groups = []
    for x in peaks:
        if not groups or x > groups[-1][-1] + 4:
            groups.append([x])
        else:
            groups[-1].append(x)
    out = im.copy()
    for g in groups:
        if len(g) < 6:
            continue
        x0, x1 = g[0], g[-1]
        yl = int(tops[max(0, x0 - 6)])
        yr = int(tops[min(len(tops) - 1, x1 + 6)])
        if yl < 0 or yr < 0:
            continue
        tip = int(tops[g].min())
        # 尖必须明显高于两侧肩点，免得把正常的肩斜面削掉
        if tip > min(yl, yr) - 20:
            continue
        xs = np.arange(x0, x1 + 1)
        t = (xs - x0) / max(1, x1 - x0)
        yline = (yl * (1 - t) + yr * t).astype(np.int32)
        for x, yc in zip(xs, yline):
            fade = np.clip((np.arange(out.shape[0]) - (int(yc) - 2)) / 3.0, 0, 1)
            out[:, x, 3] = (out[:, x, 3].astype(np.float32) * fade).astype(np.uint8)
    return out


def repair_hair_soft(im):
    """发束内部用平滑曲线把半透明收上去，外缘 3px 保持原来的羽化。

    不用一个 alpha 阈值硬切：硬切会让发梢变成墨块，缩放后外缘发灰发白。
    透明像素若带着浅色，线性采样会出白边，这里把发色渗进边缘。浅色发带不动。
    """
    rgb = im[..., :3].astype(np.float32)
    a = im[..., 3].astype(np.float32) / 255.0
    if (a > 0.12).sum() < 80:
        return im
    L = Lof(rgb)
    dist = cv2.distanceTransform((a > 0.04).astype(np.uint8), cv2.DIST_L2, 3)
    # 外缘 3px 原样。再往里 4px 用 smoothstep 把剩下的透明度收到约 2%。
    # 细过 6px 的发梢整段都在外缘里，不会被收成墨块。
    t = np.clip((dist - 3.0) / 4.0, 0.0, 1.0)
    s = t * t * (3.0 - 2.0 * t)
    a2 = np.where(dist < 3.0, a, 1.0 - (1.0 - a) * (1.0 - 0.98 * s))
    # 发带、红丝这类成块的浅色/有色饰物不改颜色
    sat = rgb.max(-1) - rgb.min(-1)
    solid_light = ((L > 150) & (a > 0.7)).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(solid_light, 8)
    keep = np.zeros(a.shape, bool)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] >= 36:
            keep |= lab == i
    keep = cv2.dilate(keep.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
    # 把发色渗进低透明度的一圈，免得和纸色一插值就出白边
    core = (a > 0.55) & (L < 110) & ~keep
    if core.sum() > 40:
        ink = np.median(rgb[core], axis=0)
    else:
        ink = np.array([28.0, 26.0, 24.0], np.float32)
    rim = cv2.dilate((a > 0.08).astype(np.uint8), np.ones((7, 7), np.uint8)) > 0
    pale = rim & (a < 0.35) & (L > 90) & (sat < 28) & ~keep
    rgb2 = rgb.copy()
    rgb2[pale] = ink
    # 近乎全透明、又贴着发丝的像素，颜色跟发丝走（线性采样不会捞到浅色）
    near = rim & (a < 0.08) & ~keep
    rgb2[near] = ink
    out = np.zeros_like(im)
    out[..., :3] = np.clip(rgb2, 0, 255)
    out[..., 3] = np.clip(a2 * 255.0 + 0.5, 0, 255).astype(np.uint8)
    return out


def feather_mask_g(im):
    """G 通道是换脸时用来压头发的脸颈保护区，硬边会像一块矩形补丁。只羽化边缘。"""
    g = im[..., 1].astype(np.float32)
    if g.max() < 20:
        return im
    soft = cv2.GaussianBlur(g, (0, 0), 8)
    mixed = g.copy()
    mixed[g < 230] = soft[g < 230]
    out = im.copy()
    out[..., 1] = np.clip(mixed, 0, 255).astype(np.uint8)
    return out


def smooth_neck(im, mask, mouth_y):
    """下颌到锁骨：低频肤色抹匀，领口墨线（高频）留下。去掉一块发方的色差。"""
    rgb = im[..., :3].astype(np.float32)
    skin = mask[..., 0] > 140
    y0 = int(mouth_y + 10)
    y1 = int(min(im.shape[0] - 2, mouth_y + 62))
    if y1 <= y0 + 8:
        return im
    hole = np.where(skin, 0, 255).astype(np.uint8)
    bgr = cv2.cvtColor(np.clip(rgb, 0, 255).astype(np.uint8), cv2.COLOR_RGB2BGR)
    filled = cv2.cvtColor(cv2.inpaint(bgr, hole, 6, cv2.INPAINT_TELEA), cv2.COLOR_BGR2RGB).astype(np.float32)
    low = cv2.GaussianBlur(filled, (0, 0), 11)
    detail = rgb - cv2.GaussianBlur(filled, (0, 0), 2.2)
    merged = np.clip(low + detail, 0, 255)
    yy = np.arange(im.shape[0])[:, None]
    band = (yy >= y0) & (yy <= y1) & skin
    # 带的上下缘淡入，免得出新的横线
    w = np.zeros(im.shape[:2], np.float32)
    w[band] = 1
    w = cv2.GaussianBlur(w, (0, 0), 4)
    w = w[..., None]
    out = im.copy()
    out[..., :3] = np.clip(rgb * (1 - w) + merged * w, 0, 255).astype(np.uint8)
    return out


# 十二张底脸都看过眉：只有 base_f3 是细描边（中段发白，像两道）。
# 其余是实心墨眉，或老人的淡眉，不再重画。
HOLLOW_BROWS = ("base_f3",)


def _brow_band(shape, anchors):
    by, bx = int(anchors["brows"][1]), int(anchors["brows"][0])
    ey = int(anchors["eyes"][1])
    H, W = shape
    y0, y1 = max(0, by - 11), min(H, min(by + 8, ey - 6))
    x0, x1 = max(0, bx - 78), min(W, bx + 78)
    return y0, y1, x0, x1


def _already_solid_brow(rgb, anchors):
    """和 base_f 一样：多数列有至少 3 个像素压到 L<140。细描边只有一两像素。"""
    L = Lof(rgb)
    by, bx = int(anchors["brows"][1]), int(anchors["brows"][0])
    thick = 0
    cols = 0
    for x in range(max(0, bx - 55), min(L.shape[1], bx + 55)):
        col = L[by - 4:by + 5, x]
        if col.min() > 155:
            continue
        cols += 1
        if int((col < 140).sum()) >= 3:
            thick += 1
    return cols > 0 and thick >= int(cols * 0.55)


def solidify_brow(rgb, anchors):
    """描边眉改成一道实心墨眉：眉区用周围肤色软补（不留方块、不留浅色擦痕），再沿原来的弧画一道。"""
    if _already_solid_brow(rgb, anchors):
        return rgb
    src = rgb.astype(np.float32)
    L = Lof(src)
    y0, y1, x0, x1 = _brow_band(L.shape, anchors)
    H, W = L.shape
    bg = cv2.dilate(L.astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (21, 11))).astype(np.float32)
    ink = np.zeros(L.shape, bool)
    ink[y0:y1, x0:x1] = (bg[y0:y1, x0:x1] - L[y0:y1, x0:x1] > 12) & (L[y0:y1, x0:x1] < 180)
    ink = cv2.morphologyEx(ink.astype(np.uint8), cv2.MORPH_OPEN, np.ones((2, 2), np.uint8)) > 0
    n, lab, st, _ = cv2.connectedComponentsWithStats(ink.astype(np.uint8), 8)
    keep = np.zeros(ink.shape, bool)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] >= 12:
            keep |= lab == i
    ink = keep
    if int(ink.sum()) < 30:
        return rgb
    xs, cy = [], []
    for x in range(x0, x1):
        ys = np.where(ink[:, x])[0]
        if len(ys) < 1:
            continue
        w = np.clip(bg[ys, x] - L[ys, x], 1, None)
        xs.append(x)
        cy.append(float(np.average(ys, weights=w)))
    if len(xs) < 12:
        return rgb
    xs = np.array(xs, np.float32)
    cy = np.array(cy, np.float32)
    k = np.array([1, 2, 4, 6, 4, 2, 1], np.float32)
    k /= k.sum()
    cy = np.convolve(np.pad(cy, (3, 3), mode="edge"), k, mode="valid")
    hole = cv2.dilate(ink.astype(np.uint8), np.ones((3, 3), np.uint8)) * 255
    bgr = cv2.cvtColor(np.clip(src, 0, 255).astype(np.uint8), cv2.COLOR_RGB2BGR)
    filled = cv2.cvtColor(cv2.inpaint(bgr, hole, 4, cv2.INPAINT_TELEA), cv2.COLOR_BGR2RGB).astype(np.float32)
    soft = cv2.GaussianBlur(hole.astype(np.float32) / 255.0, (0, 0), 1.15)[..., None]
    base = src * (1 - soft) + filled * soft
    dark = L[ink] < np.percentile(L[ink], 30)
    cols = np.where(ink)
    ink_rgb = np.median(src[cols[0][dark], cols[1][dark]], axis=0) if int(dark.sum()) > 8 else np.array([110, 98, 90], np.float32)
    ink_rgb = np.array(ink_rgb, np.float32)
    # 描边眉本身偏浅。压到和 base_f 核心差不多的墨色，避免又画出一道发白的细线。
    ink_L = float(ink_rgb @ LUM)
    if ink_L > 96:
        ink_rgb = ink_rgb * (92.0 / max(ink_L, 1.0))
    # 中间约 3px 铺实，外面再收，避免又剩成一根发白的细线。
    out = base.copy()
    ys_all = np.arange(H)
    for x, yc in zip(xs.astype(int), cy):
        if x < 0 or x >= W:
            continue
        ad = np.abs(ys_all - yc)
        wgt = np.where(ad <= 1.15, 1.0, np.exp(-0.5 * ((ad - 1.15) / 0.95) ** 2))
        wgt[:y0] = 0
        wgt[y1:] = 0
        kblend = wgt * 0.96
        out[:, x] = out[:, x] * (1 - kblend)[:, None] + ink_rgb * kblend[:, None]
    return np.clip(out, 0, 255).astype(np.uint8)


def _local_std(L):
    k = np.ones((5, 5), np.float32) / 25.0
    mean = cv2.filter2D(L, -1, k)
    sq = cv2.filter2D(L * L, -1, k)
    return np.sqrt(np.clip(sq - mean * mean, 0, None))


def heal_flat_blocks(im, pos):
    """耳旁那块没有纹理的深色长方：用上方有发丝的颜色顺着铺下来，边缘羽化。

    根因是前后发层在下颌旁接死，接缝上方留了一块几乎纯色的填充（hair_f6 左右各一块，
    画布 y 约 175–235）。旁边没有头发可借，只能从这块上方的发丝往下接。
    """
    rgb = im[..., :3].astype(np.float32).copy()
    a = im[..., 3].astype(np.float32)
    H, W = rgb.shape[:2]
    py = int(pos[1])
    L = Lof(rgb)
    std = _local_std(L)
    flat = ((std < 2.6) & (L < 34) & (a > 200)).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(flat, 8)
    hits = 0
    for i in range(1, n):
        x, y, w, h, area = st[i]
        if area < 120 or w < 8 or h < 14 or area / float(w * h) < 0.40:
            continue
        if (y + py) > 320 or (y + h + py) < 95:
            continue
        comp = lab == i
        yA = max(0, y - 22)
        if y - yA < 8:
            continue
        src = rgb[yA:y]
        src_a = a[yA:y]
        sh = src.shape[0]
        painted = np.zeros((H, W), bool)
        for xx in range(x, x + w):
            if not comp[:, xx].any():
                continue
            sm = src_a[:, xx] > 150
            if int(sm.sum()) < 5:
                continue
            med_src = np.median(src[:, xx][sm], 0)
            dev = src[:, xx] - med_src
            yB = min(H - 1, y + h + 10)
            bm = a[y + h:yB, xx] > 150
            med_below = np.median(rgb[y + h:yB, xx][bm], 0) if int(bm.sum()) >= 3 else med_src
            # 下方本来就比脸侧发丝深一档。只接上半截的落差，不要把整缕发漂成同一个浅灰。
            med_below = med_src * 0.45 + med_below * 0.55
            ys = np.where(comp[:, xx])[0]
            y0s, y1s = int(ys.min()), int(ys.max())
            span = max(1, y1s - y0s)
            for yy in ys:
                t = (yy - y0s) / span
                t = t * t * (3 - 2 * t)
                base = med_src * (1 - t) + med_below * t
                rgb[yy, xx] = base + dev[(yy - y0s) % sh] * 0.55
                painted[yy, xx] = True
        if not painted.any():
            continue
        inner = cv2.distanceTransform(painted.astype(np.uint8), cv2.DIST_L2, 3)
        rim = painted & (inner < 4)
        blur = cv2.GaussianBlur(rgb, (0, 0), 1.3)
        rgb[rim] = rgb[rim] * 0.4 + blur[rim] * 0.6
        hits += 1
    out = im.copy()
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    return out, hits


def heal_neck_seam(im, pos):
    """画布 y≈237 的横缝：下面那一层突然更黑。只抬低频，发丝纹理留着，十几像素内软接上。"""
    rgb = im[..., :3].astype(np.float32).copy()
    a = im[..., 3].astype(np.float32)
    H, W = a.shape
    py = int(pos[1])
    L = Lof(rgb)
    sat = rgb.max(-1) - rgb.min(-1)
    ornament = ((L > 150) & (a > 150)) | ((sat > 30) & (L > 120) & (a > 150))
    ornament = cv2.dilate(ornament.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
    seam_y = np.full(W, -1, np.int32)
    for x in range(W):
        best, by = 0.0, -1
        for y in range(4, H - 6):
            yc = y + py
            if yc < 220 or yc > 262:
                continue
            if a[y, x] < 150 or a[y - 1, x] < 150:
                continue
            if ornament[y, x] or ornament[y - 1, x]:
                continue
            drop = float(L[y - 1, x] - L[y, x])
            if drop > best:
                best, by = drop, y
        if best >= 8 and a[min(H - 1, by + 5), x] > 140 and L[min(H - 1, by + 5), x] < L[by - 1, x] - 5:
            seam_y[x] = by
    detected = seam_y[seam_y > 0]
    if len(detected) < 10:
        return im, 0
    consensus = int(np.median(detected))
    # 只要这一行左右都有人接缝，整条头发在这一行的下跌都算，不要漏掉耳旁那几列特别黑的。
    agree = np.zeros(W, bool)
    for x in range(W):
        if ornament[:, x].mean() > 0.4:
            continue
        for y in (consensus - 1, consensus, consensus + 1):
            if y < 2 or y >= H - 2:
                continue
            if a[y, x] < 150 or a[y - 1, x] < 150:
                continue
            if float(L[y - 1, x] - L[y, x]) >= 6:
                agree[x] = True
                seam_y[x] = y
                break
    if int(agree.sum()) < 10:
        return im, 0
    for x in np.where(agree)[0]:
        y = int(seam_y[x])
        cols = []
        for dx in (-3, -2, -1, 0, 1, 2, 3):
            xx = x + dx
            if not (0 <= xx < W and agree[xx]):
                continue
            for back in (6, 5, 4):
                yy = int(seam_y[xx]) - back
                if yy >= 1 and a[yy, xx] > 140 and not ornament[yy, xx]:
                    cols.append(rgb[yy, xx])
                    break
        if len(cols) < 3:
            continue
        src = np.median(cols, 0)
        src_L = float(src @ LUM)
        # 接缝上方若有一条发亮的棱，一并收进周围发色，免得留下一道白线
        for back in (1, 2):
            yy = y - back
            if yy < 0 or a[yy, x] < 140 or ornament[yy, x]:
                continue
            if float(rgb[yy, x] @ LUM) > src_L + 4:
                rgb[yy, x] = rgb[yy, x] * 0.35 + src * 0.65
        for dy in range(0, 32):
            yy = y + dy
            if yy >= H or a[yy, x] < 140 or ornament[yy, x]:
                continue
            w = 0.9 if dy < 14 else 0.9 * max(0.0, 1.0 - (dy - 14) / 18.0)
            cur = rgb[yy, x]
            if float(cur @ LUM) > src_L - 3:
                continue
            rgb[yy, x] = cur * (1 - w) + src * w
    out = im.copy()
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    return out, int(agree.sum())


def heal_alpha_notch(im, pos):
    """下颌高度发际若先拉成一条直线、再突然往里收一截，就是矩形缺口。顺着原来的边软补回去。"""
    rgb = im[..., :3].astype(np.float32).copy()
    a = im[..., 3].astype(np.float32).copy()
    H, W = a.shape
    px, py = int(pos[0]), int(pos[1])
    cx = 216 - px
    n = 0
    for side in ("L", "R"):
        edge = np.full(H, -1, np.int32)
        for y in range(H):
            xs = np.where(a[y] > 80)[0]
            if side == "L":
                xs = xs[xs < cx]
                if len(xs):
                    edge[y] = int(xs.max())
            else:
                xs = xs[xs > cx]
                if len(xs):
                    edge[y] = int(xs.min())
        best = None
        y = 0
        while y < H - 16:
            if edge[y] < 0:
                y += 1
                continue
            y1 = y
            while y1 < H and edge[y1] >= 0 and abs(int(edge[y1]) - int(edge[y])) <= 1:
                y1 += 1
            run = y1 - y
            yc = y + py
            if run >= 16 and y1 < H and edge[y1] >= 0 and 190 <= yc <= 250:
                jump = int(edge[y]) - int(edge[y1]) if side == "L" else int(edge[y1]) - int(edge[y])
                if jump >= 8 and (best is None or jump > best[0]):
                    best = (jump, y, y1, int(edge[y]), int(edge[y1]))
            y = max(y + 1, y1 if y1 > y else y + 1)
        if best is None:
            continue
        jump, y0, y1, old_e, new_e = best
        for yy in range(y1, min(H, y1 + jump + 6)):
            if edge[yy] < 0:
                continue
            t = min(1.0, (yy - y1) / float(jump))
            t = t * t * (3 - 2 * t)
            dest = int(round(old_e * (1 - t) + edge[yy] * t))
            src_x = int(edge[yy])
            if side == "L":
                span = range(src_x + 1, dest + 1)
            else:
                span = range(dest, src_x)
            for xx in span:
                if not (0 <= xx < W) or a[yy, src_x] < 80:
                    continue
                dist = abs(xx - src_x)
                fade = float(np.exp(-0.5 * (dist / 3.4) ** 2))
                if a[yy, xx] >= 255 * fade:
                    continue
                rgb[yy, xx] = rgb[yy, src_x]
                a[yy, xx] = max(a[yy, xx], 255.0 * fade)
        n += 1
    out = im.copy()
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(a, 0, 255).astype(np.uint8)
    return out, n


def strip_eye_brow_gap(im, pos, y_cut):
    """眼贴片上沿若在眉和眼睑之间另有一道深色，会和底眉叠成空心双眉。那一截去掉，眼睑留下。"""
    rgb = im[..., :3].astype(np.float32)
    a = im[..., 3].astype(np.float32).copy()
    L = Lof(rgb)
    y0 = int(pos[1])
    changed = False
    for y in range(im.shape[0]):
        cy = y0 + y
        if cy >= y_cut:
            continue
        # 越靠近眼睑越少削，避免把上眼线切成一条硬边
        fade = 1.0 if cy <= y_cut - 3 else 0.55
        dark = (a[y] > 30) & (L[y] < 168)
        if not dark.any():
            continue
        a[y][dark] *= (1.0 - fade)
        changed = True
    if not changed:
        return im
    out = im.copy()
    out[..., 3] = np.clip(a, 0, 255).astype(np.uint8)
    return out


def soften_mask_g(mask):
    """G 是换脸时切头发的脸颈保护区。硬边会在别的脸上切出直边。已经是软边就不再模糊。"""
    g = mask[..., 1].astype(np.float32)
    if g.max() < 20:
        return mask
    gx = np.abs(np.diff(g, axis=1)).max() if g.shape[1] > 1 else 0
    if gx < 45:
        return mask
    out = mask.copy()
    out[..., 1] = np.clip(cv2.GaussianBlur(g, (0, 0), 3.0), 0, 255).astype(np.uint8)
    return out


def soften_aux_g(im):
    """头发 aux 的 G 是源脸的保护区，和头部遮罩一样会切出直边。R（保留发丝）不动。"""
    if im.shape[2] < 2:
        return im
    g = im[..., 1].astype(np.float32)
    if g.max() < 20:
        return im
    gx = np.abs(np.diff(g, axis=1)).max() if g.shape[1] > 1 else 0
    if gx < 45:
        return im
    out = im.copy()
    out[..., 1] = np.clip(cv2.GaussianBlur(g, (0, 0), 2.4), 0, 255).astype(np.uint8)
    return out


def apply(soft_hair=True):
    """毛领尖角、发束不透（仅从烘焙原图重做时），再改底脸眉、发缝、脸颈遮罩。

    已经收过边的发布图不要再跑 repair_hair_soft：它不是幂等的，会把发缘再啃掉一圈。
    """
    lib = json.load(open(LIBP, encoding="utf-8"))
    rel = lib["parts"]["outer_f4@base_f"]["tex"]
    save_webp(rel, repair_outer_horns(load_rgba(rel)))
    print("outer_f4")
    n_hair = 0
    n_rect = 0
    n_seam = 0
    for key, e in lib["parts"].items():
        if e.get("kind") != "hair":
            continue
        im = load_rgba(e["tex"])
        if soft_hair:
            im = repair_hair_soft(im)
        im, hits = heal_flat_blocks(im, e["pos"])
        im, cols = heal_neck_seam(im, e["pos"])
        im, _notch = heal_alpha_notch(im, e["pos"])
        save_webp(e["tex"], im)
        if e.get("aux"):
            save_webp(e["aux"], soften_aux_g(load_rgba(e["aux"])))
        n_hair += 1
        n_rect += hits
        n_seam += 1 if cols else 0
    print("hair", n_hair, "flat_blocks", n_rect, "seams", n_seam)
    n_brow = 0
    for name in HOLLOW_BROWS:
        rel = "heads/%s.jpg" % name
        im = load_rgba(rel)
        rgb = solidify_brow(im[..., :3], lib["heads"][name]["anchors"])
        if rgb is not im[..., :3]:
            im = im.copy()
            im[..., :3] = rgb
            save_webp(rel, im)
            n_brow += 1
    print("brows", n_brow)
    # base_f3 的眼贴片在眉和眼睑之间多一道深色，和底眉错成空心双眉。眼睑（锚点往上 8px 以内）不动。
    n_eye = 0
    y_cut = int(lib["heads"]["base_f3"]["anchors"]["eyes"][1]) - 8
    for key, e in lib["feats"].items():
        if not key.startswith("eyes:") or "|base_f3|" not in key:
            continue
        im = load_rgba(e["tex"])
        out = strip_eye_brow_gap(im, e["pos"], y_cut)
        if out is not im:
            save_webp(e["tex"], out)
            n_eye += 1
    print("eye_gap", n_eye, "y_cut", y_cut)
    n_mask = 0
    for name in lib["heads"]:
        rel = "heads/%s.mask.png" % name
        im = load_rgba(rel)
        out = soften_mask_g(im)
        if out is not im:
            save_webp(rel, out)
            n_mask += 1
    print("masks", n_mask)
    return lib


# ---------------------------------------------------------------- 拼图（对照、自检）
def _over(canvas, layer, pos, scale=1.0):
    im = layer
    if abs(scale - 1) > 1e-3:
        nw = max(1, int(round(im.shape[1] * scale)))
        nh = max(1, int(round(im.shape[0] * scale)))
        im = np.array(Image.fromarray(im).resize((nw, nh), Image.Resampling.BILINEAR))
    H, W = canvas.shape[:2]
    lh, lw = im.shape[:2]
    x, y = int(round(pos[0])), int(round(pos[1]))
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(W, x + lw), min(H, y + lh)
    if x1 <= x0 or y1 <= y0:
        return
    sub = im[y0 - y:y0 - y + (y1 - y0), x0 - x:x0 - x + (x1 - x0)].astype(np.float32)
    a = sub[..., 3:4] / 255.0
    dst = canvas[y0:y1, x0:x1]
    dst[..., :3] = dst[..., :3] * (1 - a) + sub[..., :3] * a


def _tint(rgb, tint, ref=0.8):
    t = np.float32(tint) / 255.0
    L = (rgb @ LUM / 255.0)[..., None]
    lo = t * L / ref
    hi = t + (1 - t) * np.clip((L - ref) / (1 - ref), 0, 1)
    return np.where(L < ref, lo, hi) * 255.0


def compose(lib, base, brow=None, hair=None, robe=None, robe_tint=None, outer=None, outer_tint=None, eyes=None):
    """近似游戏里的叠法，用来出对照图。"""
    W, H = lib["canvas"]
    head = load_rgba("heads/%s.jpg" % base)
    canvas = np.zeros((H, W, 4), np.float32)
    canvas[..., :3] = head[..., :3]
    canvas[..., 3] = 255
    mask = load_rgba("heads/%s.mask.png" % base).astype(np.float32)

    def add_feat(fid):
        if not fid:
            return
        k = "%s|%s|open" % (fid, base)
        if k not in lib["feats"]:
            return
        e = lib["feats"][k]
        _over(canvas, load_rgba(e["tex"]), e["pos"])

    add_feat(eyes)
    add_feat(brow)
    if robe:
        e = lib["parts"][robe]
        layer = load_rgba(e["tex"]).astype(np.float32)
        if robe_tint is not None:
            layer = layer.copy()
            layer[..., :3] = _tint(layer[..., :3], robe_tint, 0.8)
        _paste_cut(canvas, layer, e["pos"], mask, cut=True)
    if outer:
        e = lib["parts"][outer]
        layer = load_rgba(e["tex"]).astype(np.float32)
        if outer_tint is not None:
            layer = layer.copy()
            layer[..., :3] = _tint(layer[..., :3], outer_tint, 0.7)
        _paste_cut(canvas, layer, e["pos"], mask, cut=False)
    if hair:
        _paste_hair(lib, canvas, hair, base, mask)
    return canvas[..., :3].clip(0, 255).astype(np.uint8)


def _paste_cut(canvas, layer, pos, mask, cut):
    """layer 是部件 RGBA（已上色）。cut 时用遮罩 R 去掉头部。"""
    H, W = canvas.shape[:2]
    lh, lw = layer.shape[:2]
    x, y = int(pos[0]), int(pos[1])
    full = np.zeros((H, W, 4), np.float32)
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(W, x + lw), min(H, y + lh)
    if x1 <= x0:
        return
    full[y0:y1, x0:x1] = layer[y0 - y:y0 - y + (y1 - y0), x0 - x:x0 - x + (x1 - x0)]
    if cut:
        full[..., 3] *= (1.0 - mask[..., 0] / 255.0)
    a = full[..., 3:4] / 255.0
    canvas[..., :3] = canvas[..., :3] * (1 - a) + full[..., :3] * a


def _paste_hair(lib, canvas, hair, base, mask):
    e = lib["parts"][hair]
    layer = load_rgba(e["tex"]).astype(np.float32)
    hb = hair.split("@")[1]
    s, dx, dy = 1.0, 0.0, 0.0
    if hb != base:
        s, dx, dy = lib["xf"]["skull"][hb][base]
    pos = [dx + e["pos"][0] * s, dy + e["pos"][1] * s]
    if abs(s - 1) > 1e-3:
        nw = max(1, int(round(layer.shape[1] * s)))
        nh = max(1, int(round(layer.shape[0] * s)))
        layer = np.array(Image.fromarray(layer.astype(np.uint8)).resize((nw, nh), Image.Resampling.BILINEAR)).astype(np.float32)
    if hb != base and e.get("aux") and hair not in lib["pools"].get("native_white", []):
        ax = load_rgba(e["aux"]).astype(np.float32)
        if abs(s - 1) > 1e-3:
            ax = np.array(Image.fromarray(ax.astype(np.uint8)).resize((layer.shape[1], layer.shape[0]), Image.Resampling.BILINEAR)).astype(np.float32)
        # 先放到画布上再按遮罩减 alpha
        H, W = canvas.shape[:2]
        x, y = int(round(pos[0])), int(round(pos[1]))
        full = np.zeros((H, W, 4), np.float32)
        af = np.zeros((H, W, 4), np.float32)
        lh, lw = layer.shape[:2]
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(W, x + lw), min(H, y + lh)
        if x1 > x0:
            full[y0:y1, x0:x1] = layer[y0 - y:y0 - y + (y1 - y0), x0 - x:x0 - x + (x1 - x0)]
            ah, aw = ax.shape[:2]
            ax1, ay1 = min(W, x + aw), min(H, y + ah)
            if ax1 > x0 and ay1 > y0:
                af[y0:ay1, x0:ax1] = ax[y0 - y:y0 - y + (ay1 - y0), x0 - x:x0 - x + (ax1 - x0)]
        prot = np.maximum(mask[..., 1] / 255.0, af[..., 1] / 255.0)
        keep = af[..., 0] / 255.0
        full[..., 3] *= (1.0 - prot * (1.0 - keep))
        a = full[..., 3:4] / 255.0
        canvas[..., :3] = canvas[..., :3] * (1 - a) + full[..., :3] * a
        return
    _over(canvas, layer.astype(np.uint8), pos)


def _crop_face(im, box=(150, 100, 290, 210), scale=3):
    c = im[box[1]:box[3], box[0]:box[2]]
    pic = Image.fromarray(c)
    return pic.resize((c.shape[1] * scale, c.shape[0] * scale), Image.Resampling.NEAREST)


def render_pair(lib):
    os.makedirs(DOCS, exist_ok=True)
    # 绘制时不叠眉片，只留底脸自己的眉。双丸子三张底脸。
    specs = [
        ("base_f3", "hair_f7@base_f", "eyes:fx_f4@base_f"),
        ("base_f", "hair_f7@base_f", "eyes:fx_f1@base_f"),
        ("base_f4", "hair_f7@base_f", "eyes:fx_f3@base_f"),
    ]
    tiles = []
    for base, hair, eyes in specs:
        im = compose(lib, base, hair=hair, robe="robe_f1@base_f", robe_tint=(72, 96, 150), eyes=eyes)
        face = _crop_face(im)
        d = ImageDraw.Draw(face)
        d.rectangle((0, 0, face.width, 18), fill=(255, 252, 240))
        d.text((4, 2), "%s  %s  底脸眉" % (base, hair.split("@")[0]), fill=(40, 30, 20))
        tiles.append(face)
    w = max(t.width for t in tiles)
    sheet = Image.new("RGB", (w, sum(t.height for t in tiles) + 8), (245, 240, 230))
    y = 0
    for t in tiles:
        sheet.paste(t, (0, y))
        y += t.height + 4
    return sheet


def render_cape(lib):
    tiles = []
    for base, hair in (("base_f", "hair_f6@base_f"), ("base_f3", "hair_f1@base_f"), ("base_f4", "hair_f4@base_f")):
        im = compose(lib, base, hair=hair, robe="robe_f2@base_f", robe_tint=(214, 196, 170),
                     outer="outer_f4@base_f", outer_tint=(232, 224, 210), eyes="eyes:fx_f4@base_f")
        pic = Image.fromarray(im).crop((50, 0, 390, 520)).resize((340, 520))
        d = ImageDraw.Draw(pic)
        d.rectangle((0, 0, 340, 18), fill=(255, 252, 240))
        d.text((4, 2), "%s + %s + 毛领" % (base, hair.split("@")[0]), fill=(40, 30, 20))
        tiles.append(pic)
    sheet = Image.new("RGB", (340 * len(tiles), 520), (245, 240, 230))
    for i, t in enumerate(tiles):
        sheet.paste(t, (i * 340, 0))
    return sheet


def render_contacts(lib):
    """底脸 × 发型 × 眉型，只裁眉眼，用来确认没有双眉。"""
    os.makedirs(DOCS, exist_ok=True)

    def grid(bases, hairs, name):
        # 游戏不再叠眉片。每格是这张底脸自己的眉 × 这一款发。
        cell_w, cell_h = 96, 64
        cols = len(hairs)
        sheet = Image.new("RGB", (cols * cell_w + 8, len(bases) * cell_h + 18), (250, 246, 238))
        dr = ImageDraw.Draw(sheet)
        for i, hair in enumerate(hairs):
            dr.text((i * cell_w + 4, 1), hair.split("@")[0].replace("hair_", ""), fill=(80, 60, 40))
        for r, base in enumerate(bases):
            dr.text((2, 18 + r * cell_h), base.replace("base_", ""), fill=(60, 50, 40))
            for c, hair in enumerate(hairs):
                im = compose(lib, base, hair=hair, eyes="eyes:fx_f4@base_f" if base.startswith("base_f") else "eyes:fx_m1@base_m")
                crop = Image.fromarray(im[100:180, 150:310]).resize((cell_w - 28, cell_h - 2), Image.Resampling.BILINEAR)
                sheet.paste(crop, (28 + c * cell_w, 18 + r * cell_h))
        sheet.save(os.path.join(DOCS, name))
        print(name, sheet.size)

    grid(["base_f", "base_f2", "base_f3", "base_f4", "base_f5"], lib["pools"]["hair"]["f"], "brows_all_f.png")
    grid(["base_m", "base_m2", "base_m3", "base_m4", "base_m5"], lib["pools"]["hair"]["m"], "brows_all_m.png")


def render_outers(lib):
    """披肩 / 外袍 × 几款长短发。"""
    hairs = ["hair_f6@base_f", "hair_f1@base_f", "hair_f7@base_f", "hair_f11@base_f", "hair_f4@base_f", "hair_f12@base_f"]
    outers = [None] + list(lib["pools"]["outers"]["f"])
    cell = []
    for outer in outers:
        for hair in hairs:
            im = compose(lib, "base_f3", hair=hair, robe="robe_f2@base_f", robe_tint=(214, 196, 170),
                         outer=outer, outer_tint=(210, 200, 186), eyes="eyes:fx_f4@base_f")
            pic = Image.fromarray(im).crop((70, 20, 370, 460)).resize((150, 220))
            d = ImageDraw.Draw(pic)
            d.rectangle((0, 0, 150, 16), fill=(255, 252, 240))
            d.text((2, 2), "%s" % ((outer or "none").split("@")[0][:10]), fill=(40, 30, 20))
            cell.append(pic)
    cols = len(hairs)
    rows = len(outers)
    sheet = Image.new("RGB", (cols * 150, rows * 220), (245, 240, 230))
    for i, im in enumerate(cell):
        sheet.paste(im, ((i % cols) * 150, (i // cols) * 220))
    sheet.save(os.path.join(DOCS, "outers_x_hair.png"))
    # 男外袍抽几张
    mh = lib["pools"]["hair"]["m"][:4]
    mo = [None] + list(lib["pools"]["outers"]["m"])
    cell = []
    for outer in mo:
        for hair in mh:
            im = compose(lib, "base_m2", hair=hair, robe="robe_m1@base_m", robe_tint=(90, 110, 130),
                         outer=outer, outer_tint=(70, 80, 96))
            pic = Image.fromarray(im).crop((70, 20, 370, 460)).resize((140, 200))
            cell.append(pic)
    cols = len(mh)
    sheet = Image.new("RGB", (cols * 140, len(mo) * 200), (245, 240, 230))
    for i, im in enumerate(cell):
        sheet.paste(im, ((i % cols) * 140, (i // cols) * 200))
    sheet.save(os.path.join(DOCS, "outers_x_hair_m.png"))
    print("outers")


def doubles(lib, base, brow, hair=None):
    """眉眼带里两道暗脊算双眉。头发（很黑）不算。"""
    im = compose(lib, base, brow=brow, hair=hair)
    A = lib["heads"][base]["anchors"]
    by, ey = int(A["brows"][1]), int(A["eyes"][1])
    y0, y1 = by - 12, ey - 4
    L = im[y0:y1].astype(np.float32) @ LUM
    n = 0
    for x in range(165, 275):
        col = cv2.GaussianBlur(L[:, x].reshape(-1, 1), (5, 1), 0).ravel()
        mins = []
        for i in range(2, len(col) - 2):
            if col[i] < 70:  # 刘海
                continue
            if col[i] <= col[i - 1] and col[i] <= col[i + 1] and col[i] < 165 and col[i] + 14 < col[max(0, i - 3):i].mean():
                mins.append(i)
        keep = []
        for m in mins:
            if not keep or m - keep[-1] > 4:
                keep.append(m)
            elif col[m] < col[keep[-1]]:
                keep[-1] = m
        if len(keep) >= 2:
            a, b = keep[0], keep[1]
            if col[a:b + 1].max() > min(col[a], col[b]) + 16:
                n += 1
    return n


def render_zoom(lib):
    """脸和发缘 2 倍近邻放大，专门看硬边、白边、矩形补丁、双眉。"""
    combos = [
        ("base_f", "hair_f6@base_f", (70, 40, 250, 300)),
        ("base_f3", "hair_f1@base_f", (90, 20, 300, 280)),
        ("base_f4", "hair_f4@base_f", (60, 40, 280, 300)),
        ("base_f3", "hair_f7@base_f", (90, 10, 320, 260)),
        ("base_f4", "hair_f6@base_f", (70, 30, 270, 290)),
        ("base_f", "hair_f11@base_f", (90, 20, 300, 280)),
        ("base_f3", "hair_f6@base_f", (70, 30, 270, 290)),
        ("base_f3", "hair_f4@base_f", (70, 30, 280, 300)),
        ("base_f3", "hair_f11@base_f", (80, 20, 300, 280)),
        ("base_m", "hair_m1@base_m", (70, 30, 280, 300)),
        ("base_m2", "hair_m4@base_m", (70, 30, 280, 300)),
    ]
    tiles = []
    for base, hair, box in combos:
        if base.startswith("base_m"):
            im = compose(lib, base, hair=hair, robe="robe_m1@base_m", robe_tint=(90, 110, 130),
                         eyes="eyes:fx_m1@base_m")
        else:
            im = compose(lib, base, hair=hair, robe="robe_f2@base_f", robe_tint=(214, 196, 170),
                         outer="outer_f4@base_f", outer_tint=(232, 224, 210), eyes="eyes:fx_f4@base_f")
        c = Image.fromarray(im).crop(box)
        z = c.resize((c.width * 2, c.height * 2), Image.Resampling.NEAREST)
        d = ImageDraw.Draw(z)
        d.rectangle((0, 0, 280, 22), fill=(255, 252, 240))
        d.text((4, 3), "%s + %s" % (base, hair.split("@")[0]), fill=(30, 20, 10))
        tiles.append(z)
    w = max(t.width for t in tiles)
    h = max(t.height for t in tiles)
    cols = 3
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (w * cols, h * rows), (245, 240, 230))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % cols) * w, (i // cols) * h))
    sheet.save(os.path.join(DOCS, "face_edge_2x.png"))
    print("face_edge_2x", sheet.size)


def render_after():
    lib = json.load(open(LIBP, encoding="utf-8"))
    os.makedirs(DOCS, exist_ok=True)
    render_pair(lib).save(os.path.join(DOCS, "brow_doublebun_after.png"))
    render_cape(lib).save(os.path.join(DOCS, "cape_fur_after.png"))
    render_contacts(lib)
    render_outers(lib)
    render_zoom(lib)
    print("sheets saved")


def main():
    # 修之前的对照图已经在 docs/art/v0168/*_before.png，不要覆盖。
    cmd = sys.argv[1] if len(sys.argv) > 1 else "sheets"
    if cmd == "apply":
        # 发布图上的发缘已经收过。再跑 repair_hair_soft 会把边缘再啃一圈。从烘焙原图重做时加 --resoft。
        apply(soft_hair=("--resoft" in sys.argv))
        return
    if cmd == "sheets":
        render_after()
        return
    print("用法: repair_v0168.py apply | sheets")


if __name__ == "__main__":
    main()
