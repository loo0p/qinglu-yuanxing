extends RefCounted
## v0.12 青庐 ↔ 可插拔事件引擎（addons/storylet_engine）的胶水层。
## 引擎不认识青庐：它只通过这里的 se_* 方法读写世界，表达式里用 g.xxx 调这里的查询函数，
## 内容包（data/packs/*.json，tools/make_packs.py 生成）里的游戏专属 op 也在这里落地（se_op）。
## 引擎状态整块存在 world.w["se"]（JSON 安全，随存档走）；旧档没有这一块，读档时按种子新建，不动已有的人和事。
const SE = preload("res://addons/storylet_engine/storylet_engine.gd")
const AG = preload("res://scripts/agency.gd")
const Econ = preload("res://scripts/econ.gd")   # v0.15：送她器物的门槛、托售
const PACKS := ["qinglu_core", "qinglu_life", "qinglu_bio", "qinglu_offer", "qinglu_gear", "qinglu_chron"]
const CN := ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
static var _cache := {}

var W
var eng

func _init(world) -> void:
	W = world

func boot() -> void:
	if not W.w.has("se") or not (W.w["se"] is Dictionary):
		W.w["se"] = {}
	eng = SE.new(self, W.w["se"], (int(W.w.get("rng_seed", 0)) * 7919 + 17) % 2147483647)
	eng.cfg["recent_frac"] = 0.75   # v0.15.3：同一局里少重复同一句（避开该符号最近用过的四分之三）
	for pid in PACKS:
		var p = pack(pid)
		if p is Dictionary:
			eng.add_pack(p)

static func pack(pid: String):
	if not _cache.has(pid):
		var t := FileAccess.get_file_as_string("res://data/packs/%s.json" % pid)
		_cache[pid] = JSON.parse_string(t) if t != "" else null
	return _cache[pid]

# ================================================================ 游戏这边调用
func meet(a: Dictionary, b: Dictionary, place: String) -> int:
	return eng.emit("meet", {"A": a, "B": b}, {"p": place})

func beat(c: Dictionary) -> String:
	return eng.beat(c)

func emit(sig: String, c: Dictionary, ctx: Dictionary = {}) -> int:
	return eng.emit(sig, {"A": c}, ctx)

func daily() -> void:
	eng.tick_due()
	eng.tick_world()

## 前尘：入局之前的经历。old=true 用于旧档补写：只成文，不新建任何关系
func bio(c: Dictionary, old: bool = false) -> Array:
	var seed_v := (int(c.get("pseed", 0)) * 31 + int(c["id"]) * 977 + 5) % 2147483647
	return sanxiu_fix(c, eng.biography(c, seed_v, {"age0": 5, "old": 1 if old else 0}), seed_v)

## v0.15（Gemini v7 P1）：散修的前尘里拜过宗门，就补一句怎么离的山门（不然身份与生平对不上）
const SANXIU_WHY := ["因私吞了一株灵草，被逐出山门", "师父坐化后受同门排挤，自请下山", "与执事起了争执，一怒之下离了宗门", "嫌门规太严，留书出走",
	"宗门遭了劫，师门散了", "替人顶了罪，被除了名"]
func sanxiu_fix(c: Dictionary, lst: Array, seed_v: int) -> Array:
	if String(c.get("sect", "")) != "散修" or lst.is_empty():
		return lst
	var joined := false
	for e in lst:
		var t := String(e[1])
		if t.contains("离了") or t.contains("逐出") or t.contains("下山") or t.contains("散修"):
			return lst
		if t.contains("拜入") or t.contains("外门") or t.contains("山门") or t.contains("宗门"):
			joined = true
	if not joined:
		return lst
	var age := int(lst[-1][0]) + 1 + seed_v % 3
	if age > int(float(c["age"])):
		age = int(float(c["age"]))
	lst.append([age, "%s岁，%s，自此做了散修。" % [cn(age), SANXIU_WHY[seed_v % SANXIU_WHY.size()]]])
	return lst

func is_tid(tid: String) -> bool:
	return eng.defs.has(tid) and String(eng.defs[tid].get("trigger", "")) == "offer"

func meta(tid: String) -> Array:
	var s: Dictionary = eng.defs.get(tid, {})
	return [int(s.get("tier", 1)), int(s.get("tension", 0)), true, 99, 0, 0, 1.0]

func present(tid: String, roles: Dictionary, ctx: Dictionary) -> Dictionary:
	var r: Dictionary = eng.present(eng.make_inst(tid, roles, ctx))
	return {"speaker": int(r["speaker"]), "text": r["text"], "opts": r["opts"]}

