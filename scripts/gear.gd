extends RefCounted
## v0.14 行囊 · 装备 · 坊市（design redesign-v0.13 §5）
## 物品模板：data/items.json（GLoot prototree 格式，子原型继承父属性；vendor/gloot 的 ProtoTree 读）。
## 实例（存档里）：{"u" 号, "p" 原型, "g" 品阶 0–4, "n" 名字, "af" [[词缀, 值]], "h" [[月, 事]], "dur" 耐久, "m" 造成之月, "c" 张数（符）}
## 她的东西在 gs.s["gear"]：eq（槽 → 实例 / null）、bag（随身未装的）、home（洞府里）；NPC 的在 c["gear"]（按种子懒生成）。
## 约定：什么都没装时，所有效果都是恒等（v3.2 规则测试锁的数值不动）；不用 gs.rng / W.rng（不扰乱规则与江湖的随机序列）。
const ProtoTree = preload("res://scripts/vendor/gloot/proto_tree.gd")

const SLOTS := ["fabao", "yi", "shi", "shi2", "fu", "dai"]
const SLOT_NAME := {"fabao": "法宝", "yi": "法衣", "shi": "佩饰", "shi2": "佩饰", "fu": "符", "dai": "储物"}
const GRADES := ["凡品", "法器", "灵器", "宝器", "仙器"]
const GCOL := ["#8a8478", "#5f9ea0", "#4caf7a", "#c0504d", "#d4a72c"]   # 墨灰 / 青 / 碧 / 绛 / 金
const GBASE := [5, 40, 300, 2500, 20000]
const GMIN := [0, 0, 9, 12, 15]          # 能祭用的最低境界（法器 炼气、灵器 筑基、宝器 金丹、仙器 元婴）；越阶可持有
const GPW := [0.5, 1.0, 1.8, 2.6, 3.5]   # 法宝品阶 → 斗法加成（与 lv 同一刻度）
const GMUL := [1.0, 1.0, 1.5, 2.2, 3.0]  # 词缀数值随品阶放大
const DEF_CAP := 40
const BASES := {"fabao": ["剑", "飞剑", "伞", "铃", "印"], "yi": ["道袍", "软甲"], "shi": ["玉佩", "簪", "戒"], "dai": ["储物袋", "储物戒", "芥子镯"]}
## 词缀（同 group 互斥）。pre 改名字，suf 写进说明。值域按 GMUL[品阶] 放大
const AFFIXES := [
	{"id": "qingfeng", "name": "青锋", "pos": "pre", "group": "pw_a", "slots": ["fabao"], "stat": "pw", "lo": 0.3, "hi": 0.6, "w": 10},
	{"id": "hanshuang", "name": "寒霜", "pos": "pre", "group": "pw_a", "slots": ["fabao"], "stat": "pw", "lo": 0.3, "hi": 0.6, "w": 8},
	{"id": "chiyan", "name": "赤焰", "pos": "pre", "group": "pw_a", "slots": ["fabao"], "stat": "pw", "lo": 0.4, "hi": 0.7, "w": 6},
	{"id": "liuyun", "name": "流云", "pos": "pre", "group": "def_a", "slots": ["fabao", "yi"], "stat": "def", "lo": 2, "hi": 4, "w": 8},
	{"id": "xuantie", "name": "玄铁", "pos": "pre", "group": "dur_a", "slots": ["fabao", "yi"], "stat": "tough", "lo": 20, "hi": 40, "w": 6},
	{"id": "yunwen", "name": "云纹", "pos": "pre", "group": "def_a", "slots": ["yi"], "stat": "def", "lo": 3, "hi": 5, "w": 8},
	{"id": "bihai", "name": "碧海", "pos": "pre", "group": "xw_a", "slots": ["shi"], "stat": "xw", "lo": 2, "hi": 4, "w": 8},
	{"id": "ningshen", "name": "凝神", "pos": "pre", "group": "wu_a", "slots": ["shi", "fabao"], "stat": "wu", "lo": 3, "hi": 6, "w": 6},
	{"id": "ziyu", "name": "紫玉", "pos": "pre", "group": "xw_a", "slots": ["shi"], "stat": "xw", "lo": 3, "hi": 5, "w": 5},
	{"id": "jinsi", "name": "金丝", "pos": "pre", "group": "cells_a", "slots": ["dai"], "stat": "cells", "lo": 1, "hi": 2, "w": 8},
	{"id": "qingling", "name": "轻灵", "pos": "pre", "group": "wcap_a", "slots": ["dai"], "stat": "wcap", "lo": 10, "hi": 20, "w": 8},
	{"id": "guyu", "name": "古韵", "pos": "pre", "group": "val_a", "slots": ["fabao", "yi", "shi", "dai"], "stat": "val", "lo": 10, "hi": 25, "w": 4},
	{"id": "poja", "name": "破甲", "pos": "suf", "group": "pw_b", "slots": ["fabao"], "stat": "pw", "lo": 0.2, "hi": 0.5, "w": 8},
	{"id": "zhuifeng", "name": "追风", "pos": "suf", "group": "pw_b", "slots": ["fabao"], "stat": "pw", "lo": 0.2, "hi": 0.4, "w": 8},
	{"id": "yanghun", "name": "养魂", "pos": "suf", "group": "xw_b", "slots": ["fabao", "shi", "yi"], "stat": "xw", "lo": 2, "hi": 4, "w": 6},
	{"id": "huti", "name": "护体", "pos": "suf", "group": "def_b", "slots": ["yi", "shi"], "stat": "def", "lo": 2, "hi": 4, "w": 8},
	{"id": "bizhang", "name": "避瘴", "pos": "suf", "group": "def_c", "slots": ["yi"], "stat": "def", "lo": 1, "hi": 3, "w": 6},
	{"id": "bishui", "name": "避水", "pos": "suf", "group": "def_c", "slots": ["yi"], "stat": "def", "lo": 1, "hi": 3, "w": 6},
	{"id": "guiyuan", "name": "归元", "pos": "suf", "group": "wu_b", "slots": ["shi", "fabao"], "stat": "wu", "lo": 2, "hi": 5, "w": 6},
	{"id": "bigu", "name": "辟谷", "pos": "suf", "group": "rs_b", "slots": ["shi"], "stat": "rsave", "lo": 15, "hi": 30, "w": 6},
	{"id": "jianren", "name": "坚韧", "pos": "suf", "group": "dur_b", "slots": ["fabao", "yi", "shi", "dai"], "stat": "tough", "lo": 20, "hi": 40, "w": 6},
	{"id": "naxu", "name": "纳虚", "pos": "suf", "group": "cells_b", "slots": ["dai"], "stat": "cells", "lo": 1, "hi": 3, "w": 6},
	{"id": "qingshen", "name": "轻身", "pos": "suf", "group": "wcap_b", "slots": ["dai"], "stat": "wcap", "lo": 10, "hi": 30, "w": 6},
	{"id": "jingxin", "name": "静心", "pos": "suf", "group": "wu_c", "slots": ["yi", "shi"], "stat": "wu", "lo": 2, "hi": 4, "w": 6},
	{"id": "shoushen", "name": "守神", "pos": "suf", "group": "def_d", "slots": ["fabao"], "stat": "def", "lo": 2, "hi": 3, "w": 6},
	{"id": "chengyuan", "name": "承缘", "pos": "suf", "group": "val_b", "slots": ["fabao", "yi", "shi", "dai"], "stat": "val", "lo": 10, "hi": 20, "w": 4},
]
const STAT_NAME := {"pw": "斗法", "def": "护体%", "xw": "闭关修为%", "wu": "感悟%", "rsave": "省辟谷丹%", "cells": "格数", "wcap": "负重", "tough": "耐磨%", "val": "身价%"}

