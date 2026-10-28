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
# 江湖事件背景：不进 pck，放 web_portrait/bg/（网页版按需下载）
for n in ["bg_chasi", "bg_shandao", "bg_fangshi", "bg_yeyu", "bg_dongfu", "bg_leitai", "map_world"]:
    im = Image.open(os.path.join(S, n + ".jpg")).convert("RGB").resize((540, 960), Image.LANCZOS)
    os.makedirs(os.path.join(R, "web_portrait/bg"), exist_ok=True)
    im.save(os.path.join(R, "web_portrait/bg", n + ".webp"), "WEBP", quality=66, method=6)
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

# ---- v0.4 场景化 UI：庭院、路线图、立绘表情（带渐隐透明边）、行路小人
for n in ["courtyard", "map_houshan", "map_hantan"]:
    im = Image.open(os.path.join(S, n + ".jpg")).convert("RGB").resize((540, 960), Image.LANCZOS)
    save(im, n + ".webp", 68)
def vn_portrait(im, name, w=300, h=340):
    im = im.convert("RGB"); W0, H0 = im.size
    s = max(w / W0, h / H0); im = im.resize((int(W0 * s), int(H0 * s)), Image.LANCZOS)
    l = (im.width - w) // 2; im = im.crop((l, 0, l + w, h))
    a = np.asarray(im).astype(np.float32)
    lum = a.mean(axis=2); sat = a.max(axis=2) - a.min(axis=2)
    ink = np.clip(((238 - lum) / 30) + sat / 40, 0, 1)            # 去掉纸底
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.clip(np.minimum.reduce([xx / 30, (w - 1 - xx) / 30, (h - 1 - yy) / 60, np.ones_like(xx, dtype=float)]), 0, 1)
    al = (np.maximum(edge * 0.97, ink * edge) * 255).astype(np.uint8)   # 画框式：内部不透明，四边羽化
    Image.fromarray(np.dstack([a.astype(np.uint8), al]), "RGBA").save(os.path.join(D, name + ".webp"), "WEBP", quality=80, method=6)
ex = Image.open(os.path.join(S, "heroine_expr.jpg")); EW, EH = ex.size
vn_portrait(ex.crop((0, 0, EW // 2, EH)), "vn_heroine_smile")
vn_portrait(ex.crop((EW // 2, 0, EW, EH)), "vn_heroine_resolute")
for n in ["heroine", "aunt", "turtle", "gelaosan"]:
    vn_portrait(Image.open(os.path.join(S, "por_%s.jpg" % n)), "vn_" + n)
tk = Image.open(os.path.join(S, "token.jpg")).convert("RGB")
tk = tk.crop((330, 150, 700, 840)).resize((60, 112), Image.LANCZOS)
a = np.asarray(tk).astype(np.float32); lum = a.mean(axis=2); sat = a.max(axis=2) - a.min(axis=2)
al = (np.clip(((246 - lum) / 22) + sat / 30, 0, 1) * 255).astype(np.uint8)
Image.fromarray(np.dstack([a.astype(np.uint8), al]), "RGBA").save(os.path.join(D, "token.webp"), "WEBP", quality=85, method=6)
print("v0.4 assets ok")

# v0.11.2 地点画风：12 处各一张游历底图（不进 pck，按需下载）+ 世界图上的圆形小景（进 pck，很小）
PL_VIG = {  # 名: (中心 x, 中心 y, 直径占图宽) —— 圆形小景从底图里取最有辨识度的一块
    "houshan": (0.62, 0.80, 0.50), "fangshi": (0.36, 0.17, 0.44), "hantan": (0.60, 0.17, 0.46),
    "yaowang": (0.72, 0.26, 0.42), "qingyun": (0.68, 0.13, 0.42), "yunmeng": (0.48, 0.21, 0.52),
    "xuanshuang": (0.62, 0.26, 0.48), "luoxia": (0.55, 0.20, 0.44), "wanjian": (0.58, 0.24, 0.52),
    "guzhan": (0.30, 0.83, 0.52), "mijing": (0.50, 0.15, 0.48), "xuesha": (0.50, 0.17, 0.46),
}
VS = 112
yy, xx = np.mgrid[0:VS, 0:VS]; rr = np.sqrt((xx - (VS - 1) / 2) ** 2 + (yy - (VS - 1) / 2) ** 2) / (VS / 2)
for n, (cx, cy, dw) in PL_VIG.items():
    im = Image.open(os.path.join(S, "pl_" + n + ".jpg")).convert("RGB")
    im.resize((540, 960), Image.LANCZOS).save(os.path.join(R, "web_portrait/bg", "pl_" + n + ".webp"), "WEBP", quality=60, method=6)
    W, H = im.size; d = dw * W
    c = im.crop((int(cx * W - d / 2), int(cy * H - d / 2), int(cx * W + d / 2), int(cy * H + d / 2))).resize((VS, VS), Image.LANCZOS)
    a = np.asarray(c).astype(np.float32)
    ring = np.clip(1 - np.abs(rr - 0.93) / 0.035, 0, 1)[..., None]           # 一圈淡墨边
    a = a * (1 - ring * 0.75) + np.array([60, 50, 40]) * ring * 0.75
    al = (np.clip((1.0 - rr) / 0.05, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(np.dstack([a.clip(0, 255).astype(np.uint8), al]), "RGBA").save(os.path.join(D, "vig_" + n + ".webp"), "WEBP", quality=78, method=6)