func resolve(tid: String, roles: Dictionary, ctx: Dictionary, oid: String) -> String:
	return eng.choose(eng.make_inst(tid, roles, ctx), oid)

# ================================================================ adapter 接口（引擎调用）
func se_now() -> int:
	return int(W.w["day"])

## 时间单位：引擎的一“刻”= se_now 的一格。v0.13 起一刻 = 一月（W.w["day"] 存的是月序号）。
## 青庐四个内容包声明 unit=month：原来按“日”调好的冷却/连锁/min_t 数字整体改读成月——
## 一生按年算，二十个月冷却正合“一年三五件要事”（Gemini 评审 二.1）；若逐日换算（÷30），每月的触发概率会饱和。
const TICK_UNIT = "month"
const PER_DAY = {"day": 1.0, "month": 30.0, "year": 360.0}
func se_ticks(n: float, unit: String) -> float:
	return n * float(PER_DAY.get(unit, 1.0)) / float(PER_DAY[TICK_UNIT])

func se_actors() -> Array:
	return W.npcs()

func se_id(a) -> int:
	return int(a["id"])

func se_actor(id):
	var c: Dictionary = W.C(id)
	return null if c.is_empty() else c

func se_name(a) -> String:
	return W.pn() if a.get("player", false) else String(a["name"])

func se_alive(a) -> bool:
	return bool(a["alive"])

func se_begin() -> void:
	W.fx_begin()

func se_end() -> void:
	W.fx_end()

func se_chronicle(a, text: String, inst, e) -> void:
	if text != "":
		W.chron(a, text)

func se_var(nm: String, inst, e):
	var who = null
	if inst["ctx"].has("_who"):
		who = se_actor(inst["ctx"]["_who"])
	if who == null:
		who = e.actor(inst, "A")
	if who == null:
		who = e.actor(inst, "B")
	match nm:
		"y":
			return cn(int(inst["ctx"].get("age", 0)))
		"pn":
			return W.pn()
		"jie":
			return jie()
	if who == null:
		return null
	match nm:
		"p":
			return String(who["place"])
		"s":
			return String(who["sect"])
		"r":
			return W.realm(who)
		"age":
			return cn(int(float(who["age"])))
		"ta":
			return W.ta(who)
	return null

func se_offer(inst, e) -> void:
	if not inst["cast"].has("B"):
		return
	for it in W.w.get("agq", []):
		if is_tid(String(it[1])):
			return   # 同一时间只惦记一件引擎交来的事，不挤占她的日子（游历节奏测试：最长连着有事 ≤4 日）
	AG._queue(W, String(inst["sid"]), inst["cast"].duplicate(), inst["ctx"].duplicate(true))

func _a(inst, e, role) -> Variant:
	if String(role) == "P" and not inst["cast"].has("P"):
		return W.P()   # “她”：不必进 cast，op 里写 P 就是玩家
	return e.actor(inst, String(role))

func _n(v, inst, e) -> float:
	return e.num(e.ev(v, inst)) if v is String else float(v)

