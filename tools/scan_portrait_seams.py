#!/usr/bin/env python3
"""女/男底脸 × 发型：头发里的长直线亮度跳变（矩形边、横缝）。

看的是拼好的立绘，不是单张贴图。跳变两侧都得是头发（脸、衣领、纸色不算）。
退出码 0 = 没有这种直线；1 = 还有。用法：python3 tools/scan_portrait_seams.py
"""
import os, sys, json
import numpy as np
import cv2

R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import repair_v0168 as P

# 头发内部。外轮廓（发对皮肤、发对袍）是弯的或顺着脸走，不在这里算。
# 两侧都是头发、而且跳变比前后一小段更陡，才算接缝。发丝外轮廓、衣领会落在这道线外面。
HAIR_L = 78
RUN_H = 18
JUMP = 12
Y0, Y1 = 165, 285


def _runs(mask, min_len, gap=2):
    idx = np.where(mask)[0]
    if len(idx) < min_len:
        return
    br = np.where(np.diff(idx) > gap)[0]
    st = 0
    for b in list(br) + [len(idx) - 1]:
        sl = idx[st:b + 1]
        st = b + 1
        if len(sl) >= min_len:
            yield sl


def seam_hits(im, skin):
    """im: RGB uint8。skin: 头部遮罩 R>140。返回 (方向, y或x, 起点, 终点, 平均跳变)。"""
    L = im.astype(np.float32) @ P.LUM
    hair = (L < HAIR_L) & ~skin
    hits = []
    gy = L[1:] - L[:-1]
    both_h = hair[1:] & hair[:-1]
    for y in range(Y0, min(Y1, gy.shape[0])):
        d = gy[y - 1]
        m = both_h[y - 1] & (np.abs(d) > JUMP)
        for sl in _runs(m, RUN_H):
            dd = d[sl]
            if abs(float(dd.mean())) < JUMP * 0.75:
                continue
            if (np.sign(dd) == np.sign(dd.mean())).mean() < 0.85:
                continue
            # 已经是缓坡的不算：前后 8px 的总变化不该只比这一行大一点点
            yA, yB = max(0, y - 8), min(L.shape[0] - 1, y + 8)
            span = np.abs(L[yB, sl] - L[yA, sl]).mean()
            if abs(float(dd.mean())) < 0.55 * max(float(span), 1.0):
                continue
            hits.append(("H", y, int(sl[0]), int(sl[-1]), round(float(dd.mean()), 1)))
    # 竖直：只有「一边几乎是纯色块」的长直边。普通发丝、下颌线不算。
    gx = L[:, 1:] - L[:, :-1]
    both_v = hair[:, 1:] & hair[:, :-1]
    for x in range(1, gx.shape[1] - 1):
        d = gx[:, x - 1]
        m = both_v[:, x - 1] & (np.abs(d) > 16)
        m[:Y0] = False
        m[Y1:] = False
        for sl in _runs(m, 22):
            dd = d[sl]
            if abs(float(dd.mean())) < 14:
                continue
            if (np.sign(dd) == np.sign(dd.mean())).mean() < 0.9:
                continue
            # 较暗的一侧要平，才是填出来的方块边，不是一缕发
            dark_is_right = float(dd.mean()) < 0
            col = L[sl, x] if dark_is_right else L[sl, x - 1]
            if float(col.std()) > 3.5:
                continue
            hits.append(("V", x, int(sl[0]), int(sl[-1]), round(float(dd.mean()), 1)))
    return hits


def flat_rects(im):
    """几乎没有纹理的深色长方。耳旁那块填充就是这种。"""
    L = im.astype(np.float32) @ P.LUM
    std = P._local_std(L)
    flat = ((std < 2.6) & (L < 34)).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(flat, 8)
    hits = []
    for i in range(1, n):
        x, y, w, h, area = st[i]
        if area < 400 or w < 16 or h < 24:
            continue
        if area / float(w * h) < 0.55:
            continue
        if y > 300 or y + h < 160:
            continue
        hits.append(("F", int(x), int(y), int(w), int(h), int(area)))
    return hits


def scan(lib):
    found = []
    for sex in ("f", "m"):
        bases = [b for b in lib["heads"] if lib["heads"][b]["sex"] == sex and not lib["heads"][b].get("elder")]
        for base in bases:
            skin = P.load_rgba("heads/%s.mask.png" % base)[..., 0] > 140
            eyes = "eyes:fx_f4@base_f" if sex == "f" else "eyes:fx_m1@base_m"
            robe = "robe_f2@base_f" if sex == "f" else "robe_m1@base_m"
            tint = (214, 196, 170) if sex == "f" else (90, 110, 130)
            for hair in lib["pools"]["hair"][sex]:
                im = P.compose(lib, base, hair=hair, robe=robe, robe_tint=tint, eyes=eyes)
                for h in seam_hits(im, skin):
                    found.append((base, hair, h))
                for h in flat_rects(im):
                    found.append((base, hair, h))
    return found


def main():
    lib = json.load(open(os.path.join(R, "data/lib5.json"), encoding="utf-8"))
    found = scan(lib)
    if not found:
        print("seams 0")
        return 0
    print("seams", len(found))
    for row in found[:40]:
        print(" ", row[0], row[1], row[2])
    return 1


if __name__ == "__main__":
    sys.exit(main())
