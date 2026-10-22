extends RefCounted
## 人物自主（v0.9）：每个 NPC 有性格向量、记忆、动机，每天按效用自己选一件事做。
## 事件不是写死的剧情：NPC 之间的事在幕后结算成生平和传闻；冲着她来的、或路上撞见的，才变成她面前的选择，
## 她怎么选，又写回那些人的记忆和动机里。
##
## 架构：
##   性格 ps（10 维 0–1，由两项旧性格 + 人物种子推出，随经历缓慢漂移）
##   记忆 mem（沿用 world 的 [日, 对象, 文字, 分量]，追加 [种类, 来由动作]；显著度按“记仇/痴/善”定半衰期）
##   动机 dr（{k 动机, t 对象, u 急迫, why 缘由, src 缘由动作}；每 8–12 日或记下大事后重想）
##   动作（动词）：按动机挑候选，效用 = 各项考量相乘（Pennycook Utility AI 的响应曲线 + PRODUCT 聚合），加权随机选一
##   动作日志 agl：[id, 日, 谁, 动词, 对谁, 动机, 来由动作]——每件事都能顺着来由追回去
## 所有状态都在 world.w（随存档 JSON），全是可缺省的新键；旧档读入时按人物种子补，不耗世界随机数。
## 思路借鉴：Utility AI（Dave Mark 的 Infinite Axis；代码取自 Pennycook/godot-utility-ai，MIT，见 scripts/vendor）、
## Comme il Faut / Talk of the Town 的“意向（volition）由性格×关系×记忆算出”、Tracery 的变体文法（这里用 world.pv 去重抽签）。
const UC = preload("res://scripts/vendor/utility_ai_curves.gd")

const AX = ["贪", "傲", "痴", "仇", "慎", "侠", "野", "妒", "善", "奇"]
const TRAIT_AX = {
	"温柔": {"善": 0.35, "侠": 0.1, "仇": -0.1}, "傲气": {"傲": 0.4, "野": 0.1}, "多疑": {"慎": 0.35, "善": -0.05},
	"贪财": {"贪": 0.45}, "侠义": {"侠": 0.45, "善": 0.1}, "痴情": {"痴": 0.45}, "记仇": {"仇": 0.45},
	"淡泊": {"野": -0.3, "贪": -0.25, "妒": -0.15}, "嗜战": {"傲": 0.15, "野": 0.2, "慎": -0.25}, "好奇": {"奇": 0.45},
	"怯懦": {"慎": 0.4, "傲": -0.2}, "圆滑": {"贪": 0.1, "慎": 0.15, "侠": -0.1}, "阴狠": {"侠": -0.35, "仇": 0.2, "善": -0.2},
	"薄情": {"痴": -0.35, "善": -0.1},
}
## 动机 → 可做的事
const DRIVE_VERBS = {
	"破境": ["闭关", "探秘", "夺宝", "求教", "论道"], "复仇": ["寻仇", "造谣", "截杀"], "求偶": ["示好", "馈赠", "结伴"],
	"求财": ["交易", "截杀", "偷窃", "探秘", "讨债", "夺宝"], "护人": ["求援", "寻仇", "示警"], "拜师": ["求教"],
	"报恩": ["还情", "馈赠", "示警"], "扬名": ["挑战", "夺宝"], "叛门": ["叛门"], "探秘": ["探秘", "结伴", "夺宝"],
	"收徒": ["收徒"], "压人": ["造谣", "挑战"], "交游": ["结伴", "交易", "劝和", "馈赠", "论道"],
	"疗伤": ["求药", "闭关"], "赎过": ["赔罪", "馈赠"], "后事": ["托付"],
}
const DRIVE_WORD = {"破境": "想破境", "复仇": "要报仇", "求偶": "动了心", "求财": "缺灵石", "护人": "要护着一个人", "拜师": "想拜个师父",
	"报恩": "想还一份情", "扬名": "想争个名头", "叛门": "想离开师门", "探秘": "想去探一处秘地", "收徒": "想收个徒弟", "压人": "心里不服一个人", "交游": "四处走动", "疗伤": "想把伤养好", "赎过": "想赔一个不是", "后事": "在想身后事"}
## 冲着她来时，动词 → 她面前的事件
const VERB_TID = {"寻仇": "寻仇", "截杀": "截道", "偷窃": "失窃", "示好": "示好", "馈赠": "馈赠", "结伴": "结伴", "交易": "交易",
	"讨债": "讨债", "求援": "求援", "示警": "示警", "求教": "求教", "还情": "还情", "挑战": "挑战", "造谣": "流言", "叛门": "叛门",
	"劝和": "劝和", "夺宝": "夺宝", "探秘": "邀游", "求药": "求药", "赔罪": "赔罪", "托付": "托付", "论道": "问道"}
const TIDS = ["寻仇", "截道", "失窃", "示好", "馈赠", "结伴", "交易", "讨债", "求援", "示警", "求教", "还情", "挑战", "流言", "叛门", "劝和", "夺宝", "邀游", "撞见", "求药", "赔罪", "托付", "问道"]
## 需要对象的动词：动机里有对象就只对着那个人
const AIMED = ["寻仇", "示好", "馈赠", "还情", "讨债", "求援", "造谣", "示警", "赔罪", "托付"]
const HURT_K = ["伤", "夺", "窃", "谣", "负", "辱", "拒"]
const SOLO_V = ["闭关", "叛门"]
const TREASURE = ["一株刚开花的七叶灵芝", "一窝赤血灵芝", "半块天外陨铁", "一眼刚冒头的地火灵泉", "一株月下昙", "崖缝里一枚朱果"]
const GOODS = [["herb_qingzhi", 2, "两株年份不浅的青芝"], ["pill_quzhang", 1, "一粒驱瘴丹"], ["herb_xugucao", 1, "一株续骨草"], ["pill_juqi", 1, "一粒聚气丹"]]

# ================================================================ 性格
static func pers(c: Dictionary) -> Dictionary:
	if c.has("ps"):
		return c["ps"]
	var r := RandomNumberGenerator.new()
	r.seed = int(c.get("pseed", int(c["id"]) * 7919)) ^ 0xA6E1C
	var ps := {}
	for a in AX:
		ps[a] = 0.3 + r.randf_range(-0.15, 0.15)
	for t in c.get("traits", []):
		for a in TRAIT_AX.get(t, {}):
			ps[a] = float(ps[a]) + float(TRAIT_AX[t][a])
	ps["妒"] = float(ps["妒"]) + 0.15 * (float(ps["傲"]) - 0.3)
	for a in AX:
		ps[a] = qz(clampf(float(ps[a]), 0.0, 1.0), 100.0)
	c["ps"] = ps
	return ps

static func qz(x: float, d: float) -> float:
	return float(roundi(x * d)) / d

static func px(c: Dictionary, a: String) -> float:
	return float(pers(c)[a])

## 经历让性格慢慢变（每次 ≤0.05）
static func drift(c: Dictionary, a: String, d: float) -> void:
	var ps := pers(c)
	ps[a] = qz(clampf(float(ps[a]) + d, 0.0, 1.0), 100.0)

## 说话的口吻：最突出的一维（不到 0.55 就是“平”）
static func flav(c: Dictionary) -> String:
	var best := "平"
	var bv := 0.55
	for a in ["傲", "慎", "贪", "痴", "侠", "仇", "善", "野", "奇", "妒"]:
		if px(c, a) > bv:
			bv = px(c, a)
			best = a
	return best

## 按口吻挑一句（没写这个口吻就用“平”）
static func fl(W, key: String, c: Dictionary, table: Dictionary) -> String:
	var f := flav(c)
	if not table.has(f):
		f = "平"
	return W.pv(key + ":" + f, table[f])

# ================================================================ 记忆
static func mem(W, c: Dictionary, o, text: String, wt: int, kind: String, aid: int = -1) -> void:
	W.remember(c, o, text, wt, kind, aid)
	if absi(wt) >= 12:
		c["rt"] = 1

static func mkind(m: Array) -> String:
	if m.size() > 4:
		return String(m[4])
	return "恩" if float(m[3]) > 0 else "怨"

## 显著度：分量 × 半衰（记仇的人怨恨忘得慢，痴情/心善的人恩情忘得慢）
static func sal(W, c: Dictionary, m: Array) -> float:
	var k := mkind(m)
	if k in ["了", "还"]:
		return 0.0
	var d := float(int(W.w["day"]) - int(m[0]))
	var wt := float(m[3])
	var hl := (20.0 + 90.0 * px(c, "仇")) if wt < 0 else (25.0 + 50.0 * (px(c, "痴") + px(c, "善")))
	return absf(wt) / 30.0 * pow(0.5, d / hl)

## 对某人的怨（记忆显著度 + 关系里的怨气）与它最重的那条记忆
static func grudge(W, c: Dictionary, t: Dictionary) -> Array:
	var tid := int(t["id"])
	var g := float(W._rel(c, t)["g"]) / 100.0
	var top = null
	var tv := 0.0
	for m in c["mem"]:
		if int(m[1]) == tid and float(m[3]) < 0:
			var s := sal(W, c, m)
			g += s
			if s > tv:
				tv = s
				top = m
	return [g, top]

## 关于 t 的最显著一条记忆（sign>0 恩，<0 怨），给动机找来由
static func top_mem(W, c: Dictionary, t: Dictionary, sign: int) -> Array:
	var best: Array = []
	var bv := 0.0
	for m in c["mem"]:
		if int(m[1]) == int(t["id"]) and float(m[3]) * sign > 0:
			var sv := sal(W, c, m)
			if sv > bv:
				bv = sv
				best = m
	return best

## t 心里记着 c 的多少不是（t 是她时看她对 c 的怨 g）：[分量, 那条记忆]
static func wronged(W, c: Dictionary, t: Dictionary) -> Array:
	if t["player"]:
		return [clampf(float(W._rel(t, c)["g"]) / 40.0, 0.0, 1.5), []]
	var sum := 0.0
	var best: Array = []
	var bv := 0.0
	for m in t["mem"]:
		if int(m[1]) == int(c["id"]) and float(m[3]) < 0 and mkind(m) in HURT_K:
			var sv := sal(W, t, m)
			sum += sv
			if sv > bv:
				bv = sv
				best = m
	return [sum, best]

static func _src(m: Array) -> int:
	return int(m[5]) if m.size() > 5 else -1

static func debt(W, c: Dictionary, t: Dictionary) -> Array:
	var tid := int(t["id"])
	var g := 0.0
	var top = null
	var tv := 0.0
	for m in c["mem"]:
		if int(m[1]) == tid and float(m[3]) >= 8 and mkind(m) in ["救", "恩", "助", "赠", "教", "庇"]:
			var s := sal(W, c, m)
			g += s
			if s > tv:
				tv = s
				top = m
	return [g, top]

## 记忆里的“我/你”：对她说话时把她的名字换成“你”
static func say(W, text: String) -> String:
	return text.replace(W.pn(), "你")

# ================================================================ 动机
static func _lifefrac(W, c: Dictionary) -> float:
	return float(c["age"]) / float(W.lifespan(int(c["lv"])))

static func hunters_of(W, t: Dictionary) -> Array:
	return W.npcs().filter(func(x): return x.has("dr") and String(x["dr"]["k"]) == "复仇" and int(x["dr"]["t"]) == int(t["id"]))

static func rethink(W, c: Dictionary) -> void:
	var day := int(W.w["day"])
	var lv := int(c["lv"])
	var cands := []
	var push := func(k: String, t: int, u: float, why: String, src: int):
		cands.append([k, t, u, why, src])
	# 破境
	var prog := float(c["xp"]) / (8.0 * pow(1.35, lv))
	push.call("破境", 0, 0.12 + 0.4 * px(c, "野") + 0.3 * prog + (0.12 if lv in [8, 11, 14, 17] else 0.0), "卡在%s已久" % W.realm(c), -1)
	# 复仇 / 报恩 / 求偶 / 压人：看关系里的每个人
	var best_g := [0.0, null, null]
	var best_d := [0.0, null, null]
	var best_o := [0.0, null]
	var best_r := [0.0, null]
	for k in W._ids(c["rel"]):
		var t: Dictionary = W.C(k)
		if t.is_empty() or not t["alive"] or t == c:
			continue
		var gg: Array = grudge(W, c, t)
		if float(gg[0]) > float(best_g[0]):
			best_g = [float(gg[0]), t, gg[1]]
		var dd: Array = debt(W, c, t)
		if float(dd[0]) > float(best_d[0]):
			best_d = [float(dd[0]), t, dd[1]]
		var op: float = W.opinion(c, t)
		if t["sex"] != c["sex"] and W.partner(c) == null and W.partner(t) == null and op > float(best_o[0]) and op > 15 and not ("师" in W._rel(c, t)["t"]) and not ("徒" in W._rel(c, t)["t"]):
			best_o = [op, t]
		if not t["player"] and absi(int(t["lv"]) - lv) <= 2 and op < 5 and int(t["lv"]) >= lv:
			var rv := float(int(t["lv"]) - lv + 3) / 5.0
			if rv > float(best_r[0]):
				best_r = [rv, t]
	if float(best_g[0]) > 0.15:
		var t: Dictionary = best_g[1]
		var dare := lerpf(1.0, clampf(0.5 + float(lv - int(t["lv"]) if not t["player"] else lv - W.plv()) / 6.0, 0.1, 1.0), px(c, "慎"))
		var m = best_g[2]
		push.call("复仇", int(t["id"]), minf(1.2, float(best_g[0])) * (0.3 + 0.8 * px(c, "仇")) * dare, String(m[2]) if m != null else "与%s有旧怨" % t["name"], int(m[5]) if m != null and m.size() > 5 else -1)
	if float(best_d[0]) > 0.12:
		var m2 = best_d[2]
		push.call("报恩", int(best_d[1]["id"]), minf(1.0, float(best_d[0]) * 1.5) * (0.35 + 0.6 * (px(c, "侠") + px(c, "善")) / 2.0), String(m2[2]) if m2 != null else "", int(m2[5]) if m2 != null and m2.size() > 5 else -1)
	if best_o[1] != null and _lifefrac(W, c) < 0.6:
		var lm := top_mem(W, c, best_o[1], 1)
		push.call("求偶", int(best_o[1]["id"]), (0.2 + 0.7 * px(c, "痴")) * clampf(float(best_o[0]) / 50.0, 0.0, 1.0), String(lm[2]) if not lm.is_empty() else "心里记着%s" % best_o[1]["name"], _src(lm))
	if best_r[1] != null and px(c, "妒") > 0.35:
		var rm := top_mem(W, c, best_r[1], -1)
		push.call("压人", int(best_r[1]["id"]), px(c, "妒") * 0.7 * float(best_r[0]), "见不得%s压自己一头" % best_r[1]["name"], _src(rm))
	# 求财
	var ls := int(c.get("ls", 5 + lv * 3))
	push.call("求财", 0, 0.08 + 0.5 * px(c, "贪") + (0.22 if ls < 8 else 0.0), "囊中羞涩" if ls < 8 else "贪图灵石", -1)
	# 护人：道侣/徒弟/金兰受了伤，或被人盯上
	for k in W._ids(c["rel"]):
		var t2: Dictionary = W.C(k)
		if t2.is_empty() or not t2["alive"] or t2["player"]:
			continue
		var tags: Array = W._rel(c, t2)["t"]
		if not ("道侣" in tags or "徒" in tags or "结义" in tags):
			continue
		var hs := hunters_of(W, t2)
		if int(t2["inj"]) > 0 or not hs.is_empty():
			var why := ("%s有伤在身" % t2["name"]) if hs.is_empty() else ("%s被%s盯上了" % [t2["name"], hs[0]["name"]])
			var src := -1
			if not hs.is_empty():
				src = int(hs[0]["dr"].get("src", -1))
				if src < 0:
					src = _src(top_mem(W, hs[0], t2, -1))
			push.call("护人", int(t2["id"]), 0.3 + 0.45 * maxf(px(c, "侠"), px(c, "痴")), why, src)
			break
	if W.master_of(c) == null and lv < 6 and float(c["age"]) < 45.0:
		push.call("拜师", 0, 0.08 + 0.4 * px(c, "野") + 0.12 * (1.0 - px(c, "傲")), "想有人领进门", -1)
	if lv >= 2:
		push.call("扬名", 0, 0.04 + 0.55 * pow(px(c, "傲"), 2.0) * 1.6, "不甘籍籍无名", -1)
	if c["sect"] != "散修":
		var bad := false
		for k in W._ids(c["rel"]):
			var t3: Dictionary = W.C(k)
			if not t3.is_empty() and t3["sect"] == c["sect"] and int(W._rel(c, t3)["g"]) >= 40:
				bad = true
		if bad or (px(c, "野") > 0.7 and px(c, "侠") < 0.3):
			push.call("叛门", 0, 0.22 + 0.2 * px(c, "野"), "在%s待不下去了" % c["sect"], -1)
	push.call("探秘", 0, 0.08 + 0.45 * px(c, "奇"), "听说有处秘地", -1)
	if lv >= 9:
		var has_d := false
		for k in W._ids(c["rel"]):
			if "徒" in W._rel(c, W.C(k))["t"]:
				has_d = true
		if not has_d:
			push.call("收徒", 0, 0.08 + 0.4 * px(c, "善"), "一身本事没人接", -1)
	push.call("交游", 0, 0.2 + 0.25 * px(c, "善") + 0.1 * px(c, "奇"), "", -1)
	# 疗伤：伤重就想先把伤养好（谨慎的人更是）
	if int(c["inj"]) > 8:
		var hm: Array = []
		for m in c["mem"]:
			if mkind(m) == "伤" and (hm.is_empty() or int(m[0]) >= int(hm[0])):
				hm = m
		push.call("疗伤", 0, 0.3 + float(c["inj"]) / 40.0 + 0.2 * px(c, "慎"), String(hm[2]) + "，伤还没好" if not hm.is_empty() else "伤还没好", _src(hm))
	# 赎过：心善/讲义气的人，记得自己亏欠过谁
	if (px(c, "善") + px(c, "侠")) / 2.0 > 0.45 and px(c, "傲") < 0.7:
		var bw := [0.0, null, []]
		for k in W._ids(c["rel"]):
			var t4: Dictionary = W.C(k)
			if t4.is_empty() or not t4["alive"] or t4 == c:
				continue
			var wr: Array = wronged(W, c, t4)
			if float(wr[0]) > float(bw[0]):
				bw = [float(wr[0]), t4, wr[1]]
		if float(bw[0]) > 0.25:
			var wm: Array = bw[2]
			var wy := ("当年%s，是我对不住%s" % [String(wm[2]).replace("我", W.ta(bw[1])).replace(c["name"], "我"), W.ta(bw[1])]) if not wm.is_empty() else "当年对不住%s" % bw[1]["name"]
			push.call("赎过", int(bw[1]["id"]), minf(1.0, float(bw[0])) * (0.3 + 0.6 * (px(c, "善") + px(c, "侠")) / 2.0), wy, _src(wm))
	# 后事：自知寿元将尽，想把东西托给信得过的人
	if _lifefrac(W, c) > 0.85 and not c.has("tf"):
		var bt: Array = [10.0, null]
		for k in W._ids(c["rel"]):
			var t5: Dictionary = W.C(k)
			if t5.is_empty() or not t5["alive"] or t5 == c:
				continue
			var o5: float = W.opinion(c, t5)
			if o5 > float(bt[0]):
				bt = [o5, t5]
		if bt[1] != null:
			var tm := top_mem(W, c, bt[1], 1)
			push.call("后事", int(bt[1]["id"]), 0.45 + 0.4 * px(c, "善"), "自知时日无多，" + (String(tm[2]) if not tm.is_empty() else "信得过%s" % bt[1]["name"]), _src(tm))
	var cur: Dictionary = c.get("dr", {})
	var bi := 0
	var bv := -1.0
	for i in cands.size():
		var v: float = float(cands[i][2]) + W.rng.randf_range(-0.06, 0.06)
		if not cur.is_empty() and String(cur["k"]) == String(cands[i][0]) and int(cur["t"]) == int(cands[i][1]):
			v += 0.12   # 惯性：念头不会一天一变
		if v > bv:
			bv = v
			bi = i
	var ch: Array = cands[bi]
	c["dr"] = {"k": ch[0], "t": ch[1], "u": qz(clampf(float(ch[2]), 0.0, 1.2), 100.0), "d": day, "why": ch[3], "src": ch[4]}
	c["rt"] = 0

