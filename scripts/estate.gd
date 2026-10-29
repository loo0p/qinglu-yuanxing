extends RefCounted
## v0.16（筑基以后的营生）：青庐营建（灵圃、客舍：一次性造价 + 每年正月的用度）、灵圃出高阶灵草紫芝、
## 指点后辈 / 收徒（复用履历包里的“指点晚辈”“收徒的回响”两条 storylet，不另写一套）、坊市货郎以物易物。
## 只在开了江湖的档里生效；随机数用 Gear._rng_for（不动 gs.rng / W.rng）。存档：gs.s["econ"] 里的懒字段（旧档读进来按需补）
##   pu 灵圃阶（0 没有）· pu_prog 这一茬长了几个月 · ke 客舍（0/1）· est_y 交过用度的年 · est_off 用度欠着、灵圃停着
##   tu 徒弟的人物 id（-1 没有）· tu_d 收徒的月 · teach_d 上回指点后辈的月 · bar_y / bar_done 这一年和货郎换过哪几样
## 每件事都写进她的履历，带效果小字（灵石 / 紫芝 / 青芝 / 好感……）
const Gear = preload("res://scripts/gear.gd")

const ZIZHI := "herb_zizhi"
## 青庐营建：k 键、名字、造价、每年用度、要到的境界（plv：9 筑基、12 金丹）
const BUILD := {
	"pu1": {"n": "灵圃", "build": 80, "fee": 8, "plv": 9},
	"pu2": {"n": "二阶灵圃", "build": 260, "fee": 20, "plv": 12},
	"ke": {"n": "客舍", "build": 60, "fee": 6, "plv": 9},
}
const PU_MONTHS := [0, 9, 5]        # 灵圃几个月出一株紫芝（一阶九个月、二阶五个月）
const ZIZHI_PRICE := 18             # 坊市药铺收紫芝（按行情浮动）
const TU_FEE := 6                   # 徒弟的月例（每年正月和用度一起交）
const TU_QZ := 6                    # 徒弟帮着侍弄阳田：每年正月多收的青芝
const TEACH_CD := 12                # 指点后辈：一年一回
const TEACH_GAP := 3                # 指点的人比她低三个小境界以上
const TU_GAP := 4                   # 收的徒弟比她低四个小境界以上
## 货郎：一年换一回货单，挑三样；每样一年换一回
const BARTER := [
	{"give": {"crop_linggu": 20}, "get": {"pill_juqi": 2}},
	{"give": {"herb_qingzhi": 30}, "get": {ZIZHI: 1}},
	{"give": {ZIZHI: 1}, "get": {"pill_juqi": 4}},
	{"give": {"pill_quzhang": 4}, "get": {"herb_xugucao": 1}},
	{"give": {"herb_xugucao": 1}, "get": {"herb_qingzhi": 20}},
	{"give": {ZIZHI: 1}, "get": {"herb_qingzhi": 40}},
]
const BARTER_N := 3

static func on(gs) -> bool:
	return gs != null and gs.world != null

static func E(gs) -> Dictionary:
	if not gs.s.has("econ") or not (gs.s["econ"] is Dictionary):
		gs.s["econ"] = {}
	var e: Dictionary = gs.s["econ"]
	for k in ["pu", "pu_prog", "ke", "teach_n", "tu_n", "zz_got", "zz_sold", "est_paid", "est_built", "bar_n"]:
		e[k] = int(e.get(k, 0))
	for k in ["est_y", "tu", "tu_d", "teach_d", "bar_y"]:
		e[k] = int(e.get(k, -99 if k != "tu" else -1))
	e["est_off"] = bool(e.get("est_off", false))
	if not e.has("bar_done") or not (e["bar_done"] is Array):
		e["bar_done"] = []
	return e

static func _day(gs) -> int:
	return int(gs.s.get("day", 0))

static func _year(gs) -> int:
	return (maxi(_day(gs), 1) - 1) / 12

static func _month(gs) -> int:
	return (maxi(_day(gs), 1) - 1) % 12 + 1

static func _nm(gs, id: String) -> String:
	return String(gs.NAMES.get(id, id))

# ---------------------------------------------------------------- 营建
static func next_pu(gs) -> String:
	var p := int(E(gs)["pu"])
	return "pu%d" % (p + 1) if p < 2 else ""

static func can_build(gs, k: String) -> String:
	if not on(gs):
		return "没开江湖"
	if not BUILD.has(k):
		return "没有这一样"
	if not gs.at_home():
		return "要在青庐"
	var e := E(gs)
	if k == "ke" and int(e["ke"]) > 0:
		return "已经建了"
	if k.begins_with("pu") and k != next_pu(gs):
		return "已经辟了" if int(e["pu"]) >= int(k.substr(2)) else "先辟一阶灵圃"
	var b: Dictionary = BUILD[k]
	if int(gs.plv_now()) < int(b["plv"]):
		return "%s以后才建得起" % ("筑基" if int(b["plv"]) == 9 else "结丹")
	if int(gs.s["lingshi"]) < int(b["build"]):
		return "灵石不够（要 %d）" % int(b["build"])
	return ""