func se_op(op: Dictionary, inst, e) -> void:
	var k := String(op["op"])
	var a = _a(inst, e, op.get("who", op.get("a", "A")))
	match k:
		"rel":
			var b = _a(inst, e, op.get("b", "B"))
			if a == null or b == null:
				return
			for pr in ([[a, b], [b, a]] if op.get("both", false) else [[a, b]]):
				W.radd(pr[0], pr[1], int(_n(op["f"], inst, e)) if op.has("f") else 0, int(_n(op["g"], inst, e)) if op.has("g") else 0)
		"meet":
			var b2 = _a(inst, e, op.get("b", "B"))
			if a == null or b2 == null:
				return
			for pr in [[a, b2], [b2, a]]:
				var r2: Dictionary = W.R(pr[0], pr[1])
				r2["m"] = 1
				r2["n"] = int(r2.get("n", 0)) + 1
		"tag":
			var b3 = _a(inst, e, op.get("b", "B"))
			if a == null or b3 == null:
				return
			var t := String(op["t"])
			var t2 := String(op.get("t2", t))
			var ra: Array = W.R(a, b3)["t"]
			var rb: Array = W.R(b3, a)["t"]
			if op.get("remove", false):
				ra.erase(t)
				rb.erase(t2)
			else:
				if not t in ra:
					ra.append(t)
					W.fx(a, "%s成了%s" % [se_name(b3), t], "")
				if op.get("both", true) and not t2 in rb:
					rb.append(t2)
					W.fx(b3, "%s成了%s" % [se_name(a), t2], "", false)
		"mem":
			var o = _a(inst, e, op.get("about", "B"))
			if a == null:
				return
			W.remember(a, o if o != null else {}, e.say(op.get("text", ""), inst, "mem", e._op_vars(op, inst)), int(_n(op.get("wt", 0), inst, e)), String(op.get("kind", "")))
		"inj":
			if a != null:
				var dd := int(_n(op.get("days", 10), inst, e))
				if dd > int(a["inj"]):
					W.fx(a, "伤|月", dd - int(a["inj"]))
				a["inj"] = maxi(int(a["inj"]), dd)
		"home":
			if a != null:
				a["place"] = W.SECT_HOME.get(a["sect"], "坊市")
		"move":
			if a != null:
				a["place"] = String(e.ev(op["to"], inst))
		"beat":
			var ba = _a(inst, e, op.get("a", "A"))
			var bb = _a(inst, e, op.get("b", "B"))
			if ba != null and bb != null:
				W.note_defeat(ba, bb)
		"die":
			if a != null and a["alive"]:
				W.die(a, e.say(op.get("how", "身死道消"), inst, "how", e._op_vars(op, inst)))
		"rumor":
			var who := []
			for rn in op.get("about", ["A"]):
				var x = _a(inst, e, rn)
				if x != null:
					who.append(x)
			W.rumor(e.say(op.get("text", ""), inst, "rumor", e._op_vars(op, inst)), who, String(op.get("kind", "")))
		"goal":
			if a != null:
				a["goal"] = String(e.ev(op["value"], inst))
				W.fx(a, "心愿：", String(a["goal"]))
				if op.has("gt"):
					var t3 = _a(inst, e, op["gt"])
					if t3 != null:
						a["gt"] = int(t3["id"])
		"lv":
			if a != null:
				var lv0 := int(a["lv"])
				a["lv"] = clampi(int(a["lv"]) + int(_n(op.get("add", 1), inst, e)), 0, int(op.get("max", 17)))
				a["xp"] = 0.0
				if int(a["lv"]) != lv0:
					W.fx(a, "入", W.realm(a))
		"xp":
			if a != null:
				var fr := _n(op.get("frac", 0.3), inst, e)
				if a.get("player", false):
					if W.g != null:
						W.pxw(int(round(fr * 40.0)))
				else:
					a["xp"] = W.qz(float(a["xp"]) + fr * 8.0 * pow(1.35, int(a["lv"])), 10000.0)
					W.fx(a, "修为", "精进" if fr >= 0 else "折损")
		"sect":
			if a != null:
				var s0 := String(a["sect"])
				a["sect"] = String(e.ev(op["value"], inst))
				if s0 != String(a["sect"]):
					W.fx(a, "改投", String(a["sect"]))
		"wflag":
			W._flag_add(e.say(String(op["key"]), inst), int(op.get("add", 1)))
		"kid":
			var b4 = _a(inst, e, op.get("with", "B"))
			if a == null:
				return
			var nm: String = e.say(String(op["name"]), inst) if op.has("name") else kid_name(a, e.rng.randi() % 100000)
			for x2 in [a, b4]:
				if x2 != null:
					if not x2.has("kids"):
						x2["kids"] = []
					x2["kids"].append(nm)
					W.fx(x2, "添一子嗣", "")
			inst["ctx"]["k"] = nm
		"spawn":
			# 新收的弟子：一个真正的人（以后也有自己的日子过）
			if W.npcs().size() >= 32 or a == null:
				return
			var c: Dictionary = W._new_char("", String(a["sect"]), e.rng.randi_range(0, 2))
			c["age"] = float(e.rng.randi_range(13, 22))
			c["young"] = 1
			c["place"] = a["place"]
			c["pre"] = bio(c, false)
			inst["cast"][String(op.get("as", "D"))] = int(c["id"])
			W.fx(a, "收徒%s" % String(c["name"]), "")
			inst["act"].erase(String(op.get("as", "D")))
		"seclude":
			if a != null:
				a["sbg"] = int(W.w["day"]) + int(_n(op.get("days", 10), inst, e))
				W.fx(a, "闭关", "")
		"xm":
			if a != null:
				var m0 := int(a.get("smx", 0))
				a["smx"] = int(_n(op.get("set", 1), inst, e))
				if int(a["smx"]) != m0:
					W.fx(a, "心魔" if int(a["smx"]) > 0 else "心魔消", "")
		"fav":
			if a != null:
				W.fav(a, int(_n(op.get("d", 0), inst, e)), e.say(op.get("mem", ""), inst, "fav", e._op_vars(op, inst)), int(_n(op.get("wt", 0), inst, e)))
		"ling":
			W._ling(int(_n(op.get("n", 0), inst, e)))
		"wu":
			W._wu(int(_n(op.get("n", 1), inst, e)))
		"pinj":
			var dd := int(_n(op.get("days", 2), inst, e))
			if dd < 0:   # v0.15.5：负数＝伤好得快些（别人送的丹）
				if W.g != null and int(W.g.s.get("injured", 0)) > 0:
					var cur := int(W.g.s["injured"])
					W.g.s["injured"] = maxi(0, cur + dd)
					W.fx(W.P(), "伤|月", int(W.g.s["injured"]) - cur)
			else:
				W._inj(dd)
		"pchron":
			W.chron(W.P(), e.say(op.get("text", ""), inst, "pc", e._op_vars(op, inst)))
		# v0.15：资质 / 寿元 / 她的修为 / 给她一件新东西
		"attr":
			if a != null:
				var ks := String(e.ev(op["k"], inst)) if String(op["k"]).begins_with("$") else String(op["k"])
				W.attr_add(a, ks, int(_n(op.get("d", 1), inst, e)))
		"life":
			if a != null:
				W.life_add(a, int(_n(op.get("y", 1), inst, e)))
		"pxw":
			W.pxw(int(_n(op.get("n", 10), inst, e)))
		"pitem":
			if W.g == null:
				return
			var r3 := RandomNumberGenerator.new()
			r3.seed = e.rng.randi()
			var sl3 := String(op.get("slot", ["fabao", "yi", "shi"][r3.randi() % 3]))
			var arr3: Array = W.Gear.BASES[sl3]
			var it3: Dictionary = W.Gear.make(W.g, W, r3, String(arr3[r3.randi() % arr3.size()]), int(_n(op.get("grade", 0), inst, e)), e.say(op.get("origin", "{pn}所得。"), inst, "origin", e._op_vars(op, inst)), int(W.w["day"]))
			W.Gear.give_her(W.g, it3, e.say(op.get("origin", "{pn}所得。"), inst, "origin", e._op_vars(op, inst)))
			inst["ctx"]["it"] = String(it3["n"])
			W.fx(W.P(), "得「%s」" % String(it3["n"]), "")
		"ptag":
			# 她的性子：善 / 利 / 力 / 避（显示成 仁心 / 计较 / 刚勇 / 避事）
			if W.g != null:
				var tk := String(op["k"])
				var tg: Dictionary = W.g.s["tags"]
				var dv := int(_n(op.get("d", 1), inst, e))
				tg[tk] = maxi(0, int(tg.get(tk, 0)) + dv)
				W.fx(W.P(), String(TAG_CN.get(tk, tk)), dv)
		"pmeet":
			# 她与 b 初识（不另写“初识”一条：本条履历就是相识的经过）
			var bm = _a(inst, e, op.get("b", "B"))
			if bm == null:
				return
			var rr: Dictionary = W.R(W.P(), bm)
			if int(rr["m"]) == 0:
				rr["m"] = 1
				rr["m0"] = int(W.w["day"])
				rr["lv0"] = [int(bm["lv"]), W.plv()]
			W.R(bm, W.P())["m"] = 1
		"mark":
			eng.st["vars"][e.say(String(op["key"]), inst)] = int(W.w["day"])
		# v0.14 物品：造一件 / 送一件 / 夺一件。名字放进 ctx.it（品阶 ctx.itg），文本里写 {it}
		"gen_item":
			if a == null or a.get("player", false):
				return
			var r := RandomNumberGenerator.new()
			r.seed = e.rng.randi()
			var sl := String(op.get("slot", ["fabao", "fabao", "yi", "shi"][r.randi() % 4]))
			var lvx := int(a["lv"])
			var gd := int(_n(op["grade"], inst, e)) if op.has("grade") else (0 if lvx < 3 else (1 if lvx < 9 else (2 if lvx < 12 else (3 if lvx < 15 else 4))))
			var arr: Array = W.Gear.BASES[sl]
			var it: Dictionary = W.Gear.make(null, W, r, String(arr[r.randi() % arr.size()]), gd, e.say(op.get("origin", "{A}炼成。"), inst, "origin", e._op_vars(op, inst)), int(W.w["day"]))
			W.Gear.npc_gear(W, a).append(it)
			W.fx(a, "得「%s」" % String(it["n"]), "")
			inst["ctx"]["it"] = String(it["n"])
			inst["ctx"]["itg"] = W.Gear.grade_name(it)
		"give_item", "take_item":
			# give：a 把东西给 b（best=false 给次一等的）；take：a 从 b 手里夺走最好的
			var b5 = _a(inst, e, op.get("b", "B"))
			if a == null or b5 == null:
				return
			var src: Dictionary = a if k == "give_item" else b5
			var dst: Dictionary = b5 if k == "give_item" else a
			var it2 = W.Gear.best_of(W, src)
			if k == "give_item" and not op.get("best", false) and not src.get("player", false):
				var lst: Array = W.Gear.npc_gear(W, src).duplicate()
				lst.sort_custom(func(x, y): return W.Gear.value(x) < W.Gear.value(y))
				it2 = lst[0] if not lst.is_empty() else null
			if it2 == null:
				inst["ctx"]["it"] = ""
				return
			# v0.15（Gemini v7 P0·NPC 托人白送）：送她法器以上，要够亲近、她祭得动、不高过她一个大境界，且这人一生只送一件重宝；
			# 不够格的改成“用不上，托坊市器物铺五折转给她”（包里的送礼文字不出，这里自己记）
			if k == "give_item" and dst.get("player", false) and W.g != null and not src.get("player", false):
				if not Econ.gift_ok(W, src, it2):
					var nm := String(it2["n"])
					var gn: String = W.Gear.grade_name(it2)
					var pr := Econ.consign(W, src, it2)
					inst["ctx"]["it"] = ""
					W.chron(src, "把用不上的一件%s托坊市器物铺转给%s。" % [nm, String(W.P().get("name", "她"))], {"托售「%s」" % nm: ""})
					W.g.pchron("%s捎话：手里一件%s（%s）用不上，托坊市器物铺五折转给她，%d 灵石，两年内去取。" % [src["name"], nm, gn, pr], -1, {"可取「%s」" % nm: "%d 灵石" % pr})
					W.g.notice("%s托坊市器物铺转一件%s（%s）给她，%d 灵石，两年内去坊市取。" % [src["name"], nm, gn, pr])
					return
				Econ.note_gift(W, src, it2)
			var moved: Dictionary = W.Gear.transfer(W, src, dst, it2, e.say(op.get("h", "{A}给了{B}。"), inst, "h", e._op_vars(op, inst)))
			inst["ctx"]["it"] = String(moved.get("n", ""))
			if not moved.is_empty():
				W.fx(src, "失「%s」" % String(moved["n"]), "", not src.get("player", false))
				W.fx(dst, "得「%s」" % String(moved["n"]), "", not dst.get("player", false))
			inst["ctx"]["itg"] = W.Gear.grade_name(moved) if not moved.is_empty() else ""
			if dst.get("player", false) and W.g != null and not moved.is_empty():
				W.g.notice("%s送来一件%s（%s），放在%s。" % [src["name"], moved["n"], W.Gear.grade_name(moved), "青庐" if W.g.at_home() else "行囊里"])
		"pick_lost":
			if a == null:
				return
			var lost = W.Gear.find_lost(W, String(a["place"]))
			if lost == null:
				inst["ctx"]["it"] = ""
				return
			lost["h"].append([int(W.w["day"]), "%s在%s捡到。" % [a["name"], a["place"]]])
			W.Gear.npc_gear(W, a).append(lost)
			W.fx(a, "得「%s」" % String(lost["n"]), "")
			inst["ctx"]["it"] = String(lost["n"])
			inst["ctx"]["own"] = String(lost.get("owner", "前人"))
		_:
			e._err("青庐不认识 op=" + k)