# ================================================================ 每日
static func here(W) -> String:
	return String(W.w.get("here", "青庐"))

static func on_road(W) -> bool:
	return here(W) != "青庐"

## 她在不在附近：只微调权重，从不排除（路上同一处 1.0；路上别处 0.4；在家：认识的人 0.6，生人 0.2）
static func opp_p(W, c: Dictionary) -> float:
	var k: bool = W.known(c)
	# 焦点社交圈：她近来往来的人已多时，生人更少冲她来
	var cf := 0.35 if not k and W.active_bonds() >= 4 else 1.0
	if on_road(W):
		return (1.0 if String(c["place"]) == here(W) else 0.4) * cf
	return (0.8 if k else 0.3) * cf

static func daily(W) -> void:
	var day := int(W.w["day"])
	if not W.w.has("agq"):
		W.w["agq"] = []
		W.w["agl"] = []
		W.w["agn"] = 0
	for c in W.npcs():
		pers(c)
		if not c.has("ls"):
			c["ls"] = 5 + int(c["lv"]) * 3
		if not c.has("dr") or int(c.get("rt", 0)) == 1 or day - int(c["dr"]["d"]) >= 8 + int(c["id"]) % 5:
			rethink(W, c)
	var acted := 0
	for c in W.npcs():
		if acted >= 5:
			break
		if int(c["inj"]) > 12 and String(c["dr"]["k"]) != "疗伤" and W.rng.randf() < 0.8:
			continue
		var p := 0.05 + 0.14 * float(c["dr"]["u"])
		if W.rng.randf() < p:
			if act(W, c):
				acted += 1
	# 过期的“撞见”：她没遇上，就在幕后了结
	var keep := []
	for it in W.w["agq"]:
		if day - int(it[0]) > 16:
			if String(it[1]) == "撞见":
				var a: Dictionary = W.C(it[2]["B"])
				var b: Dictionary = W.C(it[2].get("V", 0))
				if not a.is_empty() and not b.is_empty() and a["alive"] and b["alive"]:
					npc_resolve(W, a, String(it[3]["v"]), b, int(it[3]["aid"]))
			continue
		keep.append(it)
	W.w["agq"] = keep

static func log_act(W, c: Dictionary, v: String, t, k: String, cause: int) -> int:
	var aid := int(W.w.get("agn", 0))
	W.w["agn"] = aid + 1
	W.w["agl"].append([aid, int(W.w["day"]), int(c["id"]), v, int(t["id"]) if t is Dictionary and not t.is_empty() else 0, k, cause])
	if W.w["agl"].size() > 400:
		W.w["agl"].pop_front()
	return aid

static func _targets(W, c: Dictionary, v: String, dr: Dictionary) -> Array:
	if v in SOLO_V or v == "探秘" and W.rng.randf() < 0.6:
		return [{}]
	var dk := String(dr["k"])
	if dk == "护人" and v == "寻仇" and int(dr["t"]) > 0:
		# 护人去寻仇：找的是盯上她护着的人的那个
		var pr: Dictionary = W.C(dr["t"])
		return hunters_of(W, pr).slice(0, 2) if not pr.is_empty() else []
	if (v in AIMED or dk in ["复仇", "压人", "求偶", "报恩"]) and int(dr["t"]) > 0:
		var t: Dictionary = W.C(dr["t"])
		if v == "示警" or v == "求援":
			# 护人/报恩：去找能帮忙的人、或去提醒被盯上的人
			return _helpers(W, c, t) if v == "求援" else ([t] if not hunters_of(W, t).is_empty() else [])
		return [t] if not t.is_empty() and t["alive"] else []
	var out := []
	var pool: Array = W.npcs().filter(func(x): return x != c)
	for x in W._sample(pool, 5):
		out.append(x)
	out.append(W.P())
	return out

static func _helpers(W, c: Dictionary, prot: Dictionary) -> Array:
	var out := []
	for k in W._ids(c["rel"]):
		var t: Dictionary = W.C(k)
		if t.is_empty() or not t["alive"] or t == prot or t == c:
			continue
		if W.opinion(c, t) > 10 or (t["player"] and W.known(c)):
			out.append(t)
	return out.slice(0, 6)

## 效用：每个动词一串考量（输入都化到 0–1），相乘
static func score(W, c: Dictionary, v: String, t: Dictionary, dr: Dictionary) -> float:
	if t.is_empty() and not (v in SOLO_V or v == "探秘"):
		return 0.0
	var isp: bool = not t.is_empty() and t["player"]
	if isp and W._close_p(c) and v in ["截杀", "偷窃", "造谣"]:
		return 0.0   # 与她亲近的人不对她下黑手（v0.8 的硬门槛照旧）
	var u := float(dr["u"])
	var opp := 1.0
	var op := 0.5
	var pw := 0.5
	var gr := 0.0
	if not t.is_empty():
		opp = opp_p(W, c) if isp else (1.0 if t["place"] == c["place"] else 0.5)
		op = clampf((W.opinion(c, t) + 50.0) / 100.0, 0.0, 1.0)
		var tl = W.plv() if isp else int(t["lv"])
		pw = clampf(0.5 + float(int(c["lv"]) - tl) / 8.0, 0.0, 1.0)
		gr = clampf(float(grudge(W, c, t)[0]), 0.0, 1.0)
	var cause := gr > 0.25   # 有旧怨在先，平日不做的事也可能做
	var s := []
	match v:
		"闭关":
			s = [UC.consider(px(c, "野"), "lin", 0.0, 0.4, 0.8)]
		"探秘":
			s = [UC.consider(maxf(px(c, "奇"), px(c, "贪")), "lin", 0.0, 0.25), opp if not t.is_empty() else 1.0, 0.7]
		"夺宝":
			s = [UC.consider(maxf(px(c, "贪"), px(c, "野")), "log", 0.0, 0.05), UC.consider(1.0 - px(c, "善"), "lin", 0.0, 0.3), opp, 0.6]
		"求教":
			if t.is_empty() or pw > (0.66 if isp else 0.45):
				return 0.0
			s = [UC.consider(px(c, "野"), "lin", 0.0, 0.3), UC.consider(1.0 - pw, "lin"), UC.consider(op, "log", 0.0), UC.consider(1.0 - px(c, "傲"), "lin", 0.0, 0.25), opp]
		"寻仇":
			if gr < 0.1 and String(dr["k"]) != "护人":
				return 0.0
			s = [UC.consider(maxf(gr, 0.3 if String(dr["k"]) == "护人" else 0.0), "lin", 0.0, 0.2), UC.consider(px(c, "仇"), "lin", 0.0, 0.3), UC.consider(lerpf(1.0, pw, px(c, "慎")), "lin", 0.0, 0.1), opp]
		"截杀":
			if px(c, "侠") > 0.6 and not cause:
				return 0.0
			s = [UC.consider(px(c, "贪"), "log", -0.05), UC.consider(1.0 - px(c, "侠"), "lin"), UC.consider(pw, "log", 0.05), UC.consider(1.0 - op, "lin", 0.0, 0.1), opp * (1.0 if not isp else 1.2)]
		"偷窃":
			if px(c, "侠") > 0.6 and not cause:
				return 0.0
			s = [UC.consider(px(c, "贪"), "log", 0.0), UC.consider(px(c, "慎"), "lin", 0.0, 0.2), UC.consider(1.0 - px(c, "侠"), "lin"), UC.consider(1.0 - op, "lin", 0.0, 0.2), opp]
		"示好":
			if t.is_empty() or t["sex"] == c["sex"] or op < 0.6:
				return 0.0
			s = [UC.consider(op, "log", 0.15), UC.consider(px(c, "痴"), "lin", 0.0, 0.3), opp]
		"馈赠":
			if t.is_empty() or op < 0.6:
				return 0.0
			s = [UC.consider(op, "log", 0.1), UC.consider(maxf(px(c, "善"), px(c, "痴")), "lin", 0.0, 0.2), opp]
		"结伴":
			if t.is_empty() or op < 0.4:
				return 0.0
			s = [UC.consider(op, "lin", 0.2), UC.consider(maxf(px(c, "奇"), maxf(px(c, "侠"), px(c, "痴"))), "lin", 0.0, 0.2), opp]
		"交易":
			if t.is_empty() or op < 0.3:
				return 0.0
			s = [UC.consider(px(c, "贪"), "lin", 0.0, 0.35, 0.6), opp]
		"讨债":
			if t.is_empty() or int(W._rel(c, t).get("owe", 0)) <= 0:
				return 0.0
			s = [UC.consider(px(c, "贪"), "lin", 0.0, 0.5, 0.5), 1.0]
		"求援":
			if t.is_empty():
				return 0.0
			s = [UC.consider(op, "log", 0.0), 1.0 if not isp else opp + 0.3]
		"求药":
			if t.is_empty() or int(c["inj"]) <= 0:
				return 0.0
			s = [UC.consider(op, "log", -0.05), UC.consider(1.0 - px(c, "傲") * 0.6, "lin"), UC.consider(float(c["inj"]) / 20.0, "lin", 0.0, 0.2), opp * (1.3 if isp else 1.0)]
		"赔罪":
			if t.is_empty():
				return 0.0
			var wr2 := float(wronged(W, c, t)[0])
			if wr2 < 0.2:
				return 0.0
			s = [clampf(wr2, 0.0, 1.0), UC.consider((px(c, "善") + px(c, "侠")) / 2.0, "lin"), UC.consider(1.0 - px(c, "傲"), "lin", 0.0, 0.2), opp if isp else 1.0]
		"托付":
			if t.is_empty() or _lifefrac(W, c) < 0.85 or c.has("tf") or W.opinion(c, t) < 10:
				return 0.0
			s = [UC.consider(op, "log", 0.0), 1.0 if not isp else opp + 0.2]
		"论道":
			if t.is_empty() or op < 0.4:
				return 0.0
			s = [UC.consider((px(c, "奇") + px(c, "野")) / 2.0, "lin", 0.0, 0.3), UC.consider(1.0 - absf(pw - 0.5) * 1.2, "lin"), UC.consider(op, "log", 0.0), opp, 0.6]
		"示警":
			if t.is_empty():
				return 0.0
			s = [UC.consider(px(c, "侠"), "lin", 0.0, 0.3), UC.consider(op, "log", 0.0), opp if isp else 1.0]
		"还情":
			var dd := float(debt(W, c, t)[0]) if not t.is_empty() else 0.0
			if dd < 0.15:
				return 0.0
			s = [clampf(dd, 0.0, 1.0), UC.consider((px(c, "侠") + px(c, "善")) / 2.0, "lin", 0.0, 0.3), opp if isp else 1.0]
		"挑战":
			if t.is_empty() or (px(c, "傲") < 0.35 and not cause):
				return 0.0
			s = [UC.consider(px(c, "傲"), "log", -0.05), UC.consider(1.0 - absf(pw - 0.5) * 1.4, "lin", 0.0, 0.1), UC.consider(1.0 - px(c, "慎") * 0.6, "lin"), opp]
		"造谣":
			if t.is_empty() or (px(c, "侠") > 0.6 and not cause) or (px(c, "妒") < 0.4 and not cause):
				return 0.0
			s = [UC.consider(maxf(px(c, "妒"), gr), "lin", 0.0, 0.1), UC.consider(1.0 - px(c, "侠"), "lin"), UC.consider(1.0 - op, "lin"), opp if isp else 1.0]
		"叛门":
			s = [0.7]
		"劝和":
			if t.is_empty() or px(c, "善") < 0.45:
				return 0.0
			var foe: Dictionary = _foe_of(W, t, c)
			if foe.is_empty():
				return 0.0
			s = [UC.consider(px(c, "善"), "lin"), UC.consider(op, "log", 0.0), opp if isp else 1.0]
		"收徒":
			if t.is_empty() or pw < 0.7 or op < 0.55:
				return 0.0
			s = [UC.consider(px(c, "善"), "lin", 0.0, 0.3), UC.consider(op, "log", 0.05), opp if isp else 1.0]
		_:
			return 0.0
	return UC.product(s) * (0.5 + u)

