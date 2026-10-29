extends RefCounted
## v0.15 经济（Gemini v7 P0·经济与破境、专项 1 / 2 / 4c）：来源—去处—兑换率
## 只在开了江湖的档里生效（规则测试 world == null 时一切恒等，v3.2 锁的数值不动）；不用 gs.rng / W.rng（不扰乱随机序列）。
## 存档：gs.s["econ"]（只增字段，旧档读进来按需补）
##   arr 聚灵阵阶（0 无）· arr_off 欠了年费停着 · fee_y 交过年费的年 · fudan 服丹闭关开着 · fd_left 这一轮丹力还剩几个月
##   sec_run 连着闭关几个月（蒙尘）· pill_y/pill_n 这一年卖给药铺几颗丹 · consign 托售的器物 · gave 送过她重宝的人
const Gear = preload("res://scripts/gear.gd")

## 聚灵阵（洞府升级）：布阵一次性灵石、每年正月的年费、闭关修为加成、要到的境界（plv）
const ARR := [
	{},
	{"n": "一阶聚灵阵", "build": 30, "fee": 6, "pct": 20, "plv": 0},
	{"n": "二阶聚灵阵", "build": 150, "fee": 24, "pct": 45, "plv": 9},
	{"n": "三阶聚灵阵", "build": 500, "fee": 80, "pct": 75, "plv": 12},
]
## 服丹闭关：每六个月服一轮聚气丹（炼气一颗、筑基两颗、金丹以上三颗），这六个月闭关修为 +50%
const FUDAN_PCT := 50
const FUDAN_SPAN := 6
## 蒙尘：连着闭关满三年，效率减半；满五年，坐不下去了，出关。出门走一个月洗掉一半，两个月洗净
const DUST_MONTHS := 36
const DUST_BREAK := 60
const DUST_WASH := 18
## 坊市药铺收丹（每年前六颗按价，再多减半）；灵谷十斗一批
const PILL_PRICE := {"pill_juqi": 8, "pill_quzhang": 3}
const PILL_FULL := 6
const LINGGU_BATCH := 10
const LINGGU_PRICE := 5
## 药铺冰鉴里的成品寒潭莲（炼气七层以后，一年一朵；没有水田的人的保底）
const ICE_LIAN_PRICE := 110
## 游历“搭把手”按境界给灵石（炼气 → 筑基 → 金丹 → 元婴 → 化神，约 1 : 4 : 15）
const LS_BY_MAJOR := [[3, 7], [12, 28], [45, 100], [160, 360], [600, 1300]]

static func on(gs) -> bool:
	return gs != null and gs.world != null

static func E(gs) -> Dictionary:
	if not gs.s.has("econ") or not (gs.s["econ"] is Dictionary):
		gs.s["econ"] = {}
	var e: Dictionary = gs.s["econ"]
	for k in ["arr", "fee_y", "fd_left", "sec_run", "pill_y", "pill_n"]:
		if not e.has(k):
			e[k] = -1 if k in ["fee_y", "pill_y"] else 0
		e[k] = int(e[k])
	for k in ["arr_off", "fudan"]:
		e[k] = bool(e.get(k, false))
	if not e.has("consign") or not (e["consign"] is Array):
		e["consign"] = []
	if not e.has("gave") or not (e["gave"] is Dictionary):
		e["gave"] = {}
	return e

static func _year(gs) -> int:
	return (maxi(int(gs.s.get("day", 0)), 1) - 1) / 12

static func _month(gs) -> int:
	return (maxi(int(gs.s.get("day", 0)), 1) - 1) % 12 + 1

# ---------------------------------------------------------------- 游历所得
static func roam_ls(mj: int, rich: int, rr: int) -> int:
	## rr：游历掷出的原始数（1..100），按境界映射到区间里——掷骰次数与以前一样，江湖随机序列不变
	var b: Array = LS_BY_MAJOR[clampi(mj, 0, 4)]
	var lo := int(b[0]) + rich * int(b[0]) / 2
	var hi := int(b[1]) + rich * int(b[1]) / 2
	return lo + (hi - lo) * clampi(rr - 1, 0, 99) / 99

# ---------------------------------------------------------------- 闭关加成 / 消耗 / 打断
static func arr_pct(gs) -> int:
	var e := E(gs)
	if int(e["arr"]) <= 0 or bool(e["arr_off"]):
		return 0
	return int(ARR[int(e["arr"])]["pct"])

static func dusty(gs) -> bool:
	return on(gs) and int(E(gs)["sec_run"]) >= DUST_MONTHS

static func fudan_need(gs) -> int:
	return 1 + mini(2, int(gs.major()))

