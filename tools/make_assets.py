#!/usr/bin/env python3
"""art_src/ → assets/img/*.webp（缩放 + 有损压缩）；程序生成纸纹。需要 numpy + Pillow。"""
import os, numpy as np
from PIL import Image, ImageFilter
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S, D = os.path.join(R, "art_src"), os.path.join(R, "assets/img")
os.makedirs(D, exist_ok=True)
def save(im, name, q=72):
    im.save(os.path.join(D, name), "WEBP", quality=q, method=6)
for n in ["title", "bg_home", "bg_houshan", "bg_hantan", "bg_biguan", "bg_ending"]:
    im = Image.open(os.path.join(S, n + ".jpg")).convert("RGB").resize((540, 960), Image.LANCZOS)
    save(im, n + ".webp", 74 if n == "title" else 66)
for n in ["por_heroine", "por_aunt", "por_turtle", "por_gelaosan"]:
    im = Image.open(os.path.join(S, n + ".jpg")).convert("RGB").resize((256, 256), Image.LANCZOS)
    save(im, n + ".webp", 76)
# 图标：4×2 网格切片，柔边透明
sheet = Image.open(os.path.join(S, "icons_sheet.jpg")).convert("RGB")
W, H = sheet.size; cw, ch = W / 4, H / 2
names = ["ico_lingshi", "ico_qingzhi", "ico_lian", "ico_guo", "ico_juqi", "ico_zhuji", "ico_fu", "ico_ration"]
yy, xx = np.mgrid[0:96, 0:96]; rr = np.sqrt((xx - 47.5) ** 2 + (yy - 47.5) ** 2) / 48
alpha_mask = np.clip((1.0 - rr) / 0.18, 0, 1)
for i, n in enumerate(names):
    cx, cy = (i % 4 + 0.5) * cw, (i // 4 + 0.5) * ch
    side = min(cw, ch) * 0.86
    c = sheet.crop((int(cx - side / 2), int(cy - side / 2), int(cx + side / 2), int(cy + side / 2))).resize((96, 96), Image.LANCZOS)
    a = np.asarray(c).astype(np.float32)
    # 纸底（亮且低饱和）→ 透明；墨色保留
    lum = a.mean(axis=2); sat = a.max(axis=2) - a.min(axis=2)
    ink = np.clip(((235 - lum) / 45) + sat / 60, 0, 1)
    al = (np.maximum(ink, 0) * alpha_mask * 255).astype(np.uint8)
    rgba = np.dstack([a.astype(np.uint8), al])
    Image.fromarray(rgba, "RGBA").save(os.path.join(D, n + ".webp"), "WEBP", quality=80, method=6)
# 纸纹：256 平铺，低频云纹 + 纤维
rng = np.random.default_rng(7)
def tile_noise(sz, scale):
    n = rng.random((sz // scale, sz // scale))
    im = Image.fromarray((n * 255).astype(np.uint8)).resize((sz, sz), Image.BICUBIC)
    return np.asarray(im).astype(np.float32) / 255
sz = 256
base = 0.5 * tile_noise(sz, 32) + 0.3 * tile_noise(sz, 8) + 0.2 * tile_noise(sz, 2)
fib = Image.new("L", (sz, sz), 0)
fa = np.zeros((sz, sz), np.float32)
for _ in range(220):
    x, y = rng.integers(0, sz, 2); L = rng.integers(6, 22); ang = rng.random() * np.pi
    for t in range(L):
        fa[int(y + t * np.sin(ang)) % sz, int(x + t * np.cos(ang)) % sz] += 0.5
fa = np.asarray(Image.fromarray((np.clip(fa, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))).astype(np.float32) / 255
v = 0.93 + (base - 0.5) * 0.06 - fa * 0.05
rgb = np.dstack([v * 246, v * 240, v * 226]).clip(0, 255).astype(np.uint8)
Image.fromarray(rgb, "RGB").save(os.path.join(D, "paper.webp"), "WEBP", quality=70, method=6)
for f in sorted(os.listdir(D)):
    print(f, os.path.getsize(os.path.join(D, f)))