# ================================================================ 表达式里的查询（g.xxx）
## 时令引子：按当天的月份（每月三句），同一周里用同一句（不吃骰子，存读一致）
const JIE := [["开春，", "年节刚过，", "雪还没化尽时，"], ["早春，", "桃花开时，", "一场春雨后，"], ["清明前后，", "暮春，", "柳絮飞时，"],
	["入夏，", "槐花开时，", "一场雷雨后，"], ["端午前后，", "暑热里，", "蝉声里，"], ["盛夏，", "一场暴雨后，", "荷花开时，"],
	["入秋，", "七夕前后，", "秋风起时，"], ["中秋前后，", "桂子落时，", "秋高气爽时，"], ["重阳前后，", "霜降前后，", "枫叶红时，"],
	["初冬，", "落叶满山时，", "天转冷时，"], ["落雪那日，", "冬夜里，", "岁寒时节，"], ["腊月里，", "年关前，", "大雪封山时，"]]
func jie() -> String:
	var m: int = W.cal(int(W.w["day"]))[1]
	var lst: Array = JIE[(m - 1) % 12]
	return String(lst[(int(W.w["day"]) / 7) % lst.size()])

static func cn(n: int) -> String:
	if n < 0:
		return str(n)
	if n < 10:
		return CN[n]
	if n < 20:
		return "十" + ("" if n == 10 else CN[n % 10])
	if n < 100:
		return CN[n / 10] + "十" + ("" if n % 10 == 0 else CN[n % 10])
	if n < 1000:
		var r := n % 100
		var t: String = CN[n / 100] + "百"
		if r == 0:
			return t
		if r < 10:
			return t + "零" + CN[r]
		return t + (CN[r / 10] + "十" + ("" if r % 10 == 0 else CN[r % 10]))
	return str(n)

