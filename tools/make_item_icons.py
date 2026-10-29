#!/usr/bin/env python3
"""art_src/icons_gear_{a,b}.jpg（自制生成的白底水墨器物图）→ assets/img/ico_g_*.webp（透明底 128px）。
抠图：从四边漫水找白底 → 软边 alpha → pymatting 前景估计去白边。需要 numpy、scipy、Pillow、pymatting。"""
import os, numpy as np
from PIL import Image
from scipy import ndimage as ndi
from pymatting import estimate_foreground_ml
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S, D = os.path.join(R, "art_src"), os.path.join(R, "assets/img")
SZ = 128
SHEETS = [
    ("icons_gear_a.jpg", 4, ["jian", "feijian", "san", "ling", "yin", "pao", "jia", "pei",
                             "zan", "jie", "zhuo", "nang", "dai", "lingjie", "fu_huang", "fu_lan"]),
    ("icons_gear_b.jpg", 3, ["tie", "leimu", "yaodan", "fu_jiu", "fu_can", "hulu",
                             None, None, None]),   # 后三格（丹盒、铜镜、羽扇）暂不用
]

HOLES = {"jie", "lingjie", "zhuo"}   # 环形物：中间的白底也要抠掉

def cut(cell, holes=False):
    a = np.asarray(cell.convert("RGB")).astype(np.float32)
    d = (255.0 - a).max(axis=2)                       # 离纯白的距离
    near = d < 34
    lab, _ = ndi.label(near)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    bg = np.isin(lab, edge[edge > 0])
    if holes:
        sizes = ndi.sum(near, lab, range(1, lab.max() + 1))
        big = [i + 1 for i, v in enumerate(sizes) if v > near.size * 0.01]
        bg |= np.isin(lab, big)
    bg = ndi.binary_opening(bg, iterations=1) | (d < 6) & bg
    fg_core = ~ndi.binary_dilation(bg, iterations=2)
    al = np.clip((d - 8) / 40.0, 0, 1)                 # 白底附近：按深浅给软边
    al = np.where(fg_core, 1.0, np.where(bg, np.minimum(al, 0.0 + (d >= 12) * al), al))
    al = np.where(bg & (d < 12), 0.0, al)
    al = ndi.gaussian_filter(al, 0.6)
    al = np.clip(al, 0, 1)
    # 去掉离主体很远的小碎点（阴影字迹、飞溅）
    lab2, k = ndi.label(al > 0.08)
    if k > 1:
        sz = ndi.sum(np.ones_like(al), lab2, range(1, k + 1))
        keep = np.isin(lab2, [i + 1 for i, v in enumerate(sz) if v >= sz.max() * 0.04])
        keep = ndi.binary_dilation(keep, iterations=3)
        al = al * keep
    fg = estimate_foreground_ml(a / 255.0, al)
    return np.clip(fg, 0, 1), al

def main():
    tot = 0
    for fn, n, names in SHEETS:
        sh = Image.open(os.path.join(S, fn)).convert("RGB")
        W, H = sh.size
        for i, name in enumerate(names):
            if name is None:
                continue
            x0, y0 = int((i % n) * W / n), int((i // n) * H / n)
            cell = sh.crop((x0, y0, int(x0 + W / n), int(y0 + H / n)))
            fg, al = cut(cell, name in HOLES)
            ys, xs = np.where(al > 0.04)
            cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
            side = max(xs.max() - xs.min(), ys.max() - ys.min()) * 1.10 + 8
            rgba = np.dstack([fg, al])
            im = Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA")
            # 预乘缩放，避免透明区颜色渗入
            pm = np.dstack([fg * al[..., None], al])
            pim = Image.fromarray((pm * 255 + 0.5).astype(np.uint8), "RGBA")
            box = (int(cx - side / 2), int(cy - side / 2), int(cx + side / 2), int(cy + side / 2))
            p = np.asarray(pim.crop(box).resize((SZ, SZ), Image.LANCZOS)).astype(np.float32) / 255
            f = np.asarray(im.crop(box).resize((SZ, SZ), Image.LANCZOS)).astype(np.float32) / 255
            a2 = np.clip(p[..., 3], 0, 1)
            rgb = np.where(a2[..., None] > 0.02, p[..., :3] / np.maximum(a2[..., None], 1e-3), f[..., :3])
            out = np.dstack([np.clip(rgb, 0, 1), a2])
            path = os.path.join(D, "ico_g_%s.webp" % name)
            Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA").save(path, "WEBP", quality=82, method=6, exact=True)
            imp = path + ".import"
            if not os.path.exists(imp):
                open(imp, "w").write('[remap]\n\nimporter="keep"\n')
            tot += os.path.getsize(path)
            print(name, os.path.getsize(path))
    print("total", tot)

if __name__ == "__main__":
    main()
