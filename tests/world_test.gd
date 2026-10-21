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
