#!/usr/bin/env python3
"""字体子集：正文 霞鹜文楷（LXGW WenKai, OFL）+ 标题 马善政毛笔楷书（Ma Shan Zheng, OFL）。
只保留游戏里真正用到的字（扫 data/*.json、data/packs/*.json 与 scripts/*.gd）。改了文案要重跑。
用法：python3 tools/make_font.py <WenKai.ttf> <MaShanZheng.ttf>（需要 fonttools：pip install fonttools）"""
import glob, os, re, sys, subprocess
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
body = set(chr(c) for c in range(0x20, 0x7f)) | set("◎◉○●·—…×→←↑↓「」『』《》、。，！？：；（）【】％＋－／～✓⚠“”‘’")
brush = set("0123456789第日炼气一二三四五六七八九十层筑基初期圆满") | set("".join(["苏青禾", "林晚照", "沈知微", "温小满", "田丹炉仓姑母行囊近况"]))
for f in glob.glob(R + "/data/*.json") + glob.glob(R + "/data/packs/*.json") + glob.glob(R + "/scripts/*.gd"):
    t = open(f, encoding="utf-8").read(); body |= set(t)
    if f.endswith("main.gd"):
        for m in re.findall(r'H\("([^"]*)"', t): brush |= set(m)
    if f.endswith(".json"):
        for m in re.findall(r'"(?:title|name)":\s*"([^"]*)"', t): brush |= set(m)
from fontTools.ttLib import TTFont
_has = lambda path: set(chr(k) for k in TTFont(path).getBestCmap())
_hb, _hm = _has(sys.argv[1]), _has(sys.argv[2])
body = set(c for c in body if c in _hb or c in " \n")
brush = set(c for c in brush if c in _hm)   # 毛笔字体缺的字（如“·”）不列入，标题自动退回正文字体
body = "".join(sorted(c for c in body if c.isprintable()))
brush = "".join(sorted(c for c in brush if c.isprintable()))
os.makedirs(R + "/fonts", exist_ok=True)
open(R + "/fonts/glyphs.txt", "w", encoding="utf-8").write(body)   # 运行时用来判断名字能否显示
open(R + "/fonts/glyphs_brush.txt", "w", encoding="utf-8").write(brush)   # 标题字缺字时退回正文字体
for src, dst, chars in [(sys.argv[1], "WenKai-sub.ttf", body), (sys.argv[2], "MaShanZheng-sub.ttf", brush)]:
    tf = "/tmp/_chars.txt"; open(tf, "w", encoding="utf-8").write(chars + "\u200b")   # 零宽空格：避头尾的断点（main.gd kt()）
    subprocess.run([sys.executable, "-m", "fontTools.subset", src, "--text-file=" + tf, "--output-file=" + R + "/fonts/" + dst,
                    "--layout-features=*", "--no-hinting", "--desubroutinize"], check=True)
    print(dst, len(chars), "字", os.path.getsize(R + "/fonts/" + dst), "bytes")
