extends SceneTree
## v0.15（Gemini v7 P0·经济）：送礼门槛 / 托售、拍卖价带、聚灵阵年费、服丹闭关、蒙尘、药铺、寿元上限显示、老龟给莲子
const GS = preload("res://scripts/game_state.gd")
const Gear = preload("res://scripts/gear.gd")
const Econ = preload("res://scripts/econ.gd")
var fails := 0
var lines: PackedStringArray = []

func ok(c: bool, msg: String) -> void:
	lines.append(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1

func fresh(sd: int = 7):
	var g = GS.new()
	g.new_game("苏青禾", "sect", sd, true)
	for i in 6:
		g.tick("biguan")
		g.world.auto_choose()
		g.world.close()
	return g

func _init() -> void:
	t_gift()
	t_auction()
	t_array()
	t_dust()
	t_market()
	t_lifespan()
	t_rules_untouched()
	for l in lines:
		print(l)
	print("经济测试：%d 失败" % fails)
	quit(1 if fails > 0 else 0)

func t_gift() -> void:
	var g = fresh(11)
	var W = g.world
	var c: Dictionary = W.npcs()[0]
	var r = RandomNumberGenerator.new()
	r.seed = 5
	var fan: Dictionary = Gear.make(g, W, r, "jian", 0, "test", int(g.s["day"]))
	ok(Econ.gift_ok(W, c, fan), "凡品谁送都行")
	var fa: Dictionary = Gear.make(g, W, r, "jian", 1, "test", int(g.s["day"]))
	W._rel(W.P(), c)["t"] = []
	W._rel(c, W.P())["t"] = []
	ok(not Econ.gift_ok(W, c, fa) or W.opinion(c, W.P()) > 60.0, "法器：不亲近（无道侣/师徒/结义，好感 ≤ 60）不白送")
	W._rel(c, W.P())["t"] = ["结义"]
	ok(Econ.gift_ok(W, c, fa), "法器：结义的人可以送（她炼气、法器祭得动）")
	var bao: Dictionary = Gear.make(g, W, r, "jian", 3, "test", int(g.s["day"]))
	ok(not Econ.gift_ok(W, c, bao), "宝器：高过她一个大境界以上，结义也不白送")
	Econ.note_gift(W, c, fa)
	ok(not Econ.gift_ok(W, c, fa), "同一人一辈子只白送一件法器以上")
	var lst: Array = Gear.npc_gear(W, c)
	lst.append(bao)
	var pr := Econ.consign(W, c, bao)
	ok(not Gear.npc_gear(W, c).has(bao) and Econ.consign_list(g).size() == 1 and pr == roundi(Gear.value(bao, int(g.s["day"])) * 0.5), "不够格的改托售：从 NPC 身上拿下，五折挂坊市（%d 灵石）" % pr)
	g.s["lingshi"] = pr + 5
	ok(Econ.consign_buy(g, int(Econ.consign_list(g)[0]["it"]["u"])) != "", "不在坊市接不了托售")
	g.s["loc"] = "roam"
	g.s["roam"] = {"pl": "坊市"}
	var u := int(Econ.consign_list(g)[0]["it"]["u"])
	var n0: int = Gear.all_mine(g).size()
	ok(Econ.consign_buy(g, u) == "" and int(g.s["lingshi"]) == 5 and Gear.all_mine(g).size() == n0 + 1 and Econ.consign_list(g).is_empty(), "在坊市付钱接下，器物到她手里")

func t_auction() -> void:
	var sp := 0
	var au := 0
	var spring_ok := true
	var autumn_ok := true
	for sd in 6:
		var g = fresh(60 + sd)
		g.s["lingshi"] = 50
		while (int(g.s["day"]) - 1) % 12 + 1 != 3:
			g.tick("biguan")
		var A: Dictionary = Gear.auction(g)
		for k in Gear.AUC_LOTS:
			var p := int(A["price"])
			if k < Gear.AUC_LOTS - 1:
				spring_ok = spring_ok and p >= 55 and p <= 90
				sp += 1
			Gear.auction_pass(g)
			Gear.auction_next_lot(g)
		while (int(g.s["day"]) - 1) % 12 + 1 != 9:
			g.tick("biguan")
		var B: Dictionary = Gear.auction(g)
		for k in Gear.AUC_LOTS - 1:
			var p2 := int(B["price"])
			autumn_ok = autumn_ok and p2 >= 180 and p2 <= 320
			au += 1
			Gear.auction_pass(g)
			Gear.auction_next_lot(g)
	ok(spring_ok and sp == 12, "炼气春拍：小件起拍都在 55–90（%d 件）" % sp)
	ok(autumn_ok and au == 12, "炼气秋拍：小件起拍都在 180–320（%d 件）" % au)

func t_array() -> void:
	var g = fresh(12)
	g.s["lingshi"] = 100
	ok(Econ.can_build(g) == "" and Econ.build(g) and int(g.s["lingshi"]) == 70, "布一阶聚灵阵：30 灵石")
	ok(Econ.can_build(g) != "", "二阶要筑基")
	var v0 := 12
	var e: Dictionary = Econ.E(g)
	e["sec_run"] = 0
	ok(Econ.biguan_xw(g, v0) == 14, "一阶聚灵阵：闭关 12 → 14（+20%）")
	g.s["lingshi"] = 0
	while (int(g.s["day"]) - 1) % 12 + 1 != 12:
		g.tick("road")
	g.tick("road")
	ok(bool(Econ.E(g)["arr_off"]) and Econ.arr_pct(g) == 0, "正月交不上年费：阵法停了，不再加成")
	g.s["lingshi"] = 10
	g.tick("road")
	ok(not bool(Econ.E(g)["arr_off"]) and int(g.s["lingshi"]) == 10 - Econ.ARR[1]["fee"], "有了钱自动补上年费，阵法又转（扣 %d）" % Econ.ARR[1]["fee"])
	# 服丹
	g.s["store"]["pill_juqi"] = 2
	Econ.set_fudan(g, true)
	e = Econ.E(g)
	e["sec_run"] = 0
	var got := Econ.biguan_xw(g, 12)
	ok(got == 12 + 12 * 70 / 100 and g.store_n("pill_juqi") == 1, "服丹闭关：吃一颗，这个月 +50%%（连阵法 +70%%，得 %d）" % got)
	for i in 5:
		Econ.biguan_xw(g, 12)
	ok(g.store_n("pill_juqi") == 1, "一颗管六个月")
	Econ.biguan_xw(g, 12)
	ok(g.store_n("pill_juqi") == 0, "第七个月吃下一颗")
	for i in 6:
		Econ.biguan_xw(g, 12)
	ok(not bool(Econ.E(g)["fudan"]), "仓里没丹了，服丹闭关自动关掉")

func t_dust() -> void:
	var g = fresh(13)
	var e: Dictionary = Econ.E(g)
	e["sec_run"] = Econ.DUST_MONTHS
	ok(Econ.biguan_xw(g, 12) == 6, "连着闭关过三年：所得减半")
	g.tick("road")
	g.tick("road")
	ok(not Econ.dusty(g) and int(Econ.E(g)["sec_run"]) <= 1, "出门走两个月，蒙尘洗净（%d）" % int(Econ.E(g)["sec_run"]))
	ok(Econ.biguan_xw(g, 12) == 12, "洗净后照常")

func t_market() -> void:
	var g = fresh(14)
	g.s["loc"] = "roam"
	g.s["roam"] = {"pl": "坊市"}
	g.s["store"]["pill_juqi"] = 6
	g.s["lingshi"] = 0
	var got := 0
	for i in 6:
		var p := Econ.pill_price(g, "pill_juqi")
		Econ.sell_pill(g, "pill_juqi")
		got += p
	ok(int(g.s["lingshi"]) == got and got > 0, "聚气丹卖给药铺：六颗得 %d 灵石（前四颗足价，再多减半）" % got)
	g.s["store"]["crop_linggu"] = 25
	ok(Econ.sell_linggu(g) and g.store_n("crop_linggu") == 15, "灵谷十斗一批卖粮铺")
	g.s["xiuwei"] = 1500   # 炼气七层以上
	g.s["lingshi"] = 200
	ok(Econ.ice_lian_available(g) and Econ.buy_ice_lian(g) and g.total_n("herb_hantanlian") == 1 and int(g.s["lingshi"]) == 200 - Econ.ICE_LIAN_PRICE, "炼气七层以后，药铺冰鉴寒潭莲 %d 灵石，没水田的人也买得到" % Econ.ICE_LIAN_PRICE)
	ok(not Econ.ice_lian_available(g), "手里有莲了就不再卖")
	g.s["store"]["herb_qingzhi"] = 400
	g.s["loc"] = "home"
	while (int(g.s["day"]) - 1) % 12 + 1 != 12:
		g.tick("road")
	g.tick("biguan")
	ok(g.store_n("herb_qingzhi") < 400 and g.store_n("herb_qingzhi") >= 370, "仓里青芝过两百：正月陈掉多出部分的一成（%d）" % g.store_n("herb_qingzhi"))

func t_lifespan() -> void:
	var g = fresh(15)
	var lim0: int = g.shou_limit_y()
	var same := true
	for i in 30:
		g.tick("biguan")
		same = same and g.shou_limit_y() == lim0
	ok(same, "寿元上限三十个月里一直是 %d 岁（不再 99/100 横跳）" % lim0)

func t_rules_untouched() -> void:
	# 没开江湖（v3.2 规则测试的口径）：经济层一律不生效
	var h = GS.new()
	h.new_game("测试", "sect", 24)
	h.s["ration"] = 30
	var x0: int = h.I("xiuwei")
	for i in 70:
		h.tick("biguan")
	ok(not h.s.has("econ") or Econ.summary(h).get("arr", 0) == 0, "没开江湖：不建经济账")
	var x1: int = h.I("xiuwei")
	for i in 10:
		h.tick("biguan")
	ok(h.I("xiuwei") - x1 == 120 or h.at_gate(), "没开江湖：闭关第七十个月以后照样每月 12（不蒙尘，%d）" % (h.I("xiuwei") - x1))