static func build(gs, k: String) -> bool:
	if can_build(gs, k) != "":
		return false
	var e := E(gs)
	var b: Dictionary = BUILD[k]
	gs.s["lingshi"] = int(gs.s["lingshi"]) - int(b["build"])
	e["est_built"] = int(e["est_built"]) + int(b["build"])
	if e["est_y"] != _year(gs):
		e["est_y"] = _year(gs)   # 建的这一年用度含在造价里
	var fx := {"灵石": -int(b["build"])}
	var t := ""
	if k == "ke":
		e["ke"] = 1
		t = "在青庐东边起了两间客舍，往后能留人住下。"
		fx["客舍"] = "落成"
	else:
		e["pu"] = int(k.substr(2))
		e["pu_prog"] = 0
		t = "把后院一角的灵脉引上来，辟成%s，种下紫芝。" % b["n"] if k == "pu1" else "在灵圃四角埋了聚灵石，灵圃升作二阶，紫芝长得快了。"
		fx["紫芝"] = "每%d个月一株" % PU_MONTHS[int(e["pu"])]
	gs._log("%s（−%d 灵石；每年正月用度 %d）" % [t, int(b["build"]), int(b["fee"])])
	gs.pchron(t, -1, fx)
	return true

## 每年正月要交的：营建用度 + 徒弟月例
static func fee(gs) -> int:
	var e := E(gs)
	var f := 0
	if int(e["pu"]) > 0:
		f += int(BUILD["pu%d" % int(e["pu"])]["fee"])
	if int(e["ke"]) > 0:
		f += int(BUILD["ke"]["fee"])
	if int(e["tu"]) >= 0:
		f += TU_FEE
	return f

static func _pay_fee(gs, e: Dictionary, f: int) -> void:
	gs.s["lingshi"] = int(gs.s["lingshi"]) - f
	e["est_y"] = _year(gs)
	e["est_paid"] = int(e["est_paid"]) + f

## 每月（Econ.monthly 里调）：灵圃长紫芝、正月交用度、徒弟帮手、徒弟不在了就除名
static func monthly(gs) -> void:
	if not on(gs):
		return
	var e := E(gs)
	if int(e["pu"]) <= 0 and int(e["ke"]) <= 0 and int(e["tu"]) < 0:
		return
	var f := fee(gs)
	if f > 0 and int(e["est_y"]) != _year(gs) and _month(gs) == 1:
		if int(gs.s["lingshi"]) >= f:
			_pay_fee(gs, e, f)
			if int(e["tu"]) >= 0:
				gs._store_add("herb_qingzhi", TU_QZ)
		elif not bool(e["est_off"]):
			e["est_off"] = true
			gs.notice("青庐今年的用度（%d 灵石）交不上，灵圃没人照看，停了。" % f)
			gs.pchron("青庐的用度交不上，灵圃荒了一季。", -1, {"灵圃": "停"})
	elif bool(e["est_off"]) and f > 0 and int(gs.s["lingshi"]) >= f:
		_pay_fee(gs, e, f)
		e["est_off"] = false
		gs.notice("补上了青庐的用度，灵圃又有人照看了。")
	if int(e["pu"]) > 0 and not bool(e["est_off"]):
		e["pu_prog"] = int(e["pu_prog"]) + 1
		if int(e["pu_prog"]) >= int(PU_MONTHS[int(e["pu"])]):
			e["pu_prog"] = 0
			gs._store_add(ZIZHI, 1)
			e["zz_got"] = int(e["zz_got"]) + 1
	if int(e["tu"]) >= 0:
		var c: Dictionary = gs.world.C(int(e["tu"]))
		if c.is_empty() or not bool(c.get("alive", false)):
			var nm := String(c.get("name", "徒弟"))
			e["tu"] = -1
			gs.notice("%s不在了。客舍空了一间。" % nm)

static func text(gs) -> String:
	var e := E(gs)
	var parts := []
	if int(e["pu"]) > 0:
		parts.append("%s（%d 个月一株紫芝，长了 %d 个月）" % [BUILD["pu%d" % int(e["pu"])]["n"], int(PU_MONTHS[int(e["pu"])]), int(e["pu_prog"])])
	if int(e["ke"]) > 0:
		parts.append("客舍")
	if parts.is_empty():
		return "青庐：还没有灵圃、客舍"
	var t := "青庐：" + "、".join(parts) + " · 每年正月用度 %d 灵石" % fee(gs)
	if bool(e["est_off"]):
		t += " · 欠着，灵圃停着"
	return t

