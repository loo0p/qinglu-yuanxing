extends SceneTree
## v0.13 百年测试：回合=月以后，一局能不能真的走过几十上百年
## ① 筑基后长闭关→冲关，结丹、元婴各要多少年；年龄/寿元/历法对得上；寿尽会坐化
## ② 江湖百年：人会老、会死、有新人补进来，掌门会换，在世人数不塌（≥18），存档不涨爆（<2.5MB）
## ③ 性能：江湖跑 100 年（1200 个月）在无头模式下 <90 秒
## ④ 存档迁移：v2 档（含旧开局字段、筑基结局）读成 v3，经历不丢、不报错、筑基从初期接着修
const GS = preload("res://scripts/game_state.gd")
const W = preload("res://scripts/world.gd")
var fails := 0
var lines: PackedStringArray = []

func ok(c: bool, msg: String) -> void:
	lines.append(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1

func _drain(g) -> void:
	var guard := 0
	while g.world != null and not g.world.pending().is_empty() and guard < 20:
		guard += 1
		g.world.auto_choose()
		g.world.close()

## 冲一次大关：心魔题每题挑“对得上”的答案（没有就第一个）
func _gate(g) -> Dictionary:
	if not g.start_breakthrough():
		return {}
	var r: Dictionary = {}
	var guard := 0
	while g.s["loc"] == "xinmo" and guard < 6:
		guard += 1
		var q: Dictionary = g.current_xinmo()
		var pick := 0
		for i in q["answers"].size():
			if g.check(q["answers"][i]["consistent_if"]):
				pick = i
				break
		r = g.answer_xinmo(pick)
	return r

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	# ---------- ① 她的百年
	for seed in [11, 23]:
		var g = GS.new()
		g.new_game("林晚照", "sect", seed, true)
		g.s["guide"] = {}
		g._raise_to(9)   # 炼气到筑基另有测试（run_tests/ui_smoke）；这里从筑基初期起算
		var m_zhuji := int(g.s["day"])
		var hit := {}
		var guard := 0
		var ages_ok := true
		while not g.s["ended"] and guard < 400:
			guard += 1
			_drain(g)
			g.s["ration"] = 30
			g.biguan("gate", 1)
			_drain(g)
			if g.s["ended"]:
				break
			if int(g.s["injured"]) > 0 or int(g.s["unstable"]) > 0:
				g.biguan("days", maxi(int(g.s["injured"]), int(g.s["unstable"])))
				continue
			if g.at_gate():
				var gn: String = g.gate_name()
				var r := _gate(g)
				if r.get("ok", false) and not hit.has(gn):
					hit[gn] = int(g.s["day"])
			if g.age_y() != int((GS.AGE0 * 12 + int(g.s["day"])) / 12):
				ages_ok = false
			if int(g.s["plv"]) >= 15 and hit.has("凝婴"):
				break
		var yz := (int(hit.get("结丹", -1)) - m_zhuji) / 12.0
		var yy := (int(hit.get("凝婴", -1)) - m_zhuji) / 12.0
		print("seed %d done %.1fs" % [seed, (Time.get_ticks_msec() - t0) / 1000.0])
		lines.append("种子 %d：筑基→结丹 %.1f 年，→元婴 %.1f 年；结束时 %d 岁 / 寿 %d 岁，%s，江湖第 %d 月" % [seed, yz, yy, g.age_y(), g.age_y() + g.shou_years(), g.realm_text(), int(g.world.w["day"])])
		ok(hit.has("结丹") or g.s["ended"], "种子 %d：筑基后长闭关能冲到结丹（或寿尽坐化收场）" % seed)
		if hit.has("结丹"):
			ok(yz >= 15 and yz <= 120, "种子 %d：筑基→结丹用了 %.1f 年（应在 15–120 年之间，修仙的跨度）" % [seed, yz])
		ok(ages_ok, "种子 %d：年龄始终 = 开局年龄 + 月数/12" % seed)
		ok(int(g.world.w["day"]) == int(g.s["day"]), "种子 %d：江湖与她同一本历（%d / %d 月）" % [seed, int(g.world.w["day"]), int(g.s["day"])])
		# 存档往返
		var js := JSON.stringify(g.to_dict())
		var g2 = GS.new()
		ok(g2.from_dict(JSON.parse_string(js)) and int(g2.s["day"]) == int(g.s["day"]) and int(g2.s["plv"]) == int(g.s["plv"]), "种子 %d：百年后的存档读回一致" % seed)
		lines.append("  存档 %.0f KB" % (js.length() / 1024.0))
		ok(js.length() < 2500 * 1024, "种子 %d：存档 %.0f KB < 2.5 MB" % [seed, js.length() / 1024.0])
	# 寿尽：把寿元拨到 2 个月，闭关两个月就该坐化
	var g3 = GS.new()
	g3.new_game("苏青禾", "sect", 5, false)
	g3.s["shouyuan"] = 2
	g3.s["ration"] = 30
	g3.biguan("days", 6)
	ok(g3.s["ended"] and g3.s["ending"] == "zuohua", "寿元耗尽 → 坐化结局")
	# ---------- ② 江湖百年（她一直闭关，江湖照常）
	var t1 := Time.get_ticks_msec()
	var g4 = GS.new()
	g4.new_game("林晚照", "sect", 77, true)
	g4.s["guide"] = {}
	g4._raise_to(12)
	var m4 := int(g4.world.w["day"])
	var first_ids := {}
	for c in g4.world.npcs():
		first_ids[int(c["id"])] = float(c["age"])
	var min_alive := 999
	var yr_counts := []
	for y in 100:
		g4.s["ration"] = 30
		g4.s["shouyuan"] = 9999
		g4.s["xiuwei"] = 0   # 不让她修满提前出关：这一段只看江湖
		g4.biguan("days", 12)
		_drain(g4)
		var n: int = g4.world.npcs().size()
		min_alive = mini(min_alive, n)
		if y % 20 == 19:
			yr_counts.append("%d年:%d人" % [y + 1, n])
	var dt := (Time.get_ticks_msec() - t1) / 1000.0
	var gen: Dictionary = g4.world.w.get("gen", {})
	var still := 0
	var aged_ok := true
	for c in g4.world.npcs():
		if first_ids.has(int(c["id"])):
			still += 1
			if absf(float(c["age"]) - first_ids[int(c["id"])] - 100.0) > 1.0:
				aged_ok = false
	lines.append("江湖百年：%s；最少 %d 人；开局的人还在世 %d 个；生子 %d、子女入仙途 %d、收徒 %d、新人 %d、掌门更替 %d、压缩旧人 %d；用时 %.1f 秒" % [", ".join(yr_counts), min_alive, still, int(gen.get("n_birth", 0)), int(gen.get("n_come", 0)), int(gen.get("n_pupil", 0)), int(gen.get("n_new", 0)), int(gen.get("n_succ", 0)), int(gen.get("n_pruned", 0)), dt])
	ok(int(g4.world.w["day"]) - m4 == 1200, "江湖走满 100 年（%d 月）" % (int(g4.world.w["day"]) - m4))
	ok(min_alive >= 18, "百年里在世的人最少 %d（≥18，不会只剩她一个）" % min_alive)
	ok(still < first_ids.size(), "开局的人百年后有人寿尽/亡故（还在 %d/%d）" % [still, first_ids.size()])
	ok(aged_ok, "还在世的老人恰好老了 100 岁")
	ok(int(gen.get("n_new", 0)) + int(gen.get("n_come", 0)) + int(gen.get("n_pupil", 0)) >= 10, "百年里有新人入江湖（生子/收徒/补位）")
	ok(int(gen.get("n_succ", 0)) >= 1, "百年里至少换过一次掌门")
	ok(dt < 90.0, "江湖百年用时 %.1f 秒 < 90" % dt)
	var js4 := JSON.stringify(g4.to_dict())
	lines.append("  百年存档 %.0f KB" % (js4.length() / 1024.0))
	ok(js4.length() < 2500 * 1024, "江湖百年存档 %.0f KB < 2.5 MB" % (js4.length() / 1024.0))
	var nl := 0
	for x in g4.s["log"]:
		if String(x["text"]).contains("青庐") and String(x["text"]).contains("年"):
			nl += 1
	ok(nl >= 1, "生平里按“青庐 N 年”记年月（%d 条）" % nl)
	# ---------- ④ v2 → v3 迁移
	var g5 = GS.new()
	g5.new_game("沈知微", "sect", 9, true)
	for i in 30:
		g5.biguan_day()
	var d: Dictionary = JSON.parse_string(JSON.stringify(g5.to_dict()))
	d["v"] = 2
	d["cherish"] = "aunt"
	d["aunt_ration"] = 40
	d.erase("tu")
	d["ended"] = true
	d["ending"] = "zhuji"
	d["loc"] = "ending"
	var n_log := int(d["log"].size())
	var g6 = GS.new()
	var loaded: bool = g6.from_dict(d)
	ok(loaded and int(g6.s["v"]) == 3, "v2 档（含旧开局字段）读成 v3，不报错")
	ok(int(g6.s["day"]) == 30 and int(g6.s["log"].size()) >= n_log, "迁移后经历一件不丢（第 N 日记作第 N 月）")
	ok(not g6.s["ended"] and int(g6.s["plv"]) == 9 and g6.s["loc"] == "home", "旧档的筑基结局 → 从筑基初期接着修")
	ok(not g6.s.has("aunt_ration") and String(g6.s["cherish"]) != "aunt", "旧开局的亲戚字段并掉（干粮入仓）")
	ok(int(g6.s["shouyuan"]) > 0 and g6.age_y() + g6.shou_years() <= 200 + 1, "迁移后寿元按筑基寿限重算（%d 岁 / 寿 %d 岁）" % [g6.age_y(), g6.age_y() + g6.shou_years()])
	g6.s["ration"] = 30
	ok(g6.biguan("days", 3) == 3, "迁移后照常闭关过月")
	lines.append("总用时 %.1f 秒" % ((Time.get_ticks_msec() - t0) / 1000.0))
	lines.append("百年测试：%s（%d 项失败）" % ["PASS" if fails == 0 else "FAIL", fails])
	for l in lines:
		print(l)
	quit(0 if fails == 0 else 1)
