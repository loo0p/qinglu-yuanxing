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

用法：python3 tools/repair_v0168.py
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


def apply():
    """只动头发和毛领尖角。眉不在贴图上改：游戏绘制时不再叠眉片，底脸的眉留着。
    头和遮罩也不在这里抹，矩形色块和横缝就是从前那一步留下的。"""
    lib = json.load(open(LIBP, encoding="utf-8"))
    rel = lib["parts"]["outer_f4@base_f"]["tex"]
    save_webp(rel, repair_outer_horns(load_rgba(rel)))
    print("outer_f4")
    n_hair = 0
    for key, e in lib["parts"].items():
        if e.get("kind") != "hair":
            continue
        save_webp(e["tex"], repair_hair_soft(load_rgba(e["tex"])))
        n_hair += 1
    print("hair", n_hair)
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
    ]
    tiles = []
    for base, hair, box in combos:
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
    sheet = Image.new("RGB", (w * 3, h * 2), (245, 240, 230))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 3) * w, (i // 3) * h))
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
        apply()
        import subprocess
        subprocess.check_call([sys.executable, os.path.join(R, "tools/bundle_portraits.py")])
        return
    if cmd == "sheets":
        render_after()
        return
    print("用法: repair_v0168.py apply | sheets")


if __name__ == "__main__":
    main()
