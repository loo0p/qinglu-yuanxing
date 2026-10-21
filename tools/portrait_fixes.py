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
    if rel == "parts/outer_f4-base_f.png":
        return _clean_specks(im, 165)
    return im
