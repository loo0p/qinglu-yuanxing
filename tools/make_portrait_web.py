#!/usr/bin/env python3
"""立绘部件 → Web 用 WebP（不进 pck，站点 portrait/ 下按需下载）。
用法：python3 tools/make_portrait_web.py <烘焙目录，如 yunxiu/portrait/godot_rig5/portrait5>
输出：web_portrait/**.webp（彩色有损 q80；mask/aux 无损）、data/lib5.json、data/portrait_files.json。
烘焙原图（PNG/JPG，约 31 MB）不进本仓库，留在 yunxiu/portrait。"""
import os, sys, glob, json, shutil
from PIL import Image
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = sys.argv[1]
dst = os.path.join(R, 'web_portrait')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import portrait_fixes as FX          # 个别部件的修补（裘的白点等）
except ImportError:
    FX = None
lib = json.load(open(os.path.join(src, 'lib5.json')))
if FX:
    FX.LIB, FX.SRC = lib, src
rels = []
only = sys.argv[2:]                     # 可选：只重做文件名含这些子串的
for f in sorted(glob.glob(src + '/*/*')):
    if f.endswith('.import'): continue
    rel = os.path.relpath(f, src); rels.append(rel)
    if only and not any(o in rel for o in only): continue
    out = os.path.join(dst, os.path.splitext(rel)[0] + '.webp')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    im = Image.open(f)
    if FX: im = FX.fix(rel, im)
    if rel.endswith('.mask.png') or rel.endswith('.aux.png'):
        im.save(out, 'WEBP', lossless=True, quality=100, method=6)
    else:
        im.save(out, 'WEBP', quality=80, method=6)
if FX and hasattr(FX, 'fix_lib'): lib = FX.fix_lib(lib)
json.dump(lib, open(os.path.join(R, 'data/lib5.json'), 'w'), ensure_ascii=False, separators=(',', ':'))
json.dump(rels, open(os.path.join(R, 'data/portrait_files.json'), 'w'), ensure_ascii=False)
open(os.path.join(dst, '.gdignore'), 'w').close()
tot = sum(os.path.getsize(p) for p in glob.glob(dst + '/*/*.webp'))
print(len(rels), 'files', round(tot / 1e6, 2), 'MB')
# 五官贴片打包（网页版按包取）
import subprocess
subprocess.run([sys.executable, os.path.join(R, 'tools/bundle_portraits.py')], check=True)