const TAG_CN := {"善": "仁心", "利": "计较", "力": "刚勇", "避": "避事"}
func realm(a) -> String:
	return W.realm(a)
func here() -> String:
	return String(W.P()["place"])
## 救人 / 争药的地方：路上就是她所在的地方；在家时不是“青庐”屋里，是附近的山
func near() -> String:
	var h := here()
	return "青庐后山" if h == "青庐" else h
func met_m(a) -> int:
	return int(W.R(W.P(), a).get("m0", 0))
func sy_left() -> String:
	if W.g == null:
		return "数十"
	return cn(maxi(1, int(int(W.g.s.get("shouyuan", 0)) / 12)))
func maj(a) -> int:
	return W.major(int(a["lv"]))
func pt(k: String) -> int:
	return int(W.g.s["tags"].get(k, 0)) if W.g != null else 0
func ling() -> int:
	return int(W.g.s.get("lingshi", 0)) if W.g != null else 0
func pinjd() -> bool:
	return W.g != null and int(W.g.s.get("injured", 0)) > 0
func gate() -> bool:
	return W.g != null and W.g.has_method("at_gate") and W.g.at_gate()
func home_p() -> bool:
	return W.g == null or String(W.g.s.get("loc", "home")) == "home"
func eqn(slot: String) -> String:
	if W.g == null:
		return ""
	var it = W.Gear.eq(W.g, slot)
	return String(it["n"]) if it != null else ""