static var _tree = null
static var _afx := {}

static func tree():
	if _tree == null:
		_tree = ProtoTree.new()
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
		var okd: bool = _tree.deserialize(d if d is Dictionary else {})
		assert(okd, "data/items.json：有 inherits 挂不上")
		for a in AFFIXES:
			_afx[a["id"]] = a
	return _tree

static func prop(pid: String, k: String, d: Variant = null) -> Variant:
	return tree().get_prototype_property(pid, k, d)

static func has_proto(pid: String) -> bool:
	return tree().has_prototype(pid)

static func is_a(pid: String, base: String) -> bool:
	return has_proto(pid) and has_proto(base) and tree().get_prototype(pid).inherits(base)

static func afx(id: String) -> Dictionary:
	tree()
	return _afx.get(id, {})

static func slot_of(it: Dictionary) -> String:
	return String(prop(String(it["p"]), "slot", ""))

# ================================================================ 生成
static func _uid(gs, W) -> int:
	var d: Dictionary = gs.s["gear"] if gs != null and gs.s.has("gear") else W.w
	var k := "nu" if gs != null and gs.s.has("gear") else "gnu"
	d[k] = int(d.get(k, 0)) + 1
	return int(d[k])

static func _pick_w(rng: RandomNumberGenerator, arr: Array) -> Dictionary:
	var tot := 0.0
	for a in arr:
		tot += float(a["w"])
	var x := rng.randf() * tot
	for a in arr:
		x -= float(a["w"])
		if x <= 0.0:
			return a
	return arr[-1]

## 造一件。rng 是调用方给的独立随机源（店、NPC、拍卖各用各的种子）
static func make(gs, W, rng: RandomNumberGenerator, pid: String, g: int, origin: String, day: int) -> Dictionary:
	g = clampi(maxi(g, int(prop(pid, "min_g", 0))), 0, 4)
	var it := {"u": _uid(gs, W), "p": pid, "g": g, "n": String(prop(pid, "name", pid)), "af": [], "h": [[day, origin]], "dur": 100, "m": day}
	if String(prop(pid, "kind", "")) == "charm":
		it["c"] = 1
		it["g"] = 0
		return it
	var sl := String(prop(pid, "slot", ""))
	var used := {}
	var pool := []
	tree()
	for a in AFFIXES:
		if sl in a["slots"]:
			pool.append(a)
	var pre := ""
	var sufs := []
	for i in g:
		var cand := pool.filter(func(a): return not used.has(a["group"]) and not (a["pos"] == "pre" and pre != ""))
		if cand.is_empty():
			break
		var a := _pick_w(rng, cand)
		used[a["group"]] = true
		var v := (float(a["lo"]) + (float(a["hi"]) - float(a["lo"])) * rng.randf()) * float(GMUL[g])
		v = snappedf(v, 0.1) if String(a["stat"]) == "pw" else float(roundi(v))
		it["af"].append([a["id"], v])
		if a["pos"] == "pre":
			pre = a["name"]
		else:
			sufs.append(a["name"])
	if pre != "":
		var base := String(it["n"])
		var clash := false
		for ch in pre:
			if base.contains(ch):
				clash = true
		it["n"] = (pre + base) if not clash else (pre.substr(0, 1) + base)
	elif String(it["n"]).length() == 1:
		# v0.14 修：没抽到前缀的单字器物（剑、戒、簪…）补个材质，不在铺子里只写一个“剑”
		var plain: Dictionary = PLAIN_HI if g >= 1 else PLAIN_LO
		it["n"] = String(plain.get(String(it["n"]), String(it["n"])))
	return it

const PLAIN_LO := {"剑": "铁剑", "伞": "油纸伞", "铃": "铜铃", "印": "石印", "簪": "木簪", "戒": "铜戒"}
const PLAIN_HI := {"剑": "精钢剑", "伞": "青罗伞", "铃": "紫铜铃", "印": "青石印", "簪": "银簪", "戒": "银戒"}

