#!/usr/bin/env python3
"""把 web_portrait/feat/ 下的五官贴片按“目标脸型”打成一个个小包：web_portrait/pack/feat_<base>.bin。
网页版一张脸只需取 1 个包，而不是十几个小文件（v0.6.8：请求数 ~750 → ~150，弱网/跨境时少很多握手）。
包格式（小端）：u32 条数，然后每条 u16 名字长度、名字（UTF-8，即 rel）、u32 字节数、WebP 字节。
另写 data/portrait_bundles.json：{rel: "pack/feat_<base>.bin"}。用法：python3 tools/bundle_portraits.py"""
import os, re, json, struct, glob, collections
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W = os.path.join(R, "web_portrait")
rels = json.load(open(os.path.join(R, "data/portrait_files.json"), encoding="utf-8"))
groups = collections.defaultdict(list)
for rel in rels:
    if not rel.startswith("feat/"):
        continue
    m = re.search(r"__(base_[a-z0-9]+)__", rel)
    groups["feat_" + (m.group(1) if m else "misc")].append(rel)
os.makedirs(os.path.join(W, "pack"), exist_ok=True)
for f in glob.glob(os.path.join(W, "pack", "*.bin")):
    os.remove(f)
index = {}
for g, lst in sorted(groups.items()):
    out = bytearray(struct.pack("<I", len(lst)))
    for rel in lst:
        b = open(os.path.join(W, os.path.splitext(rel)[0] + ".webp"), "rb").read()
        n = rel.encode("utf-8")
        out += struct.pack("<H", len(n)) + n + struct.pack("<I", len(b)) + b
        index[rel] = "pack/%s.bin" % g
    open(os.path.join(W, "pack", g + ".bin"), "wb").write(out)
json.dump(index, open(os.path.join(R, "data/portrait_bundles.json"), "w", encoding="utf-8"), ensure_ascii=False, sort_keys=True)
print(len(groups), "包", len(index), "条", round(sum(os.path.getsize(f) for f in glob.glob(os.path.join(W, "pack", "*.bin"))) / 1e6, 2), "MB")