## v0.15.7：她门下正式的徒弟（v0.15.6 青庐营建 s["econ"]["tu"]，-1 没有；没有 econ 字段也是 -1）。履历里“有人跪求点拨”在她已有徒弟时不再出
func tu_id() -> int:
	if W.g == null:
		return -1
	return int((W.g.s.get("econ", {}) as Dictionary).get("tu", -1))
func cy() -> String:
	return W.cal_text(int(W.w["day"])).get_slice("年", 0) + "年"
func yago(m: int) -> String:
	return "%s年" % cn(maxi(1, int((int(W.w["day"]) - m) / 12)))
func now_m() -> int:
	return int(W.w["day"])
func at(a, k: String) -> int:
	return W.at(a, k)

func day() -> int:
	return int(W.w["day"])
func lv(a) -> int:
	return int(a["lv"])
func trt(a, t: String) -> bool:
	return t in a["traits"]
func px(a, k: String) -> float:
	return AG.px(a, k)
func opn(a, b) -> float:
	return W.opinion(a, b)
func f(a, b) -> int:
	return int(W.R(a, b)["f"])
func gr(a, b) -> int:
	return int(W.R(a, b)["g"])
func meets(a, b) -> int:
	return int(W.R(a, b).get("n", 0))
func met(a, b) -> bool:
	return a["rel"].has(str(int(b["id"]))) and int(a["rel"][str(int(b["id"]))]["m"]) == 1
func has_tag(a, b, t: String) -> bool:
	return t in W.rel_tags(a, b)
func bonded(a, b) -> bool:
	for t in W.rel_tags(a, b) + W.rel_tags(b, a):
		if t in W.CLOSE_TAGS:
			return true
	return false
func _mem_count(a, b, sgn: int) -> int:
	var k := 0
	for m in a["mem"] + b["mem"]:
		if int(m[1]) == int(b["id"]) or int(m[1]) == int(a["id"]):
			if float(m[3]) * sgn > 0:
				k += 1
	return mini(k, 4)
