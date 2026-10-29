#!/usr/bin/env python3
"""立绘部件里烘进去的残迹自动检查（v0.15.4）。看的是发布用的 web_portrait/parts/*.webp。
用法：python3 tools/scan_part_artefacts.py [--dir 部件目录] [--sheet 对照表.png] [--json 结果.json] [--only 子串...]
四类标记（对照表上：品红 = 亮痕，青 = 碎片，黄 = 针孔，橙 = 纸色）：
  streak  亮痕：外披里比这件布的中位亮度亮出 22 以上、贴着透明区的浅色块（人台白中衣/衣结被一起抠进来）；
          衣袍只算贴着透明区的细浅条（≤ 4 px 宽，白领口这种成片的浅色是画的，不算）
  paper   纸色：深色头发/胡须里，头部遮罩外、不饱和、衬深色底（60,70,90）时仍发白（亮度 > 125）且不成块（不是发带/玉簪）的像素
  frag    碎片：和主体不相连的小块（< 主体 2%）；深色头发里只算发白的碎块（单独一缕深色发丝是画的）
  pinhole 针孔：衣袍/外披主体内部 alpha 掉下去的小洞（3–400 px）
浅色部件（白发、白胡子、纱披 outer_f1、毛领 outer_f4）不查亮痕/纸色。
每类在 TOL 以内算干净（抗锯齿、编码噪声会留几个像素）。退出码：0 = 全部干净；1 = 有部件超出。"""
import os, sys, json, glob
import numpy as np
import cv2
from scipy import ndimage
from PIL import Image, ImageDraw

R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIGHT_PART = ("hair_fe", "hair_me", "beard_me", "outer_f1", "outer_f4")
TOL = {"streak": 40, "paper": 60, "frag": 30, "pinhole": 40}
LUM = np.array([0.299, 0.587, 0.114], np.float32)
DARK_BG = np.array([60, 70, 90], np.float32)
COL = {"streak": (255, 0, 255), "frag": (0, 255, 255), "pinhole": (255, 220, 0), "paper": (255, 140, 0)}

_lib = None
_heads = {}


def lib():
    global _lib
    if _lib is None:
        _lib = json.load(open(os.path.join(R, "data/lib5.json")))
    return _lib


def head_mask(base, d):
    if base not in _heads:
        p = os.path.join(os.path.dirname(d), "heads", base + ".mask.webp")
        if os.path.exists(p):
            hm = np.array(Image.open(p).convert("RGB"))
            _heads[base] = ((hm[..., 0] > 0) | (hm[..., 1] > 0)).astype(np.uint8)
        else:
            _heads[base] = None
    return _heads[base]


def comps(mask):
    return cv2.connectedComponentsWithStats(mask.astype(np.uint8), 8)