# ---------------------------------------------------------------- 指点后辈 / 收徒（复用 qinglu_chron 的 jiang / echo_tu）
static func _maj_ctx(gs) -> int:
	var pl := int(gs.plv_now())
	return 0 if pl < 9 else (1 if pl < 12 else (2 if pl < 15 else 3))

static func cands(gs, gap: int) -> Array:
	if not on(gs):
		return []
	var W = gs.world
	var pl := int(W.plv())
	var e := E(gs)
	var out := []
	for c in W.npcs():
		if not W.known(c) or int(c["id"]) == int(e["tu"]):
			continue
		if int(c.get("sbg", 0)) > int(W.w["day"]):
			continue   # 闭关 / 在外奔波
		if int(c.get("lv", 0)) + gap > pl:
			continue
		out.append(c)
	out.sort_custom(func(a, b): return W.opinion(a, W.P()) > W.opinion(b, W.P()))
	return out.slice(0, 3)

static func can_teach(gs) -> String:
	if not on(gs):
		return "没开江湖"
	if int(gs.plv_now()) < 9:
		return "筑基以后"
	if not gs.at_home():
		return "要在青庐"
	var e := E(gs)
	if _day(gs) - int(e["teach_d"]) < TEACH_CD:
		return "一年一回（%d 个月后）" % (TEACH_CD - (_day(gs) - int(e["teach_d"])))
	if cands(gs, TEACH_GAP).is_empty():
		return "认得的人里没有比她低三个小境界的"
	return ""

## 指点一个后辈：在家耗一个月；文字、效果、一半机会埋下“指点晚辈的回响”都走履历包里的 jiang
static func teach(gs, cid: int) -> String:
	var why := can_teach(gs)
	if why != "":
		return why
	var W = gs.world
	var c: Dictionary = W.C(cid)
	var ok := false
	for x in cands(gs, TEACH_GAP):
		if int(x["id"]) == cid:
			ok = true
	if not ok:
		return "这个人眼下指点不了"
	var e := E(gs)
	var n0: int = W.P()["log"].size()
	W.fx_begin()
	var fired: bool = W.saga().eng.fire("jiang", {"A": W.P(), "B": c}, {"sec": 0, "road": 0, "maj": _maj_ctx(gs)})
	W.fx_end()
	if not fired:
		return "这回没讲成"
	e["teach_d"] = _day(gs)
	e["teach_n"] = int(e["teach_n"]) + 1
	if W.P()["log"].size() == n0:   # 履历满了被并掉之类：至少行记里有一条
		gs._log("指点了%s一回。" % c["name"])
	else:
		gs._log("指点了%s一回（在家一个月）。" % c["name"])
	gs.tick("home")
	return ""

static func can_take_tu(gs) -> String:
	if not on(gs):
		return "没开江湖"
	if int(gs.plv_now()) < 9:
		return "筑基以后"
	if not gs.at_home():
		return "要在青庐"
	var e := E(gs)
	if int(e["ke"]) <= 0:
		return "先建客舍"
	if int(e["tu"]) >= 0:
		return "已经有一个徒弟在客舍"
	if cands(gs, TU_GAP).is_empty():
		return "认得的人里没有比她低四个小境界的"
	return ""

## 收徒：师徒名分、点拨一年的修为、好感；安顿在客舍（每年月例 6 灵石，帮着侍弄阳田）。
## 十到二十五年后走履历包里的 echo_tu（回来谢师留物 / 帮翻药圃）——不另写回响
static func take_tu(gs, cid: int) -> String:
	var why := can_take_tu(gs)
	if why != "":
		return why
	var W = gs.world
	var c: Dictionary = W.C(cid)
	var ok := false
	for x in cands(gs, TU_GAP):
		if int(x["id"]) == cid:
			ok = true
	if not ok:
		return "这个人眼下收不了"
	var e := E(gs)
	var P: Dictionary = W.P()
	W.fx_begin()
	if not ("徒" in W.R(P, c)["t"]):
		W.R(P, c)["t"].append("徒")
	if not ("师" in W.R(c, P)["t"]):
		W.R(c, P)["t"].append("师")
	W.radd(c, P, 20)
	W.radd(P, c, 10)
	W.remember(c, P, "拜入%s门下" % W.pn(), 18, "教")
	c["xp"] = W.qz(float(c["xp"]) + 0.3 * 8.0 * pow(1.35, int(c["lv"])), 10000.0)
	W.fx(c, "修为", "精进")
	gs.pchron("收%s为徒，安顿在青庐客舍。" % c["name"], -1, {"收徒": "", "客舍月例": "每年%d灵石" % TU_FEE})
	W.chron(c, "拜入%s门下，住进了青庐的客舍。" % W.pn(), {"拜师": ""})
	W.fx_end()
	var r := Gear._rng_for(gs, 7700 + _day(gs))
	var sg = W.saga()
	sg.eng.schedule(r.randi_range(120, 300), "echo_tu", {"B": c}, {"y0": sg.cy(), "m0": sg.now_m()})
	e["tu"] = int(c["id"])
	e["tu_d"] = _day(gs)
	e["tu_n"] = int(e["tu_n"]) + 1
	gs._log("收%s为徒。" % c["name"])
	return ""