static func grade_name(it: Dictionary) -> String:
	return GRADES[clampi(int(it.get("g", 0)), 0, 4)]

static func full_name(it: Dictionary) -> String:
	var n := String(it["n"])
	if it.has("c"):
		return "%s×%d" % [n, int(it["c"])]
	return n

static func suffix_text(it: Dictionary) -> String:
	var out := []
	for a in it.get("af", []):
		var d := afx(String(a[0]))
		if d.get("pos", "") == "suf":
			out.append("·" + String(d["name"]))
	return "".join(out)

# ================================================================ 数值
static func _dur_k(it: Dictionary) -> float:
	var d := int(it.get("dur", 100))
	return 1.0 if d >= 30 else (0.6 if d > 0 else 0.3)

static func stat(it: Dictionary, k: String) -> float:
	var p := String(it["p"])
	var g := clampi(int(it.get("g", 0)), 0, 4)
	var v := 0.0
	match k:
		"pw":
			if slot_of(it) == "fabao":
				v = float(prop(p, "pw", 1.0)) * float(GPW[g])
		"def":
			var b := float(prop(p, "def", 0))
			v = b + (g * 4.0 if b > 0 and slot_of(it) == "yi" else 0.0)
		"xw", "wu":
			var b2 := float(prop(p, k, 0))
			v = b2 * (1.0 + g * 0.5)
		"rsave":
			var b3 := float(prop(p, "rsave", 0))
			v = b3 + (g * 5.0 if b3 > 0 else 0.0)
		"cells", "wcap":
			v = float(prop(p, k, 0))
	for a in it.get("af", []):
		if String(afx(String(a[0])).get("stat", "")) == k:
			v += float(a[1])
	if k in ["pw", "def"]:
		v *= _dur_k(it)
	return v

## 价值（灵石，未计行情）
static func value(it: Dictionary, day: int = -1) -> int:
	var p := String(it["p"])
	var kind := String(prop(p, "kind", ""))
	if kind in ["mat", "pill", "fu"]:
		var v := float(prop(p, "value", 1))
		var life := int(prop(p, "life", 0))
		if life > 0 and day >= 0 and day - int(it.get("m", day)) > life:
			v *= float(prop(p, "decay_to", 0.5))
		return maxi(1, roundi(v)) * int(it.get("c", 1))
	if kind == "charm":
		return 6 * int(it.get("c", 1))
	var g := clampi(int(it.get("g", 0)), 0, 4)
	var k: float = 1.0 + 0.15 * it.get("af", []).size() + stat(it, "val") / 100.0
	if slot_of(it) == "dai":
		k *= 1.0 + 0.5 * maxi(0, int(stat(it, "cells")) - 6) / 6.0
	var dk := 0.4 + 0.6 * clampf(int(it.get("dur", 100)) / 100.0, 0.0, 1.0)
	return maxi(1, roundi(float(GBASE[g]) * k * dk))

static func weight(it: Dictionary) -> float:
	return float(prop(String(it["p"]), "weight", 1.0)) * int(it.get("c", 1))

static func usable(gs, it: Dictionary) -> bool:
	return int(gs.s.get("plv", 0)) >= int(GMIN[clampi(int(it.get("g", 0)), 0, 4)])

# ================================================================ 她的东西
static func blank() -> Dictionary:
	return {"nu": 0, "eq": {"fabao": null, "yi": null, "shi": null, "shi2": null, "fu": null, "dai": null},
		"bag": [], "home": [], "racc": 0, "sold": {}, "shop": {}, "auc": {}}

## 新开局 / 旧档迁移：补上 gear，并给她一只布囊（原先“随身六格”就是这只）
static func ensure(gs) -> void:
	if gs.s.has("gear") and gs.s["gear"] is Dictionary:
		var g0: Dictionary = gs.s["gear"]
		for k in blank():
			if not g0.has(k):
				g0[k] = blank()[k]
		return
	gs.s["gear"] = blank()
	var it := {"u": _uid(gs, null), "p": "布囊", "g": 0, "n": "布囊", "af": [], "h": [[0, "入青庐那年自己缝的口袋。"]], "dur": 100, "m": 0}
	gs.s["gear"]["eq"]["dai"] = it

static func eq(gs, slot: String) -> Variant:
	if not gs.s.has("gear"):
		return null
	return gs.s["gear"]["eq"].get(slot)

static func equipped(gs) -> Array:
	var out := []
	if not gs.s.has("gear"):
		return out
	for k in SLOTS:
		var it = gs.s["gear"]["eq"].get(k)
		if it != null:
			out.append(it)
	return out

static func her_stat(gs, k: String) -> float:
	var v := 0.0
	for it in equipped(gs):
		if usable(gs, it):
			v += stat(it, k)
	return minf(v, DEF_CAP) if k == "def" else v

## 行囊格数（丹、符和随身的器物共用）：储物袋的格数 − 随身未装的器物
static func cells(gs) -> int:
	var d = eq(gs, "dai")
	var c := 6 if d == null else int(stat(d, "cells"))
	if not gs.s.has("gear"):
		return c
	return maxi(0, c - gs.s["gear"]["bag"].size())

static func wcap(gs) -> float:
	var d = eq(gs, "dai")
	return 20.0 if d == null else stat(d, "wcap")

static func load_w(gs) -> float:
	var v := 0.0
	for it in equipped(gs):
		if slot_of(it) != "dai":
			v += weight(it)
	for it in gs.s["gear"]["bag"]:
		v += weight(it)
	for sl in gs.s.get("pack", []):
		v += float(prop(String(sl["id"]), "weight", 0.1)) * int(sl["n"])
	return snappedf(v, 0.1)

