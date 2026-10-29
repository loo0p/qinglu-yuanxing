extends SceneTree
## v0.15（Gemini v7 P0·经济）：送礼门槛 / 托售、拍卖价带、聚灵阵年费、服丹闭关、蒙尘、药铺、寿元上限显示、老龟给莲子
const GS = preload("res://scripts/game_state.gd")
const Gear = preload("res://scripts/gear.gd")
const Econ = preload("res://scripts/econ.gd")
const Jobs = preload("res://scripts/jobs.gd")
const Estate = preload("res://scripts/estate.gd")
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
	t_jobs()
	t_noworld_seclude()
	t_newplace_merge()
	t_estate()
	t_teach_tu()
	t_barter()
	t_estate_old_save()
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

func _to_market(g) -> void:
	g.s["loc"] = "roam"
	g.s["roam"] = {"pl": "坊市", "si": -1}

func t_jobs() -> void:
	var g = fresh(16)
	_to_market(g)
	ok(Jobs.can_comm(g) != "" and Jobs.can_bty(g) != "" and Jobs.can_kq(g) != "", "炼气：代炼、悬赏、客卿都接不到")
	g._raise_to(9)
	g.s["ration"] = 60
	g.s["store"]["herb_qingzhi"] = 40
	g.s["lingshi"] = 100
	ok(Jobs.can_kq(g) != "", "名声不到 2，坊市不请客卿")
	ok(Jobs.take_comm(g) and g.store_n("herb_qingzhi") == 30 and int(g.s["lingshi"]) == 100 - Jobs.COMM_FUEL[1] and Jobs.furnace_busy(g), "筑基接代炼：搭 10 株青芝、付地火钱，丹炉被占")
	g.s["queue"] = [["juqi", 2]]
	g.tick("road")
	ok(int(g.s["queue"][0][1]) == 2, "代炼占炉时自家的丹不走火候")
	for i in 3:
		g.tick("road")
	ok(not Jobs.furnace_busy(g), "四个月后这一单交了")
	var ls1 := int(g.s["lingshi"]) - (100 - Jobs.COMM_FUEL[1])
	ok(ls1 > 0 or int(Jobs.E(g).get("comm_fail", 0)) == 1, "成了得灵石（%d），炸了赔料钱" % ls1)
	var lg: Array = g.world.P()["log"]
	ok(lg[-1].size() == 3 and (lg[-1][2] as Dictionary).has("灵石"), "履历记一条带效果标签：%s %s" % [lg[-1][1], str(lg[-1][2])])
	var rep0 := int(Jobs.E(g)["rep"])
	ok(Jobs.take_bty(g), "揭悬赏")
	var e: Dictionary = Jobs.E(g)
	var rg: Array = Jobs.bty_range(g)
	ok(int(e["rep"]) == rep0 + 1 and int(e["jobs_cost"]) == Jobs.COMM_FUEL[1] + Jobs.BTY_KIT[1] and int(e["jobs_ls"]) - maxi(0, ls1) >= int(rg[0]) / 2 - 3, "悬赏办完：名声 +1、得赏（累计差事 %d 灵石）" % int(e["jobs_ls"]))
	ok(Jobs.can_bty(g) != "", "榜上半年才有新的（或带着伤）")
	e["rep"] = 2
	g.s["injured"] = 0
	_to_market(g)
	var ls2 := int(g.s["lingshi"])
	ok(Jobs.sit_kq(g) and int(e["kq"]) == 1 and int(g.s["lingshi"]) >= ls2 + Jobs.KQ_PAY[1] / 2, "应下客卿：坐镇一个月，先领半年俸")
	for i in 30:
		g.tick("road")
	g.s["injured"] = 0
	_to_market(g)
	ok(Jobs.kq_due(g) == 2, "隔了两年半回来，攒了两年的俸")
	var ls3 := int(g.s["lingshi"])
	Jobs.sit_kq(g)
	ok(int(g.s["lingshi"]) >= ls3 + 2 * Jobs.KQ_PAY[1], "坐镇一个月，领两年 %d 灵石" % (2 * Jobs.KQ_PAY[1]))
	for i in 38:
		g.tick("road")
	ok(int(Jobs.E(g)["kq"]) == -1, "三年多没回来坐镇：客卿之位另请了人")

func t_noworld_seclude() -> void:
	var h = GS.new()
	h.new_game("测试", "sect", 24)
	h.s["ration"] = 200
	ok(h.biguan("years", 3) == 36, "没开江湖闭关三年：不崩（_seclude_year_note 没有江湖时不写）")

