extends SceneTree
## 人物自主（v0.9，scripts/agency.gd）测试：
## ① 每一种“找上门的事”在家、在路上都能出，每个选项都有结果文字，无占位符，正文 ≤170 字；
## ② 路上真的会碰上事；③ 8 局 × 100 日：动作种类、因果链、玩家读到的事都够多样；
## ④ 每个动作都追得到缘由：寻仇必有旧怨，截道/偷窃的人不是侠义心肠（除非对方先害过他）；
## ⑤ 旧档（没有性格/动机/动作日志的江湖）照常读、照常跑；存读档往返结果一致；⑥ 30 人 100 日的耗时。
const W = preload("res://scripts/world.gd")
const AG = preload("res://scripts/agency.gd")
var fails := 0
var lines: PackedStringArray = []

func ok(c: bool, msg: String) -> void:
	lines.append(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1

func _bad(t: String) -> bool:
	return t.strip_edges() == "" or t.contains("%s") or t.contains("%d") or t.contains("{") or t.contains("<null>") or t.contains("Nil")

func _roles_for(x, tid: String) -> Dictionary:
	var ns: Array = x.npcs()
	var a: Dictionary = ns[0]
	var b: Dictionary = ns[1]
	var h: Dictionary = ns[2]
	var r := {"B": int(a["id"])}
	match tid:
		"求援":
			r["V"] = int(b["id"]); r["H"] = int(h["id"])
		"示警", "劝和":
			r["H"] = int(h["id"])
		"撞见":
			r["V"] = int(b["id"])
	return r

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	# ① 全部事件 × 全部选项 × 家/路
	var bad := []
	var n_checked := 0
	for road in [false, true]:
		for tid in AG.TIDS:
			for vsd in 3:
				var probe = W.new()
				probe.create(300 + vsd, "苏青禾")
				for d in 12:
					probe.tick(true)
					probe.close()
				var opts_n: int = 0
				var first = W.new()
				first.attach(null, JSON.parse_string(JSON.stringify(probe.w)))
				first.w["here"] = "后山" if road else "青庐"
				var c0: Dictionary = first.npcs()[0]
				AG.pers(c0)
				c0["dr"] = {"k": "复仇", "t": 1, "u": 0.8, "d": 12, "why": "苏青禾抢了我在后山看中的灵物", "src": -1}
				first.R(c0, first.P())["owe"] = 6
				var ctx0 := {"aid": -1, "why": "苏青禾抢了我在后山看中的灵物", "v": ["寻仇", "截杀", "挑战", "偷窃"][vsd % 4]}
				first.fire(tid, _roles_for(first, tid), ctx0)
				var ev: Dictionary = first.pending()
				opts_n = ev["opts"].size()
				if _bad(String(ev["text"])) or String(ev["text"]).length() > 170:
					bad.append("%s%s 正文：%s" % [tid, "(路)" if road else "", String(ev["text"]).substr(0, 50)])
				for k in opts_n:
					var y = W.new()
					y.attach(null, JSON.parse_string(JSON.stringify(probe.w)))
					y.w["here"] = "后山" if road else "青庐"
					var c1: Dictionary = y.npcs()[0]
					AG.pers(c1)
					c1["dr"] = {"k": "复仇", "t": 1, "u": 0.8, "d": 12, "why": "苏青禾抢了我在后山看中的灵物", "src": -1}
					y.R(c1, y.P())["owe"] = 6
					y.fire(tid, _roles_for(y, tid), ctx0.duplicate())
					var e2: Dictionary = y.pending()
					var oid := String(e2["opts"][mini(k, e2["opts"].size() - 1)][0])
					var res: String = y.choose(oid)
					n_checked += 1
					if _bad(res):
						bad.append("%s%s/%s 结果：%s" % [tid, "(路)" if road else "", oid, res.substr(0, 50)])
					if String(e2["text"]).length() > 170:
						bad.append("%s 正文过长 %d" % [tid, String(e2["text"]).length()])
	ok(bad.is_empty(), "%d 种找上门的事 × 家/路 × 全部选项（%d 次结算）都有文字、无占位符、正文 ≤170 字（%s）" % [AG.TIDS.size(), n_checked, "；".join(bad.slice(0, 6))])
	# ② 路上会碰上事；③ 多样性；④ 缘由
	var verbs := {}
	var tids_home := {}
	var tids_road := {}
	var flav_pairs := {}
	var chains3 := 0
	var chain_sigs := {}
	var trace_bad := []
	var road_ev := 0
	var road_days := 0
	var player_texts := {}
	var player_n := 0
	var act_n := 0
	for sd in range(101, 109):
		var x = W.new()
		x.create(sd, "苏青禾")
		for d in 100:
			var home: bool = (d % 10) < 6
			x.tick(home)
			if not home:
				road_days += 1
			var ev: Dictionary = x.pending()
			if not ev.is_empty():
				if not home:
					road_ev += 1
				var tid := String(ev["tid"])
				if tid in AG.TIDS:
					(tids_home if home else tids_road)[tid] = 1
					var sp: Dictionary = x.C(ev["roles"]["B"])
					flav_pairs["%s:%s" % [tid, AG.flav(sp)]] = 1
					player_n += 1
					var sk := String(ev["text"])
					for c in x.w["C"].values():
						sk = sk.replace(String(c["name"]), "某")
					player_texts[sk] = 1
				x.auto_choose()
		var by := {}
		for a in x.w["agl"]:
			by[int(a[0])] = a
			verbs[String(a[3])] = int(verbs.get(String(a[3]), 0)) + 1
			act_n += 1
		for a in x.w["agl"]:
			var ch := [a]
			var cur = a
			while int(cur[6]) >= 0 and by.has(int(cur[6])) and ch.size() < 10:
				cur = by[int(cur[6])]
				ch.push_front(cur)
			if ch.size() >= 3:
				chains3 += 1
				var sig := []
				for e in ch:
					sig.append(String(e[3]))
				chain_sigs["-".join(sig)] = 1
			# ④ 缘由
			var actor: Dictionary = x.C(a[2])
			var tgt: Dictionary = x.C(a[4]) if int(a[4]) > 0 else {}
			if tgt.is_empty():
				continue
			var has_neg := false
			for m in actor["mem"]:
				if int(m[1]) == int(tgt["id"]) and float(m[3]) < 0:
					has_neg = true
			var g0: int = int(x._rel(actor, tgt)["g"])
			if String(a[5]) == "复仇" and not has_neg and g0 <= 0:
				trace_bad.append("%s 为报仇%s了无冤无仇的 %s" % [actor["name"], a[3], tgt["name"]])
			match String(a[3]):
				"寻仇":
					if not has_neg and g0 <= 0 and String(a[5]) != "护人":
						trace_bad.append("%s 寻仇 %s 无旧怨" % [actor["name"], tgt["name"]])
				"截杀", "偷窃":
					if AG.px(actor, "侠") > 0.66 and not has_neg and g0 < 25:
						trace_bad.append("%s（侠 %.2f）%s %s" % [actor["name"], AG.px(actor, "侠"), a[3], tgt["name"]])
				"示好":
					if tgt["sex"] == actor["sex"]:
						trace_bad.append("%s 示好同性 %s" % [actor["name"], tgt["name"]])
	lines.append("8 局 × 100 日：动作 %d 件、%d 种 %s" % [act_n, verbs.size(), JSON.stringify(verbs)])
	lines.append("她面前：家 %d 种 %s；路 %d 种 %s；（事件, 口吻）组合 %d；不同开场 %d / %d" % [tids_home.size(), JSON.stringify(tids_home.keys()), tids_road.size(), JSON.stringify(tids_road.keys()), flav_pairs.size(), player_texts.size(), player_n])
	lines.append("因果链（≥3 环）%d 条，不同的链形 %d 种，例：%s" % [chains3, chain_sigs.size(), JSON.stringify(chain_sigs.keys().slice(0, 6))])
	ok(road_ev > 0 and float(road_ev) / road_days >= 0.18, "路上会碰上事（%d 件 / %d 个路上日）" % [road_ev, road_days])
	ok(tids_road.size() >= 8, "路上碰上的“找上门的事”≥8 种（%d）" % tids_road.size())
	ok(verbs.size() >= 15, "人物自己做的事 ≥15 种（%d）" % verbs.size())
	ok(chains3 >= 20 and chain_sigs.size() >= 10, "因果链：≥3 环的链 ≥20 条、链形 ≥10 种（%d，%d）" % [chains3, chain_sigs.size()])
	var all_seen := {}
	for k in tids_home:
		all_seen[k] = 1
	for k in tids_road:
		all_seen[k] = 1
	ok(all_seen.size() >= 10 and flav_pairs.size() >= 35, "她遇到的“找上门的事”≥10 种（共 %d 种，其余要靠结仇/赊账等前情才会冒出来）、（事件, 口吻）组合 ≥35（%d，%d）" % [AG.TIDS.size(), all_seen.size(), flav_pairs.size()])
	ok(float(player_texts.size()) / maxf(1.0, player_n) >= 0.9, "找上门的事开场去重率 ≥0.9（%.3f）" % (float(player_texts.size()) / maxf(1.0, player_n)))
	ok(trace_bad.is_empty(), "每个动作都追得到缘由：寻仇/为报仇做的事都冲着有旧怨的人、侠义之人不劫不偷（除非对方先害过他）、示好不对同性（%s）" % "；".join(trace_bad.slice(0, 5)))
	# 心事页：说得出“眼下想什么、为什么”
	var xw = W.new()
	xw.create(5, "苏青禾")
	for d in 40:
		xw.tick((d % 10) < 6)
		xw.auto_choose()
	var why_ok := 0
	for c in xw.npcs():
		var wl: Array = AG.why_lines(xw, c)
		if not wl.is_empty() and String(wl[0]).begins_with("眼下："):
			why_ok += 1
	ok(why_ok == xw.npcs().size(), "每个活着的人都说得出眼下的念头（%d/%d）" % [why_ok, xw.npcs().size()])
	lines.append("例：%s" % "｜".join(AG.why_lines(xw, xw.npcs()[0])))
	# ⑤ 旧档：去掉所有 v0.9 新键，读入继续跑
	var old = W.new()
	old.create(9, "苏青禾")
	for d in 20:
		old.tick(true)
		old.auto_choose()
	var od: Dictionary = JSON.parse_string(JSON.stringify(old.w))
	for k in ["agq", "agl", "agn", "here", "last_who", "last_ev2"]:
		od.erase(k)
	for c in od["C"].values():
		for k in ["ps", "dr", "rt", "acd", "ls"]:
			c.erase(k)
		for m in c["mem"]:
			while m.size() > 4:
				m.pop_back()
	var o2 = W.new()
	o2.attach(null, od)
	for d in 30:
		o2.tick((d % 10) < 6)
		o2.auto_choose()
	ok(int(o2.w["day"]) == 50 and o2.w.has("agl") and o2.npcs()[0].has("ps"), "没有人物自主数据的旧档读入后照常跑 30 日，并补上性格/动机")
	# 存读档往返：中途存档再读，结果与不存档一致
	var a1 = W.new()
	a1.create(17, "苏青禾")
	var b1 = W.new()
	b1.create(17, "苏青禾")
	for d in 60:
		if d == 30:
			var j := JSON.stringify(b1.w)
			b1 = W.new()
			b1.attach(null, JSON.parse_string(j))
		a1.tick((d % 10) < 6)
		a1.auto_choose()
		b1.tick((d % 10) < 6)
		b1.auto_choose()
	var na := JSON.stringify(JSON.parse_string(JSON.stringify([a1.w["agl"], a1.P()["log"], a1.w["rng"]])))
	var nb := JSON.stringify(JSON.parse_string(JSON.stringify([b1.w["agl"], b1.P()["log"], b1.w["rng"]])))
	ok(na == nb, "存读档往返后，人物的行动与生平和不存档完全一致")
	# ⑥ 耗时：30 人 100 日
	var tp := Time.get_ticks_msec()
	var big = W.new()
	big.create(23, "苏青禾", null, 30)
	for d in 100:
		big.tick((d % 10) < 6)
		big.auto_choose()
	var ms := Time.get_ticks_msec() - tp
	ok(ms < 4000, "30 人 × 100 日 世界自转 %d ms（桌面无头；手机网页约慢 3–5 倍，每日 <%.0f ms）" % [ms, ms * 5.0 / 100.0])
	lines.append("用时 %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	lines.append("人物自主测试：%d 失败" % fails)
	for l in lines:
		print(l)
	var f := FileAccess.open("res://tests/agency_results.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
	quit(1 if fails > 0 else 0)
