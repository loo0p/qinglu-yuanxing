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
	t_job_fold()
	t_echo_align()
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

const _NUMS := "0123456789一二三四五六七八九十百千零两"

func _norm(t: String) -> String:
	var s := ""
	var prev := false
	for i in t.length():
		var ch := t.substr(i, 1)
		if _NUMS.contains(ch):
			if not prev:
				s += "#"
			prev = true
		else:
			prev = false
			s += ch
	return s

func _sync(g, d: int) -> void:
	g.s["day"] = d
	if g.world != null:
		g.world.w["day"] = d

func _jobs_month(g) -> void:
	g.s["day"] = int(g.s["day"]) + 1
	Jobs.monthly(g)
	g.world.w["day"] = int(g.s["day"])

func _folds(g, kind: String) -> Array:
	var out := []
	for e in g.world.P()["log"]:
		if e.size() >= 3 and e[2] is Dictionary and String(e[2].get("_fold", "")) == kind:
			out.append(e)
	return out

## v0.16.1：平静的代炼 / 客卿 / 悬赏 / 货郎不再逐次占一条；效果小字按次累加。
## 对照：v0.16.0 每一炉成功都是同一句「替坊市药铺代炼一炉丹，成了。」
func t_job_fold() -> void:
	var g = fresh(31)
	var shown: String = g.world.fx_text({"_fold": "comm", "_n": 3, "_what": "追妖", "灵石": 80, "名声": 2})
	ok(shown == "灵石+80  名声+2", "纪要内部标记不进效果小字：%s" % shown)
	ok(g.world.fx_text({"孟微好感": 4, "对孟微好感": 5}) == "与孟微好感+5/+4", "两个方向的好感并成一条")
	g._raise_to(9)
	var succ := 0
	var fail_n := 0
	var net := 0
	for y in 4:
		_sync(g, y * 12 + 1)
		var ec: Dictionary = Jobs.E(g)
		ec["comm"] = []
		ec["comm_n"] = 0
		ec["comm_y"] = -99
		for k in 6:
			g.s["store"]["herb_qingzhi"] = 40
			g.s["lingshi"] = 800
			_to_market(g)
			if not Jobs.take_comm(g):
				ok(false, "第 %d 年第 %d 炉接不上：%s" % [y + 1, k + 1, Jobs.can_comm(g)])
				return
			Jobs.E(g)["comm"][-1][0] = 1
			var ls0 := int(g.s["lingshi"])
			_jobs_month(g)
			var dls := int(g.s["lingshi"]) - ls0
			net += dls
			if dls > 0:
				succ += 1
			else:
				fail_n += 1
	var folds: Array = _folds(g, "comm")
	var booms := 0
	var ls_sum := 0
	var rep_sum := 0
	var old_exact := 0
	var norms := {}
	for e in g.world.P()["log"]:
		var t := String(e[1])
		if t == "替坊市药铺代炼一炉丹，成了。":
			old_exact += 1
		var is_boom: bool = t.contains("炸") and t.contains("料钱")
		var is_fold: bool = e.size() >= 3 and e[2] is Dictionary and String(e[2].get("_fold", "")) == "comm"
		if not is_boom and not is_fold:
			continue
		ok(t.length() <= 150, "代炼正文 ≤150 字（%d）%s" % [t.length(), t])
		if e.size() < 3 or not (e[2] is Dictionary) or g.world.fx_text(e[2]) == "":
			ok(false, "代炼履历挂了空效果：%s" % t)
			continue
		ls_sum += int(e[2].get("灵石", 0))
		rep_sum += int(e[2].get("名声", 0))
		if is_boom:
			booms += 1
	for e2 in folds:
		var key := _norm(String(e2[1]))
		norms[key] = int(norms.get(key, 0)) + 1
	var maxn := 0
	var maxk := ""
	for k2 in norms:
		if int(norms[k2]) > maxn:
			maxn = int(norms[k2])
			maxk = String(k2)
	lines.append("代炼对照：成 %d 炉、炸 %d 炉；纪要 %d 条；旧句「成了。」%d 次；去数字后最常见纪要「%s」×%d。v0.16.0 逐次落条则同一句 %d 次。" % [succ, fail_n, folds.size(), old_exact, maxk, maxn, succ])
	ok(succ >= 12, "样本里成丹至少 12 炉（%d）" % succ)
	ok(old_exact == 0, "不再逐次写「替坊市药铺代炼一炉丹，成了。」")
	ok(folds.size() >= 1 and folds.size() * 2 <= succ, "纪要条数远少于成丹次数（%d 条 / %d 炉）" % [folds.size(), succ])
	ok(maxn >= 1 and maxn * 3 <= succ, "去数字后最常见的代炼纪要远少于成丹次数（%d vs %d）" % [maxn, succ])
	ok(booms == fail_n, "炸炉仍逐次单记（%d 条 / %d 炉）" % [booms, fail_n])
	ok(ls_sum == net, "代炼效果小字的灵石合计等于实际进出（%d / %d）" % [ls_sum, net])
	ok(rep_sum == succ, "名声按成丹次数累加（%d / %d）" % [rep_sum, succ])
	# 客卿：同一十年里只挑平静的坐镇，并成一条
	_sync(g, 121)
	Jobs.E(g)["rep"] = 5
	Jobs.E(g)["kq"] = -1
	g.s["injured"] = 0
	g.s["shouyuan"] = 8000
	var sits := 0
	var expect := 0
	var guard := 0
	while sits < 6 and guard < 40:
		guard += 1
		if (maxi(int(g.s["day"]), 1) - 1) / 120 != 1:
			break
		_to_market(g)
		g.s["injured"] = 0
		g.s["lingshi"] = 500
		# 坐镇先过一个月，闹事的骰子用的是过完那个月的日子
		var r := Gear._rng_for(g, 9300 + int(g.s["day"]) + 1)
		if r.randi_range(1, 100) <= 20:
			_sync(g, int(g.s["day"]) + 1)
			continue
		var due := Jobs.kq_due(g)
		var pay := Jobs.kq_pay(g)
		var first := int(Jobs.E(g)["kq"]) < 0
		if not Jobs.sit_kq(g):
			ok(false, "坐镇失败：%s" % Jobs.can_kq(g))
			return
		expect += pay / 2 if first else due * pay
		sits += 1
		var nxt := int(g.s["day"]) + 12
		if (maxi(nxt, 1) - 1) / 120 != 1:
			break
		_sync(g, nxt)
	var kq: Array = _folds(g, "kq")
	var old_kq := 0
	var kq_ls := 0
	for e3 in g.world.P()["log"]:
		var t3 := String(e3[1])
		if t3.begins_with("回坊市坐镇一个月，领了") or t3.begins_with("应了坊市的客卿，坐镇一个月。往后三年内"):
			old_kq += 1
		if e3.size() >= 3 and String(e3[2].get("_fold", "")) == "kq":
			kq_ls += int(e3[2].get("灵石", 0))
			ok(g.world.fx_text(e3[2]) != "", "客卿纪要有效果：%s" % t3)
	lines.append("客卿对照：平静坐镇 %d 回并成 %d 条；旧逐次句 %d 次（v0.16.0 是 %d 条）。" % [sits, kq.size(), old_kq, sits])
	ok(sits >= 4, "样本里平静坐镇至少 4 回（%d）" % sits)
	ok(kq.size() == 1, "同一十年的平静坐镇并成一条（%d）" % kq.size())
	ok(old_kq == 0, "平静坐镇不再用旧的逐次句")
	ok(kq_ls == expect, "客卿纪要的灵石等于这几回领到的（%d / %d）" % [kq_ls, expect])
	# 悬赏：每年两回平静办成，并成当年一条
	var bty_n := 0
	var bty_ls0 := int(Jobs.E(g)["jobs_ls"])
	for y2 in 3:
		var cursor := y2 * 12 + 1
		var placed := 0
		while placed < 2 and cursor < y2 * 12 + 12:
			_sync(g, cursor)
			_to_market(g)
			g.s["injured"] = 0
			g.s["lingshi"] = 500
			Jobs.E(g)["bty_d"] = cursor - 6
			var rb := Gear._rng_for(g, 9500 + cursor)
			var rg: Array = Jobs.bty_range(g)
			rb.randi_range(int(rg[0]), int(rg[1]))
			if rb.randi_range(1, 100) <= Jobs.BTY_HURT:
				cursor += 1
				continue
			if not Jobs.take_bty(g):
				ok(false, "揭悬赏失败：%s" % Jobs.can_bty(g))
				return
			bty_n += 1
			placed += 1
			cursor = int(g.s["day"]) + 1
	var bty: Array = _folds(g, "bty")
	var bty_ls := 0
	var bty_rep := 0
	var old_bty := 0
	for e4 in bty:
		bty_ls += int(e4[2].get("灵石", 0))
		bty_rep += int(e4[2].get("名声", 0))
		ok(g.world.fx_text(e4[2]) != "", "悬赏纪要有效果：%s" % e4[1])
		if String(e4[1]).ends_with("办成了。") and String(e4[1]).begins_with("揭了坊市的悬赏"):
			old_bty += 1
	lines.append("悬赏对照：平静办成 %d 回，纪要 %d 条（v0.16.0 是 %d 条逐次「办成了。」）。" % [bty_n, bty.size(), bty_n])
	ok(bty_n >= 4 and bty.size() < bty_n, "悬赏纪要少于办成次数（%d / %d）" % [bty.size(), bty_n])
	ok(old_bty == 0, "平静办成不再逐次写「揭了坊市的悬赏…办成了。」")
	ok(bty_rep == bty_n, "悬赏名声按回累加（%d / %d）" % [bty_rep, bty_n])
	ok(bty_ls == int(Jobs.E(g)["jobs_ls"]) - bty_ls0, "悬赏纪要的灵石等于这几回赏钱（%d / %d）" % [bty_ls, int(Jobs.E(g)["jobs_ls"]) - bty_ls0])
	# 货郎：同一年三回并成一条，两年两条；东西按次累加
	for id in ["crop_linggu", "herb_qingzhi", "herb_zizhi", "pill_quzhang", "herb_xugucao", "pill_juqi"]:
		g.s["store"][id] = 400
	for y3 in 2:
		_sync(g, (y3 + 3) * 12 + 2)
		_to_market(g)
		var ofs: Array = Estate.offers(g)
		var exp := {}
		for i in ofs:
			for id2 in Estate.BARTER[i]["give"]:
				g.s["store"][id2] = int(g.s["store"].get(id2, 0)) + int(Estate.BARTER[i]["give"][id2])
			ok(Estate.barter(g, i) == "", "换物 %s" % Estate.offer_text(g, i))
			for id3 in Estate.BARTER[i]["give"]:
				var nm := String(g.NAMES.get(id3, id3))
				exp[nm] = int(exp.get(nm, 0)) - int(Estate.BARTER[i]["give"][id3])
			for id4 in Estate.BARTER[i]["get"]:
				var nm2 := String(g.NAMES.get(id4, id4))
				exp[nm2] = int(exp.get(nm2, 0)) + int(Estate.BARTER[i]["get"][id4])
		var hit: Array = []
		for e5 in _folds(g, "bar"):
			if (maxi(int(e5[0]), 1) - 1) / 12 == y3 + 3:
				hit = e5
		ok(not hit.is_empty() and int(hit[2].get("_n", 0)) == ofs.size(), "第 %d 年货郎 %d 回并成一条（%s）" % [y3 + 1, ofs.size(), hit[1] if not hit.is_empty() else ""])
		if hit.is_empty():
			continue
		ok(g.world.fx_text(hit[2]) != "" and not g.world.fx_text(hit[2]).contains("_fold"), "货郎纪要小字不空：%s" % g.world.fx_text(hit[2]))
		for nm3 in exp:
			ok(int(hit[2].get(nm3, 0)) == int(exp[nm3]), "货郎 %s 合计 %s，记了 %s" % [nm3, str(exp[nm3]), str(hit[2].get(nm3, 0))])
	ok(_folds(g, "bar").size() == 2, "两年货郎两条纪要，不是六条（%d）" % _folds(g, "bar").size())

