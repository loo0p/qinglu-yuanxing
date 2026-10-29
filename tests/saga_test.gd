extends SceneTree
## v0.12 事件引擎接入测试：内容包 lint、全部玩家选项可渲染、多局长跑（错误 / 重复率 / 覆盖）、
## 存读确定性、旧档（无 se / pre）读入、tid 不与旧模板撞名、前尘履历合理。
const W = preload("res://scripts/world.gd")
const SG = preload("res://scripts/saga.gd")
const L = preload("res://addons/storylet_engine/se_lint.gd")
const SIM = preload("res://addons/storylet_engine/se_sim.gd")
const AG = preload("res://scripts/agency.gd")
const TV = preload("res://scripts/travel.gd")
const MD = preload("res://scripts/meddle.gd")
var fails := 0
var lines: PackedStringArray = []

func ok(c: bool, msg: String) -> void:
	lines.append(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1

func note(msg: String) -> void:
	lines.append("     " + msg)

func run(seed_v: int, days: int, roundtrip_at: int = -1, trace := false) -> Object:
	var x = W.new()
	x.create(seed_v, "苏青禾")
	if trace:
		x.saga().eng.trace = []
	for d in days:
		if d == roundtrip_at:
			var tr0 = x.saga().eng.trace
			var y = W.new()
			y.attach(null, JSON.parse_string(JSON.stringify(x.w)))
			x = y
			x.saga().eng.trace = tr0
		x.tick(true)
		x.auto_choose()
	return x

func bad_text(t: String) -> bool:
	return t.contains("{") or t.contains("}") or t.contains("#") or t.contains("<null>") or t.contains("Nil")

func _init() -> void:
	# 1. lint
	var packs := []
	for pid in SG.PACKS:
		packs.append(SG.pack(pid))
	var r: Dictionary = L.lint(packs)
	ok(r["errors"].is_empty(), "内容包 lint 无错误 %s" % [r["errors"].slice(0, 5)])
	ok(r["warnings"].is_empty(), "内容包 lint 无警告 %s" % [r["warnings"].slice(0, 5)])
	var st: Dictionary = r["stats"]
	note("内容：storylet %d，结果 %d，玩家选项 %d，语法符号 %d" % [st["storylets"], st["outcomes"], st["choices"], st["symbols"]])
	# 2. tid 不撞名
	var eng0 = run(3, 1).saga().eng
	var clash := []
	for sid in eng0.defs:
		if W.T.has(sid) or sid in AG.TIDS or sid in TV.TIDS or sid in MD.TIDS:
			clash.append(sid)
	ok(clash.is_empty(), "storylet id 不与旧模板 / 主动事件撞名 %s" % [clash])
	# 3. 每个玩家选项都能渲染（每条 offer × 每个选项 × 3 个不同的人）
	var x = run(5, 30)
	var offers := []
	for sid in x.saga().eng.defs:
		if x.saga().is_tid(sid):
			offers.append(sid)
	var badl := []
	var n_r := 0
	var ns: Array = x.npcs()
	for sid in offers:
		var s: Dictionary = x.saga().eng.defs[sid]
		for k in 3:
			var ch: Array = s.get("choices", [])
			for c in ch:
				var y = W.new()
				y.attach(null, JSON.parse_string(JSON.stringify(x.w)))
				var yn: Array = y.npcs()
				var roles := {"B": int(yn[k]["id"]), "C": int(yn[k + 3]["id"]), "D": int(yn[k + 6]["id"])}
				var ctx := {"k": "小满", "sect": String(yn[k]["sect"]), "rk": [int(yn[k]["id"]), int(yn[k + 3]["id"])], "res": ["treasure", "hurt", "none", "save"][k % 4]}
				var pr: Dictionary = y.present(sid, roles, ctx)
				if bad_text(String(pr["text"])) or String(pr["text"]).length() > 170 or pr["opts"].is_empty():
					badl.append([sid, pr["text"]])
				var res: String = y.resolve(sid, roles, ctx, String(c["id"]))
				n_r += 1
				if bad_text(res) or res.length() > 170:
					badl.append([sid, c["id"], res])
				if not y.saga().eng.errors.is_empty():
					badl.append([sid, c["id"], y.saga().eng.errors.slice(0, 2)])
	ok(badl.is_empty(), "玩家选项：%d 条 offer，%d 次结算，文字干净且 ≤170 字 %s" % [offers.size(), n_r, badl.slice(0, 4)])
	# 4. 多局长跑
	var tot_lines := 0
	var tot_npc_days := 0.0
	var all_seen := {}
	var errs := []
	var hit := {}
	var outs := {}
	var long_best := []
	for seed_v in [11, 12, 13]:
		var z = run(seed_v, 720, -1, true)
		var e = z.saga().eng
		errs += e.errors
		var rep: Dictionary = SIM.report(e, func(t):
			var u := String(t)
			for c in z.w["C"].values():
				u = u.replace(String(c["name"]), "某")
			return u)
		tot_lines += int(rep["lines"])
		for sid in e.defs:
			hit[sid] = int(hit.get(sid, 0)) + e.fired(sid)
		for k in e.outcome_counts():
			outs[k] = true
		var cnt := 0
		for c in z.w["C"].values():
			if not c.get("player", false):
				cnt += 1
		tot_npc_days += float(cnt) * 720.0
		note("seed %d × 720 日：引擎写了 %d 行，不同句式 %d（%.2f），重复率 %.2f，storylet 命中 %d/%d，结果命中 %d/%d" % [seed_v, rep["lines"], rep["distinct"], rep["distinct_ratio"], rep["repeat_rate"], rep["storylets_hit"], rep["storylets"], rep["outcomes_hit"], rep["outcomes"]])
		note("  最常见：%s" % [rep["top"].slice(0, 3)])
		ok(float(rep["distinct_ratio"]) > 0.5, "seed %d 全江湖句式去重率（人名抹掉）> 0.5（%.2f）" % [seed_v, rep["distinct_ratio"]])
		# 每个人的履历：相邻两行不重样
		var adj := 0
		var tl := 0
		var pd := 0.0
		var pn := 0
		for c in z.w["C"].values():
			var lg: Array = c["log"]
			for i in range(1, lg.size()):
				tl += 1
				if String(lg[i][1]) == String(lg[i - 1][1]):
					adj += 1
			if lg.size() >= 20 and not c.get("player", false):
				var u := {}
				for q in lg:
					u[String(q[1])] = 1
				pd += float(u.size()) / lg.size()
				pn += 1
			if not c.get("player", false) and lg.size() > long_best.size():
				long_best = [String(c["name"])] + lg.map(func(q): return String(q[1]))
		ok(pn > 0 and pd / pn > 0.9, "seed %d 每人履历里不同句子占比 > 0.9（%.3f，%d 人）" % [seed_v, pd / maxf(1, pn), pn])
		ok(tl > 0 and float(adj) / tl < 0.02, "seed %d 个人履历相邻重复 < 2%%（%d/%d）" % [seed_v, adj, tl])
		if seed_v == 11:
			note("  从未出现：%s" % [rep["never"].slice(0, 30)])
	ok(errs.is_empty(), "长跑无引擎运行期错误 %s" % [errs.slice(0, 5)])
	note("合计 %d 行 / %.0f 人·日 = 每人每月 %.2f 行" % [tot_lines, tot_npc_days, tot_lines / tot_npc_days * 30.0])
	var n_s := 0
	var miss := []
	for sid in eng0.defs:
		var tg := String(eng0.defs[sid].get("trigger", ""))
		if tg == "bio":
			continue
		# v0.15：她的月度小事（on:pmonth）和它们的回响链要有她的游戏状态才会触发，这里只跑江湖，不计；century_test 里查
		if tg == "on:pmonth" or String(sid).begins_with("echo_"):
			continue
		n_s += 1
		if int(hit.get(sid, 0)) == 0:
			miss.append(sid)
	ok(miss.size() <= n_s / 5, "三局里出现过的 storylet ≥ 80%%（缺 %s）" % [miss])
	note("履历最长的人（%d 行）：%s" % [long_best.size() - 1, " / ".join(long_best.slice(0, 16))])
	# 5. 存读确定性
	var a = run(21, 120)
	var b = run(21, 120, 60)
	var ja := JSON.stringify(JSON.parse_string(JSON.stringify(a.w)))
	var jb := JSON.stringify(JSON.parse_string(JSON.stringify(b.w)))
	ok(ja == jb and a.w.has("se"), "存档 JSON 往返后继续跑，与不存档完全一致（含引擎状态 w.se）")
	# 6. 旧档：去掉 se / pre 读入
	var o = run(31, 40)
	var d: Dictionary = JSON.parse_string(JSON.stringify(o.w))
	d.erase("se")
	for c in d["C"].values():
		c.erase("pre")
		c.erase("kids")
	var nrel := 0
	for c in d["C"].values():
		nrel += c["rel"].size()
	var o2 = W.new()
	o2.attach(null, d)
	var pre: Array = o2.pre_of(o2.npcs()[0])
	var nrel2 := 0
	for c in o2.w["C"].values():
		nrel2 += c["rel"].size()
	ok(pre.size() >= 3 and nrel2 == nrel, "旧档补写前尘：%d 条，不新建关系（%d→%d）" % [pre.size(), nrel, nrel2])
	for i in 40:
		o2.tick(true)
		o2.auto_choose()
	ok(o2.saga().eng.errors.is_empty() and o2.w.has("se"), "旧档继续跑 40 日无错误")
	# 7. 前尘：年岁有序、不超过当下年纪、句子干净
	var q = run(41, 1)
	var badp := []
	var lens := []
	for c in q.npcs():
		var pr: Array = c.get("pre", [])
		lens.append(pr.size())
		var last := -1
		for e in pr:
			if int(e[0]) < last or int(e[0]) > int(float(c["age"])) or bad_text(String(e[1])):
				badp.append([c["name"], c["age"], e])
			last = int(e[0])
	ok(badp.is_empty(), "前尘年岁有序、不超过年纪、文字干净 %s" % [badp.slice(0, 3)])
	lens.sort()
	ok(lens[0] >= 3, "每人前尘至少 3 条（最少 %d，最多 %d）" % [lens[0], lens[-1]])
	var c0: Dictionary = q.npcs()[0]
	note("前尘样例 %s（%s岁）：%s" % [c0["name"], int(float(c0["age"])), " / ".join(c0["pre"].map(func(e): return "%d岁 %s" % [int(e[0]), e[1]]))])
	for l in lines:
		print(l)
	print("saga_test: %s (%d fail)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
