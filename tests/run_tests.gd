extends SceneTree
## 《青庐远行》灰盒 · 候选代码 · 无头测试
## 运行：godot --headless --path /workspace/qinglu -s res://tests/run_tests.gd
## 覆盖验收 #1（与 sim.py 逐日一致）、#2（结算 6 步单元测试）、#3（防刷）、#4（老龟每个选项都改变后续）、
## #5（心魔覆盖校验器）、#6（无卡死矩阵），外加存读档往返。

const GS = preload("res://scripts/game_state.gd")
var passes = 0
var fails = 0
var out: PackedStringArray = []

func p(t: String) -> void:
	out.append(t)
	print(t)

func ok(cond: bool, name: String) -> bool:
	if cond:
		passes += 1
	else:
		fails += 1
		p("  ✗ " + name)
	return cond

func _init() -> void:
	p("=== 青庐远行 灰盒 候选代码 无头测试 ===")
	var sections = [["#1 灰盒均衡路线逐日对照 sim.py", "t_replay"], ["#2 结算顺序单元测试", "t_settlement"],
		["#3 防刷", "t_antifarm"], ["#4 老龟四选项改变后续", "t_keychoice"], ["#5 心魔覆盖校验器", "t_xinmo"],
		["#6 无卡死矩阵", "t_deadlock"], ["存读档往返（中途存档→重载→结果一致）", "t_save"]]
	var summary = []
	for sec in sections:
		var f0 = fails
		var p0 = passes
		p("--- " + sec[0])
		call(sec[1])
		var st = "PASS" if fails == f0 else "FAIL"
		summary.append("%s  %s（断言 %d 通过 / %d 失败）" % [st, sec[0], passes - p0, fails - f0])
	p("=== 汇总 ===")
	for l in summary:
		p(l)
	p("总计：%d 通过，%d 失败" % [passes, fails])
	var f = FileAccess.open("res://tests/results.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(out) + "\n")
	quit(1 if fails > 0 else 0)

# ------------------------------------------------------------ 策略（与 sim.py home_ops 同义，全部经引擎 API）
func home_ops(g, plan: Dictionary, reserve: int) -> void:
	g.eat_all(reserve)
	var need_q = int(plan.get("quzhang", 0)) - g.total_n("pill_quzhang")
	for q in g.s["queue"]:
		if q[0] == "quzhang":
			need_q -= 1
	for i in maxi(0, need_q):
		g.enqueue("quzhang")
	var zj_q: bool = g.zhuji_in_progress() or g.total_n("pill_zhuji") > 0
	var lg: bool = g.store_n("herb_hantanlian") > 0 and g.store_n("herb_chiyangguo") > 0
	while g.I("juqi_brewed") < 8 + int(g.s["flags"].get("juqi_given", 0)) and g.store_n("herb_qingzhi") >= 2 + (3 if (lg and not zj_q) else 0):
		if not g.enqueue("juqi"):
			break
	if lg and not zj_q and g.store_n("herb_qingzhi") >= 3:
		g.enqueue("zhuji")

func stay(g, days: int, plan: Dictionary, reserve: int, snaps: Dictionary, tag: String) -> void:
	home_ops(g, plan, reserve)
	snaps["到家整理后 D%d" % g.I("day")] = g.snapshot()
	for i in days:
		home_ops(g, plan, reserve)
		g.biguan_day()
	home_ops(g, plan, reserve)
	snaps["闭关 %d 日后 D%d" % [days, g.I("day")]] = g.snapshot()

func walk(g, picks: Array) -> bool:
	# picks: [[节点, 选项 or ""(快走)], ...]，最后自动走归途
	for pk in picks:
		if not g.enter_node(pk[0]):
			p("    无法进入节点 %s（可选 %s）" % [pk[0], str(g.visible_choices())])
			return false
		var r: Dictionary
		if g.s["trip"]["stage"] == "quick":
			r = g.quick_walk()
		else:
			r = g.resolve(pk[1])
		if r.is_empty():
			p("    节点 %s 选项 %s 无法结算" % [pk[0], pk[1]])
			return false
		g.continue_trip()
		while not g.s["pending_overflow"].is_empty():
			g.resolve_overflow(-1)
		if g.s["loc"] != "trip":
			return true
	return true

func pass_xinmo(g) -> void:
	while g.s["loc"] == "xinmo":
		var q: Dictionary = g.current_xinmo()
		var pick = 0
		for i in q["answers"].size():
			if g.check(q["answers"][i]["consistent_if"]):
				pick = i
				break
		g.answer_xinmo(pick)

# ------------------------------------------------------------ #1
func t_replay() -> void:
	var trace = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/trace_grey.json"))
	var g = GS.new()
	g.new_game("测试", "aunt", 1)
	g.s["debug_zhuji"] = "succeed"
	var got = []
	g.on_tick = func(sn): got.append(sn)
	var snaps = {}
	g.start_trip("houshan")
	ok(walk(g, [["H1", "A"], ["H2a", "A"], ["H3", "A"], ["H4a", "A"], ["H5", "A"]]), "第一趟后山走完")
	g.choose_extra("field")
	stay(g, 2, {}, 0, snaps, "")
	g.load_grain()
	g.buy_rations(10 - g.I("ration"))
	g.start_trip("hantan")
	ok(walk(g, [["T1", "A"], ["T2", "A"], ["T3a", "A"], ["T4", "C"], ["T5", "A"], ["T6", "A"], ["T7", "A"], ["T8", "A"], ["T9", "A"]]), "第二趟寒潭走完")
	ok(g.s["flags"].get("world_xiangyang", false), "世事卡出现（向阳坡 D23）")
	stay(g, 3, {}, 0, snaps, "")
	g.start_trip("houshan")
	ok(walk(g, [["H1", ""], ["Hstar", "A"], ["H5", "A"]]), "第三趟向阳坡走完")
	if g.total_n("herb_chiyangguo") == 0:
		g.buy_gelaosan_fruit()
	home_ops(g, {}, 0)
	snaps["到家整理后 D%d" % g.I("day")] = g.snapshot()
	var guard = 0
	while not (g.I("xiuwei") >= 600 and g.store_n("pill_zhuji") > 0) and guard < 200:
		home_ops(g, {}, 0)
		g.biguan_day()
		guard += 1
	home_ops(g, {}, 0)
	snaps["冲关前 D%d" % g.I("day")] = g.snapshot()
	ok(g.start_breakthrough(), "可以冲关")
	pass_xinmo(g)
	ok(g.s["ending"] == "zhuji", "筑基结局")
	ok(g.I("day") == 37, "筑基日 = D37（引擎 D%d）" % g.I("day"))
	# 逐日比对
	ok(got.size() == trace.size(), "日数一致（引擎 %d 日 / sim %d 日）" % [got.size(), trace.size()])
	var keys = ["day", "mode", "xiuwei", "yuyun", "ganwu", "qingzhi", "ganliang", "lingshi", "lian", "guo"]
	var bad = 0
	for i in mini(got.size(), trace.size()):
		var a: Dictionary = got[i]
		var b: Dictionary = trace[i]
		var diffs = []
		for k in keys:
			if str(a[k]) != str(b[k]).replace(".0", ""):
				diffs.append("%s 引擎=%s sim=%s" % [k, a[k], b[k]])
		var bq = []
		for x in b["queue"]:
			bq.append([String(x[0]), int(x[1])])
		if str(a["queue"]) != str(bq):
			diffs.append("炉 引擎=%s sim=%s" % [a["queue"], bq])
		for k in ["juqi", "zhuji", "quzhang"]:
			if int(a["ready"][k]) != int(b["ready"][k]):
				diffs.append("待取%s 引擎=%d sim=%d" % [k, a["ready"][k], b["ready"][k]])
		if not diffs.is_empty():
			bad += 1
			if bad <= 5:
				p("    D%d 不一致：%s" % [a["day"], "；".join(diffs)])
	ok(bad == 0, "逐日 %d 项字段全部一致（不一致 %d 日）" % [keys.size() + 4, bad])
	# out_grey.txt 快照对照
	var txt = FileAccess.get_file_as_string("res://tests/fixtures/out_grey.txt")
	var re = RegEx.new()
	re.compile("\\[(.+? D\\d+)\\] 修为 (\\d+)（余韵 (\\d+)）待炼化 (\\d+) 青芝 (\\d+) 炉 (\\S+) .*干粮 (\\d+) 灵石 (\\d+)")
	var n = 0
	for m in re.search_all(txt):
		var tag = m.get_string(1)
		n += 1
		if not ok(snaps.has(tag), "快照 [%s] 存在" % tag):
			continue
		var sn: Dictionary = snaps[tag]
		var q = []
		for x in sn["queue"]:
			q.append("%s%d" % [x[0], x[1]])
		var qs = ",".join(q) if q.size() > 0 else "空"
		var exp = [m.get_string(2), m.get_string(3), m.get_string(4), m.get_string(5), m.get_string(6), m.get_string(7), m.get_string(8)]
		var act = [str(sn["xiuwei"]), str(sn["yuyun"]), str(sn["ganwu"]), str(sn["qingzhi"]), qs, str(sn["ganliang"]), str(sn["lingshi"])]
		ok(exp == act, "快照 [%s] 修为/余韵/待炼化/青芝/炉/干粮/灵石 一致 期望 %s 实际 %s" % [tag, exp, act])
	ok(n == 6, "out_grey.txt 快照 6 条（读到 %d）" % n)
	p("  引擎：D%d 筑基；修为来源 %s；闭关占比 %d%%" % [g.I("day"), g.s["src"], roundi(100.0 * (g.s["src"]["biguan"] + g.s["src"]["ganwu"]) / 600.0)])

# ------------------------------------------------------------ #2
func fresh():
	var g = GS.new()
	g.new_game("测试", "aunt", 7)
	return g

func t_settlement() -> void:
	# ① 日初生产：田 +1，6 日一熟 2 株
	var g = fresh()
	g.tick("home")
	ok(int(g.s["fields"][0]["prog"]) == 1, "①田每日 +1")
	for i in 5:
		g.tick("home")
	ok(g.store_n("herb_qingzhi") == 4, "①②两块阳田第 6 日各收 2 株（%d）" % g.store_n("herb_qingzhi"))
	# ①只推进队首 + ⑥同日入炉从下一个日初计时
	g = fresh()
	g.s["store"]["herb_qingzhi"] = 4
	g.s["day"] = 10
	ok(g.enqueue("juqi") and g.enqueue("juqi"), "第 D 日排两颗聚气丹（0 日）")
	ok(g.I("day") == 10 and g.s["queue"][0][1] == 2, "⑥排炉当日不计时")
	g.tick("home")
	ok(g.s["queue"][0][1] == 1 and g.s["queue"][1][1] == 2, "①只推进队首一项")
	g.tick("home")
	ok(g.I("day") == 12 and g.store_n("pill_juqi") == 1, "②第 D+k 日出炉入待取")
	g.tick("home"); g.tick("home")
	ok(g.store_n("pill_juqi") == 2 and g.I("day") == 14, "第二颗 D+4 出炉")
	# 第 D 日出炉的丹当天就能服（⑤玩家操作在②之后）
	ok(g.eat_all(0) == 2, "⑤当日可服")
	# ③路上扣干粮；不够则饥乏扣寿元
	g = fresh()
	g.start_trip("houshan")
	g.s["ration"] = 1
	var sy: int = g.I("shouyuan")
	g.tick("road")
	ok(g.I("ration") == 0 and g.I("shouyuan") == sy - 1, "③路上扣 1 日干粮（寿元按日 -1）")
	g.tick("road")
	ok(g.I("hunger_days") == 1 and g.I("shouyuan") == sy - 3 and g.s["flags"].get("hungry", false), "③干粮吃完：饥乏，额外 -1 寿元")
	# ③闭关：+10，炼化 ≤20；受伤减半
	g = fresh()
	g.s["ganwu"] = 50
	g.tick("biguan")
	ok(g.I("xiuwei") == 30 and g.I("ganwu") == 30, "③闭关 +10，炼化 20")
	g.s["injured"] = 2
	g.tick("biguan")
	ok(g.I("xiuwei") == 50 and g.I("ganwu") == 20 and g.I("injured") == 1, "③受伤时炼化减半")
	# 修为溢出到余韵（≤120）
	g = fresh()
	g.s["xiuwei"] = 595
	g.s["ganwu"] = 20
	g.tick("biguan")
	ok(g.I("xiuwei") == 600 and g.I("yuyun") == 25, "修为封顶 600，溢出 25 进余韵")
	g.s["yuyun"] = 115
	g.s["ganwu"] = 20
	g.tick("biguan")
	ok(g.I("yuyun") == 120, "余韵上限 120")
	ok(g.xw_full_hint() != "", "修为满后闭关提示“只会攒余韵”")
	# 待炼化软上限 140
	g = fresh()
	g.s["ganwu"] = 130
	g.add_wu(30)
	ok(g.I("ganwu") == 150 and g.I("wu_lost") == 10, "待炼化软上限 140：超出部分减半（%d）" % g.I("ganwu"))
	# ④世事检查：D23 期限到期
	g = fresh()
	g.s["flags"]["world_xiangyang"] = true
	g.s["day"] = 23
	g.tick("home")
	ok(g.s["flags"].get("xiangyang_expired", false), "④世事倒计时到期生效（D24）")
	# 干粮溢出留在来源处
	g = fresh()
	g.start_trip("hantan")
	g.s["ration"] = 11
	g.s["flags"]["letter_pending"] = true
	g.come_home(false)
	ok(g.I("ration") == 12 and g.I("aunt_ration") == 2, "家书 +3：装到 12，多出 2 留在姑母处")
	g.s["ration"] = 3
	g.start_trip("houshan")
	g.come_home(true)
	ok(g.I("ration") == 10 and g.I("aunt_ration") == 0, "下次回家补到 8 后领回寄存的 2（%d）" % g.I("ration"))
	g = fresh()
	g.s["store"]["crop_linggu"] = 20
	g.s["ration"] = 8
	g.load_grain()
	ok(g.I("ration") == 12 and g.store_n("crop_linggu") == 16, "灵谷装袋到 12，其余留在仓里")
	# 筑基丹失败：主药保留，余韵 +20，第二炉 3 日必成
	g = fresh()
	g.s["store"] = {"herb_qingzhi": 6, "herb_hantanlian": 1, "herb_chiyangguo": 1}
	g.s["debug_zhuji"] = "fail"
	g.enqueue("zhuji")
	for i in 6:
		g.tick("home")
	ok(g.store_n("pill_zhuji") == 0 and g.store_n("herb_hantanlian") == 1 and g.I("yuyun") == 20, "筑基丹失败：主药保留，余韵 +20")
	g.enqueue("zhuji")
	ok(g.s["queue"][0][1] == 3, "第二炉 3 日")
	for i in 3:
		g.tick("home")
	ok(g.store_n("pill_zhuji") == 1, "第二炉必成")
	# 水田：灵谷 6 日 +2 灵谷 +1 青芝；莲子 20 日
	g = fresh()
	g.choose_extra("shuitian")
	g.s["store"]["seed_lianzi"] = 1
	for i in 6:
		g.tick("home")
	ok(g.store_n("crop_linggu") == 2 and g.store_n("herb_qingzhi") == 5, "水田一茬：灵谷 +2、青芝 +1")
	ok(g.plant_lianzi() and g.cancel_lianzi() and g.store_n("seed_lianzi") == 1, "莲子播种当日取消退回种子")
	g.plant_lianzi()
	for i in 20:
		g.tick("home")
	ok(g.store_n("herb_hantanlian") == 1, "莲子 20 日得寒潭莲")

# ------------------------------------------------------------ #3
func t_antifarm() -> void:
	var g = fresh()
	var ls0: int = g.I("lingshi")
	var r0: int = g.I("ration")
	var maxr = 0
	var maxl = 0
	for i in 10:
		g.start_trip("houshan")
		g.enter_node("H1")
		if g.s["trip"]["stage"] == "quick":
			g.quick_walk()
		else:
			g.resolve("A" if g.avail_n("fu_bishui") > 0 else "B")
		g.turn_back()
		maxr = maxi(maxr, g.I("ration"))
		maxl = maxi(maxl, g.I("lingshi"))
	ok(maxr <= r0 and g.I("ration") <= r0, "10 次“出门 1 日→折返→回家”：干粮没有增加（最高 %d，起始 %d）" % [maxr, r0])
	ok(maxl <= ls0, "灵石没有增加（最高 %d，起始 %d）" % [maxl, ls0])
	ok(g.I("day") == 20, "每次耗 1+⌈1/2⌉=2 日，共 20 日（%d）" % g.I("day"))
	# 出门 0 日立即折返
	var d0: int = g.I("day")
	g.start_trip("houshan")
	g.turn_back()
	ok(g.I("day") == d0 and g.I("ration") == r0, "出门不走就回：0 日，干粮不变")
	# 半路折返 ⌈n/2⌉
	g = fresh()
	g.start_trip("hantan")
	walk(g, [["T1", "A"], ["T2", "A"], ["T3a", "A"]])
	ok(g.turn_back_days() == 2, "走 3 日折返耗 ⌈3/2⌉=2 日")

# ------------------------------------------------------------ #4
func laogui_signature(opt: String) -> Dictionary:
	var g = fresh()
	g.s["xiuwei"] = 300   # 炼气五层，A 可选
	g.s["store"]["pill_juqi"] = 3
	g.pack_put("pill_juqi")
	g.start_trip("hantan")
	g.s["debug_roll"] = true
	walk(g, [["T1", "A"], ["T2", "A"], ["T3a", "A"]])
	g.enter_node("T4")
	g.resolve(opt)
	g.continue_trip()
	var sig = {}
	sig["寒潭节点额外日"] = g.day_mod()
	# 下一趟寒潭：T2 细采是否还在、T4 剩哪些选项
	g.s["trip"]["stage"] = "choose"
	g.s["trip"]["choices"] = ["T2"]
	g.enter_node("T2")
	var t2 = []
	for o in g.event_view()["options"]:
		t2.append(o["id"])
	sig["T2 选项"] = t2
	g.s["trip"]["stage"] = "choose"
	g.s["trip"]["choices"] = ["T4"]
	g.enter_node("T4")
	var t4 = []
	for o in g.event_view()["options"]:
		t4.append(o["id"])
	sig["重访 T4 选项"] = t4
	sig["暗渠路书"] = g.s["flags"].get("anqu_road", false)
	sig["心魔第二幕"] = g.pick_xinmo()[1]["id"] if g.pick_xinmo().size() > 1 else ""
	return sig

func t_keychoice() -> void:
	var sigs = {}
	for o in ["A", "B", "C", "D"]:
		sigs[o] = laogui_signature(o)
		p("  老龟 %s → %s" % [o, JSON.stringify(sigs[o])])
	var base = {"寒潭节点额外日": 0, "T2 选项": ["A", "B"], "重访 T4 选项": ["A", "B", "C", "D"], "暗渠路书": false}
	for o in sigs:
		var changed = false
		for k in base:
			if str(sigs[o][k]) != str(base[k]):
				changed = true
		ok(changed, "老龟 %s 至少改变一个后续节点/选项" % o)
	var keys = sigs.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a = sigs[keys[i]].duplicate()
			var b = sigs[keys[j]].duplicate()
			a.erase("心魔第二幕")
			b.erase("心魔第二幕")
			ok(str(a) != str(b), "老龟 %s 与 %s 的后续不是同一种（无等价补偿）" % [keys[i], keys[j]])

# ------------------------------------------------------------ #5
func t_xinmo() -> void:
	var g = fresh()
	var total = 0
	var good = 0
	var tags = ["力", "利", "善", "避"]
	for ch in ["aunt", "town", "book"]:
		for lg in ["A", "B", "C", "D", ""]:
			for mask in 16:
				for fl in 4:
					total += 1
					g.s["cherish"] = ch
					g.s["flags"] = {}
					if lg != "":
						g.s["flags"]["laogui"] = lg
					if fl & 1:
						g.s["flags"]["letter_ever"] = true
					if fl & 2:
						g.s["flags"]["stele_read"] = true
					for t in 4:
						g.s["tags"][tags[t]] = 1 if (mask >> t) & 1 else 0
					var qs: Array = g.pick_xinmo()
					var fine = qs.size() == 2 and qs[0]["id"] != qs[1]["id"]
					for q in qs:
						if not g.check(q["requires"]):
							fine = false
						var any = false
						for a in q["answers"]:
							if g.check(a["consistent_if"]):
								any = true
						if not any:
							fine = false
					if lg != "" and (qs.size() < 2 or qs[1]["id"] != "laogui_" + lg):
						fine = false
					if fine:
						good += 1
	ok(good == total, "心魔覆盖率 %d/%d = %.1f%%（最舍不得 3 × 老龟 5 × 标签 16 × 家书/残碑 4）" % [good, total, 100.0 * good / total])
	for o in ["A", "B", "C", "D"]:
		ok(g.xinmo["act2"].has("laogui_" + o), "老龟 %s 有对应心魔题" % o)

# ------------------------------------------------------------ #6
## 自动玩家：按策略走完整局，返回筑基日（-1 = 卡死）
func autoplay(laogui: String, extra: String, strat: String) -> Dictionary:
	var g = fresh()
	g.s["debug_zhuji"] = "succeed"
	var stays = [2, 3] if strat == "均衡" else [6, 10]
	var snaps = {}
	g.start_trip("houshan")
	walk(g, [["H1", "A"], ["H2a", "A"], ["H3", "A"], ["H4a", "A"], ["H5", "A"]])
	g.choose_extra(extra)
	var reserve = 1 if laogui == "B" else 0
	stay(g, stays[0], {}, reserve, snaps, "")
	if laogui == "B":
		var guard = 0
		while g.store_n("pill_juqi") < 1 and guard < 30:
			home_ops(g, {}, 1)
			g.biguan_day()
			guard += 1
		g.pack_put("pill_juqi", true)
	if laogui.begins_with("A"):
		var guard = 0
		while g.layer() < 5 and guard < 60:
			home_ops(g, {}, 0)
			g.biguan_day()
			guard += 1
		g.s["debug_roll_force"] = laogui == "A成"
	g.load_grain()
	g.buy_rations(10 - g.I("ration"))
	g.start_trip("hantan")
	var lopt = laogui.substr(0, 1)
	var t2 = "B" if lopt == "D" else "A"
	if laogui.begins_with("A"):
		_force_roll(g, laogui == "A成")
	walk(g, [["T1", "A"], ["T2", t2], ["T3a", "A"], ["T4", lopt], ["T5", "A"], ["T6", "A"], ["T7", "A"], ["T8", "A"], ["T9", "A"]])
	if g.can_plant_lianzi():
		g.plant_lianzi()
	stay(g, stays[1], {}, 0, snaps, "")
	g.start_trip("houshan")
	walk(g, [["H1", ""], ["Hstar", "A"], ["H5", "A"]])
	# 收尾循环：缺主药就去补，其余闭关
	var guard = 0
	var trips = 0
	while g.s["ending"] == "" and guard < 400:
		guard += 1
		if g.gelaosan_fruit_available():
			g.buy_gelaosan_fruit()
		var need_lian: bool = g.total_n("herb_hantanlian") == 0 and not g.zhuji_in_progress() and g.total_n("pill_zhuji") == 0 and int(g.s["lian_prog"]) < 0
		var want = 2 if g.s["flags"].get("laogui_grudge", false) else 1
		home_ops(g, {}, want if need_lian else 0)   # 缺莲时留丹作“钥匙”
		if need_lian and trips < 3:
			if g.store_n("pill_juqi") + g.pack_n("pill_juqi") >= want:
				while g.pack_n("pill_juqi") < want:
					g.pack_put("pill_juqi", true)
				g.load_grain()
				g.buy_rations(12 - g.I("ration"))
				g.start_trip("hantan")
				var t4 = "S" if want == 2 else "B"
				walk(g, [["T1", ""], ["T2", "A"], ["T3a", ""], ["T4", t4], ["T5", ""], ["T6", "B"], ["T7", ""], ["T8", ""], ["T9", "A"]])
				trips += 1
				continue
			elif g.store_n("herb_qingzhi") >= 2 and g.s["queue"].is_empty():
				g.enqueue("juqi")
		if g.can_breakthrough() == "":
			g.start_breakthrough()
			pass_xinmo(g)
			continue
		g.biguan_day()
	return {"day": g.I("day") if g.s["ending"] == "zhuji" else -1, "ending": g.s["ending"], "hunger": g.I("hunger_days")}

func _force_roll(g, success: bool) -> void:
	# 让老龟 A 的 60% 判定确定：反复换种子直到下一次 randf 落在想要的一侧（只用于测试）
	for sd in 1000:
		var r = RandomNumberGenerator.new()
		r.seed = sd
		var v = r.randf()
		if (v < 0.6) == success:
			g.rng.seed = sd
			return

func t_deadlock() -> void:
	for lg in ["A成", "A败", "B", "C", "D"]:
		for ex in ["field", "shuitian"]:
			for st in ["均衡", "偏闭关"]:
				var r = autoplay(lg, ex, st)
				var name = "老龟 %s × %s × %s" % [lg, "阳田" if ex == "field" else "水田", st]
				ok(r["day"] > 0, "%s → %s" % [name, ("D%d 筑基" % r["day"]) if r["day"] > 0 else ("卡死（%s）" % r["ending"])])
				if r["day"] > 0:
					p("  %s → D%d 筑基（饥乏 %d 日）" % [name, r["day"], r["hunger"]])

# ------------------------------------------------------------ 存读档
func t_save() -> void:
	var g = fresh()
	g.s["debug_zhuji"] = "succeed"
	g.start_trip("houshan")
	walk(g, [["H1", "A"], ["H2a", "A"], ["H3", "A"]])
	g.enter_node("H4a")   # 停在事件卡上（模拟刷新）
	var txt = JSON.stringify(g.to_dict())
	var h = GS.new()
	ok(h.from_dict(JSON.parse_string(txt)), "存档 JSON 可读回")
	ok(h.s["trip"]["stage"] == "event" and h.s["trip"]["node"] == "H4a", "读档后仍停在同一张事件卡")
	var r1: Dictionary = g.resolve("A")
	var r2: Dictionary = h.resolve("A")
	ok(str(g.snapshot()) == str(h.snapshot()), "读档后继续：状态与未中断时一致")
	# 随机判定不因刷新而重掷
	var a = fresh()
	a.s["xiuwei"] = 300
	a.start_trip("hantan")
	walk(a, [["T1", "A"], ["T2", "A"], ["T3a", "A"]])
	a.enter_node("T4")
	var save = JSON.stringify(a.to_dict())
	var outcomes = {}
	for i in 5:
		var b = GS.new()
		b.from_dict(JSON.parse_string(save))
		var rr: Dictionary = b.resolve("A")
		outcomes[rr.get("roll", "?")] = true
	ok(outcomes.size() == 1, "同一存档反复读取后判定结果相同（不能靠刷新重掷）")
