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
	t_proto()
	t_gen()
	t_identity()
	t_bag()
	t_save()
	t_effects()
	t_market()
	t_world()
	for l in lines:
		print(l)
	print("装备/闭关测试：%d 失败" % fails)
	quit(1 if fails > 0 else 0)

func t_seclude() -> void:
	var g = fresh()
	g._raise_to(9)
	g.s["ration"] = 30
	var n0: int = g.world.P()["log"].size()
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
	ok(txt.contains("闭关第十年"), "每年一笔心得")

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
	ok(h.from_dict(JSON.parse_string(j)), "v4 存档读回")
	ok(Gear.eq(h, "fabao") != null and String(Gear.eq(h, "fabao")["n"]) == String(sw["n"]) and is_equal_approx(Gear.her_stat(h, "pw"), Gear.her_stat(g, "pw")), "装备与斗法加成存读一致")
	# v3 → v4：旧档没有 gear，读入补一只布囊；行囊、灵石、仓库原样
	var d: Dictionary = JSON.parse_string(j)
	d.erase("gear")
	d["v"] = 3
	d["pack"] = [{"id": "pill_juqi", "n": 3, "key": false}, {"id": "fu_bishui", "n": 1, "key": true}]
	d["lingshi"] = 77
	var m = GS.new()
	ok(m.from_dict(d) and int(m.s["v"]) == 4 and String(Gear.eq(m, "dai")["p"]) == "布囊", "v3 档迁移到 v4：补布囊")
	ok(m.s["pack"].size() == 2 and int(m.s["lingshi"]) == 77 and Gear.cells(m) == 6, "迁移不动原有行囊与灵石")
	var f := FileAccess.open("res://tests/fixtures/save_v2_live_v0121_day36.json", FileAccess.READ)
	if f != null:
		var o = GS.new()
		ok(o.from_dict(JSON.parse_string(f.get_as_text())["state"]) and o.s.has("gear") and int(o.s["v"]) == 4, "v2 老档（v0.12.1 线上）一路迁到 v4")

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
	ok(not A.is_empty() and int(A["lot"]["g"]) >= 2, "三月拍卖会：一件%s" % Gear.grade_name(A["lot"]))
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