## 闭关这个月的修为（已含器物加成的 v）：聚灵阵 + 服丹 → 蒙尘减半
static func biguan_xw(gs, v: int) -> int:
	if not on(gs):
		return v
	var e := E(gs)
	e["sec_run"] = int(e["sec_run"]) + 1
	var pct := arr_pct(gs)
	if bool(e["fudan"]):
		if int(e["fd_left"]) <= 0:
			var need := fudan_need(gs)
			if gs.store_n("pill_juqi") >= need:
				gs._store_add("pill_juqi", -need)
				e["fd_left"] = FUDAN_SPAN
				e["fd_used"] = int(e.get("fd_used", 0)) + need
			else:
				e["fudan"] = false
				gs.notice("仓里的聚气丹不够一轮（要 %d 颗），服丹闭关停了。" % need)
		if int(e["fd_left"]) > 0:
			e["fd_left"] = int(e["fd_left"]) - 1
			pct += FUDAN_PCT
	var out := v + v * pct / 100
	if int(e["sec_run"]) > DUST_MONTHS:
		out = out / 2
		if int(e["sec_run"]) == DUST_MONTHS + 1:
			gs.notice("连着闭关满三年，心境蒙尘：闭关所得减半。出门走两个月就好。")
			gs.pchron("闭关久了，心境蒙尘，修为进得慢了。")
	return out

## 每月（tick 末尾）：出门洗蒙尘、正月交聚灵阵年费、欠费的有钱了就续上、拍卖回响、托售过期
static func monthly(gs, mode: String) -> void:
	if not on(gs):
		return
	var e := E(gs)
	if mode == "road" or mode == "busy":
		e["sec_run"] = maxi(0, int(e["sec_run"]) - DUST_WASH)
	var a := int(e["arr"])
	if a > 0:
		var fee := int(ARR[a]["fee"])
		var y := _year(gs)
		if int(e["fee_y"]) != y and _month(gs) == 1:
			if int(gs.s["lingshi"]) >= fee:
				gs.s["lingshi"] = int(gs.s["lingshi"]) - fee
				e["fee_y"] = y
				e["fee_paid"] = int(e.get("fee_paid", 0)) + fee
			elif not bool(e["arr_off"]):
				e["arr_off"] = true
				if bool(gs.s.get("seclude", false)):
					e["arr_break"] = true
				gs.notice("%s的年费（%d 灵石）交不上，阵眼的灵石耗尽，阵法停了。" % [ARR[a]["n"], fee])
				gs.pchron("%s的灵石耗尽，阵法停了。" % ARR[a]["n"])
		elif bool(e["arr_off"]) and int(gs.s["lingshi"]) >= fee:
			gs.s["lingshi"] = int(gs.s["lingshi"]) - fee
			e["fee_y"] = y
			e["fee_paid"] = int(e.get("fee_paid", 0)) + fee
			e["arr_off"] = false
			gs.notice("补上了%s的年费，阵法又转起来了。" % ARR[a]["n"])
	_echo_due(gs)
	var day := int(gs.s.get("day", 0))
	var cs: Array = e["consign"]
	for i in range(cs.size() - 1, -1, -1):
		if int(cs[i].get("until", 0)) < day:
			cs.remove_at(i)

## 长闭关要不要被打断（每月查一次）：返回打断的缘由，"" 表示接着坐
static func seclude_break(gs) -> String:
	if not on(gs):
		return ""
	var e := E(gs)
	if bool(e.get("arr_break", false)):
		e.erase("arr_break")
		return "阵法停了，静室里的灵气一天天薄下去。她出关去想办法。"
	if int(e["sec_run"]) >= DUST_BREAK:
		e["sec_run"] = DUST_MONTHS   # 出关这一下算歇过；不出门走走，尘还在（再闭关仍是半成功效，两年后又坐不住）
		return "连着闭关五年，心头蒙了一层尘，坐不下去了。她出关走走。"
	return ""

# ---------------------------------------------------------------- 洞府：聚灵阵、服丹闭关
static func arr_next(gs) -> Dictionary:
	var a := int(E(gs)["arr"])
	return ARR[a + 1] if a + 1 < ARR.size() else {}

static func can_build(gs) -> String:
	if not gs.at_home():
		return "要在青庐"
	var nx := arr_next(gs)
	if nx.is_empty():
		return "已是最高一阶"
	if int(gs.plv_now()) < int(nx["plv"]):
		return "境界不够（%s才布得起）" % ("筑基" if int(nx["plv"]) == 9 else "结丹")
	if int(gs.s["lingshi"]) < int(nx["build"]):
		return "灵石不够（要 %d）" % int(nx["build"])
	return ""