func t_newplace_merge() -> void:
	var h = GS.new()
	h.new_game("测试", "sect", 25)
	var n0: int = h.s["log"].size()
	h._log("新去处：后山。")
	h._log("采了些青芝。")
	h._log("新去处：坊市。")
	ok(h.s["log"].size() == n0 + 2 and String(h.s["log"][n0]["text"]).begins_with("新去处：后山、坊市"), "同一个月隔了别的行记，新去处也并成一条")
	h.s["seclude"] = true
	h.s["sec_m0"] = int(h.s["day"])
	h.s["day"] = int(h.s["day"]) + 7
	h._log("新去处：寒潭。")
	h.s.erase("seclude")
	h.s.erase("sec_m0")
	ok(h.s["log"].size() == n0 + 2 and String(h.s["log"][n0]["text"]).contains("寒潭"), "一次长闭关里陆续认得的路，并进同一条")
	h._log("新去处：药谷。")
	ok(h.s["log"].size() == n0 + 3, "出关以后另起一条")

func _home(g) -> void:
	g.s["loc"] = "home"
	g.s["roam"] = {}

func _last_fx(g) -> Dictionary:
	var lg: Array = g.world.P()["log"]
	return lg[-1][2] if lg[-1].size() >= 3 and lg[-1][2] is Dictionary else {}

## v0.16：灵圃 / 客舍：造价、每年正月用度、欠了就停、补上再开；灵圃出紫芝；履历带效果
func t_estate() -> void:
	var g = fresh(31)
	_home(g)
	ok(Estate.can_build(g, "pu1") != "", "炼气辟不了灵圃")
	g._raise_to(9)
	g.s["lingshi"] = 200
	ok(Estate.build(g, "pu1") and int(g.s["lingshi"]) == 120 and int(Estate.E(g)["pu"]) == 1, "筑基辟灵圃：−80 灵石")
	ok(String(g.world.P()["log"][-1][1]).contains("灵圃") and int(_last_fx(g).get("灵石", 0)) == -80, "履历一条带效果：%s" % str(_last_fx(g)))
	ok(Estate.can_build(g, "pu2") != "", "二阶灵圃要结丹")
	ok(Estate.build(g, "ke") and int(Estate.E(g)["ke"]) == 1 and int(g.s["lingshi"]) == 60, "建客舍：−60 灵石")
	var z0: int = g.store_n(Estate.ZIZHI)
	for i in Estate.PU_MONTHS[1]:
		g.tick("biguan")
		g.world.auto_choose()
		g.world.close()
	ok(g.store_n(Estate.ZIZHI) == z0 + 1, "灵圃九个月出一株紫芝")
	# 到下一个正月：交用度 8 + 6
	while (int(g.s["day"]) - 1) % 12 + 1 != 12:
		g.tick("biguan")
	g.s["lingshi"] = 100
	g.tick("biguan")
	ok(int(g.s["lingshi"]) == 100 - 14 and int(Estate.E(g)["est_y"]) == (int(g.s["day"]) - 1) / 12, "正月交用度 14 灵石")
	for i in 11:
		g.tick("biguan")
	g.s["lingshi"] = 5
	var pr0 := int(Estate.E(g)["pu_prog"])
	g.tick("biguan")
	ok(bool(Estate.E(g)["est_off"]) and int(Estate.E(g)["pu_prog"]) == pr0, "用度交不上：灵圃停着不长")
	ok(String(g.world.P()["log"][-1][1]).contains("用度"), "欠用度写进履历")
	g.s["lingshi"] = 50
	g.tick("biguan")
	ok(not bool(Estate.E(g)["est_off"]) and int(g.s["lingshi"]) == 36, "有钱了补上用度，灵圃接着长")

func _junior(g, lv: int) -> Dictionary:
	var W = g.world
	for c in W.npcs():
		if int(c.get("sbg", 0)) <= int(W.w["day"]):
			c["lv"] = lv
			W.R(W.P(), c)["m"] = 1
			return c
	return {}