func mpos(a, b) -> int:
	return _mem_count(a, b, 1)
func mneg(a, b) -> int:
	return _mem_count(a, b, -1)
func shi(a, b) -> bool:
	for t in W.rel_tags(a, b):
		if "师" in t or "徒" in t:
			return true
	return false
func partner(a):
	return W.partner(a)
func single(a) -> bool:
	return W.partner(a) == null
func is_partner(a, b) -> bool:
	return "道侣" in W.rel_tags(a, b)
func side(a) -> String:
	return W.side(a)
func foes(a, b) -> bool:
	var x: String = W.side(a)
	var y: String = W.side(b)
	return x != y and x != "中" and y != "中"
func age(a) -> float:
	return float(a["age"])
func life(a) -> int:
	return W.lifespan_of(a)
func lf(a) -> float:
	return float(a["age"]) / float(W.lifespan_of(a))
func player():
	return W.P()
func known(a) -> bool:
	return W.known(a)
## v0.14 物品条件
func has_gear(a, slot: String = "") -> bool:
	if a == null:
		return false
	for it in (W.Gear.equipped(W.g) if a.get("player", false) and W.g != null else W.Gear.npc_gear(W, a)):
		if slot == "" or W.Gear.slot_of(it) == slot:
			return true
	return false
func gear_pw(a) -> float:
	return 0.0 if a == null else W.Gear.pw_of(W, a)
func gear_n(a) -> int:
	return 0 if a == null or a.get("player", false) else W.Gear.npc_gear(W, a).size()
func lost_here(a) -> bool:
	return a != null and not W.w.get("lost", {}).get(String(a["place"]), []).is_empty()
func pf(a) -> int:
	return int(W.R(W.P(), a)["f"])
func plv() -> int:
	return W.plv()
func busy(a) -> bool:
	return int(a.get("sbg", 0)) > int(W.w["day"])
func xm(a) -> bool:
	return int(a.get("smx", 0)) == 1
func inj(a) -> bool:
	return int(a["inj"]) > 0
func prot(a) -> bool:
	return W._protected(a)
func may_kill(a, b) -> bool:
	return W.may_kill(a, b)
func cowed(a, b) -> bool:
	return W.cowed(a, b)
func xia(a) -> bool:
	return W.xia(a)
func kids(a) -> int:
	return a.get("kids", []).size()
func kid(a) -> String:
	var ks: Array = a.get("kids", [])
	return String(ks[-1]) if not ks.is_empty() else ""
func like(a) -> String:
	return String(a["likes"][0])
func ls() -> int:
	return W.lingshi()
func agei(a) -> int:
	return int(float(a["age"]))
func ndisc(a) -> int:
	return disciples(a).size()
func sx(a) -> String:
	return "_m" if a["sex"] == "男" else ""
func jt(a) -> String:
	return "_san" if a["sect"] == "散修" else ("_mo" if W.side(a) == "魔" else "")
func gtgt(a):
	return se_actor(a["gt"]) if int(a.get("gt", 0)) > 0 else null
func seeks(a, b) -> bool:
	return a["goal"] == "寻道侣" or b["goal"] == "寻道侣"
func wild(pl: String) -> bool:
	return pl in ["古战场", "云梦泽"]
func pk(a, b) -> String:
	return W._pair(a, b)
func nm(i) -> String:
	var c = se_actor(i)
	return "" if c == null else String(c["name"])
func cnr(a, lst: Array) -> String:
	return cn(rank_of(a, lst))
func next_realm(a) -> String:
	return W.realm_name(mini(18, int(a["lv"]) + 1))
func newgoal() -> String:
	return String(W.GOALS[eng.rng.randi() % 6])
func mj_ids(k: int) -> Array:
	var out := []
	for c in mj_party(k):
		out.append(int(c["id"]))
	return out
func mj_ok() -> bool:
	return W.npcs().filter(func(o): return int(o["lv"]) >= 3 and not busy(o) and int(o["inj"]) == 0).size() >= 3
func mourners(a) -> Array:
	var out := []
	var pt = W.partner(a)
	if pt != null:
		out.append(pt)
	for d in disciples(a):
		if not d in out:
			out.append(d)
	return out