static func find(gs, u: int) -> Array:
	## 返回 [所在, 键/下标, 实例]；所在 = "eq" / "bag" / "home"
	var G: Dictionary = gs.s["gear"]
	for k in SLOTS:
		var it = G["eq"].get(k)
		if it != null and int(it["u"]) == u:
			return ["eq", k, it]
	for where in ["bag", "home"]:
		for i in G[where].size():
			if int(G[where][i]["u"]) == u:
				return [where, i, G[where][i]]
	return []

static func _take(gs, u: int) -> Dictionary:
	var f := find(gs, u)
	if f.is_empty():
		return {}
	if f[0] == "eq":
		gs.s["gear"]["eq"][f[1]] = null
	else:
		gs.s["gear"][f[0]].remove_at(int(f[1]))
	return f[2]

## 装上：只在青庐（或随身带着时）能换；越阶的不能祭用；原槽里的放回原处
static func equip(gs, u: int) -> String:
	var f := find(gs, u)
	if f.is_empty() or f[0] == "eq":
		return "没有这件。"
	var it: Dictionary = f[2]
	if f[0] == "home" and not gs.at_home():
		return "这件放在青庐里，回去才能换上。"
	if not usable(gs, it):
		return "%s要%s以上才祭得动。" % [grade_name(it), ["炼气", "炼气", "筑基", "金丹", "元婴"][int(it["g"])]]
	var sl := slot_of(it)
	if sl == "":
		return "这不是能佩在身上的东西。"
	if sl == "shi" and eq(gs, "shi") != null and eq(gs, "shi2") == null:
		sl = "shi2"
	if sl == "dai" and not gs.at_home():
		return "储物袋要在青庐里倒腾。"
	var old = gs.s["gear"]["eq"].get(sl)
	_take(gs, u)
	gs.s["gear"]["eq"][sl] = it
	if old != null:
		gs.s["gear"][f[0]].append(old)
	if sl == "dai":
		_fit_pack(gs)
	return ""

static func unequip(gs, u: int) -> String:
	var f := find(gs, u)
	if f.is_empty() or f[0] != "eq":
		return "没装着。"
	if f[1] == "dai":
		return "储物袋卸不得，换一只别的装上就是。"
	var it := _take(gs, u)
	if gs.at_home():
		gs.s["gear"]["home"].append(it)
	elif cells(gs) > 0:
		gs.s["gear"]["bag"].append(it)
	else:
		gs.s["gear"]["eq"][f[1]] = it
		return "行囊满了，卸下来没处放。"
	return ""

## 带上（洞府 → 行囊）/ 放回（行囊 → 洞府）
static func carry(gs, u: int) -> String:
	var f := find(gs, u)
	if f.is_empty() or f[0] != "home":
		return "没有这件。"
	if cells(gs) - gs.s.get("pack", []).size() <= 0:
		return "行囊满了。"
	if load_w(gs) + weight(f[2]) > wcap(gs):
		return "太沉了，%s装不下（负重 %s/%s 斤）。" % [String(eq(gs, "dai")["n"]) if eq(gs, "dai") != null else "布囊", str(load_w(gs)), str(wcap(gs))]
	gs.s["gear"]["bag"].append(_take(gs, u))
	return ""

static func stash(gs, u: int) -> String:
	var f := find(gs, u)
	if f.is_empty() or f[0] != "bag":
		return "没有这件。"
	if not gs.at_home():
		return "人在外头，放不回青庐。"
	gs.s["gear"]["home"].append(_take(gs, u))
	return ""

## 换小袋子时，装不下的丹符退回洞府（不丢）
static func _fit_pack(gs) -> void:
	var room := cells(gs)
	while gs.s["pack"].size() > room and not gs.s["pack"].is_empty():
		var sl = gs.s["pack"].pop_back()
		gs._store_add(String(sl["id"]), int(sl["n"]))
	while cells(gs) < 0 and not gs.s["gear"]["bag"].is_empty():
		gs.s["gear"]["home"].append(gs.s["gear"]["bag"].pop_back())

## 她得到一件（送的 / 买的 / 捡的）：在青庐就放洞府，在外头先进行囊，行囊满了托人捎回青庐
static func give_her(gs, it: Dictionary, how: String) -> void:
	var W = gs.world
	var day := int(W.w["day"]) if W != null else int(gs.s.get("day", 0))
	if it.get("ext", false):   # 从别人手里来的：换成她这边的号
		it.erase("ext")
		it["u"] = _uid(gs, null)
	it["h"].append([day, how])
	if it.has("c"):
		var cur = eq(gs, "fu")
		if cur != null and String(cur["p"]) == String(it["p"]) and int(cur["c"]) + int(it["c"]) <= int(prop(String(it["p"]), "stack", 9)):
			cur["c"] = int(cur["c"]) + int(it["c"])
			cur["m"] = day
			return
		if cur == null:
			gs.s["gear"]["eq"]["fu"] = it
			return
	if gs.at_home() or cells(gs) - gs.s.get("pack", []).size() <= 0:
		gs.s["gear"]["home"].append(it)
	else:
		gs.s["gear"]["bag"].append(it)

static func all_mine(gs) -> Array:
	var out := equipped(gs)
	out.append_array(gs.s["gear"]["bag"])
	out.append_array(gs.s["gear"]["home"])
	return out

## 被劫走的：随身最值钱的那件（不含储物袋本身）
static func her_best_carried(gs) -> Variant:
	var best = null
	var day := int(gs.s.get("day", 0))
	var lst := []
	for it in equipped(gs):
		if slot_of(it) != "dai" and not it.has("c"):
			lst.append(it)
	lst.append_array(gs.s["gear"]["bag"])
	for it in lst:
		if best == null or value(it, day) > value(best, day):
			best = it
	return best

# ================================================================ 效果钩子（全都“没装 = 原样”）
static func xw_bonus(gs, v: int) -> int:
	var p := int(her_stat(gs, "xw"))
	return v + v * p / 100 if p > 0 else v

