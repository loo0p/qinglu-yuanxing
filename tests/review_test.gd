extends SceneTree
## Gemini v5 评审落地（docs/design/review-gemini-v5.md）的回归与指标：16 局 × 110 日，在家闭关 / 出门游历交替，选项轮着点。
## ① 选角硬前提：赔罪、旧友死讯、借庐、旧债上门、白首……的人，真见过她、真有那段旧事
## ② 不再有“命定之人”：结道侣要慢慢处出来；道侣遇险只在道侣真受伤 / 被盯上时出
## ③ 侠义之人不害无仇之人的命；寻仇连败后先去变强，不再一头撞上去
## ④ 寻凶有进度：同一条文字不重复，按住剑之后修为没追上不再催
## ⑤ 风声只让地方“耳闻”，认得要靠修为 / 舆图 / 引路 / 请柬
## ⑥ 她露了财，也会有人冲她来
## ⑦ 事件标题不写“陌生人”
const GS = preload("res://scripts/game_state.gd")
const W = preload("res://scripts/world.gd")
const TV = preload("res://scripts/travel.gd")
const AG = preload("res://scripts/agency.gd")
var fails := 0
var lines: PackedStringArray = []
var strict := true

func ok(c: bool, msg: String) -> void:
	lines.append(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1

var bad := {}
var stat := {}
var ex := {}

func _bad(k: String, s: String) -> void:
	bad[k] = int(bad.get(k, 0)) + 1
	if not ex.has(k):
		ex[k] = s

func _st(k: String, d: float = 1.0) -> void:
	stat[k] = float(stat.get(k, 0.0)) + d

func _met_day(w, c: Dictionary) -> int:
	var r: Dictionary = w._rel(w.P(), c)
	if int(r.get("m", 0)) != 1:
		return -1
	if r.has("m0"):
		return int(r["m0"])
	for l in w.P()["log"]:
		if String(l[1]).begins_with("初识" + String(c["name"])):
			return int(l[0])
	return 0

## 事件刚弹出来时（fire 之后、选之前）核对选角
func _audit(g, ev: Dictionary, seen_txt: Dictionary) -> void:
	var w = g.world
	var tid := String(ev["tid"])
	var roles: Dictionary = ev["roles"]
	var ctx: Dictionary = ev["ctx"]
	var day := int(w.w["day"])
	var p: Dictionary = w.P()
	var n: Dictionary = w.C(roles["B"]) if roles.has("B") else {}
	_st("ev:" + tid)
	var title := String(ev.get("title", ""))
	match tid:
		"赔罪":
			var md := _met_day(w, n)
			if md < 0 or day - md < W.pace("apology_gap"):
				_bad("赔罪·生人或刚认识", "D%d %s 初识 D%d" % [day, n["name"], md])
		"旧友死讯":
			var r: Dictionary = w._rel(n, p)
			if _met_day(w, n) < 0 or int(r.get("n", 0)) < W.pace("friend_n") or int(w._rel(p, n)["f"]) < W.pace("friend_f"):
				_bad("旧友死讯·一面之缘", "D%d %s 同历 %d 好感 %d" % [day, n["name"], int(r.get("n", 0)), int(w._rel(p, n)["f"])])
		"借庐":
			var hurt := int(w._rel(p, n)["g"]) > 0
			for m in p["mem"]:
				if int(m[1]) == int(n["id"]) and float(m[3]) < 0:
					hurt = true
			if hurt:
				_st("借庐·旧怨")
				if not ctx.get("foe", false):
					_bad("借庐·仇人无前嫌", "D%d %s" % [day, n["name"]])
		"旧债上门":
			if float(n["age"]) < float(p["age"]) + 15.0 and int(w._rel(n, p).get("owe", 0)) <= 0:
				_bad("旧债上门·债主太年轻又没借过", "D%d %s %.0f 岁" % [day, n["name"], float(n["age"])])
			if _met_day(w, n) == day and int(w._rel(n, p).get("n", 0)) <= 1 and String(ev["text"]).contains("当年"):
				_bad("旧债上门·初识即旧账", "D%d %s" % [day, n["name"]])
		"讨债":
			if int(w._rel(n, p).get("owe", 0)) <= 0 and not roles.has("V"):
				_bad("讨债·她没欠", "D%d %s" % [day, n["name"]])
		"白首":
			if int(w._rel(n, p).get("n", 0)) < 2:
				_bad("白首·没见过第二面", "D%d %s" % [day, n["name"]])
		"表白":
			_st("表白")
		"道侣遇险":
			_st("道侣遇险")
			var hunted: bool = not AG.hunters_of(w, n).is_empty()
			if not (int(n["inj"]) > 0 or hunted or ctx.has("why")):
				_bad("道侣遇险·凭空排期", "D%d %s" % [day, n["name"]])
		"寻凶":
			var t := String(ev["text"])
			if seen_txt.has(t):
				_bad("寻凶·同一句又来", t)
			seen_txt[t] = 1
			var hs: Dictionary = w.w.get("hunt", {}).get(str(int(n["id"])), {})
			if int(hs.get("st", 0)) == 1 and w.plv() < int(n["lv"]):
				_bad("寻凶·没追上还催", "D%d" % day)
		"失窃", "截道", "夺宝":
			if not n.is_empty() and roles.has("B"):
				_st("冲她来:" + tid)
	if ev.get("anon", false):
		_bad("标题·陌生人", tid)

func play(seed: int, days: int) -> Dictionary:
	var g = GS.new()
	g.new_game("苏青禾", "aunt", seed, true)
	var w = g.world
	var k := seed
	var left := 3
	var seen_txt := {}
	var r := {"bond_day": -1, "bond_n": 0, "ken30": 0, "ken60": 0, "ken100": 0, "ken_lt5": 0, "ear100": 0}
	while int(g.s["day"]) < days and not g.s["ended"]:
		k += 1
		if g.s["loc"] == "trip":
			g.turn_back()
			continue
		var roaming: bool = g.s["loc"] == "roam"
		if g.s["loc"] != "home" and not roaming:
			break
		if not roaming:
			if left > 0:
				g.biguan_day()
				left -= 1
			else:
				var ps: Array = TV.places(w)
				g.start_roam(String(ps[(k * 7) % ps.size()]))
				left = 3 + k % 3
		else:
			if left > 0:
				g.roam_spot(k % 3)
				left -= 1
			else:
				g.roam_home()
				left = 2 + k % 3
		var guard := 0
		while not w.pending().is_empty() and guard < 6:
			guard += 1
			var ev: Dictionary = w.pending()
			_audit(g, ev, seen_txt)
			var opts: Array = ev["opts"]
			w.choose(String(opts[k % opts.size()][0]))
			w.close()
		if r["bond_day"] < 0:
			var pt = w.partner(w.P())
			if pt != null:
				r["bond_day"] = int(w.w["day"])
				r["bond_n"] = int(w._rel(pt, w.P()).get("n", 0))
		var d := int(g.s["day"])
		var ken: int = TV.places(w).size()
		if d <= 30:
			r["ken30"] = ken
		if d <= 60:
			r["ken60"] = ken
		r["ken100"] = ken
		if w.plv() < 4:
			r["ken_lt5"] = ken
	r["ear100"] = TV.locked(w).filter(func(pl): return TV.heard_n(w, pl) > 0).size()
	# 侠义之人害命：看每个死于他人之手的人
	for c in w.npcs(false):
		if c["alive"] or c["asc"]:
			continue
		var how := String(c["log"][-1][1]) if not c["log"].is_empty() else ""
		var kl = w._killer_of(how)
		if kl == null or kl["player"]:
			continue
		_st("他杀")
		if AG.px(kl, "侠") > 0.6 or w.tag(kl, "侠义"):
			var gr := int(w._rel(kl, c)["g"])
			var hate := gr >= 50
			for m in kl["mem"]:
				if int(m[1]) == int(c["id"]) and float(m[3]) <= -25:
					hate = true
			if not hate:
				_bad("侠义害无仇之人", "%s 杀 %s（%s）" % [kl["name"], c["name"], how])
	# 寻仇连败：同一对人在境界没变时连着寻仇落败的次数
	var runs := {}
	for c in w.npcs(false):
		var streak := 0
		var last := ""
		for l in c["log"]:
			var t := String(l[1])
			if t.contains("报仇不成") or t.contains("又一次败给") or (t.contains("回去寻") and t.contains("没讨到便宜")):
				streak += 1
				runs[c["name"]] = maxi(int(runs.get(c["name"], 0)), streak)
			elif t.contains("破境") or t.contains("闭门不出"):
				streak = 0
	var mx := 0
	for v in runs.values():
		mx = maxi(mx, int(v))
	r["fz_max"] = mx
	return r

func _init() -> void:
	strict = not OS.get_cmdline_user_args().has("--measure")
	var agg := {"ken30": 0.0, "ken60": 0.0, "ken100": 0.0, "ken_lt5": 0.0, "ear100": 0.0}
	var bonds := []
	var bond_ns := []
	var fz := 0
	var N := 16
	for sd in range(101, 101 + N):
		var r := play(sd, 110)
		for kk in agg:
			agg[kk] += float(r[kk]) / N
		if int(r["bond_day"]) >= 0:
			bonds.append(int(r["bond_day"]))
			bond_ns.append(int(r["bond_n"]))
		fz = maxi(fz, int(r["fz_max"]))
	var keys := stat.keys()
	keys.sort()
	var sl := []
	for kk in keys:
		sl.append("%s %d" % [kk, int(stat[kk])])
	lines.append("事件与统计（%d 局 × 110 日）：%s" % [N, "，".join(sl)])
	lines.append("穿帮计数：%s" % JSON.stringify(bad))
	for kk in ex:
		lines.append("  例：%s —— %s" % [kk, ex[kk]])
	lines.append("结道侣的局 %d/%d；结侣日 %s；结侣时同历 %s" % [bonds.size(), N, str(bonds), str(bond_ns)])
	lines.append("认得几处（均值）：D30 %.1f / D60 %.1f / D100 %.1f；炼气五层前 %.1f；第 110 日只耳闻 %.1f；寻仇最长连败 %d" % [agg["ken30"], agg["ken60"], agg["ken100"], agg["ken_lt5"], agg["ear100"], fz])
	if strict:
		ok(int(bad.get("赔罪·生人或刚认识", 0)) == 0, "赔罪的人都早就认识她（≥ 赔罪间隔）")
		ok(int(bad.get("旧友死讯·一面之缘", 0)) == 0, "旧友死讯只给真处过的人（同历 ≥ %d、好感 ≥ %d）" % [W.pace("friend_n"), W.pace("friend_f")])
		ok(int(bad.get("借庐·仇人无前嫌", 0)) == 0, "伤过她的人来借庐，走“我知道曾伤过你”的变体")
		ok(int(bad.get("旧债上门·债主太年轻又没借过", 0)) == 0 and int(bad.get("旧债上门·初识即旧账", 0)) == 0, "旧债上门的是长辈或真借过她东西的人")
		ok(int(bad.get("讨债·她没欠", 0)) == 0, "讨债只冲真欠了账的她来")
		ok(int(bad.get("白首·没见过第二面", 0)) == 0, "白首的“上回见时”是真见过两面以上")
		ok(int(bad.get("道侣遇险·凭空排期", 0)) == 0, "道侣遇险只在道侣真受伤 / 被盯上时出")
		ok(bonds.size() <= N / 4, "110 日里结成道侣的局不超过 1/4（缘分要慢慢处）：%d/%d" % [bonds.size(), N])
		var early := bonds.filter(func(d): return d < W.pace("romance_known"))
		ok(early.is_empty(), "没有在相识门槛之前结侣")
		ok(int(bad.get("侠义害无仇之人", 0)) == 0, "侠义之人不害无仇之人的命")
		ok(fz <= 2, "寻仇最长连败 ≤ 2 回（败了先去变强 / 找帮手）：%d" % fz)
		ok(int(bad.get("寻凶·同一句又来", 0)) == 0 and int(bad.get("寻凶·没追上还催", 0)) == 0, "寻凶不重复、按住剑后不空催")
		ok(agg["ken_lt5"] <= 5.0, "炼气五层前认得的地方 ≤ 5 处（均 %.1f）" % agg["ken_lt5"])
		ok(int(bad.get("标题·陌生人", 0)) == 0, "事件标题不写“陌生人”")
	print("\n".join(lines))
	print("review_test: %d fail(s)" % fails)
	quit(1 if fails > 0 else 0)