## t 的一个仇家（给劝和用；排除说和的人自己）
static func _foe_of(W, t: Dictionary, not_c: Dictionary) -> Dictionary:
	for k in W._ids(t["rel"]):
		var o: Dictionary = W.C(k)
		if o.is_empty() or not o["alive"] or o == not_c or o["player"]:
			continue
		if int(W._rel(o, t)["g"]) >= 25:
			return o
	if t["player"]:
		for o in W.npcs():
			if o != not_c and int(W._rel(o, t)["g"]) >= 25:
				return o
	return {}

static func act(W, c: Dictionary) -> bool:
	var dr: Dictionary = c["dr"]
	var opts := []
	var scs := []
	var day := int(W.w["day"])
	var acd: Dictionary = c.get("acd", {})
	for v in DRIVE_VERBS.get(String(dr["k"]), ["结伴"]):
		for t in _targets(W, c, v, dr):
			var s := score(W, c, v, t, dr)
			# 同一件事对同一个人，十来天里不反复做（免得两个人互相造谣造到天荒地老）
			var ck := "%s:%d" % [v, int(t.get("id", 0))]
			if acd.has(ck) and day - int(acd[ck]) < 12:
				s *= 0.12
			if s > 0.02:
				opts.append([v, t])
				scs.append(s)
	var i := UC.choose_random(opts, scs, W.rng)
	if i < 0:
		return false
	var v: String = opts[i][0]
	var t: Dictionary = opts[i][1]
	acd["%s:%d" % [v, int(t.get("id", 0))]] = day
	for k in acd.keys():
		if day - int(acd[k]) > 30:
			acd.erase(k)
	c["acd"] = acd
	var aid := log_act(W, c, v, t, String(dr["k"]), int(dr.get("src", -1)))
	W._flag_add("ag:" + v)
	if not t.is_empty() and t["player"]:
		_intent(W, c, v, {}, aid)
		return true
	if v in ["寻仇", "截杀", "挑战", "偷窃"] and not t.is_empty():
		# 路上同一处、或一成多的机会，她会撞见
		var near := on_road(W) and (String(c["place"]) == here(W) or String(t["place"]) == here(W))
		var strangers: bool = not W.known(c) and not W.known(t)
		var pz := (0.5 if near else 0.1) * (0.3 if strangers and W.active_bonds() >= 4 else 1.0)
		if W.rng.randf() < pz:
			_queue(W, "撞见", {"B": int(c["id"]), "V": int(t["id"])}, {"v": v, "aid": aid})
			return true
	if v == "叛门":
		npc_resolve(W, c, v, {}, aid)
		if W.known(c) and int(W._rel(c, W.P())["g"]) < 15 and W.rng.randf() < 0.6:
			_intent(W, c, "叛门", {}, aid)
		return true
	if v == "劝和" and not t.is_empty() and not t["player"]:
		npc_resolve(W, c, v, t, aid)
		return true
	npc_resolve(W, c, v, t, aid)
	return true

static func _queue(W, tid: String, roles: Dictionary, ctx: Dictionary) -> void:
	for it in W.w["agq"]:
		if int(it[2].get("B", -1)) == int(roles.get("B", -2)):
			return   # 同一个人一次只惦记一件冲着她的事
	if W.w["agq"].size() >= 6:
		W.w["agq"].pop_front()
	W.w["agq"].append([int(W.w["day"]), tid, roles, ctx])

static func _intent(W, c: Dictionary, v: String, extra: Dictionary, aid: int) -> void:
	if not VERB_TID.has(v):
		return
	var tid: String = VERB_TID[v]
	var roles := {"B": int(c["id"])}
	var ctx := {"aid": aid, "why": String(c["dr"]["why"]), "k": String(c["dr"]["k"])}
	var dr: Dictionary = c["dr"]
	match v:
		"求援":
			var prot: Dictionary = W.C(dr["t"])
			if prot.is_empty():
				return
			roles["V"] = int(prot["id"])
			var hs := hunters_of(W, prot)
			if not hs.is_empty():
				roles["H"] = int(hs[0]["id"])
		"示警":
			var hs2 := hunters_of(W, W.P())
			if hs2.is_empty():
				return
			roles["H"] = int(hs2[0]["id"])
		"劝和":
			var foe: Dictionary = _foe_of(W, W.P(), c)
			if foe.is_empty():
				return
			roles["H"] = int(foe["id"])
	for k in extra:
		ctx[k] = extra[k]
	_queue(W, tid, roles, ctx)

## 说书人来取：在家/路上各一份权重（路上的事在路上更常见，但哪件都可能在哪儿发生）
const ROADISH = ["截道", "结伴", "交易", "夺宝", "邀游", "撞见", "挑战", "寻仇"]
static func take(W, road: bool) -> Array:
	var q: Array = W.w.get("agq", [])
	if q.is_empty():
		return []
	var ws := []
	# v0.8 的焦点社交圈照旧：近来往来的人已有 4 个时，生人找上门的权重 ×0.15，并留一份“今天没人来”
	var crowded: bool = W.active_bonds() >= 4
	for it in q:
		var c: Dictionary = W.C(it[2]["B"])
		if c.is_empty() or not c["alive"]:
			ws.append(0.0)
			continue
		var wt := 1.0 + 0.5 * float(c.get("dr", {}).get("u", 0.3))
		if crowded and not W.known(c):
			wt *= 0.15
		if road == (String(it[1]) in ROADISH):
			wt *= 1.5
		if W.w["last"].has(String(it[1])) and int(W.w["day"]) - int(W.w["last"][String(it[1])]) < 8:
			wt *= 0.2   # 同一类事别扎堆
		var lw: Dictionary = W.w.get("last_who", {})
		if int(W.w["day"]) - int(lw.get(str(int(c["id"])), -99)) < 10:
			wt *= 0.3   # 同一个人别天天来
		ws.append(wt)
	var tot := 0.0
	for x in ws:
		tot += float(x)
	if tot <= 0.0:
		W.w["agq"] = []
		return []
	if crowded:
		var q2: Array = q + [[]]
		var it3: Array = W._wch(q2, ws + [0.6])
		if it3.is_empty():
			return []
		q.erase(it3)
		return it3
	var it2: Array = W._wch(q, ws)
	q.erase(it2)
	return it2

## 路上没有人惦记她时：附近的某个人按自己的动机，看看能对这个路过的女修做点什么
static func crossing(W) -> Array:
	var crowded: bool = W.active_bonds() >= 4
	var cs := []
	var ws := []
	for c in W.npcs():
		if not c.has("dr"):
			continue
		cs.append(c)
		ws.append((1.0 if String(c["place"]) == here(W) else 0.35) * (0.5 + float(c["dr"]["u"])) * (0.15 if crowded and not W.known(c) else 1.0))
	if cs.is_empty():
		return []
	for tries in 4:
		var c: Dictionary = W._wch(cs, ws)
		var dr: Dictionary = c["dr"]
		var opts := []
		var scs := []
		# 心里装着别人（要报仇的对象、想赔罪的人……）时，路过她只会做些寻常事
		var own: Array = DRIVE_VERBS.get(String(dr["k"]), [])
		if String(dr["k"]) in ["复仇", "压人", "求偶", "报恩", "赎过", "后事", "护人"] and int(dr["t"]) != 1:
			own = []
		for v in own + ["结伴", "交易", "挑战", "示好", "求教", "论道"]:
			if not VERB_TID.has(v) or v in ["讨债", "求援", "示警", "还情", "劝和", "叛门", "赔罪", "托付"] and not _aimed_ok(W, c, v):
				continue
			var s := score(W, c, v, W.P(), dr)
			if VERB_TID.has(v) and W.w["last"].has(VERB_TID[v]) and int(W.w["day"]) - int(W.w["last"][VERB_TID[v]]) < 8:
				s *= 0.2
			if s > 0.02:
				opts.append(v)
				scs.append(s)
		var i := UC.choose_random(opts, scs, W.rng)
		if i < 0:
			continue
		var v2: String = opts[i]
		var aid := log_act(W, c, v2, W.P(), String(dr["k"]), int(dr.get("src", -1)))
		_intent(W, c, v2, {}, aid)
		for it in W.w["agq"]:
			if int(it[2]["B"]) == int(c["id"]):
				W.w["agq"].erase(it)
				return it
	return []

static func _aimed_ok(W, c: Dictionary, v: String) -> bool:
	match v:
		"讨债":
			return int(W._rel(c, W.P()).get("owe", 0)) > 0
		"还情":
			return float(debt(W, c, W.P())[0]) > 0.15
		"赔罪":
			return float(wronged(W, c, W.P())[0]) > 0.2
		"托付":
			return int(c["dr"]["t"]) == 1
	return false

# ================================================================ 幕后结算（NPC 对 NPC）
static func _ls(c: Dictionary) -> int:
	return int(c.get("ls", 5 + int(c["lv"]) * 3))

static func _add_ls(c: Dictionary, d: int) -> int:
	var b := _ls(c)
	c["ls"] = maxi(0, b + d)
	return int(c["ls"]) - b

static func _win(W, a: Dictionary, b: Dictionary, ea: float = 4.0, eb: float = 4.0) -> bool:
	return float(a["lv"]) + W.rng.randf() * ea > float(b["lv"]) + W.rng.randf() * eb

## 一件事了结了：把那条记忆标成“了”，下回重想
static func _settle(c: Dictionary, src_oid: int, kinds: Array) -> void:
	for m in c["mem"]:
		if int(m[1]) == src_oid and (kinds.is_empty() or (m.size() > 4 and String(m[4]) in kinds) or (m.size() <= 4 and float(m[3]) < 0 and kinds.has("怨"))):
			if m.size() > 4:
				m[4] = "了"
			else:
				m.append("了")
				m.append(-1)
	c["rt"] = 1

