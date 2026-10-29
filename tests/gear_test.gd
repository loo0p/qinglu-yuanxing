extends SceneTree
## v0.14：闭关履历 / 行囊装备 / 坊市行情 / 存档 v3→v4 迁移
const GS = preload("res://scripts/game_state.gd")
var fails := 0
var lines: PackedStringArray = []

func ok(c: bool, msg: String) -> void:
	lines.append(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1

func fresh(sd: int = 7):
	var g = GS.new()
	g.new_game("苏青禾", "sect", sd, true)
	for i in 40:
		g.tick("biguan")
		g.world.auto_choose()
		g.world.close()
	return g

const Gear = preload("res://scripts/gear.gd")

func _init() -> void:
	t_seclude()
	t_stalled()
	t_unlock_merge()
	t_trim()
	t_proto()
	t_gen()
	t_identity()
	t_bag()
	t_save()
	t_effects()
	t_market()
	t_world()
	t_lq1800()
	t_auc_lots()
	for l in lines:
		print(l)
	print("装备/闭关测试：%d 失败" % fails)
	quit(1 if fails > 0 else 0)

func t_seclude() -> void:
	var g = fresh()
	g._raise_to(9)
	g.s["ration"] = 30
	var n0: int = g.world.P()["log"].size()
	var done: int = g.biguan("years", 20)
	# v0.15（Gemini v7 专项 2）：计划闭关二十年，连坐满五年心头蒙尘、出关；出门走两个月洗净再闭
	ok(done <= 60, "计划二十年，最多连坐五年（这回 %d 个月）就出关" % done)
	for i in 2:
		g.tick("road")
	g.biguan("years", 20)
	var lg: Array = g.world.P()["log"]
	var add := lg.slice(n0)
	var txt := "\n".join(add.map(func(e): return "%s %s" % [g.world.cal_text(int(e[0])), e[1]]))
	print(txt)
	ok(add.size() >= 15, "二十年闭关写进她的履历 %d 条（≥15）" % add.size())
	var sorted := true
	for i in range(1, lg.size()):
		if int(lg[i][0]) < int(lg[i - 1][0]):
			sorted = false
	ok(sorted, "履历按年月先后")
	ok(txt.contains("入静室闭关") and txt.contains("出关"), "有入关、出关两笔")
	# v0.15：不再每年写一笔空心得；关中的事（顿悟、走岔、心魔、灵脉涨潮…）每条都带效果，出关那条带修为/境界
	var with_fx := add.filter(func(e): return e.size() > 2 and not (e[2] as Dictionary).is_empty()).size()
	ok(with_fx * 10 >= add.size() * 8, "闭关期间写的 %d 条里 %d 条带效果（≥八成）" % [add.size(), with_fx])
	var sumi := add.filter(func(e): return String(e[1]).begins_with("入静室闭关"))
	# v0.15.0 起连坐五年蒙尘就出关，二十年计划会分成几段，每段一条合并条
	ok(sumi.size() >= 1 and sumi.all(func(e): return String(e[1]).contains("出关时") and e.size() > 2 and not (e[2] as Dictionary).is_empty()), "合并的闭关条（%d 段）：入关几年、出关时境界，带效果" % sumi.size())
	ok(txt.contains("心境蒙尘") and txt.contains("坐不下去了"), "满三年蒙尘、五年蒙尘出关写进履历")

## v0.14.1：修为满了还闭关——履历里“关口”只记一回，连着几回并成一行，不再“入关/关口/出关”三笔一组地重复
func t_stalled() -> void:
	var g = fresh(9)
	g.s["ration"] = 30
	g.s["xiuwei"] = g.xw_goal()
	ok(g.at_gate(), "炼气圆满、修为满 = 卡在筑基关口")
	var n0: int = g.world.P()["log"].size()
	var used := 0
	for i in 3:
		used += g.biguan("years", 10)
	var add: Array = g.world.P()["log"].slice(n0)
	var txt := "\n".join(add.map(func(e): return String(e[1])))
	print(txt)
	ok(used == 3, "卡在关口的长闭关每回一个月就出关（共 %d 月）" % used)
	ok(txt.count("修为到了筑基的关口") == 1, "“修为到了筑基的关口”只记一次")
	ok(txt.count("修为停在筑基的关口") == 1 and txt.contains("前后又坐了三个月"), "三回空坐并成一行“前后又坐了三个月”（中间夹了别的事也不断开）")
	ok(not txt.contains("入静室闭关") and not txt.contains("出关。"), "不再写入关、出关")
	ok(not g.s.has("last_seclude"), "不弹“这些年”出关小结")

## v0.14.1：同一个月认得好几处路——行记和履历各并成一条
func t_unlock_merge() -> void:
	var g = GS.new()
	g.new_game("苏青禾", "sect", 5, true)
	var TV = load("res://scripts/travel.gd")
	TV.ensure(g.world)
	var l0: int = g.s["log"].size()
	var c0: int = g.world.P()["log"].size()
	var got := []
	for p in TV.ORDER:
		if got.size() < 3 and not g.world.w["unl"].has(p):
			TV.unlock(g.world, p, "测试")
			got.append(p)
	var news: Array = g.s["log"].slice(l0).filter(func(e): return String(e["text"]).begins_with("新去处"))
	var ch: Array = g.world.P()["log"].slice(c0).filter(func(e): return String(e[1]).begins_with("知道了去"))
	print(news, ch)
	ok(got.size() >= 2 and news.size() == 1 and ch.size() == 1, "解锁 %d 处：行记 %d 条、履历 %d 条（都应是 1）" % [got.size(), news.size(), ch.size()])
	var all_in := true
	for p in got:
		if not String(news[0]["text"]).contains(p) or not String(ch[0][1]).contains(p):
			all_in = false
	ok(all_in, "并起来的那条里每处地名都在")

## v0.14.1：她的履历满 300 条时，先挤传闻、再挤日常；闭关补记（pchron）也不再直接挤掉最早的大事
func t_trim() -> void:
	var g = GS.new()
	g.new_game("苏青禾", "sect", 3, true)
	var lg: Array = g.world.P()["log"]
	var first := String(lg[0][1])
	var cap: int = g.world.PLOG_CAP   # v0.15：900 条（v0.14 是 300）
	for i in cap + 100:
		g.pchron("（出关后才听说）有人在后山夺了一件宝物（%d）。" % i)
	ok(lg.size() == cap and String(lg[0][1]) == first, "满 %d 条：开局那条还在（%s）" % [cap, String(lg[0][1]).left(12)])
	for i in cap + 100:
		g.pchron("在静室里坐了一个月（%d）。" % i)
	ok(String(lg[0][1]) == first and lg.filter(func(e): return String(e[1]).begins_with("（出关后才听说）")).is_empty(), "传闻先被挤光，大事仍在")
	# v0.15：日常不再整条删掉，同一个十年里的并成一条“十年纪要”
	var jy := lg.filter(func(e): return String(e[1]).begins_with("十年纪要"))
	ok(jy.size() >= 1 and lg.size() <= cap and String(jy[0][1]).contains("在静室里坐了一个月"), "满了把一个十年的日常并成“十年纪要”（%d 条；%s）" % [jy.size(), String(jy[0][1]).left(40) if jy.size() > 0 else ""])

func t_proto() -> void:
	ok(Gear.prop("飞剑", "slot") == "fabao" and is_equal_approx(float(Gear.prop("飞剑", "weight")), 2.0), "prototree：飞剑继承法宝的槽、覆盖重量")
	ok(Gear.is_a("芥子镯", "储物") and not Gear.is_a("剑", "法衣"), "prototree：inherits 判断")
	ok(int(Gear.prop("储物袋", "cells")) == 12 and int(Gear.prop("布囊", "cells")) == 6, "储物：布囊 6 / 储物袋 12 格")

func t_gen() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var W = load("res://scripts/world.gd").new()
	W.create(5, "苏青禾")
	var bad := 0
	var cnt := [0, 0, 0, 0, 0]
	var names := {}
	for i in 3000:
		var sl: String = ["fabao", "yi", "shi", "dai"][i % 4]
		var arr: Array = Gear.BASES[sl]
		var g := i % 5
		var it: Dictionary = Gear.make(null, W, r, String(arr[r.randi() % arr.size()]), g, "测", 1)
		var groups := {}
		var pres := 0
		for a in it["af"]:
			var d := Gear.afx(String(a[0]))
			if groups.has(d["group"]) or not (sl in d["slots"]):
				bad += 1
			groups[d["group"]] = true
			if d["pos"] == "pre":
				pres += 1
		if pres > 1 or it["af"].size() != int(it["g"]):
			bad += 1
		var n := String(it["n"])
		for k in n.length() - 1:
			if n[k] == n[k + 1]:
				bad += 1
		cnt[int(it["g"])] += 1
		names[n] = true
	ok(bad == 0, "生成 3000 件：词缀数 = 品阶、同组互斥、只一个前缀、槽对得上、名字无叠字（坏 %d）" % bad)
	ok(names.size() > 60, "名字够多样（%d 种）" % names.size())
	var v0: int = Gear.value({"p": "剑", "g": 0, "af": [], "dur": 100})
	var v2: int = Gear.value({"p": "剑", "g": 2, "af": [["poja", 1.0], ["qingfeng", 1.0]], "dur": 100})
	ok(v0 == 5 and v2 == 390, "价值：凡品剑 5，灵器两词缀 390（%d / %d）" % [v0, v2])

func t_identity() -> void:
	var g = fresh(3)
	ok(Gear.cells(g) == 6 and Gear.eq(g, "dai") != null and String(Gear.eq(g, "dai")["p"]) == "布囊", "开局：一只布囊，6 格")
	var z := true
	for k in ["pw", "def", "xw", "wu", "rsave"]:
		if Gear.her_stat(g, k) != 0.0:
			z = false
	ok(z and Gear.xw_bonus(g, 10) == 10 and Gear.wu_bonus(g, 7) == 7 and Gear.on_injury(g, 4) == 4, "什么都没佩：效果恒等")

func _give(g, pid: String, gr: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = 7 + gr
	var it: Dictionary = Gear.make(g, g.world, r, pid, gr, "测试", int(g.s["day"]))
	Gear.give_her(g, it, "测试给的")
	return it

func t_bag() -> void:
	var g = fresh(4)
	for i in 6:
		g._pack_add_one("pill_juqi", false) if g.has_method("_pack_add_one") else null
	var sword := _give(g, "剑", 1)
	ok(Gear.find(g, int(sword["u"]))[0] == "home", "在青庐得的东西放洞府")
	g.s["pack"] = []
	for i in 6:
		g.s["pack"].append({"id": "fu_bishui", "n": 1, "key": false})
	ok(Gear.carry(g, int(sword["u"])) != "", "行囊六格满了：带不上")
	g.s["pack"].pop_back()
	ok(Gear.carry(g, int(sword["u"])) == "" and Gear.cells(g) == 5, "空出一格：带上了，格数剩 5（器物占格）")
	var bag := _give(g, "储物袋", 1)
	ok(Gear.equip(g, int(bag["u"])) == "" and Gear.cells(g) >= 11, "换上储物袋：格数 %d" % Gear.cells(g))
	ok(Gear.equip(g, int(sword["u"])) == "" and Gear.eq(g, "fabao") != null, "装上法宝")
	var big := _give(g, "剑", 2)
	ok(Gear.equip(g, int(big["u"])) != "", "炼气期祭不动灵器（越阶可持有）")
	var soft := _give(g, "软甲", 1)
	var stone := _give(g, "印", 1)
	g.s["gear"]["bag"].clear()
	ok(Gear.carry(g, int(soft["u"])) == "", "软甲带得上")
	var w0: float = Gear.load_w(g)
	ok(w0 > 0.0 and w0 <= Gear.wcap(g), "负重 %s/%s" % [str(w0), str(Gear.wcap(g))])

func _uids(g) -> Dictionary:
	var d := {}
	for it in Gear.all_mine(g):
		d[int(it["u"])] = int(d.get(int(it["u"]), 0)) + 1
	return d

func t_save() -> void:
	var g = fresh(5)
	var sw := _give(g, "飞剑", 1)
	Gear.equip(g, int(sw["u"]))
	var j := JSON.stringify(g.to_dict())
	var h = GS.new()
	ok(h.from_dict(JSON.parse_string(j)), "当前版本存档读回")
	ok(Gear.eq(h, "fabao") != null and String(Gear.eq(h, "fabao")["n"]) == String(sw["n"]) and is_equal_approx(Gear.her_stat(h, "pw"), Gear.her_stat(g, "pw")), "装备与斗法加成存读一致")
	# v3 → v4：旧档没有 gear，读入补一只布囊；行囊、灵石、仓库原样
	var d: Dictionary = JSON.parse_string(j)
	d.erase("gear")
	d["v"] = 3
	d["pack"] = [{"id": "pill_juqi", "n": 3, "key": false}, {"id": "fu_bishui", "n": 1, "key": true}]
	d["lingshi"] = 77
	var m = GS.new()
	ok(m.from_dict(d) and int(m.s["v"]) == GS.SAVE_VERSION and String(Gear.eq(m, "dai")["p"]) == "布囊", "v3 档迁移到当前版本：补布囊")
	ok(m.s["pack"].size() == 2 and int(m.s["lingshi"]) == 77 and Gear.cells(m) == 6, "迁移不动原有行囊与灵石")
	var f := FileAccess.open("res://tests/fixtures/save_v2_live_v0121_day36.json", FileAccess.READ)
	if f != null:
		var o = GS.new()
		ok(o.from_dict(JSON.parse_string(f.get_as_text())["state"]) and o.s.has("gear") and int(o.s["v"]) == GS.SAVE_VERSION, "v2 老档（v0.12.1 线上）一路迁到当前版本 v%d" % GS.SAVE_VERSION)

func t_effects() -> void:
	var g = fresh(6)
	var robe := _give(g, "道袍", 1)
	Gear.equip(g, int(robe["u"]))
	ok(Gear.on_injury(g, 10) < 10, "法衣减伤：10 → %d" % Gear.on_injury(g, 10))
	var d0 := int(robe["dur"])
	ok(d0 < 100, "受伤磨损法衣（耐久 %d）" % d0)
	var fu := _give(g, "护身符", 0)
	fu = Gear.eq(g, "fu")
	var c0 := int(fu["c"])
	var hurt := Gear.on_injury(g, 10)
	ok(Gear.eq(g, "fu") == null or int(Gear.eq(g, "fu")["c"]) == c0 - 1, "护身符烧一张")
	var pei := _give(g, "玉佩", 1)
	Gear.equip(g, int(pei["u"]))
	ok(Gear.xw_bonus(g, 100) > 100, "玉佩：闭关修为 100 → %d" % Gear.xw_bonus(g, 100))
	var ring := _give(g, "戒", 1)
	Gear.equip(g, int(ring["u"]))
	var saved := 0
	for i in 40:
		if Gear.ration_saved(g):
			saved += 1
	ok(saved >= 6, "戒：四十个月省下 %d 颗辟谷丹" % saved)
	# 符箓过期
	var g2 = fresh(8)
	_give(g2, "护身符", 0)
	for i in 61:
		g2.tick("biguan")
	ok(Gear.eq(g2, "fu") == null, "护身符放了五年失灵")
	# 斗法加成
	var W = g.world
	var n: Dictionary = W.npcs()[0]
	var e0: float = Gear.edge(W, n)
	ok(e0 == Gear.her_stat(g, "pw") - Gear.npc_pw(W, n), "斗法：她的法宝 − 对方的法宝")

func t_market() -> void:
	var g = fresh(9)
	var seen := {}
	for d in range(1, 49):
		seen[Gear.price_idx(d)] = true
	ok(seen.size() >= 12, "行情逐月变（四年里 %d 种）" % seen.size())
	var st: Array = Gear.shop(g)
	ok(st.size() >= 5, "器物铺有货 %d 件" % st.size())
	g.s["lingshi"] = 500
	var u := int(st[0]["u"])
	var nm := String(st[0]["n"])
	ok(Gear.shop_buy(g, u) == "" and not Gear.find(g, u).is_empty(), "买下%s" % nm)
	g.s["loc"] = "roam"
	g.s["gear"]["bag"].append(Gear._take(g, u))
	var it: Dictionary = Gear.find(g, u)[2]
	var p1 := Gear.sell_price(g, it, int(g.s["day"]))
	g.s["gear"]["sold"][String(it["p"])] = 3
	ok(Gear.sell_price(g, it, int(g.s["day"])) < p1, "同类卖多了价钱往下走")
	g.s["loc"] = "home"
	# 拍卖：三月
	while (int(g.s["day"]) - 1) % 12 + 1 != 3:
		g.tick("biguan")
	g.s["lingshi"] = 100000
	var A: Dictionary = Gear.auction(g)
	ok(not A.is_empty() and int(A["n"]) == Gear.AUC_LOTS and int(A["i"]) == 1, "三月拍卖会：一场 %d 件，先拍第一件（%s）" % [int(A.get("n", 0)), Gear.grade_name(A["lot"])])
	var n0: int = Gear.all_mine(g).size()
	for i in 30:
		if A["done"]:
			break
		Gear.auction_bid(g)
	ok(A["done"] and int(A["lead"]) == -1 and Gear.all_mine(g).size() == n0 + 1 and int(g.s["lingshi"]) == 100000 - int(A["price"]), "举牌到底：拍得，灵石扣对（%d）" % int(A["price"]))
	var dup := false
	for k in _uids(g).values():
		if int(k) > 1:
			dup = true
	ok(not dup, "她的东西没有重号")

func t_world() -> void:
	var g = fresh(11)
	var lv0: Dictionary = {}
	for i in 360:
		g.tick("biguan")
		g.world.auto_choose()
		g.world.close()
	var W = g.world
	var moved := 0
	var made := 0
	var holders := {}
	var dup := 0
	for c in W.w["C"].values():
		for it in c.get("gear", []):
			if holders.has(it):
				dup += 1
			holders[it] = true
			if it["h"].size() > 1:
				moved += 1
	var txt := ""
	for c in W.w["C"].values():
		for e in c["log"]:
			txt += String(e[1]) + "\n"
	for k in ["炼成一件", "寻到一件", "夺了", "赠给了", "捡到一件"]:
		if txt.contains(k):
			made += 1
	print("三十年江湖：易过手的器物 %d 件；物品事 %d 种出现" % [moved, made])
	ok(moved >= 1, "三十年里有器物换过主人（%d 件）" % moved)
	ok(made >= 2, "法宝事件出现 %d 种（炼器/寻宝/夺宝/赠物/捡遗物）" % made)
	ok(dup == 0, "一件器物同时只在一个人身上")

## v0.14.2：炼气 600 → 1800。旧档修为 ×3、层数不变；每层当月记进履历，顺序是先破层、后关口、再出关
func t_lq1800() -> void:
	ok(GS.XW_GOAL == 1800, "炼气修为上限 1800")
	for xw in [0, 199, 200, 250, 599, 600, 1000]:
		var g = fresh(21)
		var lay0: int = int(1 + xw * 9 / 600) if xw < 600 else 9
		var full0: bool = xw >= 600
		var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
		d["v"] = 4
		d["xiuwei"] = mini(xw, 600)
		var m = GS.new()
		var okd: bool = m.from_dict(d)
		ok(okd and m.I("xiuwei") == mini(xw, 600) * 3 and m.layer() == lay0 and (m.I("xiuwei") >= m.xw_goal()) == full0, "v4 旧档修为 %d → %d，层数 %d 不变%s" % [mini(xw, 600), m.I("xiuwei"), lay0, "，仍是圆满" if full0 else ""])
	var z = fresh(22)
	z._raise_to(10)
	z.s["xiuwei"] = 777
	var dz: Dictionary = JSON.parse_string(JSON.stringify(z.to_dict()))
	dz["v"] = 4
	var mz = GS.new()
	ok(mz.from_dict(dz) and mz.I("xiuwei") == 777 and mz.I("plv") == 10, "筑基以后的旧档修为不动（777）")
	var f := FileAccess.open("res://tests/fixtures/save_v2_live_v0121_day36.json", FileAccess.READ)
	if f != null:
		var raw: Dictionary = JSON.parse_string(f.get_as_text())["state"]
		var o = GS.new()
		o.from_dict(raw.duplicate(true))
		var exp: int = int(raw.get("xiuwei", 0)) * 3 if not (bool(raw.get("ended", false)) and String(raw.get("ending", "")) == "zhuji") else 0
		ok(o.I("xiuwei") == exp, "v2 线上老档修为 %d → %d" % [int(raw.get("xiuwei", 0)), o.I("xiuwei")])
	# 长闭关：每过一层都在当月记一笔，修满记关口，最后出关
	var g = fresh(23)
	g.s["ration"] = 30
	g.s["ganwu"] = 0
	var n0: int = g.world.P()["log"].size()
	for k in 6:   # v0.15：五年一出关，出门走两个月再接着闭
		if g.at_gate():
			break
		g.biguan("years", 10)
		for i in 2:
			g.tick("road")
	var add: Array = g.world.P()["log"].slice(n0)
	var texts: Array = add.map(func(e): return String(e[1]))
	var txt := "\n".join(texts)
	ok(txt.count("修为精进，入炼气") >= 6 and txt.contains("入炼气九层"), "长闭关里过的层当月记下（%d 笔，含九层；一个月连过两层只记后一层）" % txt.count("修为精进，入炼气"))
	var i9 := -1
	var ig := -1
	var io := -1
	for i in texts.size():
		if texts[i].contains("入炼气九层") and i9 < 0:
			i9 = i
		if texts[i].contains("修为到了筑基的关口") and ig < 0:
			ig = i
		if texts[i].begins_with("入静室闭关") and texts[i].contains("出关时"):
			io = i
	# v0.15：每回长闭关只写一条合并的（在入关那个月，含“出关时…”）
	ok(i9 >= 0 and ig > i9 and io >= 0, "顺序：入炼气九层（%d）→ 到了关口（%d）；合并的闭关条在（%d）" % [i9, ig, io])
	ok(txt.count("修为到了筑基的关口") == 1, "关口只记一次")
	var sorted := true
	var lg: Array = g.world.P()["log"]
	for i in range(1, lg.size()):
		if int(lg[i][0]) < int(lg[i - 1][0]):
			sorted = false
	ok(sorted, "履历按年月先后")
	ok(bool(g.s["flags"].get("zhuji_hint", false)), "修到炼气七层，翻出筑基丹方（以前看 s.plv，炼气时永远是 0，这条不触发）")
	# 炼气圆满要多久：纯闭关（不出门、不服丹）
	var h = GS.new()
	h.new_game("测试", "sect", 24)   # 不开江湖：只看闭关本身的速度
	h.s["ration"] = 30
	var mon := 0
	while h.I("xiuwei") < h.xw_goal() and mon < 400:
		h.tick("biguan")
		mon += 1
	ok(mon == 150, "只闭关不出门：炼气圆满要 %d 个月（1800 / 12 = 150，十二年半）" % mon)

## v0.14.2：拍卖一场三件，前两件够得着，压轴一件高她一两个大境界
func t_auc_lots() -> void:
	var g = fresh(31)
	g.s["lingshi"] = 30
	while (int(g.s["day"]) - 1) % 12 + 1 != 3:
		g.tick("biguan")
	var A: Dictionary = Gear.auction(g)
	var seen := []
	var cheap := 0
	var grades := []
	for k in Gear.AUC_LOTS:
		seen.append("%s·%s 起拍 %d" % [A["lot"]["n"], Gear.grade_name(A["lot"]), int(A["price"])])
		grades.append(int(A["lot"]["g"]))
		if k < Gear.AUC_LOTS - 1 and int(A["price"]) >= 55 and int(A["price"]) <= 90:
			cheap += 1
		Gear.auction_pass(g)
		if k < Gear.AUC_LOTS - 1:
			ok(Gear.auction_more(A) and Gear.auction_next_lot(g), "第 %d 件落槌，摆下一件" % (k + 1))
	print("拍卖（炼气，手里 30 灵石）：" + "；".join(seen))
	ok(not Gear.auction_more(A) and A["done"], "三件拍完散场")
	ok(cheap == Gear.AUC_LOTS - 1, "v0.15 春拍小拍：前两件起拍在 55–90 灵石：%s" % "；".join(seen))
	ok(grades[0] == 1 and grades[1] == 1 and grades[2] == 1, "炼气时春拍：三件都是法器（%s）" % str(grades))
	# 赢得下：多试几场，她至少拍下过一件小件
	var won := 0
	for sd in 12:
		var w = fresh(40 + sd)
		w.s["lingshi"] = 120
		while (int(w.s["day"]) - 1) % 12 + 1 != 3:
			w.tick("biguan")
		var B: Dictionary = Gear.auction(w)
		var n0: int = Gear.all_mine(w).size()
		for t in 20:
			if B["done"]:
				break
			if Gear.auction_bid(w) != "":
				Gear.auction_pass(w)
		if Gear.all_mine(w).size() > n0:
			won += 1
	ok(won >= 3, "炼气、手里 120 灵石，十二场春拍里拍下第一件 %d 回（≥3）" % won)
	# 筑基以后：小件升到灵器（身家够的话），压轴宝器起
	var z = fresh(32)
	z._raise_to(9)
	z.s["lingshi"] = 400
	while (int(z.s["day"]) - 1) % 12 + 1 != 9:
		z.tick("biguan")
	var C: Dictionary = Gear.auction(z)
	ok(int(C["lot"]["g"]) == 2 and int(C["price"]) >= 180 and int(C["price"]) <= 320, "筑基秋拍：第一件是灵器，起拍 180–320（%s %d）" % [Gear.grade_name(C["lot"]), int(C["price"])])
	Gear.auction_pass(z)
	Gear.auction_next_lot(z)
	Gear.auction_pass(z)
	Gear.auction_next_lot(z)
	ok(int(C["lot"]["g"]) == 3, "筑基秋拍压轴：宝器（%s）" % Gear.grade_name(C["lot"]))
