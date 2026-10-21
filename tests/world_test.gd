extends SceneTree
## 江湖（world.gd）指标测试：8 个种子 × 100 日，说书人每天都可出事件，选项随机点。
## 门槛（design-v4 §8）：最常见模板 < 20%，三连序列去重率 > 95%，生平句骨架去重率 > 65%；
## 并检查：存档 JSON 往返后继续跑，结果与不存档完全一致（确定性）。
const W = preload("res://scripts/world.gd")
var fails := 0
var lines: PackedStringArray = []

func ok(c: bool, msg: String) -> void:
	lines.append(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1

func run(seed_v: int, days: int, roundtrip_at: int = -1) -> Object:
	var x = W.new()
	x.create(seed_v, "苏青禾")
	for d in days:
		if d == roundtrip_at:
			var j := JSON.stringify(x.w)
			var y = W.new()
			y.attach(null, JSON.parse_string(j))
			x = y
		x.tick(true)
		x.auto_choose()
	return x

func metrics(x) -> Dictionary:
	var ev: Array = x.w["events"]
	var cnt := {}
	for e in ev:
		cnt[e] = int(cnt.get(e, 0)) + 1
	var top := 0
	for k in cnt:
		top = maxi(top, cnt[k])
	var tri := {}
	for i in ev.size() - 2:
		tri["%s|%s|%s" % [ev[i], ev[i + 1], ev[i + 2]]] = 1
	var sk := {}
	var lg: Array = x.P()["log"]
	for l in lg:
		var t: String = l[1]
		for c in x.w["C"].values():
			t = t.replace(c["name"], "某")
		sk[t] = 1
	return {"n": ev.size(), "tpl": cnt.size(), "top": float(top) / maxf(1, ev.size()), "tri": float(tri.size()) / maxf(1, ev.size() - 2),
		"skel": float(sk.size()) / maxf(1, lg.size()), "met": x.acquaintances().size(), "cnt": cnt}

## 把一段文字切成句子：去掉（…）数值提示，人名换“某”，数字换 N；句末引号跟着前一句
func _sents(x, t: String) -> Array:
	var re := RegEx.new()
	re.compile("（[^）]*）")
	t = re.sub(t, "", true)
	for c in x.w["C"].values():
		t = t.replace(String(c["name"]), "某")
	var rn := RegEx.new()
	rn.compile("[0-9]+")
	t = rn.sub(t, "N", true)
	var out := []
	var cur := ""
	for i in t.length():
		cur += t[i]
		var end := t[i] in ["。", "！", "？"] and not (i + 1 < t.length() and t[i + 1] in ["”", "」"])
		if t[i] in ["”", "」"] and i > 0 and t[i - 1] in ["。", "！", "？"]:
			end = true
		if end:
			if cur.strip_edges() != "":
				out.append(cur.strip_edges())
			cur = ""
	if cur.strip_edges() != "":
		out.append(cur.strip_edges())
	return out

func _init() -> void:
	var agg := {"top": 0.0, "tri": 0.0, "skel": 0.0, "n": 0.0, "tpl": 0.0, "met": 0.0}
	var all := {}
	for sd in range(7, 15):
		var m := metrics(run(sd, 100))
		lines.append("seed %d: 事件 %d 模板 %d 最常见 %.2f 三连 %.2f 骨架 %.2f 结识 %d" % [sd, m.n, m.tpl, m.top, m.tri, m.skel, m.met])
		for k in agg:
			agg[k] += float(m[k]) / 8.0
		for k in m.cnt:
			all[k] = int(all.get(k, 0)) + m.cnt[k]
	lines.append("均值：%s" % JSON.stringify(agg))
	lines.append("模板计数：%s" % JSON.stringify(all))
	ok(agg.top < 0.20, "最常见模板占比 < 20%%（%.3f）" % agg.top)
	ok(agg.tri > 0.95, "三连序列去重率 > 95%%（%.3f）" % agg.tri)
	ok(agg.skel > 0.65, "生平句骨架去重率 > 65%%（%.3f）" % agg.skel)
	ok(agg.n >= 25, "每 100 日至少 25 件玩家事件（%.1f）" % agg.n)
	var a = run(3, 80)
	var b = run(3, 80, 37)
	var ja := JSON.stringify(JSON.parse_string(JSON.stringify(a.w)))
	var jb := JSON.stringify(JSON.parse_string(JSON.stringify(b.w)))
	if ja != jb:
		for i in ja.length():
			if ja[i] != jb[i]:
				lines.append("差异：" + ja.substr(maxi(0, i - 80), 160) + " ||| " + jb.substr(maxi(0, i - 80), 160))
				break
	ok(ja == jb, "存档往返后继续跑，结果一致（确定性）")
	# 立绘：每个 NPC 的立绘选项可还原
	ok(a.portrait_opts(a.npcs()[0]).has("sex"), "NPC 立绘选项")
	var n0: Dictionary = a.npcs()[0]
	ok(int(n0.get("pv", 0)) == 7 and not a.portrait_opts(n0).has("exclude"), "新人物可抽 v0.7 立绘部件")
	var old_c := n0.duplicate(true); old_c.erase("pv")
	ok(a.portrait_opts(old_c).get("exclude", []).size() == 9, "旧存档人物不抽新部件（脸不变）")
	var r_old := Portrait5Lib.roll(123, a.portrait_opts(old_c))
	ok(not (r_old["hair"] in a.PV7_NEW) and not (r_old["robe"] in a.PV7_NEW), "旧人物立绘只用旧部件")
	# 文字重复度：玩家 100 日里读到的事件文字、结果、自己的生平，按句切开（人名换成“某”、数字换成 N、去掉括号里的数值提示），不同句子占比
	var ur := 0.0
	var worst := ""
	for sd in range(51, 59):
		var x = W.new()
		x.create(sd, "苏青禾")
		var sents := []
		for d in 100:
			x.tick(true)
			var ev = x.pending()
			if ev.is_empty():
				continue
			sents.append_array(_sents(x, String(ev["text"])))
			var o: Array = x._ch(ev["opts"])
			sents.append_array(_sents(x, x.choose(String(o[0]))))
			x.close()
		for l in x.P()["log"]:
			sents.append_array(_sents(x, String(l[1])))
		var uq := {}
		var cnt := {}
		for t in sents:
			uq[t] = 1
			cnt[t] = int(cnt.get(t, 0)) + 1
		ur += float(uq.size()) / maxf(1, sents.size()) / 8.0
		if sd == 51:
			var top := []
			for t in cnt:
				if cnt[t] >= 3:
					top.append("%d×%s" % [cnt[t], t])
			worst = "；".join(top)
	lines.append("100 日不同句子占比 %.3f（种子 51 里出现 ≥3 次的：%s）" % [ur, worst])
	ok(ur >= 0.80, "100 日内玩家读到的句子不同句占比 ≥ 0.80（%.3f）" % ur)
	# 故事线：一局 45 日（约 6 成日子在青庐、其余在路上），玩家总选第一个选项（结伴/救人/应下/收殓/去寻）
	var arcs := {"表白": 0, "道侣遇险": 0, "旧友死讯": 0, "寻凶": 0}
	var tops := 0.0
	for sd in range(21, 29):
		var x = W.new()
		x.create(sd, "苏青禾")
		for d in 45:
			var home: bool = (d % 10) < 6
			x.tick(home)
			var ev = x.pending()
			if not ev.is_empty():
				x.choose(String(ev["opts"][0][0]))
				x.close()
		var m := metrics(x)
		tops += m.top / 8.0
		for k in arcs:
			if m.cnt.has(k):
				arcs[k] += 1
	lines.append("45 日故事线（8 局里出现的局数）：%s；最常见模板占比均值 %.3f" % [JSON.stringify(arcs), tops])
	ok(arcs["表白"] >= 7 and arcs["旧友死讯"] >= 7, "45 日内：表白、旧友死讯至少 7/8 局出现")
	ok(arcs["道侣遇险"] >= 6 and arcs["寻凶"] >= 6, "45 日内：道侣遇险、寻凶至少 6/8 局出现（应下/收殓时）")
	ok(tops < 0.20, "45 日局最常见模板占比 < 0.20（%.3f）" % tops)
	# 拒绝型玩家：总选第二个选项（婉拒/遥遥一拜/烧香送走……），后续也要有戏
	var arcs2 := {"婉拒后": 0, "旧友托梦": 0, "仇家寻上门": 0}
	var tops2 := 0.0
	for sd in range(31, 39):
		var x = W.new()
		x.create(sd, "苏青禾")
		for d in 45:
			x.tick((d % 10) < 6)
			var ev = x.pending()
			if not ev.is_empty():
				var o: Array = ev["opts"][1] if ev["opts"].size() > 1 else ev["opts"][0]
				x.choose(String(o[0]))
				x.close()
		var m := metrics(x)
		tops2 += m.top / 8.0
		if m.cnt.has("暗恋不舍") or m.cnt.has("怨偶"):
			arcs2["婉拒后"] += 1
		for k in ["旧友托梦", "仇家寻上门"]:
			if m.cnt.has(k):
				arcs2[k] += 1
	lines.append("拒绝型 45 日（8 局里出现的局数）：%s；最常见模板占比均值 %.3f" % [JSON.stringify(arcs2), tops2])
	ok(arcs2["婉拒后"] >= 7 and arcs2["旧友托梦"] >= 7, "拒绝型：婉拒后有暗恋不舍/怨偶、不收殓有旧友托梦，至少 7/8 局")
	ok(arcs2["仇家寻上门"] >= 6, "拒绝型：送走故人后仇家寻上门，至少 6/8 局")
	ok(tops2 < 0.20, "拒绝型 45 日局最常见模板占比 < 0.20（%.3f）" % tops2)
	# 旧档补种故事线
	var y = W.new()
	y.create(41, "苏青禾")
	for d in 30:
		y.tick(true)
		if not y.pending().is_empty():
			y.auto_choose()
			y.close()
	y.w.erase("arc")
	var y2 = W.new()
	y2.attach(null, JSON.parse_string(JSON.stringify(y.w)))
	ok(y2.w.has("arc") and int(y2.w["arc"]["death_day"]) > int(y2.w["day"]), "没有故事线的旧档读入时补种，排在今天之后")
	# 接进青庐规则：v1 旧档迁移 + 世界随日子走 + 存读档
	var GS = load("res://scripts/game_state.gd")
	var h = GS.new()
	h.new_game("苏青禾", "aunt", 11)
	var v1: Dictionary = h.to_dict()
	v1["v"] = 1
	v1.erase("world")
	var m = GS.new()
	ok(m.from_dict(JSON.parse_string(JSON.stringify(v1))) and m.world == null, "v1 旧档可读（迁移前没有江湖）")
	m.start_world(99)
	for i in 30:
		m.tick("biguan")
		m.world.auto_choose()
	ok(int(m.world.w["day"]) == 30 and m.world.w["events"].size() > 0, "迁移后江湖随闭关日推进（事件 %d 件）" % m.world.w["events"].size())
	for i in 3:
		m.tick("road")
	ok(m.world.pending().is_empty() or int(m.world.pending()["day"]) <= 30, "路上不出江湖事件")
	var m2 = GS.new()
	ok(m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict()))) and m2.world != null and int(m2.world.w["day"]) == 33, "带江湖的 v2 存档往返")
	ok(int(m2.s["v"]) == GS.SAVE_VERSION, "存档版本号 = %d" % GS.SAVE_VERSION)
	for l in lines:
		print(l)
	print("江湖测试：%d 失败" % fails)
	quit(0 if fails == 0 else 1)