static func wu_bonus(gs, v: int) -> int:
	var p := int(her_stat(gs, "wu"))
	return v + v * p / 100 if p > 0 and v > 0 else v

## 路上一个月：戒指的“省辟谷丹”累计到 100 就省一颗（确定性，不掷骰子）
static func ration_saved(gs) -> bool:
	var p := int(her_stat(gs, "rsave"))
	if p <= 0:
		return false
	var G: Dictionary = gs.s["gear"]
	G["racc"] = int(G.get("racc", 0)) + p
	if int(G["racc"]) >= 100:
		G["racc"] = int(G["racc"]) - 100
		return true
	return false

## 受伤：法衣减月数；符槽里有护身符就烧一张；法宝、法衣磨损。返回实际伤的月数
static func on_injury(gs, days: int) -> int:
	if not gs.s.has("gear") or days <= 0:
		return days
	var d := days
	var df := her_stat(gs, "def")
	if df > 0:
		d = maxi(1, d - int(d * df / 100.0))
	var fu = eq(gs, "fu")
	if fu != null and int(prop(String(fu["p"]), "ward", 0)) > 0 and int(fu.get("c", 0)) > 0:
		d = maxi(1, d - int(d * int(prop(String(fu["p"]), "ward", 0)) / 100))
		fu["c"] = int(fu["c"]) - 1
		gs._log("护身符烧成了灰，伤轻了些。")
		if int(fu["c"]) <= 0:
			gs.s["gear"]["eq"]["fu"] = null
	for sl in ["fabao", "yi"]:
		var it = eq(gs, sl)
		if it != null:
			var wr := int(prop(String(it["p"]), "wear", 0))
			wr = maxi(1, wr - int(wr * stat(it, "tough") / 100.0)) if wr > 0 else 0
			var before := int(it.get("dur", 100))
			it["dur"] = maxi(0, before - wr)
			if before >= 30 and int(it["dur"]) < 30:
				gs.notice("%s磨损得厉害（耐久 %d），回坊市修一修。" % [it["n"], int(it["dur"])])
	return d

## 冲关心魔没过：静心符烧一张，道心不稳从 3 个月减到 1 个月
static func on_xinmo_fail(gs) -> bool:
	var fu = eq(gs, "fu")
	if fu != null and int(prop(String(fu["p"]), "calm", 0)) > 0 and int(fu.get("c", 0)) > 0:
		fu["c"] = int(fu["c"]) - 1
		if int(fu["c"]) <= 0:
			gs.s["gear"]["eq"]["fu"] = null
		return true
	return false