static func build(gs) -> bool:
	if can_build(gs) != "":
		return false
	var e := E(gs)
	var nx := arr_next(gs)
	gs.s["lingshi"] = int(gs.s["lingshi"]) - int(nx["build"])
	e["arr"] = int(e["arr"]) + 1
	e["arr_off"] = false
	e["fee_y"] = _year(gs)   # 布阵这一年的年费含在里头
	e["built_ls"] = int(e.get("built_ls", 0)) + int(nx["build"])
	gs._log("在静室布下%s（−%d 灵石；闭关修为 +%d%%，每年正月交 %d 灵石）。" % [nx["n"], int(nx["build"]), int(nx["pct"]), int(nx["fee"])])
	gs.pchron("在青庐静室布下%s。" % nx["n"])
	return true

static func set_fudan(gs, on_: bool) -> void:
	var e := E(gs)
	e["fudan"] = on_

static func arr_text(gs) -> String:
	var e := E(gs)
	var a := int(e["arr"])
	if a <= 0:
		return "静室：没有聚灵阵"
	var t := "静室：%s（闭关 +%d%%，年费 %d）" % [ARR[a]["n"], int(ARR[a]["pct"]), int(ARR[a]["fee"])]
	if bool(e["arr_off"]):
		t += " · 欠费停着"
	return t

# ---------------------------------------------------------------- 坊市药铺：卖丹、卖灵谷、冰鉴寒潭莲
static func at_market(gs) -> bool:
	return String(gs.s.get("loc", "")) == "roam" and String(gs.s.get("roam", {}).get("pl", "")) == "坊市"

static func pill_price(gs, id: String) -> int:
	var e := E(gs)
	var n := int(e["pill_n"]) if int(e["pill_y"]) == _year(gs) else 0
	var base := float(PILL_PRICE.get(id, 0)) * Gear.price_idx(int(gs.s.get("day", 0)))
	return maxi(1, roundi(base if n < PILL_FULL else base / 2.0))

static func sell_pill(gs, id: String) -> bool:
	if not at_market(gs) or not PILL_PRICE.has(id) or gs.store_n(id) <= 0:
		return false
	var e := E(gs)
	var got := pill_price(gs, id)
	if int(e["pill_y"]) != _year(gs):
		e["pill_y"] = _year(gs)
		e["pill_n"] = 0
	e["pill_n"] = int(e["pill_n"]) + 1
	gs._store_add(id, -1)
	gs.s["lingshi"] = int(gs.s["lingshi"]) + got
	gs.roam_note("一颗%s卖给了药铺（+%d 灵石）。" % [gs.NAMES.get(id, id), got])
	return true

static func linggu_price(gs) -> int:
	return maxi(1, roundi(LINGGU_PRICE * Gear.price_idx(int(gs.s.get("day", 0)))))

static func sell_linggu(gs) -> bool:
	if not at_market(gs) or gs.store_n("crop_linggu") < LINGGU_BATCH:
		return false
	var got := linggu_price(gs)
	gs._store_add("crop_linggu", -LINGGU_BATCH)
	gs.s["lingshi"] = int(gs.s["lingshi"]) + got
	gs.roam_note("十斗灵谷批给了粮铺（+%d 灵石）。" % got)
	return true

static func ice_lian_available(gs) -> bool:
	return at_market(gs) and int(gs.plv_now()) >= 6 and int(gs.s["plv"]) < 9 \
		and gs.total_n("herb_hantanlian") == 0 and gs.total_n("pill_zhuji") == 0 and not gs.zhuji_in_progress() \
		and int(gs.s["flags"].get("ice_lian_year", -1)) != _year(gs)

static func buy_ice_lian(gs) -> bool:
	if not ice_lian_available(gs) or int(gs.s["lingshi"]) < ICE_LIAN_PRICE or not gs.s["pending_overflow"].is_empty():
		return false
	gs.s["lingshi"] = int(gs.s["lingshi"]) - ICE_LIAN_PRICE
	gs.s["flags"]["ice_lian_year"] = _year(gs)
	gs.add_item("herb_hantanlian", 1)
	gs.roam_note("药铺冰鉴里取出一朵寒潭莲，她倾了囊（−%d 灵石）。" % ICE_LIAN_PRICE)
	gs._log("在坊市药铺买下一朵冰鉴里的寒潭莲。")
	return true

# ---------------------------------------------------------------- NPC 送器物：看交情、看境界、一生一件重宝；不够格的改五折托售
static func _close(W, c: Dictionary) -> bool:
	var p: Dictionary = W.P()
	for t in W._rel(p, c)["t"] + W._rel(c, p)["t"]:
		if t in ["道侣", "师", "徒", "结义", "亲"]:
			return true
	return W.opinion(c, p) > 60.0