## v0.16：指点后辈（复用 jiang）、收徒（要客舍；复用 echo_tu）
func t_teach_tu() -> void:
	var g = fresh(47)
	_home(g)
	g._raise_to(9)
	var W = g.world
	ok(Estate.can_teach(g) != "" or Estate.cands(g, 3).size() > 0, "指点要有比她低三个小境界的熟人")
	var c := _junior(g, 2)
	ok(not c.is_empty() and Estate.can_teach(g) == "", "筑基、在家、有后辈：能指点")
	var xp0 := float(c["xp"])
	var n0: int = W.P()["log"].size()
	var d0 := int(g.s["day"])
	ok(Estate.teach(g, int(c["id"])) == "", "指点一回")
	ok(int(g.s["day"]) == d0 + 1, "在家耗一个月")
	ok(float(c["xp"]) > xp0 or int(c["lv"]) > 2, "后辈修为精进")
	var hit := false
	for i in range(n0, W.P()["log"].size()):
		var e: Array = W.P()["log"][i]
		if e.size() >= 3 and not (e[2] as Dictionary).is_empty():
			hit = true
	ok(W.P()["log"].size() > n0 and hit, "履历里有指点的一条，带效果小字")
	ok(Estate.can_teach(g) != "", "一年一回")
	ok(Estate.can_take_tu(g) == "先建客舍", "收徒要先建客舍")
	g.s["lingshi"] = 200
	Estate.build(g, "ke")
	ok(Estate.can_take_tu(g) == "", "建了客舍能收徒")
	var q0: int = W.saga().eng.st["q"].size()
	ok(Estate.take_tu(g, int(c["id"])) == "", "收徒")
	ok("徒" in W.R(W.P(), c)["t"] and "师" in W.R(c, W.P())["t"], "师徒名分")
	ok(W.saga().eng.st["q"].size() == q0 + 1 and String(W.saga().eng.st["q"][-1][1]) == "echo_tu", "排上了履历包的“收徒的回响”")
	ok(String(W.P()["log"][-1][1]).contains("为徒") and _last_fx(g).has("收徒"), "履历：%s %s" % [W.P()["log"][-1][1], str(_last_fx(g))])
	ok(Estate.can_take_tu(g) != "", "客舍里只留一个徒弟")
	ok(Estate.fee(g) == Estate.BUILD["ke"]["fee"] + Estate.TU_FEE, "用度里加上徒弟月例")
	# 回响到期：走 echo_tu，写进她的履历
	var it: Array = W.saga().eng.st["q"][-1]
	it[0] = W.saga().eng.now()
	var n1: int = W.P()["log"].size()
	W.saga().daily()
	var echo := false
	for i in range(n1, W.P()["log"].size()):
		if String(W.P()["log"][i][1]).contains(String(c["name"])):
			echo = true
	ok(echo, "收徒的回响到期写进她的履历")
	c["alive"] = false
	g.tick("biguan")
	ok(int(Estate.E(g)["tu"]) == -1, "徒弟不在了，客舍空出来")

## v0.16：货郎以物易物：一年三样、每样一年一回、仓里不够换不了、履历带效果
func t_barter() -> void:
	var g = fresh(58)
	_to_market(g)
	ok(Estate.offers(g).is_empty(), "炼气没有货郎")
	g._raise_to(9)
	_to_market(g)
	var ofs: Array = Estate.offers(g)
	ok(ofs.size() == 3 and ofs == Estate.offers(g), "筑基：货郎一年带三样（同一年不变）")
	for id in ["crop_linggu", "herb_qingzhi", Estate.ZIZHI, "pill_quzhang", "herb_xugucao", "pill_juqi"]:
		g.s["store"][id] = 0
	g.s["store"].clear()
	var i: int = ofs[0]
	ok(Estate.can_barter(g, i).begins_with("仓里"), "仓里不够换不了")
	for id in Estate.BARTER[i]["give"]:
		g.s["store"][id] = int(Estate.BARTER[i]["give"][id])
	var ls0 := int(g.s["lingshi"])
	ok(Estate.barter(g, i) == "", "换了：%s" % Estate.offer_text(g, i))
	var got_ok := true
	for id in Estate.BARTER[i]["get"]:
		got_ok = got_ok and g.store_n(id) == int(Estate.BARTER[i]["get"][id])
	for id in Estate.BARTER[i]["give"]:
		got_ok = got_ok and g.store_n(id) == 0
	ok(got_ok and int(g.s["lingshi"]) == ls0, "东西换过来，灵石不动")
	ok(String(g.world.P()["log"][-1][1]).contains("以物易物") and _last_fx(g).size() >= 2, "履历带效果：%s" % str(_last_fx(g)))
	for id in Estate.BARTER[i]["give"]:
		g.s["store"][id] = 99
	ok(Estate.can_barter(g, i) == "今年换过了", "每样一年一回")
	var notin := -1
	for k in Estate.BARTER.size():
		if not (k in ofs):
			notin = k
	ok(Estate.can_barter(g, notin) != "", "货单上没有的换不了")
	g.s["store"][Estate.ZIZHI] = 2
	var ls1 := int(g.s["lingshi"])
	ok(Estate.sell_zizhi(g) and int(g.s["lingshi"]) == ls1 + Estate.zizhi_price(g), "紫芝卖给药铺")

## 旧档（没有 v0.16 字段）读进来照常
func t_estate_old_save() -> void:
	var g = fresh(77)
	g._raise_to(9)
	var d: Dictionary = g.to_dict()
	var e: Dictionary = d.get("econ", {}) if d.has("econ") else {}
	var h = GS.new()
	ok(h.from_dict(JSON.parse_string(JSON.stringify(d))), "存档读回")
	h.s["econ"] = {"arr": 1}
	ok(Estate.fee(h) == 0 and Estate.text(h).contains("还没有") and int(Estate.E(h)["tu"]) == -1, "旧档没有营建字段：按需补上")
	h.tick("biguan")
	ok(int(h.s["econ"]["arr"]) == 1, "旧档的聚灵阵不动")