static func npc_resolve(W, a: Dictionary, v: String, b: Dictionary, aid: int) -> void:
	var pl: String = String(a["place"])
	var an: String = a["name"]
	var bn: String = b.get("name", "")
	match v:
		"闭关":
			a["xp"] = qz(float(a["xp"]) + W.rng.randf_range(2.0, 5.0), 10000.0)
			if W.rng.randf() < 0.4:
				W.chron(a, W.pv("闭关记", ["闭关数日，心里那道坎松动了些。", "在%s闭了一回关。" % pl, "闭门不出，只托人送过两回饭。"]))
		"探秘":
			if W.rng.randf() < 0.35 + 0.1 * float(a["lv"]) / 9.0:
				var tr: String = W._ch(TREASURE)
				_add_ls(a, W.rng.randi_range(6, 15))
				a["xp"] = qz(float(a["xp"]) + 4.0, 10000.0)
				W.chron(a, "在%s寻到%s。" % [pl, tr])
				if W.rng.randf() < 0.4:
					W.rumor(W.pv("探秘闻", ["听说%s在%s寻到了%s。", "%s从%s回来，带着%s，满面春风。"]) % [an, pl, tr], [a], "宝")
			else:
				a["inj"] = maxi(int(a["inj"]), 8)
				W.chron(a, W.pv("探秘败", ["去%s探一处旧洞府，触了禁制，负伤而回。", "在%s迷了三日路，空手而归。", "在%s遇上守宝的妖兽，带伤逃了出来。"]) % pl)
				drift(a, "慎", 0.02)
		"夺宝":
			if b.is_empty():
				return
			var ab := [a, b] if _win(W, a, b) else [b, a]
			var wn: Dictionary = ab[0]
			var ls2: Dictionary = ab[1]
			_add_ls(wn, 8)
			mem(W, ls2, wn, "%s在%s夺了我看中的灵物" % [wn["name"], pl], -15, "夺", aid)
			W.R(ls2, wn)["g"] = int(W.R(ls2, wn)["g"]) + 15
			W.chron(wn, "在%s与%s争一株灵药，争到了手。" % [pl, ls2["name"]])
			W.chron(ls2, "在%s与%s争一株灵药，落了下风。" % [pl, wn["name"]])
			drift(wn, "傲", 0.02)
			if W.rng.randf() < 0.35:
				W.rumor(W.pv("夺宝闻", ["{w}与{l}在{p}为一株灵药动了手，{w}占了上风。", "{w}在{p}截下了{l}看中的东西。"]).format({"w": wn["name"], "l": ls2["name"], "p": pl}), [wn, ls2])
		"寻仇":
			if b.is_empty() or not b["alive"]:
				_settle(a, int(b.get("id", 0)), [])
				return
			if _win(W, a, b, 4.0, 3.5):
				b["inj"] = maxi(int(b["inj"]), 18)
				W.chron(a, W.pv("寻仇胜", ["在{p}寻到{b}，了结旧账。", "追到{p}，与{b}斗了一场，出了这口气。", "在{p}截住{b}，一剑挑落了{t}的发冠。"]).format({"p": pl, "b": bn, "t": W.ta(b)}))
				W.chron(b, "在%s被%s寻仇，重伤。" % [pl, an])
				mem(W, b, a, "%s在%s伤我" % [an, pl], -22, "伤", aid)
				W.R(b, a)["g"] = int(W.R(b, a)["g"]) + 20
				_settle(a, int(b["id"]), [])
				W.R(a, b)["g"] = maxi(0, int(W.R(a, b)["g"]) - 30)
				drift(a, "仇", -0.03)
				if int(a["lv"]) - int(b["lv"]) >= 3 and px(a, "侠") < 0.3 and W.rng.randf() < 0.4:
					W.die(b, "死于%s之手" % an)
				elif W.rng.randf() < 0.5:
					W.rumor(W.pv("寻仇闻", ["%s寻%s报仇，在%s把人打成重伤。", "听说%s到底还是找到了%s，在%s。"]) % [an, bn, pl], [a, b], "伤")
			else:
				a["inj"] = maxi(int(a["inj"]), 20)
				W.chron(a, "寻%s报仇不成，负伤遁走。" % bn)
				W.chron(b, "%s寻上门来，被打退了。" % an)
				mem(W, a, b, "又败在%s手里" % bn, -12, "辱", aid)
				W.R(b, a)["g"] = int(W.R(b, a)["g"]) + 15
				drift(a, "仇", 0.02)
		"截杀":
			if b.is_empty():
				return
			if _win(W, a, b, 5.0, 3.0):
				var got := _add_ls(b, -mini(_ls(b), W.rng.randi_range(5, 12)))
				_add_ls(a, -got)
				W.chron(a, "在%s截了%s的道。" % [pl, bn])
				W.chron(b, W.pv("被截记", ["在%s被%s截了道，储物袋没了。", "路过%s时遭%s劫掠。", "在%s吃了%s一记闷棍，醒来时身上空了。"]) % [pl, an])
				mem(W, b, a, "%s在%s劫了我" % [an, pl], -25, "劫", aid)
				W.R(b, a)["g"] = int(W.R(b, a)["g"]) + 25
				drift(a, "侠", -0.02)
				drift(b, "慎", 0.03)
				if W.rng.randf() < 0.4:
					W.rumor(W.pv("截道闻", ["{p}附近有人截道，{b}遭了殃。", "听说{b}在{p}被人劫了，劫道的像是{a}。"]).format({"p": pl, "b": bn, "a": an}), [a, b], "劫")
			else:
				a["inj"] = maxi(int(a["inj"]), 12)
				W.chron(a, "在%s截%s的道，反被打伤。" % [pl, bn])
				W.chron(b, "在%s遇上劫道的%s，把人打跑了。" % [pl, an])
				mem(W, b, a, "%s想劫我" % an, -12, "劫", aid)
				mem(W, a, b, "截道时栽在%s手里" % bn, -10, "辱", aid)
				drift(b, "傲", 0.02)
		"偷窃":
			if b.is_empty():
				return
			var got2 := _add_ls(b, -mini(_ls(b), W.rng.randi_range(3, 8)))
			_add_ls(a, -got2)
			if W.rng.randf() > px(a, "慎"):
				W.chron(b, "丢了 %d 块灵石，后来才知道是%s手脚不干净。" % [-got2, an])
				mem(W, b, a, "%s偷过我的东西" % an, -12, "窃", aid)
				W.R(b, a)["g"] = int(W.R(b, a)["g"]) + 12
			else:
				W.chron(b, "储物袋里少了几块灵石，没想明白丢在了哪。")
			W.chron(a, "顺走了%s几块灵石。" % bn)
		"示好":
			if b.is_empty():
				return
			var ob: float = W.opinion(b, a)
			W.R(a, b)["n"] = int(W.R(a, b).get("n", 0)) + 1
			W.R(b, a)["n"] = int(W.R(b, a).get("n", 0)) + 1
			if ob > 15:
				W.R(b, a)["f"] = int(W.R(b, a)["f"]) + 8
				W.R(a, b)["f"] = int(W.R(a, b)["f"]) + 6
				mem(W, b, a, "%s待我好" % an, 8, "情", aid)
				W.chron(a, W.pv("示好成", ["约{b}在{p}看了一夜的灯。", "给{b}送去一包{l}，对方收下了。", "陪{b}走了一趟{p}。"]).format({"b": bn, "p": pl, "l": W._ch(b["likes"])}))
				if ob > 35 and W.opinion(a, b) > 35 and int(W.R(a, b)["n"]) >= 2 and W.partner(a) == null and W.partner(b) == null and not W._protected(a) and not W._protected(b):
					W.R(a, b)["t"].append("道侣")
					W.R(b, a)["t"].append("道侣")
					W.chron(a, "与%s结为道侣。" % bn)
					W.chron(b, "与%s结为道侣。" % an)
					W.rumor("%s与%s结为道侣。听说是%s先开的口。" % [an, bn, an], [a, b], "侣")
					a["rt"] = 1
			else:
				W.chron(a, "向%s表了心意，被婉拒了。" % bn)
				var k := "辱" if px(a, "傲") > 0.6 else "拒"
				mem(W, a, b, "%s拒了我" % bn, -10 if k == "辱" else -4, k, aid)
				drift(a, "痴", -0.02)
		"馈赠":
			if b.is_empty():
				return
			W.R(b, a)["f"] = int(W.R(b, a)["f"]) + 6
			mem(W, b, a, "%s送过我%s" % [an, W._ch(b["likes"])], 7, "赠", aid)
			W.chron(a, "托人给%s捎去一份礼。" % bn)
		"结伴":
			if b.is_empty():
				return
			W.R(a, b)["f"] = int(W.R(a, b)["f"]) + 5
			W.R(b, a)["f"] = int(W.R(b, a)["f"]) + 5
			W.R(a, b)["n"] = int(W.R(a, b).get("n", 0)) + 1
			W.R(b, a)["n"] = int(W.R(b, a).get("n", 0)) + 1
			W.chron(a, W.pv("结伴记", ["与%s结伴去了一趟%s。", "同%s在%s住了几日。", "和%s一道去%s采药。"]) % [bn, pl])
			W.chron(b, "与%s结伴去了一趟%s。" % [an, pl])
			mem(W, b, a, "与%s同行过" % an, 5, "伴", aid)
		"交易":
			if b.is_empty():
				return
			if px(a, "贪") > 0.65 and px(a, "侠") < 0.35 and W.rng.randf() < 0.5:
				_add_ls(b, -4)
				_add_ls(a, 4)
				if W.rng.randf() > px(a, "慎") * 0.8:
					mem(W, b, a, "%s卖我假货" % an, -12, "骗", aid)
					W.R(b, a)["g"] = int(W.R(b, a)["g"]) + 10
					W.chron(b, "从%s手里买了一株假灵草。" % an)
			else:
				W.R(b, a)["f"] = int(W.R(b, a)["f"]) + 2
				W.chron(a, "和%s做了一笔买卖。" % bn)
				if _ls(b) < 4 and W.rng.randf() < 0.5:
					W.R(a, b)["owe"] = int(W._rel(a, b).get("owe", 0)) + 5
					W.chron(b, "赊了%s五块灵石的账。" % an)
		"讨债":
			if b.is_empty():
				return
			var owe := int(W._rel(a, b).get("owe", 0))
			if _ls(b) >= owe or px(b, "侠") > 0.5:
				_add_ls(b, -owe)
				_add_ls(a, owe)
				W.R(a, b)["owe"] = 0
				W.chron(a, "从%s那里讨回了旧账。" % bn)
			else:
				mem(W, a, b, "%s赖我的账" % bn, -15, "负", aid)
				W.R(a, b)["g"] = int(W.R(a, b)["g"]) + 15
				W.chron(a, "找%s讨账，被赖了。" % bn)
		"求援":
			if b.is_empty():
				return
			var prot: Dictionary = W.C(a["dr"]["t"])
			if prot.is_empty():
				return
			if W.opinion(b, a) > 10 and (px(b, "侠") > 0.4 or px(b, "善") > 0.45):
				prot["inj"] = maxi(0, int(prot["inj"]) - 10)
				mem(W, a, b, "%s肯为%s出手" % [bn, prot["name"]], 14, "助", aid)
				mem(W, prot, b, "%s救过我" % bn, 16, "救", aid)
				W.chron(b, "应%s之托，去照看%s。" % [an, prot["name"]])
				W.chron(a, "求%s帮忙照看%s，%s应了。" % [bn, prot["name"], W.ta(b)])
			else:
				mem(W, a, b, "求%s的时候，%s推了" % [bn, W.ta(b)], -6, "拒", aid)
				W.chron(a, "去求%s，碰了一鼻子灰。" % bn)
		"求药":
			if b.is_empty():
				return
			if W.opinion(b, a) >= 0 and (_ls(b) > 3 or px(b, "善") > 0.5):
				a["inj"] = maxi(0, int(a["inj"]) - 10)
				mem(W, a, b, "%s在我伤重时给过药" % bn, 14, "救", aid)
				W.chron(a, W.pv("求药记", ["伤重，去%s那里讨了药。", "托人向%s求来一剂药，伤好了大半。"]) % bn)
				W.chron(b, "给负伤的%s送了药。" % an)
				drift(b, "善", 0.01)
			else:
				mem(W, a, b, "伤重时去求%s，%s没给" % [bn, W.ta(b)], -6, "拒", aid)
				W.chron(a, "带伤去求%s，空手而回。" % bn)
		"赔罪":
			if b.is_empty():
				return
			if px(b, "仇") < 0.55 or W.rng.randf() < 0.3 + 0.5 * px(b, "善"):
				for m in b["mem"]:
					if int(m[1]) == int(a["id"]) and float(m[3]) < 0 and mkind(m) in HURT_K:
						if m.size() > 4:
							m[4] = "了"
				b["rt"] = 1
				W.R(b, a)["g"] = maxi(0, int(W.R(b, a)["g"]) - 25)
				mem(W, b, a, "%s登门赔过不是" % an, 6, "恩", aid)
				a["rt"] = 1
				W.chron(a, W.pv("赔罪成", ["登门向%s赔了不是，对方收下了。", "提着礼去见%s，把当年的事说开了。"]) % bn)
				W.chron(b, "%s上门赔罪，旧事揭过。" % an)
				drift(a, "善", 0.02)
			else:
				mem(W, a, b, "去赔罪，%s把门关了" % bn, -4, "拒", aid)
				W.chron(a, "去向%s赔罪，吃了闭门羹。" % bn)
				W.chron(b, "%s来赔罪，被挡在门外。" % an)
		"托付":
			if b.is_empty():
				return
			a["tf"] = 1
			var half := _ls(a) / 2
			_add_ls(a, -half)
			_add_ls(b, half)
			mem(W, b, a, "%s把身后事托给了我" % an, 16, "托", aid)
			W.chron(a, W.pv("托付记", ["把一生的积蓄和一卷手札托给了%s。", "把身后事托给了%s。"]) % bn)
			W.chron(b, "%s把身后事托给了自己。" % an)
		"论道":
			if b.is_empty():
				return
			a["xp"] = qz(float(a["xp"]) + 2.0, 10000.0)
			b["xp"] = qz(float(b["xp"]) + 2.0, 10000.0)
			W.chron(a, String(W._ch(W.VAR["论道"])).format({"p": pl, "o": bn}))
			W.chron(b, String(W._ch(W.VAR["论道"])).format({"p": pl, "o": an}))
			if (px(a, "傲") > 0.7 or px(b, "傲") > 0.7) and W.rng.randf() < 0.35:
				var lo: Dictionary = a if px(a, "傲") > px(b, "傲") else b
				var hi: Dictionary = b if lo == a else a
				mem(W, lo, hi, "论道时被%s驳得说不出话" % hi["name"], -6, "辱", aid)
			else:
				mem(W, a, b, "与%s论过道" % bn, 5, "论", aid)
				mem(W, b, a, "与%s论过道" % an, 5, "论", aid)
		"示警":
			if b.is_empty():
				return
			var hs := hunters_of(W, b)
			if hs.is_empty():
				return
			mem(W, b, a, "%s提醒过我小心%s" % [an, hs[0]["name"]], 8, "恩", aid)
			W.chron(a, "给%s递了句话：小心%s。" % [bn, hs[0]["name"]])
			b["place"] = W.SECT_HOME[b["sect"]]
		"还情":
			if b.is_empty():
				return
			W.R(b, a)["f"] = int(W.R(b, a)["f"]) + 8
			_settle(a, int(b["id"]), ["救", "恩", "助", "赠", "教", "庇"])
			for m in a["mem"]:
				if int(m[1]) == int(b["id"]) and m.size() > 4 and String(m[4]) == "了" and float(m[3]) > 0:
					m[4] = "还"
			W.chron(a, W.pv("还情记", ["去还了%s的人情。", "给%s送去一份厚礼，了了心事。", "替%s跑了一趟腿，算是还了当年的情。"]) % bn)
			W.chron(b, "%s来还当年的人情。" % an)
		"挑战":
			if b.is_empty():
				return
			var ab2 := [a, b] if _win(W, a, b) else [b, a]
			var wn2: Dictionary = ab2[0]
			var ls3: Dictionary = ab2[1]
			W.chron(wn2, "与%s切磋，胜了半招。" % ls3["name"])
			W.chron(ls3, "与%s切磋，输了半招。" % wn2["name"])
			drift(wn2, "傲", 0.02)
			if px(ls3, "傲") > 0.55 or px(ls3, "仇") > 0.6:
				mem(W, ls3, wn2, "当众输给%s" % wn2["name"], -12, "辱", aid)
			else:
				mem(W, ls3, wn2, "%s的剑确实快" % wn2["name"], 6, "服", aid)
				drift(ls3, "傲", -0.02)
			if W.rng.randf() < 0.3:
				W.rumor("%s与%s在%s切磋，%s胜了半招。" % [an, bn, pl, wn2["name"]], [a, b])
		"造谣":
			if b.is_empty():
				return
			for o in W._sample(W.npcs().filter(func(x): return x != a and x != b), 3):
				W.R(o, b)["f"] = int(W.R(o, b)["f"]) - 3
			W.chron(a, "在%s说了%s几句闲话。" % [pl, bn])
			if W.rng.randf() < 0.5:
				mem(W, b, a, "%s背后嚼我舌根" % an, -8, "谣", aid)
				W.R(b, a)["g"] = int(W.R(b, a)["g"]) + 6
		"叛门":
			var old: String = a["sect"]
			if old == "散修":
				return
			a["sect"] = "散修"
			W.w["ag_oldsect:%d" % int(a["id"])] = old
			W.chron(a, "离了%s，做了散修。" % old)
			W.rumor(W.pv("叛门闻", ["%s叛出%s，%s正在四处找人。", "听说%s连夜下了%s的山门，%s放了话要拿人。"]) % [an, old, old], [a], "叛")
			for o in W.npcs():
				if o != a and o["sect"] == old and W.rng.randf() < 0.5:
					mem(W, o, a, "%s叛了师门" % an, -10, "叛", aid)
					W.R(o, a)["g"] = int(W.R(o, a)["g"]) + 10
			a["rt"] = 1
		"劝和":
			if b.is_empty():
				return
			var foe: Dictionary = _foe_of(W, b, a)
			if foe.is_empty():
				return
			if W.rng.randf() < 0.3 + 0.5 * px(a, "善") - 0.4 * px(foe, "仇"):
				W.R(foe, b)["g"] = maxi(0, int(W.R(foe, b)["g"]) - 25)
				_settle(foe, int(b["id"]), [])
				W.chron(a, "从中说和，%s与%s的旧怨解了。" % [foe["name"], bn])
				W.chron(foe, "经%s说和，与%s放下了旧怨。" % [an, bn])
			else:
				W.chron(a, "想替%s与%s说和，没说成。" % [bn, foe["name"]])
		"收徒":
			if b.is_empty() or "师" in W._rel(b, a)["t"]:
				return
			if W.master_of(b) == null and W.opinion(b, a) > 10:
				W.R(a, b)["t"].append("徒")
				W.R(b, a)["t"].append("师")
				W.chron(a, "收%s为徒。" % bn)
				W.chron(b, "拜%s为师。" % an)
				mem(W, b, a, "%s肯教我" % an, 15, "教", aid)
		"求教":
			if b.is_empty():
				return
			if W.opinion(b, a) > 0 and px(b, "傲") < 0.7:
				a["xp"] = qz(float(a["xp"]) + 3.0, 10000.0)
				mem(W, a, b, "%s指点过我" % bn, 10, "教", aid)
				W.chron(a, "向%s请教，得了几句要紧话。" % bn)
				if W.master_of(a) == null and int(b["lv"]) - int(a["lv"]) >= 4 and W.opinion(b, a) > 20:
					npc_resolve(W, b, "收徒", a, aid)
			else:
				mem(W, a, b, "向%s请教，被冷着脸打发了" % bn, -6, "辱", aid)

# ================================================================ 她面前的事
const OUTDOOR = ["截道", "夺宝", "撞见", "结伴", "邀游"]
static func _at(W, ctx: Dictionary, tid: String = "") -> String:
	if ctx.has("at"):
		return String(ctx["at"])
	var s := ""
	if not on_road(W) and tid in OUTDOOR:
		# 在家时，这类事发生在青庐附近的野地里（她出门采药、去镇上的路上）
		s = W.pv("庐外地", ["青庐后头的山坡上", "青庐外的溪涧边", "山脚下的老林子里", "去镇上的半路", "她去后山砍柴的路上", "镇外的石桥边"])
	elif on_road(W):
		s = W.pv("路途地", ["%s的山道上", "%s路边的茶棚下", "去%s的溪桥边", "%s的林子边", "%s半道的破亭子里", "%s的石阶上", "%s的岔路口"]) % here(W)
	else:
		s = W.pv("庐前地", ["青庐柴门外", "青庐院里", "桂树下", "灵田埂上", "井边", "院门口", "青庐后头的竹林边"])
	ctx["at"] = s
	ctx["road"] = on_road(W)
	return s

static func _o(id: String, label: String) -> Array:
	return [id, label]