## 结怨回响说的药，就是当初争的那一株；指点的正文点到被指点的人，好感不挂到旁的句子上。
func t_echo_align() -> void:
	var herbs := ["百年黄精", "雪莲", "血灵芝", "龙涎草", "紫金藤", "寒铁"]
	var g0 = fresh(5)
	var gram: Dictionary = g0.world.saga().eng.grammar
	for k in ["q_jiang_0", "q_jiang_1", "q_jiang_2", "q_jiang_3"]:
		for line in gram[k]:
			ok(String(line).contains("{B}"), "%s 每句都点到被指点的人：%s" % [k, line])
	for line2 in gram["q_feud"]:
		ok(String(line2).contains("{herb}") and not String(line2).contains("#q_herb#"), "结怨正文用已经定下的那株药：%s" % line2)
	for line3 in gram["q_echo_jiang"]:
		ok(String(line3).contains("{B}") and String(line3).contains("点拨"), "指点回响点到人：%s" % line3)
	g0._raise_to(12)
	var W0 = g0.world
	var b0 := {}
	for c0 in W0.npcs():
		if bool(c0.get("alive", false)):
			W0.R(W0.P(), c0)["m"] = 1
			b0 = c0
			break
	var n0: int = W0.P()["log"].size()
	ok(W0.saga().eng.fire("jiang", {"A": W0.P(), "B": b0}, {"sec": 0, "road": 0, "maj": 2}), "指点发出")
	var named := false
	var orphan := false
	for i in range(n0, W0.P()["log"].size()):
		var e0: Array = W0.P()["log"][i]
		var tx := String(e0[1])
		var fx0: Dictionary = e0[2] if e0.size() >= 3 and e0[2] is Dictionary else {}
		var rel := false
		for kk in fx0:
			var ks := String(kk)
			if ks.contains(String(b0["name"])) and (ks.contains("好感") or ks.contains("印象")):
				rel = true
		if rel and String(b0["name"]) in tx:
			named = true
		if rel and String(b0["name"]) not in tx:
			orphan = true
	ok(named and not orphan, "指点的好感挂在点了%s名字的那一条上" % b0["name"])
	var matched := 0
	for sd in [3, 11, 23, 31, 47, 58]:
		var g = fresh(int(sd))
		g._raise_to(9)
		var W = g.world
		var b := {}
		for c in W.npcs():
			if bool(c.get("alive", false)) and int(c["lv"]) <= int(g.plv_now()):
				b = c
				break
		if b.is_empty():
			ok(false, "种子 %d 没有可结怨的人" % sd)
			continue
		var n1: int = W.P()["log"].size()
		ok(W.saga().eng.fire("feud", {"A": W.P(), "B": b}, {"sec": 0, "road": 1, "maj": 1}), "种子 %d 结怨发出" % sd)
		var told := ""
		for j in range(n1, W.P()["log"].size()):
			var tj := String(W.P()["log"][j][1])
			if tj.contains(String(b["name"])):
				told = tj
		var herb := ""
		for h in herbs:
			if h in told:
				herb = h
		var saved := ""
		var slot: Array = []
		for it in W.saga().eng.st["q"]:
			if String(it[1]) == "echo_feud":
				saved = String(it[3].get("herb", ""))
				slot = it
		ok(herb != "" and herb == saved, "种子 %d 结怨正文与回响是同一株（%s / %s）%s" % [sd, herb, saved, told])
		if herb == "" or herb != saved or slot.is_empty():
			continue
		matched += 1
		slot[0] = W.saga().eng.now()
		var n2: int = W.P()["log"].size()
		W.saga().daily()
		var echo := ""
		for j2 in range(n2, W.P()["log"].size()):
			if herb in String(W.P()["log"][j2][1]):
				echo = String(W.P()["log"][j2][1])
		ok(echo != "", "种子 %d 回响里还是%s：%s" % [sd, herb, echo])
	ok(matched == 6, "六个种子的结怨药名前后一致（%d）" % matched)

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
