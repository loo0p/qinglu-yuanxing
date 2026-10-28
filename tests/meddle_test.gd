extends SceneTree
## 插手（v0.10，scripts/meddle.gd）测试：
## ① 每一种“谋着的事” × 风声/插手 × 在家/路上 × 每个选项：都有结果文字、无占位符、正文 ≤170 字，
##    除“不插手”外都把她写进当事人的记忆，事情的状态跟着变；
## ② 12 局 × 100 日（随机插手）：谋事、走漏、风声在家/路上、各选项次数；插手与“不管”的反事实对照，结局确有不同；打印 2–3 条例子；
## ③ 少见的动作（讨债、劝和、叛门、示警、失窃）都出现；节奏仍是在家 ~0.5、路上 ~0.3 件/日、最长连着有事 ≤3.2 日；
## ④ 带插手的局存读档往返一致；没有 plots 键的旧档照常读、照常跑。
const W = preload("res://scripts/world.gd")
const AG = preload("res://scripts/agency.gd")
const MD = preload("res://scripts/meddle.gd")
var fails := 0
var lines: PackedStringArray = []

func ok(c: bool, msg: String) -> void:
	lines.append(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1

func _bad(t: String) -> bool:
	return t.strip_edges() == "" or t.contains("%s") or t.contains("%d") or t.contains("{") or t.contains("}") or t.contains("<null>") or t.contains("Nil")

func _copy(x):
	var y = W.new()
	y.attach(null, JSON.parse_string(JSON.stringify(x.w)))
	return y

func _pmem(x, c: Dictionary) -> int:
	var n := 0
	var pid := int(x.P()["id"])
	for m in c["mem"]:
		if int(m[1]) == pid:
			n += 1
	return n

## 在 x 里给 v 这件事找一对人并强行起念；返回 pid（-1 = 这局凑不出）
func _force(x, v: String, variant: int) -> int:
	var ns: Array = x.npcs()
	var a: Dictionary = {}
	var b: Dictionary = {}
	for c in ns:
		if v == "叛门" and String(c["sect"]) == "散修":
			continue
		a = c
		break
	if a.is_empty():
		return -1
	if v != "叛门":
		for c in ns:
			if c == a:
				continue
			if v == "示好" and c["sex"] == a["sex"]:
				continue
			b = c
			break
		if b.is_empty():
			return -1
	if v == "讨债":
		x.R(a, b)["owe"] = 6
	if variant == 1:
		# 起念的人是她的熟人：恶事会多出“去拦着”
		x.meet(a)
		x.R(a, x.P())["f"] = 40
	if variant == 2 and not b.is_empty():
		x.meet(b)
	for pt in MD.plots(x):
		if int(pt["a"]) == int(a["id"]):
			pt["p"] = 2
	var n0: int = int(x.w.get("pln", 0))
	if not MD.plan(x, a, v, b, -1, true):
		return -1
	x.w["agq"] = x.w["agq"].filter(func(it): return String(it[1]) != "风声")
	return n0

func _open(x, tid: String, pid: int, road: bool) -> Dictionary:
	x.w["here"] = "后山" if road else "青庐"
	x.close()
	if tid == "插手":
		MD.open(x, pid)
	else:
		var pt: Dictionary = MD.get_plot(x, pid)
		var inf: Dictionary = {}
		for c in x.npcs():
			if int(c["id"]) != int(pt["a"]) and int(c["id"]) != int(pt["b"]):
				inf = c
				break
		x.fire("风声", {"B": int(inf["id"]), "X": int(pt["a"]), "V": int(pt["b"])}, {"pid": pid, "aid": -1, "ov": 0 if road else 1})
	return x.pending()

## 一件事对 b（或 a）的结局：伤、亡、破财、换了门派、对 a 的好感
func _outcome(x, pt: Dictionary, b0: Dictionary) -> Dictionary:
	var a: Dictionary = x.C(pt["a"])
	var b: Dictionary = x.C(pt["b"]) if int(pt["b"]) > 0 else {}
	# r：事情自己到期了结时是 成/败/空；被她当场了结（护住、拿住、说和、抢先……）则没有 r
	var o := {"a伤": int(a["inj"]) > int(b0["ai"]), "a门": String(a["sect"]), "r": String(pt.get("r", "她了结"))}
	if not b.is_empty():
		o["b伤"] = int(b["inj"]) > int(b0["bi"]) or not b["alive"]
		o["b财"] = AG._ls(b) < int(b0["bl"])
		o["ab好"] = int(x._rel(b, a)["f"]) - int(b0["bf"]) >= 8
	return o

func _snap(x, pt: Dictionary) -> Dictionary:
	var a: Dictionary = x.C(pt["a"])
	var b: Dictionary = x.C(pt["b"]) if int(pt["b"]) > 0 else {}
	return {"ai": int(a["inj"]), "bi": int(b.get("inj", 0)), "bl": AG._ls(b) if not b.is_empty() else 0,
		"bf": int(x._rel(b, a)["f"]) if not b.is_empty() else 0}

## 反事实那边，当事人日志里与这件事有关的一句
func _cflog(x, pt: Dictionary, d: int) -> String:
	var a: Dictionary = x.C(pt["a"])
	var b: Dictionary = x.C(pt["b"]) if int(pt["b"]) > 0 else {}
	for c in [b, a]:
		if c.is_empty():
			continue
		var other: String = String(a["name"]) if c == b else String(b.get("name", a["sect"]))
		for e in c["log"]:
			if int(e[0]) >= d and String(e[1]).contains(other):
				return "%s：%s" % [c["name"], e[1]]
	return "（风平浪静）"

func _run_to(x, day: int) -> void:
	while int(x.w["day"]) < day:
		x.tick(true)
		x.auto_choose()

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	# ① 全部谋事 × 风声/插手 × 家/路 × 全部选项
	var bad := []
	var no_mem := []
	var no_state := []
	var n_checked := 0
	var opt_seen := {}
	for v in MD.PLOT_V:
		for variant in 3:
			var probe = W.new()
			probe.create(700 + variant, "苏青禾")
			for d in 12:
				probe.tick(true)
				probe.close()
			var pid := _force(probe, v, variant)
			if pid < 0:
				bad.append("%s 凑不出人" % v)
				continue
			for road in [false, true]:
				for tid in MD.TIDS:
					var e0: Dictionary = _open(_copy(probe), tid, pid, road)
					if e0.is_empty():
						bad.append("%s/%s 打不开" % [v, tid])
						continue
					if _bad(String(e0["text"])) or String(e0["text"]).length() > 170:
						bad.append("%s/%s 正文：%s（%d 字）" % [v, tid, String(e0["text"]).substr(0, 40), String(e0["text"]).length()])
					for o in e0["opts"]:
						if _bad(String(o[1])) or String(o[1]).length() > 22:
							bad.append("%s 选项：%s" % [v, o[1]])
						var y = _copy(probe)
						_open(y, tid, pid, road)
						var pt: Dictionary = MD.get_plot(y, pid)
						var a: Dictionary = y.C(pt["a"])
						var b: Dictionary = y.C(pt["b"]) if int(pt["b"]) > 0 else {}
						var m0: int = _pmem(y, a) + (_pmem(y, b) if not b.is_empty() else 0)
						var oid := String(o[0])
						opt_seen["%s:%s" % [v, oid]] = 1
						var res: String = y.choose(oid)
						n_checked += 1
						if _bad(res) or res.length() > 170:
							bad.append("%s/%s/%s 结果：%s" % [v, tid, oid, res.substr(0, 40)])
						var m1: int = _pmem(y, a) + (_pmem(y, b) if not b.is_empty() else 0)
						if oid != "ignore" and m1 <= m0:
							no_mem.append("%s/%s" % [v, oid])
						if oid == "ignore" and int(pt.get("ig", 0)) != 1:
							no_state.append("%s/ignore" % v)
						if oid != "ignore" and int(pt["p"]) == 0:
							no_state.append("%s/%s" % [v, oid])
						if MD.actable(y, pt):
							no_state.append("%s/%s 还能再插手" % [v, oid])
						# 到了日子照常了结、不出错
						y.close()
						_run_to(y, int(pt["due"]) + 1)
						if int(pt["p"]) != 2:
							no_state.append("%s/%s 到期未了结" % [v, oid])
	ok(bad.is_empty(), "%d 种谋事 × 风声/插手 × 家/路 × 全部选项（%d 次结算，%d 种（事, 选项））都有文字、无占位符、正文 ≤170 字（%s）" % [MD.PLOT_V.size(), n_checked, opt_seen.size(), "；".join(bad.slice(0, 6))])
	ok(no_mem.is_empty(), "每个插手选项都把她写进当事人的记忆（%s）" % "；".join(no_mem.slice(0, 6)))
	ok(no_state.is_empty(), "插手后事情状态跟着变：不能再插手、到日子了结；不管 = 放下（%s）" % "；".join(no_state.slice(0, 6)))
	ok(opt_seen.size() >= 30, "（事, 选项）组合 ≥30（%d）" % opt_seen.size())
	# ② ③ 12 局 × 100 日（v0.13 合并 v0.12.1 后 8 局只抽到 8 种选项：样本太少，加到 12 局；每个选项都能出的穷举在 ①），随机插手
	var n_plot := 0
	var n_leak := 0
	var fs_home := 0
	var fs_road := 0
	var opens := 0
	var by_opt := {}
	var changed := 0
	var compared := 0
	var examples := []
	var verbs := {}
	var p_tids := {}
	var leak_txt := {}
	var res_txt := {}
	var n_res := 0
	for sd in range(201, 213):
		var x = W.new()
		x.create(sd, "苏青禾")
		var pr := RandomNumberGenerator.new()
		pr.seed = sd * 7919
		var acts := []
		for d in 100:
			var home: bool = (d % 10) < 6
			x.tick(home)
			var ev: Dictionary = x.pending()
			var tid := ""
			if not ev.is_empty():
				tid = String(ev["tid"])
				p_tids[tid] = int(p_tids.get(tid, 0)) + 1
				if tid == "风声":
					if home:
						fs_home += 1
					else:
						fs_road += 1
			elif pr.randf() < 0.35:
				for it in x.recent_news(10):
					var pid: int = MD.news_pid(x, it)
					if pid >= 0 and MD.open(x, pid):
						opens += 1
						ev = x.pending()
						tid = "插手"
						break
			if tid in MD.TIDS and not ev.is_empty() and ev.get("stage", "") == "ask" and ev["ctx"].has("pid") and not ev["ctx"].has("stale"):
				var pid2 := int(ev["ctx"]["pid"])
				var pt: Dictionary = MD.get_plot(x, pid2)
				var o: Array = ev["opts"][pr.randi_range(0, ev["opts"].size() - 1)]
				var oid := String(o[0])
				by_opt[oid] = int(by_opt.get(oid, 0)) + 1
				var b0 := _snap(x, pt)
				var cf = _copy(x)
				var res: String = x.choose(oid)
				res_txt[res.substr(0, 14)] = 1
				n_res += 1
				x.close()
				if oid != "ignore":
					# 反事实：同一刻选“不管”，两边都走到事情了结之后再比
					cf.choose("ignore")
					cf.close()
					var ac = _copy(x)
					var due := int(pt["due"]) + 1
					_run_to(ac, due)
					_run_to(cf, due)
					var oa := _outcome(ac, MD.get_plot(ac, pid2), b0)
					var oc := _outcome(cf, MD.get_plot(cf, pid2), b0)
					compared += 1
					if JSON.stringify(oa) != JSON.stringify(oc):
						changed += 1
						acts.append({"d": int(x.w["day"]), "pid": pid2, "oid": oid, "label": String(o[1]), "res": res, "oa": oa, "oc": oc,
							"cfa": _cflog(cf, pt, int(x.w["day"]))})
			else:
				x.auto_choose()
			x.close()
		for pt in MD.plots(x):
			n_plot += 1
		n_leak += x.w["news"].filter(func(n): return String(n[3]) == "谋").size()
		for n in x.w["news"]:
			if String(n[3]) == "谋":
				var sk := String(n[1])
				for c in x.w["C"].values():
					sk = sk.replace(String(c["name"]), "某")
				leak_txt[sk] = 1
		for a in x.w["agl"]:
			verbs[String(a[3])] = int(verbs.get(String(a[3]), 0)) + 1
		# 例子：插手改了结局，之后当事人又因此对她做了什么
		for it in acts:
			if examples.size() >= 3:
				break
			var pt: Dictionary = MD.get_plot(x, it["pid"])
			if pt.is_empty():
				continue
			var a: Dictionary = x.C(pt["a"])
			var b: Dictionary = x.C(pt["b"]) if int(pt["b"]) > 0 else {}
			var later := []
			for g in x.w["agl"]:
				if int(g[1]) > int(it["d"]) and int(g[4]) == int(x.P()["id"]) and String(g[5]) in ["报恩", "复仇", "赎过", "护人"] and (int(g[2]) == int(a["id"]) or (not b.is_empty() and int(g[2]) == int(b["id"]))):
					later.append("第%d日 %s 对她「%s」（%s）" % [int(g[1]), x.C(g[2])["name"], g[3], g[5]])
			var mems := []
			for c in [a, b]:
				if c.is_empty():
					continue
				for m in c["mem"]:
					if int(m[1]) == int(x.P()["id"]) and int(m[0]) >= int(it["d"]) and m.size() > 5 and int(m[5]) == int(pt["aid"]):
						mems.append("%s记着：%s" % [c["name"], m[2]])
			if later.is_empty() and mems.is_empty():
				continue
			examples.append("【局%d 第%d日】%s → 她选「%s」：%s ‖ 若不管：%s ‖ 之后：%s ‖ %s" % [sd, it["d"], MD.leak(x, pt), it["label"], String(it["res"]).replace("\n", ""), it["cfa"], "；".join(later.slice(0, 2)) if not later.is_empty() else "（无）", "；".join(mems.slice(0, 2))])
	lines.append("12 局 × 100 日：谋事 %d 件、走漏成传闻 %d 条（不同说法 %d）、风声 在家 %d / 路上 %d、从传闻插手 %d 次；选项分布 %s" % [n_plot, n_leak, leak_txt.size(), fs_home, fs_road, opens, JSON.stringify(by_opt)])
	lines.append("插手 vs 不管（反事实）：比了 %d 次，结局不同 %d 次" % [compared, changed])
	lines.append("动作计数：讨债 %d、劝和 %d、叛门 %d、示警 %d、偷窃 %d；她面前：失窃 %d、讨债 %d、示警 %d、劝和 %d、叛门 %d" % [int(verbs.get("讨债", 0)), int(verbs.get("劝和", 0)), int(verbs.get("叛门", 0)), int(verbs.get("示警", 0)), int(verbs.get("偷窃", 0)), int(p_tids.get("失窃", 0)), int(p_tids.get("讨债", 0)), int(p_tids.get("示警", 0)), int(p_tids.get("劝和", 0)), int(p_tids.get("叛门", 0))])
	for e in examples:
		lines.append("例 " + e)
	ok(n_plot >= 60 and n_leak >= 30, "谋事 ≥60 件、走漏 ≥30 条（%d，%d）" % [n_plot, n_leak])
	ok(fs_home >= 3 and fs_road >= 2, "风声在家、在路上都会找上门（%d，%d）" % [fs_home, fs_road])
	ok(by_opt.size() >= 9, "随机插手用到的选项 ≥9 种（%d）" % by_opt.size())
	ok(compared >= 20 and float(changed) / compared >= 0.5, "插手比不管，至少一半的结局不同（事成/落空/被她了结、当事人伤没伤、破没破财、好感、门派）（%d / %d）" % [changed, compared])
	ok(examples.size() >= 2, "能举出插手改变结局、之后当事人记着她的例子（%d）" % examples.size())
	ok(float(leak_txt.size()) / maxf(1.0, n_leak) >= 0.55, "走漏的传闻说法去重率 ≥0.55（v0.13 月刻度：同一桩谋事在一年里走漏多回，说法略有重复）（%.2f）" % (float(leak_txt.size()) / maxf(1.0, n_leak)))
	var rare_ok := int(verbs.get("讨债", 0)) >= 1 and int(verbs.get("劝和", 0)) >= 1 and int(verbs.get("叛门", 0)) >= 1 and int(verbs.get("示警", 0)) >= 1 and int(p_tids.get("失窃", 0)) + int(verbs.get("偷窃", 0)) >= 1
	ok(rare_ok, "少见的动作都出现：讨债、劝和、叛门、示警、失窃/偷窃")
	# 节奏：与 world_test 同口径（16 局 × 50 日，选项按日轮换，不主动插手）
	var phd := 0.0
	var prd := 0.0
	var ph := 0.0
	var prr := 0.0
	var pst := 0.0
	for sd in range(500, 516):
		var x = W.new()
		x.create(sd, "苏青禾")
		var st := 0
		var smax := 0
		for d in 50:
			var home: bool = (d % 10) < 6
			x.tick(home)
			if home:
				phd += 1
			else:
				prd += 1
			var ev = x.pending()
			if ev.is_empty():
				st = 0
				continue
			if home:
				ph += 1
			else:
				prr += 1
			st += 1
			smax = maxi(smax, st)
			x.choose(String(ev["opts"][d % ev["opts"].size()][0]))
			x.close()
		pst += smax / 16.0
	lines.append("节奏：在家 %.2f 件/日，路上 %.2f 件/日，最长连续有事 %.1f 日" % [ph / phd, prr / prd, pst])
	ok(ph / phd >= 0.4 and ph / phd <= 0.6 and prr / prd >= 0.2 and prr / prd <= 0.42 and pst <= 3.2, "节奏不变：在家 0.4–0.6、路上 0.2–0.42 件/日、最长连着有事 ≤3.2 日")
	# ④ 存读档往返（中途有插手）
	var sigs := []
	for mode in 2:
		var x = W.new()
		x.create(77, "苏青禾")
		var pr := RandomNumberGenerator.new()
		pr.seed = 4242
		for d in 70:
			if mode == 1 and d == 33:
				var s := JSON.stringify(x.w)
				x = W.new()
				x.attach(null, JSON.parse_string(s))
			x.tick((d % 10) < 6)
			if x.pending().is_empty():
				for it in x.recent_news(10):
					var pid: int = MD.news_pid(x, it)
					if pid >= 0 and pr.randf() < 0.5 and MD.open(x, pid):
						break
			var ev: Dictionary = x.pending()
			if not ev.is_empty() and ev["stage"] == "ask":
				x.choose(String(ev["opts"][pr.randi_range(0, ev["opts"].size() - 1)][0]))
			x.close()
		# 读档后整数会变成浮点：先过一遍 JSON 再比
		sigs.append(JSON.stringify(JSON.parse_string(JSON.stringify([x.w["plots"], x.w["agl"], x.w["news"], x.P()["log"], x.w["day"]]))).md5_text())
	ok(sigs[0] == sigs[1], "带插手的局，第 33 日存读档后结果与不存档一致")
	var old = W.new()
	old.create(9, "苏青禾")
	for d in 15:
		old.tick(true)
		old.auto_choose()
	var od: Dictionary = JSON.parse_string(JSON.stringify(old.w))
	od.erase("plots")
	od.erase("pln")
	od.erase("edge")
	od["agq"] = od["agq"].filter(func(it): return String(it[1]) != "风声")
	var o2 = W.new()
	o2.attach(null, od)
	for d in 40:
		o2.tick((d % 10) < 6)
		o2.auto_choose()
	ok(int(o2.w["day"]) >= 55 and o2.w.has("plots"), "没有 plots 键的旧档照常读入、照常跑 40 日（第 %d 日，谋事 %d 件）" % [int(o2.w["day"]), o2.w.get("plots", []).size()])
	lines.append("用时 %.1f 秒" % ((Time.get_ticks_msec() - t0) / 1000.0))
	for l in lines:
		print(l)
	print("MEDDLE %s（%d 项失败）" % ["OK" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