def scan(a, name, d):
    al = a[..., 3].astype(np.float32)
    c = a[..., :3].astype(np.float32)
    L = c @ LUM
    sat = c.max(-1) - c.min(-1)
    kind = name.split("_")[0]
    cloth = kind in ("robe", "outer") and "outer_f1" not in name
    light_part = any(name.startswith(k) for k in LIGHT_PART)
    z = np.zeros(al.shape, bool)
    masks = {"streak": z.copy(), "frag": z.copy(), "pinhole": z.copy(), "paper": z.copy()}
    solid = al > 200
    if solid.sum() < 100:
        return {k: 0 for k in masks}, masks
    med = float(np.median(L[solid]))
    ink = float(np.percentile(L[solid], 25))
    clear = al < 24
    nearclear = cv2.dilate(clear.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    # ---- streak
    if cloth and not light_part:
        if kind == "outer":
            light = (L > med + 22) & (al > 60)
        else:
            light = (L > max(med + 22, 150)) & (al > 60)
        light = cv2.morphologyEx(light.astype(np.uint8), cv2.MORPH_OPEN, np.ones((2, 2), np.uint8))
        n, lab, st, _ = comps(light)
        dt = cv2.distanceTransform(light, cv2.DIST_L2, 3)
        for i in range(1, n):
            if st[i, 4] < 15:
                continue
            cm = lab == i
            if not (cm & nearclear).any():
                continue
            if kind == "robe" and dt[cm].max() > 2.0:
                continue
            masks["streak"] |= cm
    # ---- paper (dark hair / beard / dark acc)
    if kind in ("hair", "beard") and not light_part and ink < 90:
        key = name.replace("-", "@", 1)
        pos = lib()["parts"].get(key, {}).get("pos", [0, 0])
        h, w = al.shape
        H = np.zeros((h, w), np.uint8)
        hm = head_mask(key.split("@")[1], d)
        if hm is not None:
            sub = hm[pos[1]:pos[1] + h, pos[0]:pos[0] + w]
            H[:sub.shape[0], :sub.shape[1]] = sub
            H = cv2.dilate(H, np.ones((5, 5), np.uint8))
        comp_dark = c * (al[..., None] / 255) + DARK_BG * (1 - al[..., None] / 255)
        vis = (comp_dark @ LUM > 125) & (sat < 40) & (H == 0)
        blob = cv2.morphologyEx(((L > ink + 100) & (al > 150)).astype(np.uint8), cv2.MORPH_OPEN,
                                cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)))
        vis &= ~(cv2.dilate(blob, np.ones((5, 5), np.uint8)) > 0)
        # 从头顶垂下来的浅色饰物（发带）：和 portrait_fixes.fix_hair_paper 同一条规则
        n, lab, st, _ = comps((L > ink + 100) & (al > 150))
        for i in range(1, n):
            y1 = st[i, cv2.CC_STAT_TOP] + pos[1]
            if st[i, 4] >= 100 and y1 < 110 < y1 + st[i, cv2.CC_STAT_HEIGHT]:
                vis &= ~(cv2.dilate((lab == i).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0)
        masks["paper"] = vis
    # ---- frag
    n, lab, st, _ = comps(al > 24)
    if n > 1:
        main = 1 + int(np.argmax(st[1:, 4]))
        big = st[main, 4]
        for i in range(1, n):
            if i == main or st[i, 4] < 12 or st[i, 4] >= 0.02 * big:
                continue
            cm = lab == i
            if kind in ("hair", "beard") and not light_part and float(np.median(L[cm])) < ink + 60:
                continue
            masks["frag"] |= cm
    # ---- pinhole
    if cloth:
        body = (al > 120).astype(np.uint8)
        hole = ndimage.binary_fill_holes(body > 0) & (body == 0)   # 四面被布包住的洞，不算边上的缺口
        n, lab, st, _ = comps(hole)
        for i in range(1, n):
            if 3 <= st[i, 4] <= 400:
                masks["pinhole"] |= lab == i
    out = {k: int(v.sum()) for k, v in masks.items()}
    return out, masks


def tile(a, masks, label, size=200):
    al = a[..., 3:4].astype(np.float32) / 255
    img = a[..., :3].astype(np.float32) * al + DARK_BG * (1 - al)
    for k, col in COL.items():
        m = masks.get(k)
        if m is not None and m.any():
            mm = cv2.dilate(m.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
            img[mm] = img[mm] * 0.2 + np.array(col, np.float32) * 0.8
    im = Image.fromarray(img.clip(0, 255).astype(np.uint8))
    bb = Image.fromarray(a[..., 3]).getbbox()
    if bb:
        im = im.crop(bb)
    im.thumbnail((size, size))
    t = Image.new("RGB", (size, size + 16), (30, 30, 36))
    t.paste(im, ((size - im.width) // 2, 0))
    ImageDraw.Draw(t).text((3, size + 2), label[:36], fill=(230, 230, 230))
    return t


# 逐张看过、确认是画出来的东西（不是残迹）的标记：允许到这个数为止，再多就还是报。
REVIEWED = {
    ("robe_f15-base_f", "streak"): (60, "领口白边，画的"),
    ("robe_f16-base_f", "streak"): (70, "羽披外缘的白羽尖"),
    ("robe_m11-base_m", "streak"): (160, "白交领的内沿高光"),
    ("robe_m14-base_m", "streak"): (160, "毛领外缘的毛尖"),
    ("hair_f4-base_f", "paper"): (100, "银发冠"),
    ("hair_f7-base_f", "paper"): (180, "白发带的结 + 头路"),
    ("hair_m5-base_m", "paper"): (130, "银发冠"),
    ("hair_m7-base_m", "paper"): (80, "金冠的细边"),
    ("hair_fe2-base_fe", "frag"): (100, "冠上的珠子"),
    ("outer_f1-base_f", "frag"): (160, "纱披上单独的一缕纱"),
}


def bad(r, name=""):
    return any(r[k] > max(TOL[k], REVIEWED.get((name, k), (0, ""))[0]) for k in TOL)


def main():
    args = sys.argv[1:]
    opt = {}
    for key in ("--dir", "--sheet", "--json"):
        if key in args:
            i = args.index(key); opt[key] = args[i + 1]; del args[i:i + 2]
    only = args[args.index("--only") + 1:] if "--only" in args else []
    d = opt.get("--dir", os.path.join(R, "web_portrait/parts"))
    files = sorted(f for f in glob.glob(d + "/*.webp")
                   if not f.endswith((".aux.webp", ".mask.webp", ".paper.webp")))
    if only:
        files = [f for f in files if any(o in f for o in only)]
    res = {}; tiles = []; flagged = []
    for f in files:
        name = os.path.basename(f)[:-len(".webp")]
        a = np.array(Image.open(f).convert("RGBA"))
        r, m = scan(a, name, d)
        res[name] = r
        if bad(r, name):
            flagged.append(name)
            print("%-24s streak %5d  paper %5d  frag %4d  pinhole %4d" % (name, r["streak"], r["paper"], r["frag"], r["pinhole"]))
        tiles.append(tile(a, m, "%s%s s%d p%d f%d h%d" % ("!" if bad(r, name) else "", name.replace("-base_", "@"),
                                                       r["streak"], r["paper"], r["frag"], r["pinhole"])))
    rev = sorted(set(n for (n, k) in REVIEWED if n in res and res[n][k] > TOL[k]))
    print("scanned", len(res), "flagged", len(flagged), "reviewed-ok", len(rev), "tolerance", TOL)
    if "--sheet" in opt:
        cols = 10; rows = (len(tiles) + cols - 1) // cols
        S = Image.new("RGB", (cols * 200, rows * 216), (20, 20, 24))
        for i, t in enumerate(tiles):
            S.paste(t, ((i % cols) * 200, (i // cols) * 216))
        S.save(opt["--sheet"])
    if "--json" in opt:
        json.dump({"tol": TOL, "flagged": flagged, "parts": res}, open(opt["--json"], "w"), ensure_ascii=False, indent=1)
    return 1 if flagged else 0


if __name__ == "__main__":
    sys.exit(main())