static func present(W, tid: String, roles: Dictionary, ctx: Dictionary) -> Dictionary:
	var n: Dictionary = W.C(roles["B"])
	var nm: String = n["name"]
	var at := _at(W, ctx, tid)
	var why := say(W, String(ctx.get("why", "")))
	var f := {"n": nm, "at": at, "why": why, "ta": W.ta(n), "tb": W._tb(n)}
	var anon: bool = not W.known(n)
	match tid:
		"寻仇":
			var t := fl(W, "寻仇开", n, {
				"傲": ["{at}，{n}拦在前头，剑没出鞘：“{why}。这笔账，我不屑暗地里算——拔剑。”", "“{why}。”{n}立在{at}，衣袂不动，“我等你先出手。”"],
				"慎": ["{n}远远跟了她半日，到{at}四下无人，才现身：“{why}。我想了很久，今天该了结了。”", "{at}，一道传音先到：“{why}。”随后才是{n}的人。"],
				"仇": ["“{why}。”{n}在{at}一字一顿，“我每天都记着。”", "{at}，{n}笑了一下，笑得很冷：“{why}。你忘了，我没忘。”"],
				"痴": ["{n}眼睛是红的，堵在{at}：“{why}。今日我替人讨。”"],
				"平": ["{at}，{n}挡住了去路：“{why}，你可还记得？”", "{at}，{n}把剑插在地上：“{why}。今日说个明白。”"]}).format(f)
			return {"speaker": int(n["id"]), "text": t, "opts": [_o("fight", "迎战"), _o("talk", "把当时的原委说清楚"), _o("pay", "赔礼（10 灵石）") if W.lingshi() >= 10 else _o("bow", "低头赔个不是"), _o("run", "不与%s纠缠，走" % f["tb"])]}
		"截道":
			var t2 := fl(W, "截道开", n, {
				"贪": ["{at}，一人横剑拦路，笑嘻嘻的：“储物袋留下，人走。”", "{at}，有人蹲在路中间数灵石，见她来了，把手一摊：“过路钱。”"],
				"慎": ["{at}，林子里没人露脸，只一道传音：“放下十块灵石，往前走，莫回头。”"],
				"傲": ["{at}，一人抱剑而立：“这条路，今日我说了算。交钱，或者交手。”"],
				"平": ["{at}，草里窜出一人，刀已经横到她颈边。", "{at}，前后各站了一个人。前头那个开口：“姑娘，借点盘缠。”"]}).format(f)
			var o2 := [_o("pay", "给%d块灵石了事" % mini(10, W.lingshi())) if W.lingshi() > 0 else _o("pay", "把空储物袋抖给%s看" % f["tb"]), _o("fight", "动手")]
			o2.append(_o("name", "叫破%s的名字" % nm) if not anon else _o("bluff", "说身后有师门的人跟着"))
			return {"speaker": int(n["id"]), "anon": anon, "text": t2, "opts": o2}
		"失窃":
			var amt := mini(W.lingshi(), W.rng.randi_range(4, 9))
			ctx["amt"] = amt
			var t3 := ""
			if on_road(W):
				t3 = W.pv("失窃路", ["{at}歇了一夜，醒来行囊轻了。不远处，{n}正往林子里走，脚步很快。", "{at}人挤人，等她回过神，腰间的灵石袋松了口。回头看去，{n}刚好转过身。"]).format(f)
			else:
				t3 = W.pv("失窃家", ["她回到屋里，发觉灵石少了一小撮。窗台上有半个红泥脚印——前几日来过的{n}，鞋底也沾着这样的泥。", "丹炉边的灵石匣被人动过，摆放的方向不对。她想起昨日{n}在院里多坐了一会儿。"]).format(f)
			t3 += ("（少了 %d 块灵石）" % amt) if amt > 0 else "（灵石匣本就是空的，倒没少什么）"
			return {"speaker": int(n["id"]), "text": t3, "opts": [_o("chase", "追上去讨回来"), _o("let", "不声张，记下了"), _o("report", "去%s告%s一状" % [n["sect"] if n["sect"] != "散修" else "坊市管事那里", f["tb"]])]}
		"示好":
			var like: String = W._ch(n["likes"])
			ctx["like"] = like
			f["like"] = like
			var t4 := fl(W, "示好开", n, {
				"痴": ["{n}在{at}等了她很久，见了面却只说：“顺路。”袖口里露出半截{like}。", "{n}在{at}站着，手里攥着一包{like}，攥得纸都皱了。"],
				"傲": ["“我{n}不常请人。”{ta}在{at}把一盏茶推过来，“今日算你一个。”", "{at}，{n}把一包{like}丢给她：“多买了，不要就扔了。”"],
				"慎": ["{n}在{at}绕了好几句闲话，才问：“下回出门，可否知会我一声？”", "{n}在{at}递来一封信，说回去再看。信里只写了一句：天凉，加衣。"],
				"善": ["{n}在{at}拦住她，递上一包{like}：“上回见你没吃好。”"],
				"平": ["{at}，{n}寻了个由头同她说话，说了半晌，话都绕回她身上。", "{n}在{at}等她，带了一包{like}。"]}).format(f)
			return {"speaker": int(n["id"]), "text": t4, "opts": [_o("yes", "收下这份心意"), _o("polite", "以礼相待，不远不近"), _o("no", "把话说明白：无意")]}
		"馈赠":
			var g: Array = W._ch(GOODS)
			ctx["g"] = g
			var note := fl(W, "馈赠语", n, {
				"痴": ["路过时想起你。", "见了就想着你用得上。"], "傲": ["多余的，别推。", "我用不着这种东西。"],
				"善": ["山里冷，自己当心。", "上回的事，一直想谢你。"], "慎": ["东西验过，干净的。", "莫对旁人说是我给的。"],
				"平": ["顺手。", "留着用。"]})
			var t5 = W.pv("馈赠开", ["{n}托人捎来{g}，附一张字条：“{note}”", "{at}，{n}塞给她{g}，只说：“{note}”", "回来时，{at}放着{g}，压着一张字条：“{note}”落款是{n}。"]).format({"n": nm, "g": g[2], "note": note, "at": at})
			return {"speaker": int(n["id"]), "text": t5, "opts": [_o("take", "收下"), _o("back", "收下，回一份礼（−3 灵石）") if W.lingshi() >= 3 else _o("thank", "收下，托人带句谢"), _o("refuse", "原样退回")]}
		"结伴":
			var t6 := fl(W, "结伴开", n, {
				"奇": ["{at}，{n}指着远处一块石碑：“上头的字没人认得——一起去瞧瞧？”", "{n}在{at}追上她：“听说前头有处泉眼，夜里会亮。同去？”"],
				"侠": ["{at}，{n}看了看天色：“这段路不太平，我陪你走一程。”"],
				"贪": ["{n}在{at}拦住她：“同路便同行。路上捡着东西，三七分，我七。”"],
				"痴": ["{n}在{at}等着，像是早知道她要走这条路：“我也去那边。”"],
				"平": ["{at}，{n}也往这边走，问能不能同行一段。", "{n}在{at}歇脚，见她来了，挪出半块石头的地方。"]}).format(f)
			return {"speaker": int(n["id"]), "anon": anon, "text": t6, "opts": [_o("go", "同行"), _o("no", "谢过，独自走")]}
		"交易":
			var g2: Array = W._ch(GOODS)
			var price := int(round(5.0 + 9.0 * px(n, "贪") - 3.0 * px(n, "侠")))
			price = clampi(price, 3, 14)
			var fake: bool = px(n, "贪") > 0.65 and px(n, "侠") < 0.35 and W.rng.randf() < 0.6
			ctx["g"] = g2
			ctx["price"] = price
			ctx["fake"] = fake
			f["g"] = g2[2]
			f["p"] = str(price)
			var t7 := fl(W, "交易开", n, {
				"贪": ["{at}，{n}掀开包袱一角：“{g}，{p}块灵石，过了这村没这店。”", "{n}在{at}凑过来：“好东西。{g}，{p}块，不还价。”"],
				"慎": ["{n}在{at}把{g}摆在帕子上，让她先验：“{p}块灵石。”"],
				"侠": ["{at}，{n}说手头有{g}，用不上：“{p}块，给个本钱就行。”"],
				"平": ["{at}，{n}摆了个小摊，{g}要价{p}块灵石。", "{n}在{at}问她要不要{g}，{p}块灵石。"]}).format(f)
			var o7 := []
			if W.lingshi() >= price:
				o7.append(_o("buy", "买下（−%d 灵石）" % price))
				o7.append(_o("haggle", "还价"))
			else:
				o7.append(_o("credit", "先赊着，下回还"))
			o7.append(_o("no", "不要"))
			return {"speaker": int(n["id"]), "anon": anon, "text": t7, "opts": o7}
		"讨债":
			var owe := int(W._rel(n, W.P()).get("owe", 0))
			ctx["owe"] = owe
			f["k"] = str(owe)
			var t8 := fl(W, "讨债开", n, {
				"贪": ["{at}，{n}摊开手：“上回赊的{k}块灵石，连本带利，今天该清了。”"],
				"傲": ["“我不缺那{k}块灵石。”{n}在{at}说，“缺的是规矩。”"],
				"善": ["{n}在{at}有些不好意思：“那{k}块灵石……不急，就是路过问一声。”"],
				"仇": ["{n}在{at}等她：“{k}块灵石。我记账向来记得清楚。”"],
				"平": ["{at}，{n}提起旧账：“{k}块灵石，你看什么时候方便？”"]}).format(f)
			return {"speaker": int(n["id"]), "text": t8, "opts": ([_o("pay", "如数还上（−%d 灵石）" % owe)] if W.lingshi() >= owe else []) + [_o("later", "求宽限几日"), _o("deny", "不认这笔账")]}
		"求援":
			var v: Dictionary = W.C(roles["V"])
			var h: Dictionary = W.C(roles.get("H", 0))
			f["v"] = v["name"]
			f["h"] = h.get("name", "")
			var trouble := ("被{h}盯上了，这几日就要动手" if not h.is_empty() else "伤得重，药王谷的药不够")
			var t9 := fl(W, "求援开", n, {
				"痴": ["{n}来得急，衣襟上全是土：“{v}" + trouble + "。我只想得到你。”"],
				"傲": ["{n}在{at}站了半天，才低头：“我从不求人。{v}" + trouble + "——帮我一回。”"],
				"侠": ["“{v}" + trouble + "。”{n}说，“我一个人护不住，你肯不肯来？”"],
				"平": ["{at}，{n}拉住她：“{v}" + trouble + "，你那里可有法子？”"]}).format(f)
			var o9 := [_o("go", "跟%s去一趟" % f["tb"])]   # 用家里东西的选项从不放第一个
			if W._has("pill_quzhang"):
				o9.append(_o("pill", "给一粒驱瘴丹"))
			elif W._has("pill_juqi"):
				o9.append(_o("pill", "给一粒聚气丹"))
			if W.lingshi() >= 8:
				o9.append(_o("ls", "给 8 块灵石买药"))
			o9.append(_o("no", "爱莫能助"))
			return {"speaker": int(n["id"]), "text": t9, "opts": o9}
		"求药":
			var t21 := fl(W, "求药开", n, {
				"傲": ["{n}扶着{at}的门框，脸白得像纸，偏不肯坐：“听说你种药。卖我一株，价钱好说。”"],
				"慎": ["{n}在{at}犹豫了很久才开口：“伤口一直不收。我信不过镇上的郎中。”"],
				"痴": ["{n}在{at}笑得很勉强：“又伤了。你别骂，先给我点药。”"],
				"善": ["{n}在{at}站着，袖口渗出血来：“不好意思开口……你那里有止血的草么？”"],
				"平": ["{at}，{n}带着一身伤来了：“听说你种着灵草，能不能匀我一点？”", "{n}在{at}坐下，半边衣裳都是血：“有药么？”"]}).format(f)
			var o21 := [_o("look", "替%s看看伤，开个方子" % f["tb"])]
			if W._has("herb_xugucao"):
				o21.append(_o("herb", "给一株续骨草"))
			if W._has("herb_qingzhi"):
				o21.append(_o("sell", "卖一株青芝（6 灵石）"))
			o21.append(_o("no", "说手头没有"))
			return {"speaker": int(n["id"]), "text": t21, "opts": o21}
		"赔罪":
			var t22 := fl(W, "赔罪开", n, {
				"侠": ["{n}在{at}抱拳，深深一揖：“{why}。今天来，任打任罚。”"],
				"善": ["{n}在{at}提着一盒点心，站了很久才进来：“{why}……一直睡不安稳。”"],
				"慎": ["{n}先托人递了话，第二日才到{at}：“{why}。我想当面说清楚。”"],
				"平": ["{at}，{n}低着头：“{why}。这些东西，你收下吧。”", "{n}在{at}放下一只布包：“{why}。”"]}).format(f)
			return {"speaker": int(n["id"]), "text": t22, "opts": [_o("forgive", "让%s起来，事情过去了" % f["tb"]), _o("take", "收下赔礼，各不相欠"), _o("refuse", "不受")]}
		"托付":
			var t23 := fl(W, "托付开", n, {
				"侠": ["{n}在{at}坐下，咳了几声：“我这辈子不欠谁。只是有件事，想托给你。”"],
				"善": ["{n}老了许多，在{at}把一只旧木匣推到她面前：“{why}。别推。”"],
				"傲": ["“我的事，从不求人。”{n}在{at}沉默半晌，“这一件例外。”"],
				"平": ["{at}，{n}拄着杖来了：“{why}。这些东西，留给你。”", "{n}在{at}说起了身后事，说得很平静。"]}).format(f)
			return {"speaker": int(n["id"]), "text": t23, "opts": [_o("take", "收下"), _o("deliver", "答应替%s把东西送回%s" % [f["tb"], n["sect"]]), _o("comfort", "劝%s别说这样的话" % f["tb"])]}
		"问道":
			var t24 := fl(W, "问道开", n, {
				"奇": ["{n}在{at}拉住她：“我昨夜想到一个怪念头——灵气走经脉，为什么非得是顺的？”"],
				"野": ["{at}，{n}开门见山：“我卡在这一层半年了。你怎么看‘破境’两个字？”"],
				"傲": ["{n}在{at}背着手：“听说你也悟了些东西。说来听听，我看对不对。”"],
				"平": ["{at}，{n}提了一壶茶来：“闲着，论论道？”", "{n}在{at}坐下，说起这阵子修行上的几处疑难。"]}).format(f)
			return {"speaker": int(n["id"]), "text": t24, "opts": [_o("long", "论到天明"), _o("listen", "听多说少"), _o("no", "推说累了")]}
		"示警":
			var h2: Dictionary = W.C(roles["H"])
			f["h"] = h2["name"]
			f["hw"] = say(W, String(h2.get("dr", {}).get("why", "旧事")))
			var t10 := fl(W, "示警开", n, {
				"侠": ["{at}，{n}压低声音：“{h}在打听你。为的是——{hw}。早做准备。”"],
				"慎": ["{n}在{at}与她擦肩，袖里塞来一张纸条：{h}要找你，小心。"],
				"善": ["{n}在{at}拉住她，欲言又止：“{h}那边……你这阵子别一个人走夜路。”"],
				"平": ["{at}，{n}说起一件事：{h}在四处打听她的下落，为了“{hw}”。"]}).format(f)
			return {"speaker": int(n["id"]), "text": t10, "opts": [_o("ready", "谢过，心里有了防备"), _o("mediate", "托%s带话，想与%s说和" % [f["tb"], h2["name"]]), _o("shrug", "不放在心上")]}
		"求教":
			var t11 := fl(W, "求教开", n, {
				"傲": ["“我不是来求你的。”{n}在{at}别过脸，“只是……那一式，你怎么收的势？”"],
				"慎": ["{n}在{at}捧着本小册子，问题列了三页，第一页就有七处圈了红。"],
				"野": ["{n}在{at}拦住她：“我想三年内筑基。炼气那几层，你是怎么熬过来的？”"],
				"平": ["{at}，{n}有些局促：“有几处经脉的走法，想请教。”", "{n}在{at}等她，说练功练岔了气，想问问她。"]}).format(f)
			return {"speaker": int(n["id"]), "text": t11, "opts": [_o("teach", "细细讲一下午"), _o("brief", "指点两句"), _o("no", "推说自己也不懂")]}
		"还情":
			var t12 := fl(W, "还情开", n, {
				"侠": ["{n}在{at}找到她：“{why}——这份情，我搁在心里很久了。”"],
				"善": ["{n}在{at}递过一个布包：“{why}。一直想谢你，又不知送什么好。”"],
				"傲": ["“{why}。”{n}在{at}说，“我不爱欠人。说吧，要什么。”"],
				"平": ["{at}，{n}提起旧事：“{why}。今日来还。”"]}).format(f)
			return {"speaker": int(n["id"]), "text": t12, "opts": [_o("take", "收下%s的心意" % f["tb"]), _o("tea", "留%s喝碗茶，东西就不必了" % f["tb"]), _o("ask", "请%s日后帮一个忙" % f["tb"])]}
		"挑战":
			var t13 := fl(W, "挑战开", n, {
				"傲": ["“听说你剑不慢。”{n}在{at}把剑横在膝上，“切磋一场，点到为止。”", "{n}在{at}拦住她：“我不和庸人动手。你不算。”"],
				"野": ["{n}在{at}活动着手腕：“打一场。输赢都记账，我在攒对手。”"],
				"妒": ["“都说你进境快。”{n}在{at}说，语气不太好听，“让我看看有多快。”"],
				"平": ["{at}，{n}抱拳：“久闻，切磋一二？”"]}).format(f)
			return {"speaker": int(n["id"]), "anon": anon, "text": t13, "opts": [_o("fight", "应战"), _o("yield", "拱手认输，让%s这个名头" % f["tb"]), _o("later", "改日再说")]}
		"流言":
			var rm: String = W.pv("流言内容", ["青庐那女修的丹方是偷来的", "她当年在寒潭边见死不救", "她的修为是拿别人的灵根换的", "她和魔门的人有来往", "她欠了一屁股债，连姑母都躲着她", "她采药专挑别人的地盘"])
			ctx["rm"] = rm
			f["rm"] = rm
			var t14 = W.pv("流言开", ["{at}，有人背着她嚼舌根：{rm}。传话的人说，最先是从{n}嘴里出来的。", "坊市的熟人支支吾吾地告诉她，外头在传：{rm}。源头像是{n}。", "{at}，有人对她指指点点。她听见一句：“{rm}。”说这话的人，前几日刚和{n}喝过酒。"]).format(f)
			return {"speaker": 0, "text": t14, "opts": [_o("face", "去找%s当面说清" % nm), _o("clear", "请几位熟人喝茶，把事说明（−5 灵石）") if W.lingshi() >= 5 else _o("clear", "托几位熟人替她分辩"), _o("ignore", "由它去")]}
		"叛门":
			f["s"] = String(W.w.get("ag_oldsect:%d" % int(n["id"]), "师门"))
			var t15 = W.pv("叛门开", ["{at}，{n}的腰牌已经摘了：“{s}容不下我了。借个地方躲几日。”", "夜里有人叩门。{n}浑身是露水：“我出了{s}。他们在找我。”", "{at}，{n}一身旧衣，看不出原来的服色：“{s}的人在后头。你若为难，我这就走。”"]).format(f)
			return {"speaker": int(n["id"]), "text": t15, "opts": [_o("hide", "收留%s几日" % f["tb"]), _o("road", "给%s指条小路，再塞点干粮" % f["tb"]), _o("turn", "把人交给%s" % f["s"])]}
		"劝和":
			var h3: Dictionary = W.C(roles["H"])
			f["h"] = h3["name"]
			var cond: String = W.pv("劝和条件", ["当面赔个礼", "陪%s喝顿酒，把话说开" % W.ta(h3), "把那件事认下来", "往后见了%s，让一步" % W.ta(h3)])
			ctx["cond"] = cond
			f["c"] = cond
			var t16 = W.pv("劝和开", ["{at}，{n}带来了{h}的话：“{h}说，只要你{c}，那件事就算了。”", "{n}在{at}叹气：“你和{h}那点事，拖下去谁都不好过。{h}松了口——你{c}就行。”"]).format(f)
			return {"speaker": int(n["id"]), "text": t16, "opts": [_o("yes", "应下：%s" % cond), _o("no", "不应"), _o("back", "反问%s当初的不是" % h3["name"])]}
		"夺宝":
			var tr: String = W._ch(TREASURE)
			ctx["tr"] = tr
			f["tr"] = tr
			var t17 := fl(W, "夺宝开", n, {
				"贪": ["{at}，{tr}就在眼前。另一边，{n}也看见了：“先到先得。”"],
				"傲": ["{at}，{tr}。{n}也到了，抱着手：“让你先出手。”"],
				"慎": ["{at}，{tr}。{n}站在三丈外，没动，等她先开口。"],
				"侠": ["{at}，{tr}。{n}看了一眼，又看了看她：“你先看见的。”"],
				"平": ["{at}，{tr}。几乎同时，{n}也到了。"]}).format(f)
			return {"speaker": int(n["id"]), "anon": anon, "text": t17, "opts": [_o("grab", "抢先下手"), _o("share", "提议二人平分"), _o("yield", "让给%s" % f["tb"])]}
		"邀游":
			var t18 := fl(W, "邀游开", n, {
				"奇": ["{n}在{at}摊开一张残图，眼睛发亮：“后山底下有座旧洞府！一起？”"],
				"慎": ["{n}在{at}问她：“有处洞府，我探过外头，禁制不难。你帮我望个风，所得分你三成。”"],
				"贪": ["“洞府里的东西，我七你三。”{n}在{at}说，“你只管跟着。”"],
				"平": ["{at}，{n}说听闻附近有座无主洞府，一个人不敢去。"]}).format(f)
			return {"speaker": int(n["id"]), "anon": anon, "text": t18, "opts": [_o("go", "同去"), _o("advice", "只帮%s看看图" % f["tb"]), _o("no", "不去")]}
		"撞见":
			var v2: Dictionary = W.C(roles["V"])
			f["v"] = v2["name"]
			var verb := String(ctx.get("v", "寻仇"))
			var scene := ""
			match verb:
				"寻仇":
					scene = W.pv("撞见仇", ["{at}，{n}正把{v}逼得连退几步，剑尖指着{v}的喉咙：“还记得吗？”", "{at}传来兵刃声。{n}与{v}斗在一处，{v}已经见了血。"])
				"截杀":
					scene = W.pv("撞见劫", ["{at}，{n}拦着{v}，正去扯{v}腰间的储物袋。", "{at}，{v}倒在路边，{n}弯腰在翻{v}的东西。"])
				"挑战":
					scene = W.pv("撞见斗", ["{at}围了一圈人。{n}与{v}在切磋，看着已经动了真火。"])
				_:
					scene = W.pv("撞见窃", ["{at}，{n}的手悄悄伸进了{v}的袖袋。{v}还在同人说笑。"])
			var t19 := scene.format(f)
			return {"speaker": int(n["id"]), "anon": anon, "text": t19, "opts": [_o("stop", "出手拦下"), _o("shout", "喝一声"), _o("leave", "装作没看见")]}
	return {"speaker": int(n["id"]), "text": "%s来过。" % nm, "opts": [_o("ok", "知道了")]}

