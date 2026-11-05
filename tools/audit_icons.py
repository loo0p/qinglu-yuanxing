#!/usr/bin/env python3
"""v0.15.8：物品图标 + 关键 UI 行必须带图。
用法：python3 tools/audit_icons.py [--list] [--strict]
--strict：缺图标文件，或关键 UI 仍用纯文字按钮渲染人物/物品 → 退出 1（挂进 run_tests.sh）
"""
import json, os, re, sys
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = os.path.join(R, "assets/img")
main = open(os.path.join(R, "scripts/main.gd"), encoding="utf-8").read()
gs = open(os.path.join(R, "scripts/game_state.gd"), encoding="utf-8").read()
items = json.load(open(os.path.join(R, "data/items.json"), encoding="utf-8"))

def parse_const_dict(src, name):
    m = re.search(rf"const {name}\s*=\s*\{{(.*?)\n\}}", src, re.S)
    if not m:
        return {}
    return dict(re.findall(r'"([^"]+)"\s*:\s*"([^"]+)"', m.group(1)))

ICON = parse_const_dict(main, "ICON")
GICON = parse_const_dict(main, "GICON")
GICON_KEY = parse_const_dict(main, "GICON_KEY")
UI_ICON = parse_const_dict(main, "UI_ICON")
NAMES = dict(re.findall(r'"([^"]+)"\s*:\s*"([^"]+)"', re.search(r"const NAMES := \{(.*?)\}", gs, re.S).group(1)))

def resolve(iid):
    if iid in ICON: return ICON[iid]
    if iid in GICON: return GICON[iid]
    if iid in UI_ICON: return UI_ICON[iid]
    cur = items.get(iid, {})
    key = cur.get("icon") if isinstance(cur, dict) else None
    seen = set()
    while isinstance(cur, dict) and cur.get("inherits") and not key:
        inh = cur["inherits"]
        if inh in seen: break
        seen.add(inh)
        cur = items.get(inh, {})
        key = cur.get("icon") if isinstance(cur, dict) else None
    if key and key in GICON_KEY: return GICON_KEY[key]
    if key and key in GICON: return GICON[key]
    return None

ids = set()
for k in NAMES:
    if not k.startswith("res_"):
        ids.add(k)
for k, v in items.items():
    if isinstance(v, dict) and v.get("name"):
        ids.add(k)
# also abstract UI keys
for k in UI_ICON:
    ids.add(k)

missing_map = []
missing_file = []
proxy = []  # kept for report only; proxies of distinct items are FAIL if same as qingzhi for zizhi/xugucao
for iid in sorted(ids):
    ico = resolve(iid)
    if not ico:
        missing_map.append(iid)
        continue
    path = os.path.join(IMG, ico + ".webp")
    if not os.path.isfile(path):
        missing_file.append((iid, ico))
    if iid in ("herb_zizhi", "herb_xugucao") and ico == "ico_qingzhi":
        proxy.append((iid, ico))
    if iid == "pill_quzhang" and ico == "ico_g_hulu":
        proxy.append((iid, ico))

# UI pattern checks: critical surfaces must call BI/IC/PBox/_mini_face (not bare text for items/people)
ui_checks = []
def has(pat, label, where_slice=None):
    src = main if where_slice is None else main[where_slice[0]:where_slice[1]]
    ok = re.search(pat, src, re.S) is not None
    ui_checks.append((label, ok))

# locate function bodies roughly
def body(fn):
    m = re.search(rf"func {fn}\(.*?\).*?:\n(.*?)(?=\nfunc |\Z)", main, re.S)
    return m.group(0) if m else ""

bj = body("_sheet_jobs")
ui_checks.append(("差事榜用 BI/IC", ("BI(" in bj or "IC(" in bj) and "UI_ICON" in bj))
by = body("_sheet_yao")
ui_checks.append(("货郎以物易物用 BI+item_icon", "item_icon" in by and "BI(" in by and "Estate.BARTER" in by))
ba = body("_sheet_auc")
ui_checks.append(("拍卖拍品带 gear_icon/IC", "gear_icon(lot)" in ba and "IC(" in ba))
bm = body("_sheet_men")
ui_checks.append(("门下带 PBox 小头像", "PBox" in bm and "npc_spec" in bm))
be = body("_estate_card")
ui_checks.append(("营建按钮用 BI+UI_ICON", "BI(" in be and "UI_ICON" in be))
bl = body("_life_timeline")
ui_checks.append(("履历条目可挂物品小图标", "_life_items" in bl and "item_icon" in bl))
# seclude 故人
ui_checks.append(("出关故人可挂小头像", "_mini_face" in body("_modal") or ("故人" in main and "_mini_face(o" in main)))
ui_checks.append(("存在 item_icon 助手", "func item_icon(" in main))

print("物品 id %d：缺映射 %d，缺文件 %d，禁止套用 %d" % (len(ids), len(missing_map), len(missing_file), len(proxy)))
if "--list" in sys.argv or missing_map or missing_file or proxy:
    for x in missing_map: print("  缺映射", x)
    for a,b in missing_file: print("  缺文件", a, "->", b)
    for a,b in proxy: print("  仍套用", a, "->", b)
print("UI 检查：")
for lab, ok in ui_checks:
    print("  %s %s" % ("OK" if ok else "FAIL", lab))

fail = bool(missing_map or missing_file or proxy or any(not ok for _, ok in ui_checks))
if "--strict" in sys.argv and fail:
    print("FAIL audit_icons")
    sys.exit(1)
print("PASS audit_icons" if not fail else "WARN audit_icons（未 --strict）")
sys.exit(0 if not fail else (1 if "--strict" in sys.argv else 0))
