#!/usr/bin/env python3
"""给导出目录里的大文件生成 .gz（以及可用时的 .br），并打印首次加载体积。"""
import gzip, os, sys
d = sys.argv[1] if len(sys.argv) > 1 else "build/web"
try:
    import brotli
except Exception:
    brotli = None
tot = totgz = 0
for f in sorted(os.listdir(d)):
    p = os.path.join(d, f)
    if not os.path.isfile(p) or f.endswith((".gz", ".br")):
        continue
    raw = open(p, "rb").read()
    tot += len(raw)
    gz = gzip.compress(raw, 9, mtime=0)
    totgz += len(gz)
    if f.endswith((".wasm", ".pck", ".js", ".html")):
        open(p + ".gz", "wb").write(gz)
        if brotli:
            open(p + ".br", "wb").write(brotli.compress(raw, quality=11))
    print("%-28s %9d  gz %9d" % (f, len(raw), len(gz)))
print("合计 %.2f MB · gzip 后 %.2f MB" % (tot / 1e6, totgz / 1e6))