## 能白送吗：凡品随意；法器以上要亲近、她祭得动、不高过她一个大境界、这人没送过重宝
static func gift_ok(W, src: Dictionary, it: Dictionary) -> bool:
	var gs = W.g
	if gs == null:
		return true
	var gr := int(it.get("g", 0))
	if gr <= 0 or it.has("c"):
		return true
	if not _close(W, src):
		return false
	if not Gear.usable(gs, it) or gr > int(gs.major()) + 1:
		return false
	return not E(gs)["gave"].has(str(int(src["id"])))

static func note_gift(W, src: Dictionary, it: Dictionary) -> void:
	if W.g != null and int(it.get("g", 0)) > 0:
		E(W.g)["gave"][str(int(src["id"]))] = int(W.w["day"])

## 托售：NPC 用不上的器物，挂在坊市器物铺，五折卖给她（两年内）
static func consign(W, src: Dictionary, it: Dictionary) -> int:
	var gs = W.g
	var day := int(gs.s.get("day", 0))
	var lst: Array = Gear.npc_gear(W, src)
	var i := lst.find(it)
	if i >= 0:
		lst.remove_at(i)
	var x: Dictionary = it.duplicate(true)
	x["h"].append([int(W.w["day"]), "%s用不上，托坊市器物铺五折转给她。" % src["name"]])
	var pr := maxi(1, roundi(Gear.value(x, day) * 0.5))
	var e := E(gs)
	e["consign"].append({"it": x, "from": String(src["name"]), "fid": int(src["id"]), "price": pr, "until": day + 24})
	if e["consign"].size() > 4:
		e["consign"].pop_front()
	return pr

static func consign_list(gs) -> Array:
	if gs == null or not gs.s.has("econ"):
		return []
	return E(gs)["consign"]

static func consign_find(gs, u: int) -> Dictionary:
	for x in consign_list(gs):
		if int(x["it"]["u"]) == u:
			return x
	return {}

static func consign_buy(gs, u: int) -> String:
	var x := consign_find(gs, u)
	if x.is_empty():
		return "这件已经不在了。"
	if not at_market(gs):
		return "要到坊市器物铺取。"
	var pr := int(x["price"])
	if int(gs.s["lingshi"]) < pr:
		return "灵石不够（要 %d，手里 %d）。" % [pr, int(gs.s["lingshi"])]
	gs.s["lingshi"] = int(gs.s["lingshi"]) - pr
	E(gs)["consign"].erase(x)
	var it: Dictionary = x["it"]
	it["ext"] = true
	Gear.give_her(gs, it, "她以 %d 灵石从%s手里接下。" % [pr, x["from"]])
	gs._log("在坊市接下%s托售的%s（%d 灵石）。" % [x["from"], Gear.full_name(it), pr])
	gs.pchron("以 %d 灵石接下%s托售的一件%s。" % [pr, x["from"], it["n"]])
	return ""

# ---------------------------------------------------------------- 拍卖回响
static func echo_add(gs, due: int, text: String, ids: Array, drop_u: int = -1, cid: int = -1) -> void:
	var e := E(gs)
	if not e.has("echo"):
		e["echo"] = []
	e["echo"].append([due, text, ids, drop_u, cid])

static func _echo_due(gs) -> void:
	var e := E(gs)
	if not e.has("echo") or e["echo"].is_empty():
		return
	var W = gs.world
	var day := int(gs.s.get("day", 0))
	var keep := []
	for x in e["echo"]:
		if int(x[0]) > day:
			keep.append(x)
			continue
		var who := []
		for id in x[2]:
			var c: Dictionary = W.C(int(id))
			if not c.is_empty():
				who.append(c)
		if int(x[3]) >= 0 and int(x[4]) >= 0:
			var c2: Dictionary = W.C(int(x[4]))
			if c2.is_empty() or not c2["alive"]:
				continue
			var lst: Array = Gear.npc_gear(W, c2)
			var hit = null
			for it in lst:
				if int(it["u"]) == int(x[3]):
					hit = it
			if hit == null:
				continue
			lst.erase(hit)
			W.chron(c2, "出了坊市没多远，被人截了道，拍来的%s丢了。" % hit["n"])
		W.rumor(String(x[1]), who, "拍")
	e["echo"] = keep

static func summary(gs) -> Dictionary:
	if gs == null or not gs.s.has("econ"):
		return {}
	var e := E(gs)
	return {"arr": int(e["arr"]), "fee_paid": int(e.get("fee_paid", 0)), "built_ls": int(e.get("built_ls", 0)), "fd_used": int(e.get("fd_used", 0)), "consign": e["consign"].size(), "gave": e["gave"].size()}