## 结算：写回双方的记忆、关系、动机；返回结果文字
static func resolve(W, tid: String, roles: Dictionary, ctx: Dictionary, oid: String) -> String:
	var p: Dictionary = W.P()
	var n: Dictionary = W.C(roles["B"])
	var nm: String = n["name"]
	var aid := int(ctx.get("aid", -1))
	var at := _at(W, ctx, tid)
	var pl := float(W.plv())
	var tb: String = W._tb(n)
	var out := ""
	var fresh: bool = W.meet(n)
	match tid:
		"寻仇":
			match oid:
				"fight":
					var bonus := 3.0 if W._flag("ag_warn:%d" % int(n["id"])) > 0 else 0.0
					if W._roll(pl + bonus, float(n["lv"]), 5, 4):
						n["inj"] = maxi(int(n["inj"]), 12)
						out = W.pv("寻仇退", ["三十招后，{n}的剑被她挑开。{n}退了两步，没再上前。", "她一掌拍在{n}剑脊上。{n}踉跄退开，咬着牙：“今日不算。”", "剑光收住时，{n}的衣袖被削去一截。{n}看了她很久，转身走了。"]).format({"n": nm})
						if px(n, "慎") > 0.6:
							mem(W, n, p, "%s的剑不好惹" % W.pn(), -4, "惧", aid)
							_settle(n, 1, [])
							out += "\n%s往后大概不会再来了。" % nm
						else:
							mem(W, n, p, "又败在%s手里" % W.pn(), -12, "辱", aid)
							drift(n, "仇", 0.02)
						W.chron(p, "%s寻仇而来，在%s被她打退。" % [nm, at])
						W.chron(n, "寻%s报仇，败退。" % W.pn())
					else:
						W._inj(3)
						W.R(n, p)["g"] = maxi(0, int(W.R(n, p)["g"]) - 30)
						_settle(n, 1, [])
						mem(W, n, p, "在%s讨回了公道" % at, 4, "了", aid)
						out = W.pv("寻仇负", ["她输了。{n}收剑：“两清。”走时没回头。", "她的剑落在地上。{n}看了一眼，没有再出手：“这口气出了。”"]).format({"n": nm}) + "\n（受伤：闭关炼化减半 3 日）"
						W.chron(p, "%s寻仇而来，她败了。" % nm)
						W.chron(n, "向%s讨回了旧账。" % W.pn())
						drift(n, "仇", -0.03)
				"talk":
					var ch := 0.25 + 0.35 * px(n, "善") + 0.25 * px(n, "慎") - 0.45 * px(n, "仇")
					if W.rng.randf() < ch:
						W.R(n, p)["g"] = maxi(0, int(W.R(n, p)["g"]) - 35)
						_settle(n, 1, [])
						mem(W, n, p, "听%s说了当时的原委" % W.pn(), 8, "解", aid)
						out = W.pv("寻仇解", ["她把那日的事从头说了一遍。{n}听完，沉默了很久，把剑收回鞘里。", "{n}一开始不肯听。她说到第三句，{n}的手松了。“……原来如此。”"]).format({"n": nm})
						W.chron(p, "与%s把旧事说开了。" % nm)
						W.chron(n, "听%s说了原委，放下了旧怨。" % W.pn())
					else:
						W.R(n, p)["g"] = int(W.R(n, p)["g"]) + 5
						out = W.pv("寻仇不解", ["她说得越多，{n}的脸色越冷：“说完了？”", "“借口。”{n}只回了两个字，转身走了，说改日再来。"]).format({"n": nm})
						W.chron(p, "想同%s说清旧事，对方不信。" % nm)
				"pay", "bow":
					if oid == "pay":
						W._ling(-10)
					var k := 20 if px(n, "仇") < 0.6 else 10
					W.R(n, p)["g"] = maxi(0, int(W.R(n, p)["g"]) - k)
					n["dr"]["u"] = qz(float(n["dr"]["u"]) * 0.5, 100.0)
					out = (W.pv("寻仇赔傲", ["{n}收了灵石，冷笑一声：“早这样多好。”", "{n}看着她，看了很久：“记住今日。”"]) if px(n, "傲") > 0.55 else W.pv("寻仇赔", ["{n}沉默了一会儿：“……罢了。”", "{n}收了剑：“这次先算了。”"])).format({"n": nm})
					W.chron(p, "%s寻仇而来，她赔了礼。" % nm)
				_:
					drift(n, "仇", 0.02)
					var rr: Dictionary = W.R(n, p)
					rr["run"] = int(rr.get("run", 0)) + 1
					out = W.pv("寻仇走", ["她没有接，绕开{n}走了。身后传来一句：“你走得了几回？”", "她转身就走，{n}没追，只在身后说：“下回。”"]).format({"n": nm})
					if int(rr["run"]) >= 3:
						_settle(n, 1, [])
						out += "\n躲了三回，%s大概也倦了。" % nm
					W.chron(p, "躲开了来寻仇的%s。" % nm)
		"截道":
			match oid:
				"pay":
					var got = W._ling(-mini(10, W.lingshi()))
					_add_ls(n, -got)
					W.R(p, n)["g"] = int(W.R(p, n)["g"]) + 15
					mem(W, n, p, "%s肯破财" % W.pn(), 2, "弱", aid)
					out = (W.pv("截道给", ["对方掂了掂灵石，让开了路。", "灵石落进对方手里，对方吹了声口哨，钻回林子。"]) + "（%d 块灵石）" % -got) if got < 0 else W.pv("截道空", ["对方看着空空的储物袋愣了一下，啐了一口，让开了。"])
					W.chron(p, "在%s被%s截了道，破财免灾。" % [at, nm])
					W.chron(n, "在%s截了%s的道。" % [at, W.pn()])
				"fight":
					if W._roll(pl, float(n["lv"]), 5, 4):
						n["inj"] = maxi(int(n["inj"]), 10)
						out = W.pv("截道胜", ["她出手比对方快。三招之后，{n}捂着肩膀退进了林子。", "她没废话，一剑削断了对方的刀。{n}脸色一变，扭头就跑。"]).format({"n": nm})
						if px(n, "仇") > 0.55:
							mem(W, n, p, "截道时被%s打伤" % W.pn(), -15, "辱", aid)
						else:
							mem(W, n, p, "%s不好惹" % W.pn(), -3, "惧", aid)
						W._wu(2)
						out += "\n（感悟 +2）"
						W.chron(p, "在%s打退了截道的%s。" % [at, nm])
						W.chron(n, "截%s的道，反被打伤。" % W.pn())
					else:
						var got2 = W._ling(-mini(12, W.lingshi()))
						W._inj(2)
						_add_ls(n, -got2)
						W.R(p, n)["g"] = int(W.R(p, n)["g"]) + 25
						out = "她没打过。%s拿走了 %d 块灵石。\n（受伤：闭关炼化减半 2 日）" % [nm, -got2]
						W.chron(p, "在%s遭%s劫掠，带伤而回。" % [at, nm])
						W.chron(n, "在%s劫了%s。" % [at, W.pn()])
				"name", "bluff":
					if px(n, "慎") > 0.5 or (oid == "name" and W.rng.randf() < 0.5):
						mem(W, n, p, "被%s认了出来" % W.pn(), -5, "惧", aid)
						out = (W.pv("截道名", ["“{n}。”她只说了名字。对方愣住，退进林子里，再没出来。", "她把{n}的名号报了出来，又报了宗门。对方骂了一句，走了。"]) if oid == "name" else W.pv("截道诈", ["她往身后看了一眼，像在等人。对方犹豫片刻，退走了。"])).format({"n": nm})
						W.chron(p, "在%s吓退了截道的%s。" % [at, nm])
					else:
						var got3 = W._ling(-mini(14, W.lingshi()))
						_add_ls(n, -got3)
						W.R(p, n)["g"] = int(W.R(p, n)["g"]) + 20
						out = "对方笑了：“那就更不能放你走了。”她赔上了 %d 块灵石才脱身。" % -got3
						W.chron(p, "在%s被%s截了道。" % [at, nm])
		"失窃":
			var amt := int(ctx.get("amt", 5))
			match oid:
				"chase":
					if W._roll(pl, float(n["lv"]) * (0.6 + 0.4 * px(n, "慎")), 5, 4):
						mem(W, n, p, "偷%s的东西被当场拿住" % W.pn(), -10, "辱", aid)
						out = W.pv("失窃追回", ["她在第三个岔口追上了{n}。灵石一块不少地回来了。{n}的脸红得像要滴血。", "她一把扣住{n}的手腕。{n}没挣，把东西还了，低声说了句对不住。"]).format({"n": nm})
						if px(n, "善") > 0.45:
							drift(n, "侠", 0.03)
							mem(W, n, p, "%s没把事闹大" % W.pn(), 6, "恩", aid)
						W.chron(p, "追上偷东西的%s，讨回了灵石。" % nm)
					else:
						W._ling(-amt)
						_add_ls(n, amt)
						out = "她追了半里，人影早没了。"
						W.chron(p, "丢了 %d 块灵石，像是%s拿的。" % [amt, nm])
				"let":
					W._ling(-amt)
					_add_ls(n, amt)
					W.R(p, n)["g"] = int(W.R(p, n)["g"]) + 10
					if px(n, "善") > 0.4 or px(n, "侠") > 0.4:
						mem(W, n, p, "偷了%s的灵石，%s却没声张" % [W.pn(), "她"], 12, "恩", aid)
						drift(n, "侠", 0.02)
						out = "她什么也没说。过了几日，听说%s在坊市里一个人喝了很久的闷酒。" % nm
					else:
						out = "她没声张，只把灵石匣挪了地方。"
					W.chron(p, "丢了 %d 块灵石，没有追究。" % amt)
				_:
					W._ling(-amt)
					W.R(p, n)["g"] = int(W.R(p, n)["g"]) + 10
					mem(W, n, p, "%s告了我一状" % W.pn(), -18, "辱", aid)
					W.R(n, p)["g"] = int(W.R(n, p)["g"]) + 18
					if n["sect"] != "散修":
						for o in W.npcs():
							if o != n and o["sect"] == n["sect"] and W.rng.randf() < 0.4:
								W.R(o, n)["f"] = int(W.R(o, n)["f"]) - 5
					out = W.pv("失窃告", ["管事的听完，把{n}叫去训了半日。灵石没追回来，{n}看她的眼神却变了。", "这一状告下去，{n}在同门面前丢尽了脸。"]).format({"n": nm})
					W.chron(p, "%s偷了她的灵石，她去告了一状。" % nm)
					W.chron(n, "偷东西被%s告到了门里。" % W.pn())
		"示好":
			var like := String(ctx.get("like", "灵茶"))
			match oid:
				"yes":
					W.fav(n, 10, "%s收下了我的心意" % W.pn(), 8)
					W.R(p, n)["f"] = int(W.R(p, n)["f"]) + 4
					out = W.pv("示好收", ["她收下了那包{l}。{n}像是松了口气，又像是不知道接下来该说什么。", "她接过{l}，道了谢。{n}低头笑了一下，耳根有点红。", "她说：“下回一起去。”{n}愣了愣，用力点了点头。"]).format({"n": nm, "l": like})
					W.chron(p, "收下了%s送的%s。" % [nm, like])
					W.chron(n, "%s收下了我送的%s。" % [W.pn(), like])
					var rn: Dictionary = W.R(n, p)
					if int(rn["f"]) > 45 and int(rn.get("n", 0)) >= 3 and n["sex"] != p["sex"] and W.partner(n) == null and W.partner(p) == null and not n.has("dz"):
						var queued := false
						for it in W.w["queue"]:
							if String(it[1]) == "表白" and int(it[2].get("B", -1)) == int(n["id"]):
								queued = true
						if not queued:
							W.schedule(W.rng.randi_range(5, 10), "表白", {"B": int(n["id"])})
				"polite":
					W.fav(n, 3)
					out = W.pv("示好礼", ["她以礼相待，话说得周全。{n}听懂了，也没再多说。", "她请{n}喝了碗茶，说了些路上的事，不远不近。"]).format({"n": nm})
				_:
					var k2 := "辱" if px(n, "傲") > 0.6 else "拒"
					mem(W, n, p, "%s把话说明白了" % W.pn(), -10 if k2 == "辱" else -3, k2, aid)
					drift(n, "痴", -0.03)
					if n.has("dr") and String(n["dr"]["k"]) == "求偶":
						n["rt"] = 1
					out = (W.pv("示好拒傲", ["{n}脸色白了白：“是我自作多情。”转身就走。"]) if k2 == "辱" else W.pv("示好拒", ["{n}点点头：“我知道了。”走出几步，又回头说了声保重。", "{n}沉默了一会儿：“说开了也好。”"])).format({"n": nm})
					W.chron(p, "婉拒了%s的心意。" % nm)
		"馈赠":
			var g: Array = ctx.get("g", GOODS[0])
			match oid:
				"take", "back", "thank":
					if W.g != null:
						W.g.add_item(String(g[0]), int(g[1]))
					W.fav(n, 4 + (6 if oid == "back" else 0), "%s回了礼" % W.pn() if oid == "back" else "", 6 if oid == "back" else 0)
					if oid == "back":
						W._ling(-3)
					out = W.pv("馈赠收", ["她收下了{g}。", "{g}收进了行囊。"]).format({"g": g[2]}) + ("她回了一包自家晒的灵茶。" if oid == "back" else "") + "\n（%s ×%d）" % [W.g.NAMES.get(String(g[0]), "") if W.g != null else "", int(g[1])]
					W.chron(p, "%s送来%s。" % [nm, g[2]])
				_:
					if px(n, "傲") > 0.55:
						mem(W, n, p, "%s退了我的礼" % W.pn(), -8, "辱", aid)
					else:
						W.fav(n, -2)
					out = "她把东西原样退了回去。%s" % ("听说%s把它扔进了河里。" % nm if px(n, "傲") > 0.55 else "%s回了一句：“也好。”" % nm)
		"结伴":
			if oid == "go":
				W.fav(n, 8, "与%s同行过" % W.pn(), 5)
				var fv := flav(n)
				var wu := 2
				if fv == "贪" and px(n, "侠") < 0.4 and W.rng.randf() < 0.5:
					out = "路上捡到一株%s，%s先揣进了自己怀里：“说好的，我七。”她只分到一片叶子。" % ["青芝", nm]
					wu = 1
				elif fv == "侠" or fv == "善":
					out = W.pv("结伴侠", ["过一道窄桥时，{n}走在外侧。夜里{n}守了上半夜，没叫醒她。", "路上碰见一只受伤的灵狐，{n}蹲下来包扎了半天，她也跟着等。"]).format({"n": nm})
					wu = 3
				elif fv == "奇":
					out = W.pv("结伴奇", ["那块石碑上的字果然没人认得。{n}拓了一份，硬塞给她一半，说回去慢慢猜。", "泉眼夜里真的会亮。两个人看到后半夜，谁也没说话。"]).format({"n": nm})
					wu = 3
				else:
					out = W.pv("结伴平", ["结伴走了一程，说了些各自的来处。分别时{n}说，下回还走这条路。", "一路上{n}话不多，到了岔口才说：“这一程走得舒坦。”"]).format({"n": nm})
				W._wu(wu)
				out += "\n（感悟 +%d）" % wu
				W.chron(p, "与%s结伴走了一程。" % nm)
				W.chron(n, "与%s结伴走了一程。" % W.pn())
			else:
				out = W.pv("结伴别", ["她谢过{n}，独自走了。", "她笑着摇头。{n}也不勉强，拱拱手，先走了。"]).format({"n": nm})
		"交易":
			var g2: Array = ctx.get("g", GOODS[0])
			var price := int(ctx.get("price", 8))
			var fake: bool = ctx.get("fake", false)
			match oid:
				"buy", "haggle":
					if oid == "haggle":
						if px(n, "贪") < 0.5 or px(n, "善") > 0.5:
							price = maxi(2, price - 3)
							out = "%s笑了笑，让了 3 块。" % nm
						elif px(n, "傲") > 0.55:
							price += 2
							out = "%s脸一沉：“看不上就别看。”反倒涨了 2 块。" % nm
							mem(W, n, p, "%s跟我讨价还价" % W.pn(), -3, "辱", aid)
						else:
							out = "%s磨了半天，只肯让 1 块。" % nm
							price -= 1
					price = mini(price, W.lingshi())
					W._ling(-price)
					_add_ls(n, price)
					if fake:
						W.R(p, n)["g"] = int(W.R(p, n)["g"]) + 15
						out += W.pv("交易假", ["回去细看，{g}是染过色的萝卜须。她把东西扔进了灶膛。", "到家一验，{g}早就失了灵气，是拿药水泡过的。"]).format({"g": g2[2]}) + "（−%d 灵石）" % price
						W.chron(p, "从%s手里买了假货。" % nm)
						W.chron(n, "把假货卖给了%s。" % W.pn())
					else:
						if W.g != null:
							W.g.add_item(String(g2[0]), int(g2[1]))
						W.fav(n, 2)
						out += "她买下了%s。（−%d 灵石）" % [g2[2], price]
						W.chron(p, "从%s手里买了%s。" % [nm, g2[2]])
				"credit":
					if px(n, "慎") > 0.6 and not W.known(n):
						out = "%s摇头：“生人不赊。”" % nm
					else:
						if W.g != null and not fake:
							W.g.add_item(String(g2[0]), int(g2[1]))
						W.R(n, p)["owe"] = int(W._rel(n, p).get("owe", 0)) + price
						mem(W, n, p, "%s赊了我%d块灵石" % [W.pn(), price], -2, "欠", aid)
						out = "%s想了想，让她先拿走了%s：“%d块，记着。”" % [nm, g2[2], price]
						W.chron(p, "赊了%s %d 块灵石的账。" % [nm, price])
				_:
					out = W.pv("交易不", ["她摇了摇头，走开了。", "她看了看，没要。{n}也不在意，又去招呼别人。"]).format({"n": nm})
		"讨债":
			var owe := int(ctx.get("owe", 0))
			match oid:
				"pay":
					W._ling(-owe)
					_add_ls(n, owe)
					W.R(n, p)["owe"] = 0
					_settle(n, 1, ["欠"])
					W.fav(n, 4)
					out = "她如数还上。%s数也没数就收了：“你这人，靠得住。”" % nm
					W.chron(p, "还清了欠%s的账。" % nm)
				"later":
					if px(n, "善") > 0.45 or px(n, "贪") < 0.4:
						out = "%s摆摆手：“那就下回。”" % nm
					else:
						W.R(n, p)["owe"] = owe + 2
						out = "%s冷着脸：“再宽限，就是%d块了。”" % [nm, owe + 2]
				_:
					W.R(n, p)["owe"] = 0
					mem(W, n, p, "%s赖我的账" % W.pn(), -20, "负", aid)
					W.R(n, p)["g"] = int(W.R(n, p)["g"]) + 20
					out = "她不认。%s盯着她看了一会儿：“好。我记下了。”" % nm
					W.chron(p, "没认%s的那笔账。" % nm)
		"求援":
			var v: Dictionary = W.C(roles["V"])
			var h: Dictionary = W.C(roles.get("H", 0))
			var vn: String = v["name"]
			match oid:
				"pill", "ls":
					if oid == "pill":
						W._use("pill_quzhang" if W._has("pill_quzhang") else "pill_juqi")
					else:
						W._ling(-8)
					v["inj"] = maxi(0, int(v["inj"]) - 15)
					mem(W, n, p, "%s肯为%s出手" % [W.pn(), vn], 18, "助", aid)
					mem(W, v, p, "%s救过我" % W.pn(), 14, "救", aid)
					out = W.pv("求援给", ["{n}接过去，手在抖：“这份情我记下了。”转身就跑了。", "{n}没说谢，只深深看了她一眼，走了。半月后，听说{v}能下地了。"]).format({"n": nm, "v": vn})
					W.chron(p, "托%s把药带给%s。" % [nm, vn])
				"go":
					if h.is_empty() or W._roll(pl, float(h["lv"]), 5, 4):
						mem(W, n, p, "%s陪我去护%s" % [W.pn(), vn], 22, "助", aid)
						mem(W, v, p, "%s救过我" % W.pn(), 20, "救", aid)
						if not h.is_empty():
							mem(W, h, p, "%s坏了我的事" % W.pn(), -15, "怨", aid)
							W.R(h, p)["g"] = int(W.R(h, p)["g"]) + 15
							h["inj"] = maxi(int(h["inj"]), 8)
						out = (W.pv("求援去胜", ["两人赶到时，{h}正要动手。她和{n}一左一右挡在{v}身前，{h}掂量了一下，退了。", "那一夜没睡。{h}终究没能靠近{v}一步。"]) if not h.is_empty() else W.pv("求援去", ["她陪{n}守了{v}三天三夜。第四日清早，{v}睁开了眼。"])).format({"n": nm, "v": vn, "h": h.get("name", "")})
						W._wu(2)
						out += "\n（感悟 +2）"
						W.chron(p, "随%s去护%s。" % [nm, vn])
					else:
						W._inj(3)
						v["inj"] = maxi(int(v["inj"]), 15)
						mem(W, n, p, "%s陪我去护%s" % [W.pn(), vn], 14, "助", aid)
						out = "%s比想的还强。她挨了一掌，%s也没能护住。\n（受伤：闭关炼化减半 3 日）" % [h["name"], vn]
						W.chron(p, "随%s去护%s，负伤。" % [nm, vn])
				_:
					mem(W, n, p, "求%s的时候，她推了" % W.pn(), -8, "拒", aid)
					out = W.pv("求援拒", ["{n}点点头，什么也没说，走得很快。", "“……也是，与你何干。”{n}走了。"]).format({"n": nm})
		"求药":
			match oid:
				"herb":
					W._use("herb_xugucao")
					n["inj"] = 0
					mem(W, n, p, "我伤重时%s给过续骨草" % W.pn(), 16, "救", aid)
					W.fav(n, 8)
					out = W.pv("求药草", ["{n}嚼碎了敷上，疼得直吸气，第三日就能提剑了。", "续骨草熬成一碗黑汤。{n}一口喝干，皱着眉道了声谢。"]).format({"n": nm})
				"look":
					n["inj"] = maxi(0, int(n["inj"]) - 6)
					mem(W, n, p, "%s替我看过伤" % W.pn(), 8, "助", aid)
					W.fav(n, 4)
					out = "她替%s清了伤口，写了张方子，又嘱咐了三件忌口的事。%s听得很认真。" % [nm, tb]
				"sell":
					W._use("herb_qingzhi")
					var got = W._ling(6)
					n["inj"] = maxi(0, int(n["inj"]) - 8)
					_add_ls(n, -6)
					mem(W, n, p, "从%s那里买过药" % W.pn(), 4, "交", aid)
					out = "%s数了 %d 块灵石放在桌上，接过青芝，没多说什么。" % [nm, got]
				_:
					if px(n, "傲") > 0.55 or px(n, "仇") > 0.55:
						mem(W, n, p, "伤重时去求%s，%s说没有" % [W.pn(), "她"], -5, "拒", aid)
					out = W.pv("求药拒", ["{n}点点头，扶着墙走了。", "“……打扰了。”{n}没再看她。"]).format({"n": nm})
			W.chron(n, "带伤去青庐求药。" if not on_road(W) else "带伤路上遇见%s，求了药。" % W.pn())
		"赔罪":
			match oid:
				"forgive":
					W.R(p, n)["g"] = 0
					mem(W, n, p, "%s原谅了我" % W.pn(), 14, "恩", aid)
					W.fav(n, 8)
					drift(n, "善", 0.02)
					out = W.pv("赔罪恕", ["{n}直起身，眼圈有点红。两人坐着喝完了一壶茶，谁也没再提那件事。", "她把{n}扶起来。{n}走的时候，脚步轻了许多。"]).format({"n": nm})
				"take":
					var got2 = W._ling(W.rng.randi_range(6, 12))
					W.R(p, n)["g"] = maxi(0, int(W.R(p, n)["g"]) - 20)
					mem(W, n, p, "去向%s赔过罪" % W.pn(), 4, "了", aid)
					out = "她收下了 %d 块灵石。%s松了口气：“那就……两清了。”" % [got2, nm]
				_:
					mem(W, n, p, "去赔罪，%s不受" % W.pn(), -5, "拒", aid)
					if px(n, "傲") > 0.5:
						drift(n, "仇", 0.02)
					out = W.pv("赔罪拒", ["{n}站了一会儿，把东西收回去，走了。", "“我明白了。”{n}说完，再没回头。"]).format({"n": nm})
			n["rt"] = 1
			W.chron(p, "%s登门赔罪。" % nm)
			W.chron(n, "向%s赔了不是。" % W.pn())
		"托付":
			n["tf"] = 1
			match oid:
				"take":
					var got3 = W._ling(maxi(8, _ls(n) / 2))
					_add_ls(n, -got3)
					W._wu(2)
					mem(W, n, p, "把身后事托给了%s" % W.pn(), 12, "托", aid)
					W.fav(n, 6)
					out = "木匣里是 %d 块灵石，一卷写满批注的手札。%s看着她收好，才放心似的闭了闭眼。\n（感悟 +2）" % [got3, nm]
				"deliver":
					W._wu(3)
					mem(W, n, p, "%s答应替我把东西送回%s" % [W.pn(), n["sect"]], 16, "托", aid)
					W.fav(n, 10)
					out = "%s把匣子交给她，说了地方和名字。临走时，又塞给她半页心得。\n（感悟 +3）" % nm
				_:
					W.fav(n, 8, "%s劝我别想身后事" % W.pn(), 8)
					out = W.pv("托付劝", ["{n}笑了：“好，不说。”可那只木匣还是留在了桌上。", "{n}摇摇头，没再坚持，只说：“记得常去看看我。”"]).format({"n": nm})
			W.chron(p, "%s把身后事托给了她。" % nm)
			W.chron(n, "把身后事托给了%s。" % W.pn())
		"问道":
			match oid:
				"long":
					W._wu(3)
					n["xp"] = qz(float(n["xp"]) + 2.0, 10000.0)
					if px(n, "傲") > 0.7 and W.rng.randf() < 0.4:
						mem(W, n, p, "论道时被%s驳得说不出话" % W.pn(), -6, "辱", aid)
						out = "天亮时，%s还在争最后一处。末了一甩袖子：“我回去再想想。”\n（感悟 +3）" % nm
					else:
						mem(W, n, p, "与%s论道到天明" % W.pn(), 8, "论", aid)
						W.fav(n, 6)
						out = W.pv("问道长", ["灯芯剪了三回。{n}走时说，这一夜抵得上半年苦修。", "两人从灵气说到人心，又从人心说回剑。天亮了，谁都没觉得困。"]).format({"n": nm}) + "\n（感悟 +3）"
				"listen":
					W._wu(2)
					W.fav(n, 3)
					out = "她多半在听。%s说得兴起，临走时有点不好意思：“尽是我在说。”\n（感悟 +2）" % nm
				_:
					out = "%s愣了一下，说改日再来。" % nm
			W.chron(n, "与%s论道。" % W.pn())
		"示警":
			var h2: Dictionary = W.C(roles["H"])
			match oid:
				"ready":
					W._flag_add("ag_warn:%d" % int(h2["id"]))
					W.fav(n, 4)
					W.R(p, n)["f"] = int(W.R(p, n)["f"]) + 6
					out = "她谢过%s。那几日出门，剑都没离手。" % nm
				"mediate":
					W.R(h2, p)["g"] = maxi(0, int(W.R(h2, p)["g"]) - 15)
					if W.rng.randf() < 0.3 + 0.5 * px(h2, "善") - 0.4 * px(h2, "仇"):
						_settle(h2, 1, [])
						out = "%s去传了话。过了几日，%s托%s带回一句：“那件事，就当没有过。”" % [nm, h2["name"], nm]
						W.chron(p, "托%s说和，与%s的旧怨解了。" % [nm, h2["name"]])
					else:
						out = "%s去了一趟，回来只摇头：“%s不肯。”" % [nm, h2["name"]]
				_:
					out = "她笑了笑，说知道了。%s看着她，像是还想说什么。" % nm
		"求教":
			match oid:
				"teach":
					mem(W, n, p, "%s教过我" % W.pn(), 14, "教", aid)
					n["xp"] = qz(float(n["xp"]) + 4.0, 10000.0)
					W._wu(2)
					out = W.pv("求教细", ["讲到日落，{n}的册子又多了五页。她自己也把几处想通了。", "她把当年怎么熬过来的说了，连走过的岔路也说了。{n}听得很认真。"]).format({"n": nm}) + "\n（教学相长：感悟 +2）"
					if px(n, "傲") > 0.55:
						drift(n, "傲", -0.02)
					W.chron(p, "指点%s修行，讲了一下午。" % nm)
					W.chron(n, "向%s请教，受益良多。" % W.pn())
				"brief":
					mem(W, n, p, "%s指点过我两句" % W.pn(), 6, "教", aid)
					out = "她指点了两句。%s若有所思地走了。" % nm
				_:
					if px(n, "傲") > 0.5:
						mem(W, n, p, "向%s请教，被打发了" % W.pn(), -6, "辱", aid)
					out = "她推说自己也不懂。%s“哦”了一声，走了。" % nm
		"还情":
			_settle(n, 1, ["救", "恩", "助", "赠", "教", "庇"])
			for m in n["mem"]:
				if int(m[1]) == 1 and m.size() > 4 and String(m[4]) == "了" and float(m[3]) > 0:
					m[4] = "还"
			match oid:
				"take":
					var got = W._ling(W.rng.randi_range(6, 12))
					W.fav(n, 4)
					out = "%s留下一只布包。打开来，是 %d 块灵石，还有一包%s。" % [nm, got, W._ch(n["likes"])]
				"tea":
					W.fav(n, 12, "%s留我喝了碗茶" % W.pn(), 6)
					out = W.pv("还情茶", ["茶续了三回。{n}说起那日的事，她只笑说记不清了。", "两人对着灶火坐了半日。{n}走时，回头看了她一眼。"]).format({"n": nm}) + W._swap_ks(n)
				_:
					W.R(p, n)["ally"] = 1
					W.fav(n, 6)
					out = "%s点头：“有事传讯给我。”说完把一枚传讯符放在她手里。" % nm
			W.chron(p, "%s来还当年的人情。" % nm)
			W.chron(n, "去还了%s的人情。" % W.pn())
		"挑战":
			match oid:
				"fight":
					if W._roll(pl, float(n["lv"]), 5, 4):
						drift(n, "傲", -0.03)
						W._wu(3)
						if px(n, "傲") > 0.6 and px(n, "仇") > 0.45:
							mem(W, n, p, "当众输给%s" % W.pn(), -12, "辱", aid)
							out = "她胜了半招。%s收剑，脸色很难看：“下回。”\n（感悟 +3）" % nm
						else:
							mem(W, n, p, "%s的剑确实快" % W.pn(), 8, "服", aid)
							W.fav(n, 6)
							out = "她胜了半招。%s愣了愣，大笑起来：“痛快！”\n（感悟 +3）" % nm
						W.chron(p, "与%s切磋，胜了半招。" % nm)
						W.chron(n, "与%s切磋，输了半招。" % W.pn())
					else:
						W._inj(1)
						W._wu(2)
						drift(n, "傲", 0.02)
						mem(W, n, p, "胜过%s" % W.pn(), 2, "胜", aid)
						out = "她输了半招，手腕震得发麻。%s收剑：“还行。”\n（感悟 +2，受伤：闭关炼化减半 1 日）" % nm
						W.chron(p, "与%s切磋，输了半招。" % nm)
				"yield":
					W.fav(n, 3)
					out = "她拱手认输。%s哼了一声，像是赢了又像是没赢，走了。" % nm
				_:
					if px(n, "傲") > 0.6:
						mem(W, n, p, "%s不肯应战" % W.pn(), -4, "辱", aid)
					out = "她说改日。%s盯了她一会儿：“我记着。”" % nm
		"流言":
			match oid:
				"face":
					if px(n, "慎") > 0.55 or px(n, "善") > 0.5:
						_settle(n, 1, [])
						out = "她找到%s，只问了一句：“是你说的？”%s的脸一下子红了，第二日，坊市里就没人提这事了。" % [nm, nm]
						W.chron(p, "找%s当面说清了流言。" % nm)
					elif px(n, "傲") > 0.55:
						mem(W, n, p, "%s找上门来质问我" % W.pn(), -10, "辱", aid)
						out = "%s冷笑：“说了又如何？”话不投机，%s撂下一句改日见真章。" % [nm, nm]
						W.chron(p, "与%s为流言起了争执。" % nm)
					else:
						W.R(n, p)["g"] = int(W.R(n, p)["g"]) + 8
						out = "%s矢口否认，说是旁人编排。她没再多问。" % nm
				"clear":
					if W.lingshi() >= 5:
						W._ling(-5)
					for c in W.acquaintances().slice(0, 4):
						if c["alive"]:
							W.R(c, p)["f"] = int(W.R(c, p)["f"]) + 2
					out = W.pv("流言清", ["她把事情说清楚了。几位熟人点头，说本来也不信。", "她把来龙去脉摊开讲了。有人当场骂传话的人嘴碎。"])
					W.chron(p, "澄清了%s放出的流言。" % nm)
				_:
					for c in W._sample(W.acquaintances(), 2):
						if c["alive"] and c != n:
							W.R(c, p)["f"] = int(W.R(c, p)["f"]) - 3
					out = W.pv("流言由它", ["她没理会。有人信了，有人没信，日子照过。", "她只当没听见。倒是有两位熟人，见了她，话少了些。"])
		"叛门":
			var sect := String(W.w.get("ag_oldsect:%d" % int(n["id"]), "师门"))
			match oid:
				"hide":
					mem(W, n, p, "落难时%s收留了我" % W.pn(), 26, "庇", aid)
					for o in W.npcs():
						if o["sect"] == sect and W.rng.randf() < 0.4:
							mem(W, o, p, "%s窝藏了叛徒%s" % [W.pn(), nm], -10, "庇", aid)
							W.R(o, p)["g"] = int(W.R(o, p)["g"]) + 10
					out = W.pv("叛门留", ["{n}在柴房住了五日。第六日清早，柴房空了，灶上留着一碗温着的粥。", "她把{n}藏进后屋。{s}的人来问过一回，她说没见过。"]).format({"n": nm, "s": sect})
					W.chron(p, "收留了出走的%s几日。" % nm)
					W.chron(n, "出走后在%s那里躲了几日。" % W.pn())
				"road":
					W.fav(n, 10, "%s给我指过一条路" % W.pn(), 10)
					out = "她指了条采药人走的小路，又塞了两块干粮。%s接过去，深深一揖。" % nm
				_:
					mem(W, n, p, "%s把我交给了%s" % [W.pn(), sect], -40, "负", aid)
					W.R(n, p)["g"] = int(W.R(n, p)["g"]) + 40
					W._ling(8)
					n["inj"] = maxi(int(n["inj"]), 20)
					out = "%s的人把%s带走了，给她留了 8 块灵石的谢礼。%s回头看她的那一眼，她很久都没忘。" % [sect, nm, nm]
					W.chron(p, "把出走的%s交给了%s。" % [nm, sect])
					W.chron(n, "被%s出卖，押回%s。" % [W.pn(), sect])
		"劝和":
			var h3: Dictionary = W.C(roles["H"])
			match oid:
				"yes":
					W.R(h3, p)["g"] = maxi(0, int(W.R(h3, p)["g"]) - 35)
					_settle(h3, 1, [])
					mem(W, h3, p, "%s肯%s" % [W.pn(), String(ctx.get("cond", "让一步"))], 6, "解", aid)
					W.fav(n, 6)
					out = "她应了。事情办完，%s托%s带来一句话：“往后见面，还是朋友。”" % [h3["name"], nm]
					W.chron(p, "经%s说和，与%s冰释前嫌。" % [nm, h3["name"]])
				"no":
					W.R(h3, p)["g"] = int(W.R(h3, p)["g"]) + 5
					out = "她摇头。%s叹了口气：“那我也没法子了。”" % nm
				_:
					if px(h3, "善") > 0.5:
						W.R(h3, p)["g"] = maxi(0, int(W.R(h3, p)["g"]) - 10)
						out = "她把当初%s的不是也一一说了。%s传话回去，%s那边沉默了好几日。" % [h3["name"], nm, h3["name"]]
					else:
						W.R(h3, p)["g"] = int(W.R(h3, p)["g"]) + 10
						out = "话传回去，%s反倒更恼了。" % h3["name"]
		"夺宝":
			var tr := String(ctx.get("tr", "一株灵药"))
			match oid:
				"grab":
					if W._roll(pl, float(n["lv"]), 5, 4):
						W._wu(4)
						W._ling(4)
						mem(W, n, p, "%s夺了我看中的灵物" % W.pn(), -14, "夺", aid)
						W.R(n, p)["g"] = int(W.R(n, p)["g"]) + 14
						out = "她抢先一步把%s收进了玉匣。%s停在原地，脸色很难看。\n（感悟 +4，灵石 +4）" % [tr, nm]
						W.chron(p, "在%s与%s争%s，争到了。" % [at, nm, tr])
						W.chron(n, "在%s与%s争宝，落了空。" % [at, W.pn()])
					else:
						W._inj(2)
						mem(W, n, p, "与%s争过宝" % W.pn(), -4, "夺", aid)
						out = "%s比她快。她扑了个空，还挨了一记。\n（受伤：闭关炼化减半 2 日）" % nm
						W.chron(p, "在%s与%s争%s，没争过。" % [at, nm, tr])
				"share":
					if px(n, "贪") > 0.65 and px(n, "侠") < 0.35 and W.rng.randf() < 0.5:
						W.R(p, n)["g"] = int(W.R(p, n)["g"]) + 15
						out = "%s满口答应，等她转身，连根带土都卷走了。" % nm
						W.chron(p, "与%s说好平分%s，被对方独吞。" % [nm, tr])
					else:
						W._wu(2)
						W.fav(n, 8, "与%s分过一株灵药" % W.pn(), 6)
						out = "两人各取一半。%s说：“下回再遇上，还这么分。”\n（感悟 +2）" % nm
						W.chron(p, "与%s平分了%s。" % [nm, tr])
				_:
					W.fav(n, 10, "%s把%s让给了我" % [W.pn(), tr], 10)
					if px(n, "侠") > 0.5:
						W._wu(2)
						out = "她退开一步。%s取了%s，却硬分给她三片叶子：“不能白受你的。”\n（感悟 +2）" % [nm, tr]
					else:
						out = "她退开一步。%s取了%s，朝她拱了拱手。" % [nm, tr]
		"邀游":
			match oid:
				"go":
					if W.rng.randf() < 0.45 + 0.05 * pl:
						if px(n, "贪") > 0.65 and px(n, "侠") < 0.3 and W.rng.randf() < 0.5:
							W.R(p, n)["g"] = int(W.R(p, n)["g"]) + 20
							W._wu(2)
							out = "洞府里真有东西。她还在破最后一层禁制，%s已经卷了玉匣先走了。\n（感悟 +2）" % nm
							W.chron(p, "与%s同探洞府，被对方独吞了宝物。" % nm)
						else:
							W._wu(5)
							W._ling(6)
							W.fav(n, 10, "与%s一同探过洞府" % W.pn(), 8)
							out = "洞府里有半卷残经，几块灵石。%s把残经推给她：“你破的禁制。”\n（感悟 +5，灵石 +6）" % nm
							W.chron(p, "与%s同探洞府，有所得。" % nm)
					else:
						W._inj(2)
						W.fav(n, 4, "与%s一同涉险" % W.pn(), 4)
						out = "禁制比想的凶。两人狼狈退出来，%s的袖子烧了半截，还在笑。\n（受伤：闭关炼化减半 2 日）" % nm
						W.chron(p, "与%s探洞府，触了禁制。" % nm)
				"advice":
					W.fav(n, 3)
					out = "她指出图上两处画错的地方。%s道了谢，独自去了。" % nm
				_:
					out = "她摇头。%s收起图：“那我找别人。”" % nm
		"撞见":
			var v2: Dictionary = W.C(roles["V"])
			var verb := String(ctx.get("v", "寻仇"))
			var vn2: String = v2["name"]
			W.meet(v2)
			match oid:
				"stop":
					if W._roll(pl, float(n["lv"]), 5, 4):
						mem(W, v2, p, "%s在%s救了我" % [W.pn(), at], 22, "救", aid)
						mem(W, n, p, "%s坏了我的事" % W.pn(), -14, "怨", aid)
						W.R(n, p)["g"] = int(W.R(n, p)["g"]) + 14
						out = "她拔剑挡在%s身前。%s看了她一眼，啐了一口，走了。%s扶着树站起来：“……多谢。”" % [vn2, nm, vn2]
						W.chron(p, "在%s拦下了%s，救了%s。" % [at, nm, vn2])
						W.chron(v2, "%s在%s出手相救。" % [W.pn(), at])
					else:
						W._inj(2)
						mem(W, v2, p, "%s为我挡过一剑" % W.pn(), 16, "救", aid)
						mem(W, n, p, "%s多管闲事" % W.pn(), -10, "怨", aid)
						npc_resolve(W, n, verb, v2, aid)
						out = "她挡了一剑，没挡住第二剑。%s得手走了。%s记住了她。\n（受伤：闭关炼化减半 2 日）" % [nm, vn2]
				"shout":
					if W.rng.randf() < 0.5:
						mem(W, v2, p, "%s喊了一声，我才逃掉" % W.pn(), 10, "恩", aid)
						mem(W, n, p, "%s搅了我的事" % W.pn(), -6, "怨", aid)
						out = "她一声断喝。%s一愣，%s趁机脱了身。" % [nm, vn2]
					else:
						npc_resolve(W, n, verb, v2, aid)
						out = "她喝了一声。%s回头瞪了她一眼，手上没停。" % nm
				_:
					npc_resolve(W, n, verb, v2, aid)
					if W.rng.randf() < 0.4:
						mem(W, v2, p, "%s看见了，没管" % W.pn(), -8, "拒", aid)
					out = W.pv("撞见走", ["她转过身，绕路走了。身后的声音渐渐听不见了。", "她低下头，加快了脚步。"])
	if fresh and out != "":
		out += "\n（初识%s）" % nm
	return out

