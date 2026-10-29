#!/usr/bin/env python3
"""v0.15：履历“机制挂钩”审计——每条会写履历的 storylet / 结果分支，有没有真的改动什么。
看得见的效果 op（会在履历条下面显示成小字）：rel tag mem inj lv xp sect goal kid seclude xm fav ling wu pinj gen_item give_item take_item pick_lost attr life die spawn
纯风声（rumor，不写履历）不算。用法：python3 tools/audit_fx.py [--list] [--strict]
--strict：纯文字分支占比 ≥10%，或出现了不在 FLAVOUR_OK 白名单里的纯文字分支，就以 1 退出（run_tests.sh 里当 lint 用）"""
import json, glob, os, sys
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MECH = {"rel","tag","mem","inj","lv","xp","sect","goal","kid","seclude","xm","fav","ling","wu","pinj","gen_item","give_item","take_item","pick_lost","attr","life","die","spawn","pxw",
        "pitem","ptag","pmeet","offer","run","lead","sched"}
# 允许纯文字的分支（风闻、心境类一句话；有意为之）。新增的纯文字分支要么挂上效果，要么写进这里并说明理由
FLAVOUR_OK = set()
CH = {"chron","log","pchron"}
def walk(ops, acc):
    for o in ops or []:
        if not isinstance(o, dict): continue
        k = o.get("op","")
        acc.add(k)
        for key in ("then","else","effects"):
            if key in o: walk(o[key], acc)
        for opt in o.get("options",[]) or []:
            walk(opt.get("effects",[]), acc)
    return acc
rows = []
for f in sorted(glob.glob(os.path.join(R,"data/packs/*.json"))):
    p = json.load(open(f))
    for s in p.get("storylets", []):
        if s.get("trigger") == "bio": continue
        base = walk(s.get("effects",[]), set())
        if s.get("host_fx"):
            base.add("attr")   # 效果由游戏代码在 emit 之前改好（破境、冲关失败等），挂在这件事的条目下
        branches = []
        if s.get("outcomes"):
            for o in s["outcomes"]:
                branches.append((s["id"]+"/"+str(o.get("id","")), base | walk(o.get("effects",[]), set())))
        elif s.get("choices"):
            for c in s["choices"]:
                cb = base | walk(c.get("effects",[]), set())
                if c.get("outcomes"):
                    for o in c["outcomes"]:
                        branches.append((s["id"]+"/"+c["id"]+"/"+str(o.get("id","")), cb | walk(o.get("effects",[]), set())))
                else:
                    branches.append((s["id"]+"/"+c["id"], cb))
        else:
            branches.append((s["id"], base))
        for bid, ops in branches:
            if ops & CH:
                rows.append((os.path.basename(f), bid, bool(ops & MECH)))
n = len(rows); flav = [r for r in rows if not r[2]]
print("写履历的分支 %d 个，其中没有任何看得见效果的 %d 个（%.1f%%）" % (n, len(flav), 100.0*len(flav)/max(1,n)))
by = {}
for r in rows: by.setdefault(r[0], [0,0]); by[r[0]][0]+=1; by[r[0]][1]+= (not r[2])
for k,v in by.items(): print("  %s：%d 个分支，纯文字 %d" % (k, v[0], v[1]))
if "--list" in sys.argv:
    for r in flav: print("  纯文字：", r[0], r[1])

if "--strict" in sys.argv:
    bad = [r for r in flav if r[1] not in FLAVOUR_OK]
    pct = 100.0 * len(flav) / max(1, n)
    if pct >= 10.0 or bad:
        print("FAIL 无效果的 storylet 分支（%.1f%%，白名单外 %d 个）：" % (pct, len(bad)))
        for r in bad: print("   ", r[0], r[1])
        sys.exit(1)
    print("PASS 写履历的分支都有看得见的效果（白名单 %d 个）" % len(FLAVOUR_OK))