## 每月：符箓过期（失了灵）、坊市卖货的饱和慢慢消退
static func monthly(gs) -> void:
	if not gs.s.has("gear"):
		return
	var G: Dictionary = gs.s["gear"]
	var day := int(gs.s.get("day", 0))
	var lst := equipped(gs)
	lst.append_array(G["bag"])
	lst.append_array(G["home"])
	for it in lst:
		var life := int(prop(String(it["p"]), "life", 0))
		if life > 0 and String(prop(String(it["p"]), "kind", "")) == "charm" and day - int(it.get("m", day)) >= life:
			var f := find(gs, int(it["u"]))
			if not f.is_empty():
				_take(gs, int(it["u"]))
				gs._log("%s放了%s年，朱砂褪了色，失了灵。" % [full_name(it), ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"][clampi(life / 12 - 1, 0, 9)]])
				gs.notice("%s过了年头，失了灵。" % it["n"])
	if day % 6 == 0:
		for k in G["sold"].keys():
			G["sold"][k] = maxi(0, int(G["sold"][k]) - 1)
			if int(G["sold"][k]) == 0:
				G["sold"].erase(k)

# ================================================================ 江湖里的人
static func npc_gear(W, c: Dictionary) -> Array:
	if c.is_empty() or c.get("player", false):
		return []
	if not c.has("gear"):
		c["gear"] = []
		var r := RandomNumberGenerator.new()
		r.seed = int(c.get("pseed", int(c["id"]) * 7919)) ^ 0x6EA2
		var lv := int(c["lv"])
		var gmax := 0 if lv < 3 else (1 if lv < 9 else (2 if lv < 12 else (3 if lv < 15 else 4)))
		var n := 0
		if lv >= 9:
			n = 2 + (1 if r.randf() < 0.5 else 0)
		elif lv >= 3:
			n = 1 + (1 if r.randf() < 0.4 else 0)
		elif r.randf() < 0.3:
			n = 1
		var day := int(c.get("born", 0))
		var slots := ["fabao", "yi", "shi"]
		for i in n:
			var sl: String = slots[i]
			var arr: Array = BASES[sl]
			var pid: String = arr[r.randi() % arr.size()]
			var g := clampi(gmax - (1 if r.randf() < 0.4 else 0), 0, 4)
			var origin: String = ["%s所赐。" % String(c.get("sect", "师门")), "早年在山中寻得。", "坊市里买的，砍过三回价。", "自己一点点温养出来的。"][r.randi() % 4]
			var it := make(null, W, r, pid, g, origin, day)
			c["gear"].append(it)
	return c["gear"]

static func npc_pw(W, c: Dictionary) -> float:
	var v := 0.0
	for it in npc_gear(W, c):
		v = maxf(v, stat(it, "pw")) if slot_of(it) == "fabao" else v
	return v

static func pw_of(W, c: Dictionary) -> float:
	if c.get("player", false):
		return her_stat(W.g, "pw") if W.g != null else 0.0
	return npc_pw(W, c)

## 斗法时她这边多出（或少）的：自己的法宝 − 对方的法宝
static func edge(W, n: Dictionary) -> float:
	if W == null or W.g == null or not W.g.s.has("gear"):
		return 0.0
	return her_stat(W.g, "pw") - (0.0 if n.is_empty() else npc_pw(W, n))

static func best_of(W, c: Dictionary) -> Variant:
	if c.get("player", false):
		return her_best_carried(W.g) if W.g != null else null
	var best = null
	for it in npc_gear(W, c):
		if best == null or value(it) > value(best):
			best = it
	return best

## 一件东西换了主人（夺宝、截道、送、遗赠）。text 写进物品履历；返回移过去的实例（没东西可移返回 {}）
static func transfer(W, from: Dictionary, to: Dictionary, it: Variant, text: String) -> Dictionary:
	if it == null:
		return {}
	var day := int(W.w["day"])
	if from.get("player", false):
		var gs = W.g
		if gs == null or _take(gs, int(it["u"])).is_empty():
			return {}
	elif not from.is_empty():
		var lst: Array = npc_gear(W, from)
		var i := lst.find(it)
		if i < 0:
			return {}
		lst.remove_at(i)
	if to.get("player", false):
		if W.g != null:
			it["ext"] = true
			give_her(W.g, it, text)
	elif not to.is_empty():
		it["h"].append([day, text])
		npc_gear(W, to).append(it)
		if npc_gear(W, to).size() > 5:   # 太多了：留最好的五件，其余换了灵石
			var lst2: Array = npc_gear(W, to)
			lst2.sort_custom(func(a, b): return value(a) > value(b))
			lst2.resize(5)
	return it

## 人死了：东西给道侣，没有就给徒弟；都没有，留在死处（日后游历那处可能捡到）
static func on_death(W, c: Dictionary) -> void:
	if c.get("player", false) or not c.has("gear") or c["gear"].is_empty():
		return
	var heir = W.partner(c)
	if heir == null:
		for k in c["rel"]:
			if "徒" in c["rel"][k]["t"]:
				var o: Dictionary = W.C(int(k))
				if not o.is_empty() and o["alive"] and not o.get("player", false):
					heir = o
					break
	var lst: Array = c["gear"].duplicate()
	for it in lst:
		if heir != null:
			transfer(W, c, heir, it, "%s身故，留给了%s。" % [c["name"], heir["name"]])
		else:
			c["gear"].erase(it)
			it["h"].append([int(W.w["day"]), "%s死在%s，这件东西落在了那里。" % [c["name"], c["place"]]])
			it["owner"] = String(c["name"])
			if not W.w.has("lost"):
				W.w["lost"] = {}
			var pl := String(c["place"])
			if not W.w["lost"].has(pl):
				W.w["lost"][pl] = []
			W.w["lost"][pl].append(it)
			if W.w["lost"][pl].size() > 4:
				W.w["lost"][pl].pop_front()

## 游历某处时捡到前人的遗物（每处每回最多一件；按日子与地名定，不掷骰子）
static func find_lost(W, place: String) -> Variant:
	var L: Dictionary = W.w.get("lost", {})
	if not L.has(place) or L[place].is_empty():
		return null
	if (int(W.w["day"]) + place.length()) % 3 != 0:
		return null
	return L[place].pop_back()

# ================================================================ 坊市：行情、器物铺、拍卖
## 行情（每月变）：一年一个来回（年底年初要过年，东西贵），叠一个 37 个月的小周期；不掷骰子
static func price_idx(day: int) -> float:
	var m := float(day)
	return snappedf(1.0 + 0.12 * cos(TAU * (m - 1.0) / 12.0) + 0.06 * sin(TAU * m / 37.0), 0.01)

static func idx_text(day: int) -> String:
	var x := price_idx(day)
	return "偏贵" if x >= 1.08 else ("偏贱" if x <= 0.92 else "平")

static func buy_price(it: Dictionary, day: int) -> int:
	return maxi(1, roundi(value(it, day) * price_idx(day) * 1.25))

static func sell_price(gs, it: Dictionary, day: int) -> int:
	var sat := int(gs.s["gear"]["sold"].get(String(it["p"]), 0))
	return maxi(1, roundi(value(it, day) * price_idx(day) * 0.5 / (1.0 + 0.15 * sat)))

static func _rng_for(gs, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(gs.s.get("rng_seed", 0)) ^ (salt * 2654435761)
	return r

## 器物铺：每年开春换一回货（凡品、法器、护身符、偶尔一只储物袋）
static func shop(gs) -> Array:
	var G: Dictionary = gs.s["gear"]
	var day := int(gs.s.get("day", 0))
	var y := (maxi(day, 1) - 1) / 12
	if int(G["shop"].get("y", -1)) != y:
		var r := _rng_for(gs, 1000 + y)
		var st := []
		var W = gs.world
		for i in 4:
			var sl: String = ["fabao", "yi", "shi", ["fabao", "yi", "shi"][r.randi() % 3]][i]
			var arr: Array = BASES[sl]
			var pid: String = arr[r.randi() % arr.size()]
			if pid == "飞剑" and r.randf() < 0.5:
				pid = "剑"
			st.append(make(gs, W, r, pid, 1 if r.randf() < 0.45 else 0, "坊市器物铺的货。", day))
		if r.randf() < 0.6:
			st.append(make(gs, W, r, "储物袋", 1, "坊市器物铺的货。", day))
		var fu := make(gs, W, r, "护身符" if r.randf() < 0.7 else "静心符", 0, "坊市器物铺画的符。", day)
		fu["c"] = 3
		st.append(fu)
		G["shop"] = {"y": y, "stock": st}
	return G["shop"]["stock"]

static func shop_buy(gs, u: int) -> String:
	var st: Array = shop(gs)
	var day := int(gs.s.get("day", 0))
	for i in st.size():
		var it: Dictionary = st[i]
		if int(it["u"]) == u:
			var pr := buy_price(it, day)
			if int(gs.s["lingshi"]) < pr:
				return "灵石不够（要 %d，手里 %d）。" % [pr, int(gs.s["lingshi"])]
			gs.s["lingshi"] = int(gs.s["lingshi"]) - pr
			st.remove_at(i)
			give_her(gs, it, "她在坊市器物铺以 %d 灵石购得。" % pr)
			gs._log("在坊市器物铺买了%s（%d 灵石）。" % [full_name(it), pr])
			gs.pchron("在坊市买下一件%s。" % it["n"], -1, {"灵石": -pr, "得「%s」" % String(it["n"]): ""})
			return ""
	return "这件已经卖掉了。"

static func sell(gs, u: int) -> String:
	var f := find(gs, u)
	if f.is_empty():
		return "没有这件。"
	if f[0] == "eq" and f[1] == "dai":
		return "储物袋正用着，先换一只。"
	var it: Dictionary = f[2]
	if f[0] == "home":
		return "东西在青庐里，带出来才卖得了。"
	var day := int(gs.s.get("day", 0))
	var pr := sell_price(gs, it, day)
	_take(gs, u)
	gs.s["lingshi"] = int(gs.s["lingshi"]) + pr
	var sold: Dictionary = gs.s["gear"]["sold"]
	sold[String(it["p"])] = int(sold.get(String(it["p"]), 0)) + 1
	it["h"].append([day, "她在坊市卖了，得 %d 灵石。" % pr])
	gs._log("在坊市卖了%s，得 %d 灵石。" % [full_name(it), pr])
	return ""

static func repair_cost(it: Dictionary) -> int:
	return maxi(1, roundi((100 - int(it.get("dur", 100))) / 100.0 * GBASE[clampi(int(it.get("g", 0)), 0, 4)] * 0.3))

static func repair(gs, u: int) -> String:
	var f := find(gs, u)
	if f.is_empty() or f[0] == "home":
		return "要带在身上才修得了。"
	var it: Dictionary = f[2]
	if int(it.get("dur", 100)) >= 100:
		return "不用修。"
	var c := repair_cost(it)
	if int(gs.s["lingshi"]) < c:
		return "灵石不够（修一修要 %d）。" % c
	gs.s["lingshi"] = int(gs.s["lingshi"]) - c
	it["dur"] = 100
	it["h"].append([int(gs.s.get("day", 0)), "在坊市修过一回。"])
	return ""

## 拍卖：三月、九月坊市有拍卖会（春拍 / 秋拍）
## v0.14.2：一场三件，按她的境界和身家配——前两件是够得着的小件（炼气时多是旧法器，起拍二三十灵石，跟价的也是境界相近的人），
## 压轴一件高她一两个大境界（炼气时是灵器，偶有宝器），给她看看、攒个念想。一件落槌再拍下一件
const AUC_LOTS := 3
static func auction_month(day: int) -> bool:
	return (maxi(day, 1) - 1) % 12 + 1 in [3, 9]

static func _her_major(gs) -> int:
	return int(gs.major()) if gs.has_method("major") else 0

static func _round5(x: float) -> int:
	return maxi(5, roundi(x / 5.0) * 5)

## 一件拍品（含 NPC 心里的价）。small=true 是够得着的小件
static func _auc_lot(gs, r: RandomNumberGenerator, small: bool, day: int) -> Dictionary:
	var W = gs.world
	var mj := _her_major(gs)
	var ls := int(gs.s.get("lingshi", 0))
	var her_lv: int = int(gs.plv_now()) if gs.has_method("plv_now") else 0
	var sl: String = ["fabao", "fabao", "yi", "shi", "dai"][r.randi() % 5]
	var arr: Array = BASES[sl]
	var pid: String = arr[r.randi() % arr.size()]
	var g := 0
	var origin := ""
	if small:
		g = clampi(mj + 1, 1, 3)
		while g > 1 and GBASE[g] * 0.4 > maxf(float(ls), 10.0):   # 身家够不着就降一品
			g -= 1
		origin = ["哪位散修手头紧，拿出来押的。", "旧洞府里清出来的，有些磨损。", "坊市老铺子压箱底的。"][r.randi() % 3]
	else:
		g = clampi(mj + 2, 2, 4)
		if r.randf() < 0.2:
			g = mini(4, g + 1)
		origin = ["出自古战场。", "某位前辈坐化后，洞府里清出来的。", "海外商船带来的。"][r.randi() % 3]
	var lot := make(gs, W, r, pid, g, origin, day)
	if small:
		lot["dur"] = 60 + r.randi() % 31   # 旧东西，成色六到九成
	var v := value(lot, day)
	var bid := {}
	if W != null:
		var cands: Array = W.npcs().filter(func(c): return (absi(int(c["lv"]) - her_lv) <= 3) if small else int(c["lv"]) >= 6)
		cands.sort_custom(func(a, b): return int(a["id"]) < int(b["id"]))
		for i in mini(3 if not small else 2, cands.size()):
			var c: Dictionary = cands[r.randi() % cands.size()]
			var k: float = (0.5 + 0.5 * r.randf()) if small else (0.7 + 0.6 * r.randf())
			bid[str(int(c["id"]))] = roundi(v * k * (1.0 + int(c["lv"]) / 30.0))
	var st := _round5(v * (0.4 if small else 0.6))
	return {"lot": lot, "max": bid, "price": st}

static func auction(gs) -> Dictionary:
	var G: Dictionary = gs.s["gear"]
	var day := int(gs.s.get("day", 0))
	if not auction_month(day):
		return {}
	if int(G["auc"].get("d", -1)) == day:
		return G["auc"]
	var r := _rng_for(gs, 5000 + day)
	var q := []
	for i in AUC_LOTS:
		q.append(_auc_lot(gs, r, i < AUC_LOTS - 1, day))
	G["auc"] = {"d": day, "q": q, "i": 0, "n": AUC_LOTS}
	_auc_open(gs, G["auc"])
	return G["auc"]

## 把队里的下一件摆上台
static func _auc_open(gs, A: Dictionary) -> void:
	var nx: Dictionary = A["q"].pop_front()
	A["i"] = int(A.get("i", 0)) + 1
	A["lot"] = nx["lot"]
	A["max"] = nx["max"]
	A["price"] = int(nx["price"])
	A["lead"] = 0
	A["done"] = false
	var tag := "压轴" if A["q"].is_empty() else "第%s件" % ["一", "二", "三", "四"][clampi(int(A["i"]) - 1, 0, 3)]
	A["log"] = ["%s：%s，起拍 %d 灵石。" % [tag, A["lot"]["n"], int(A["price"])]]
	_npc_raise(gs, A)

## 还有下一件没拍
static func auction_more(A: Dictionary) -> bool:
	return not A.is_empty() and not A.get("q", []).is_empty()

## 这件落槌了，摆下一件；返回 false 表示整场散了
static func auction_next_lot(gs) -> bool:
	var A := auction(gs)
	if A.is_empty() or not A["done"] or not auction_more(A):
		return false
	_auc_open(gs, A)
	return true

static func _npc_raise(gs, A: Dictionary) -> void:
	var best_id := ""
	var best := 0
	for k in A["max"]:
		if int(A["max"][k]) > best and k != str(int(A["lead"])):
			best = int(A["max"][k])
			best_id = k
	var nxt := int(ceil(int(A["price"]) * 1.1 / 5.0) * 5) if int(A["lead"]) != 0 else int(A["price"])
	if best_id != "" and best >= nxt:
		A["price"] = nxt
		A["lead"] = int(best_id)
		var nm := "有人"
		if gs.world != null:
			nm = String(gs.world.C(int(best_id)).get("name", "有人"))
		A["log"].append("%s举牌：%d。" % [nm, nxt])
	elif int(A["lead"]) < 0:
		A["log"].append("满堂静了。没人再跟。")

static func auction_next(A: Dictionary) -> int:
	return int(ceil(int(A["price"]) * 1.1 / 5.0) * 5)

## 她举牌（+一成）。返回提示；NPC 跟不跟，写进 log
static func auction_bid(gs) -> String:
	var A := auction(gs)
	if A.is_empty() or A["done"]:
		return "拍卖会散了。"
	var nxt := auction_next(A) if int(A["lead"]) != 0 else int(A["price"])
	if int(gs.s["lingshi"]) < nxt:
		return "手里灵石不够举这一牌（要 %d）。" % nxt
	A["price"] = nxt
	A["lead"] = -1
	A["log"].append("她举牌：%d。" % nxt)
	_npc_raise(gs, A)
	if int(A["lead"]) == -1:
		_auction_close(gs, A)
	return ""

## 她收手（或没人跟）：落槌
static func auction_pass(gs) -> String:
	var A := auction(gs)
	if A.is_empty() or A["done"]:
		return ""
	_auction_close(gs, A)
	return ""

static func _auction_close(gs, A: Dictionary) -> void:
	A["done"] = true
	var lot: Dictionary = A["lot"]
	var pr := int(A["price"])
	var day := int(gs.s.get("day", 0))
	if int(A["lead"]) == -1:
		gs.s["lingshi"] = int(gs.s["lingshi"]) - pr
		give_her(gs, lot.duplicate(true), "她在坊市拍卖会以 %d 灵石拍得。" % pr)
		A["log"].append("落槌。%s归她，%d 灵石。" % [lot["n"], pr])
		gs._log("在坊市拍卖会拍下%s（%s，%d 灵石）。" % [lot["n"], grade_name(lot), pr])
		gs.pchron("在坊市拍卖会上，以 %d 灵石拍下一件%s%s。" % [pr, grade_name(lot), lot["n"]])
	elif int(A["lead"]) > 0 and gs.world != null:
		var W = gs.world
		var c: Dictionary = W.C(int(A["lead"]))
		if not c.is_empty():
			var it: Dictionary = lot.duplicate(true)
			it["h"].append([int(W.w["day"]), "%s在坊市拍卖会以 %d 灵石拍得。" % [c["name"], pr]])
			npc_gear(W, c).append(it)
			W.chron(c, "在坊市拍卖会上拍下一件%s。" % it["n"])
			A["log"].append("落槌。%s归了%s，%d 灵石。" % [lot["n"], c["name"], pr])
	else:
		A["log"].append("流拍。")

# ================================================================ 给界面的短字
static func stat_text(it: Dictionary) -> String:
	var out := []
	for k in ["pw", "def", "xw", "wu", "rsave", "cells", "wcap"]:
		var v := stat(it, k)
		if v <= 0.0:
			continue
		match k:
			"pw": out.append("斗法 +%s" % str(snappedf(v, 0.1)))
			"def": out.append("护体 %d%%" % int(v))
			"xw": out.append("闭关修为 +%d%%" % int(v))
			"wu": out.append("感悟 +%d%%" % int(v))
			"rsave": out.append("省辟谷丹 %d%%" % int(v))
			"cells": out.append("%d 格" % int(v))
			"wcap": out.append("负重 %d 斤" % int(v))
	if it.has("c"):
		var p := String(it["p"])
		if int(prop(p, "ward", 0)) > 0:
			out.append("挡伤 %d%%" % int(prop(p, "ward", 0)))
		if int(prop(p, "calm", 0)) > 0:
			out.append("冲关稳心")
	return " · ".join(out)

static func her_summary(gs) -> String:
	var out := ["斗法 +%s" % str(snappedf(her_stat(gs, "pw"), 0.1)), "护体 %d%%" % int(her_stat(gs, "def")), "闭关 +%d%%" % int(her_stat(gs, "xw"))]
	if her_stat(gs, "wu") > 0:
		out.append("感悟 +%d%%" % int(her_stat(gs, "wu")))
	return " · ".join(out)