## 大比里“爆冷”：排在 a 后面、却比 a 高两层以上的人
func upset_over(a, lst: Array):
	var r := rank_of(a, lst)
	for i in range(r, lst.size()):
		var c = se_actor(lst[i])
		if c != null and int(c["lv"]) >= int(a["lv"]) + 2:
			return c
	return null
func disc_ok(m) -> bool:
	return disciples(m).size() < 3
func old_how(c: Dictionary) -> String:
	return eng.say("#d_old_death#", eng.make_inst("", {"A": c}))
func pop() -> int:
	return W.npcs().size()
func home(a) -> String:
	return W.SECT_HOME.get(a["sect"], "坊市")
func old_death_ok(a) -> bool:
	return not W._protected(a)
## 亲传弟子（活着的）
func disciples(a) -> Array:
	var out := []
	for o in W.npcs():
		if "师" in W.rel_tags(o, a):
			out.append(o)
	return out
func master(a):
	var m = W.master_of(a)
	return m if m != null and not m.is_empty() and m["alive"] else null
## 同门（同宗门、活着、不是自己；散修没有同门）
func mates(a) -> Array:
	if a["sect"] == "散修":
		return []
	return W.npcs().filter(func(o): return o["sect"] == a["sect"] and int(o["id"]) != int(a["id"]))
## 秘境同行：境界够、没在闭关，好奇 / 贪财 / 嗜战的人更想进去
func mj_party(k: int) -> Array:
	var pool: Array = W.npcs().filter(func(o): return int(o["lv"]) >= 3 and not busy(o) and int(o["inj"]) == 0)
	var out := []
	while out.size() < k and not pool.is_empty():
		var ws := []
		for o in pool:
			ws.append(1.0 + 1.5 * int(trt(o, "好奇")) + int(trt(o, "贪财")) + int(trt(o, "嗜战")) - 0.6 * int(trt(o, "怯懦")))
		var o2 = eng._wpick(pool, ws)
		out.append(o2)
		pool.erase(o2)
	return out
## 大比：挑一个人多、九十日内没办过的宗门
func dabi_sect() -> String:
	var cnt := {}
	for o in W.npcs():
		if o["sect"] != "散修":
			cnt[o["sect"]] = int(cnt.get(o["sect"], 0)) + 1
	var ok := []
	for s in W.SECT_LIST:
		if int(cnt.get(s, 0)) >= 3 and int(W.w["day"]) - int(eng.st["vars"].get("dabi:" + s, -999)) >= 90:
			ok.append(s)
	if ok.is_empty():
		return ""
	return ok[eng.rng.randi() % ok.size()]
## 名次：境界 + 临场发挥（引擎的骰子），排好的 id 列表
func dabi_rank(sect: String) -> Array:
	var xs := []
	for o in W.npcs():
		if o["sect"] == sect and not busy(o):
			xs.append([float(o["lv"]) + eng.rng.randf() * 4.0 + (1.0 if trt(o, "嗜战") else 0.0) - (1.0 if int(o["inj"]) > 0 else 0.0), int(o["id"])])
	xs.sort_custom(func(x, y): return x[0] > y[0] or (x[0] == y[0] and x[1] < y[1]))
	var out := []
	for x in xs:
		out.append(x[1])
	return out
func ids(lst: Array) -> Array:
	var out := []
	for i in lst:
		var c = se_actor(i)
		if c != null:
			out.append(c)
	return out
func rank_of(a, lst: Array) -> int:
	for i in lst.size():
		if int(lst[i]) == int(a["id"]):
			return i + 1
	return 99
## 名次表上紧挨着排在前面的人（输给了谁）
func beat_by(a, lst: Array):
	var r := rank_of(a, lst)
	if r <= 1 or r > lst.size():
		return null
	return se_actor(lst[r - 2])
func fake_name(sex: String, seed_v: int) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var giv: Array = W.F_GIV if sex == "女" else W.M_GIV
	return String(W.SURN[r.randi() % W.SURN.size()]) + String(giv[r.randi() % giv.size()]) + String(giv[r.randi() % giv.size()])
func opp(sex: String) -> String:
	return "男" if sex == "女" else "女"
func kid_name(a, seed_v: int) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var nm := String(a["name"])
	var sur := nm.substr(0, 2) if nm.length() >= 4 else nm.substr(0, 1)
	for s in W.SURN:
		if nm.begins_with(s):
			sur = s
	var pool: Array = W.F_GIV + W.M_GIV
	var c1 := String(pool[r.randi() % pool.size()])
	var c2 := String(pool[r.randi() % pool.size()])
	return sur + c1 + (c2 if c2 != c1 else "")