static func tu_text(gs) -> String:
	var e := E(gs)
	if int(e["tu"]) < 0:
		return "门下：没有徒弟"
	var c: Dictionary = gs.world.C(int(e["tu"]))
	if c.is_empty():
		return "门下：没有徒弟"
	return "门下：徒弟%s（%s，入门 %d 年）" % [c["name"], gs.world.realm(c), maxi(0, (_day(gs) - int(e["tu_d"])) / 12)]

# ---------------------------------------------------------------- 坊市：紫芝卖药铺、货郎以物易物
static func at_market(gs) -> bool:
	return String(gs.s.get("loc", "")) == "roam" and String(gs.s.get("roam", {}).get("pl", "")) == "坊市"

static func zizhi_price(gs) -> int:
	return maxi(1, roundi(ZIZHI_PRICE * Gear.price_idx(_day(gs))))

static func sell_zizhi(gs) -> bool:
	if not at_market(gs) or gs.store_n(ZIZHI) <= 0:
		return false
	var got := zizhi_price(gs)
	gs._store_add(ZIZHI, -1)
	gs.s["lingshi"] = int(gs.s["lingshi"]) + got
	E(gs)["zz_sold"] = int(E(gs)["zz_sold"]) + 1
	gs.roam_note("一株紫芝卖给了药铺（+%d 灵石）。" % got)
	return true

## 这一年货郎带的三样（按年份定，读档重进不变）
static func offers(gs) -> Array:
	if not on(gs) or int(gs.plv_now()) < 9:
		return []
	var r := Gear._rng_for(gs, 8100 + _year(gs))
	var idx := []
	for i in BARTER.size():
		idx.append(i)
	for i in range(idx.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t = idx[i]
		idx[i] = idx[j]
		idx[j] = t
	return idx.slice(0, BARTER_N)

static func _goods(gs, d: Dictionary) -> String:
	var out := []
	for id in d:
		out.append("%s×%d" % [_nm(gs, String(id)), int(d[id])])
	return "、".join(out)

static func offer_text(gs, i: int) -> String:
	var o: Dictionary = BARTER[i]
	return "%s 换 %s" % [_goods(gs, o["give"]), _goods(gs, o["get"])]

static func can_barter(gs, i: int) -> String:
	if not at_market(gs):
		return "要在坊市"
	if not (i in offers(gs)):
		return "货郎今年没带这样"
	var e := E(gs)
	if int(e["bar_y"]) == _year(gs) and i in e["bar_done"]:
		return "今年换过了"
	var o: Dictionary = BARTER[i]
	for id in o["give"]:
		if gs.store_n(String(id)) < int(o["give"][id]):
			return "仓里%s不够" % _nm(gs, String(id))
	return ""

static func barter(gs, i: int) -> String:
	var why := can_barter(gs, i)
	if why != "":
		return why
	var e := E(gs)
	if int(e["bar_y"]) != _year(gs):
		e["bar_y"] = _year(gs)
		e["bar_done"] = []
	e["bar_done"].append(i)
	e["bar_n"] = int(e["bar_n"]) + 1
	var o: Dictionary = BARTER[i]
	var fx := {}
	for id in o["give"]:
		gs._store_add(String(id), -int(o["give"][id]))
		fx[_nm(gs, String(id))] = -int(o["give"][id])
	for id in o["get"]:
		gs._store_add(String(id), int(o["get"][id]))
		fx[_nm(gs, String(id))] = int(fx.get(_nm(gs, String(id)), 0)) + int(o["get"][id])
	var t := "在坊市跟挑担的货郎以物易物：%s换了%s。" % [_goods(gs, o["give"]), _goods(gs, o["get"])]
	gs.roam_note(t)
	gs.pchron(t, -1, fx)
	return ""

static func summary(gs) -> Dictionary:
	if gs == null or not gs.s.has("econ"):
		return {}
	var e := E(gs)
	return {"pu": int(e["pu"]), "ke": int(e["ke"]), "zz_got": int(e["zz_got"]), "zz_sold": int(e["zz_sold"]), "est_built": int(e["est_built"]), "est_paid": int(e["est_paid"]), "teach_n": int(e["teach_n"]), "tu_n": int(e["tu_n"]), "bar_n": int(e["bar_n"])}