# ================================================================ 为什么（给人物卡）
## 眼下的念头 + 最重的几件记忆，写成两三句话
static func why_lines(W, c: Dictionary) -> Array:
	var out := []
	if c["player"] or not c["alive"]:
		return out
	pers(c)
	if c.has("dr"):
		var dr: Dictionary = c["dr"]
		var t: Dictionary = W.C(dr["t"]) if int(dr["t"]) > 0 else {}
		var who := ""
		if not t.is_empty():
			who = "你" if t["player"] else String(t["name"])
		var line := "眼下：%s" % DRIVE_WORD.get(String(dr["k"]), "")
		if who != "":
			line += "——%s" % who
		var wy := say(W, String(dr.get("why", "")))
		if wy != "":
			line += "。因为%s。" % wy
		else:
			line += "。"
		out.append(line)
	var ms := []
	for m in c["mem"]:
		var s := sal(W, c, m)
		if s > 0.05:
			ms.append([s, m])
	ms.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	for x in ms.slice(0, 3):
		var m: Array = x[1]
		out.append("记着：%s（第%d日）" % [say(W, String(m[2])), int(m[0])])
	var tops := []
	for a in AX:
		if px(c, a) >= 0.62:
			tops.append(a)
	if not tops.is_empty():
		out.append("性子：%s" % "、".join(tops.slice(0, 3)))
	return out
