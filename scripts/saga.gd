extends RefCounted
## v0.12 青庐 ↔ 可插拔事件引擎（addons/storylet_engine）的胶水层。
## 引擎不认识青庐：它只通过这里的 se_* 方法读写世界，表达式里用 g.xxx 调这里的查询函数，
## 内容包（data/packs/*.json，tools/make_packs.py 生成）里的游戏专属 op 也在这里落地（se_op）。
## 引擎状态整块存在 world.w["se"]（JSON 安全，随存档走）；旧档没有这一块，读档时按种子新建，不动已有的人和事。
const SE = preload("res://addons/storylet_engine/storylet_engine.gd")
const AG = preload("res://scripts/agency.gd")
const PACKS := ["qinglu_core", "qinglu_life", "qinglu_bio", "qinglu_offer"]
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
	return eng.biography(c, seed_v, {"age0": 5, "old": 1 if old else 0})

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

## 时间单位：引擎的一“刻”= se_now 的一格。眼下一刻 = 一日；v0.13 改成按月走时，把 se_now 换成月序号、
## 这里返回“n 个 unit 合多少个月”（日 → n/30.0，年 → n*12）即可，内容包不用改。
const TICK_UNIT = "day"
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
				var r: Dictionary = W.R(pr[0], pr[1])
				if op.has("f"):
					r["f"] = int(r["f"]) + int(_n(op["f"], inst, e))
				if op.has("g"):
					r["g"] = maxi(0, int(r["g"]) + int(_n(op["g"], inst, e)))
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
				if op.get("both", true) and not t2 in rb:
					rb.append(t2)
		"mem":
			var o = _a(inst, e, op.get("about", "B"))
			if a == null:
				return
			W.remember(a, o if o != null else {}, e.say(op.get("text", ""), inst, "mem", e._op_vars(op, inst)), int(_n(op.get("wt", 0), inst, e)), String(op.get("kind", "")))
		"inj":
			if a != null:
				a["inj"] = maxi(int(a["inj"]), int(_n(op.get("days", 10), inst, e)))
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
				if op.has("gt"):
					var t3 = _a(inst, e, op["gt"])
					if t3 != null:
						a["gt"] = int(t3["id"])
		"lv":
			if a != null:
				a["lv"] = clampi(int(a["lv"]) + int(_n(op.get("add", 1), inst, e)), 0, int(op.get("max", 17)))
				a["xp"] = 0.0
		"xp":
			if a != null:
				a["xp"] = W.qz(float(a["xp"]) + _n(op.get("frac", 0.3), inst, e) * 8.0 * pow(1.35, int(a["lv"])), 10000.0)
		"sect":
			if a != null:
				a["sect"] = String(e.ev(op["value"], inst))
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
			inst["act"].erase(String(op.get("as", "D")))
		"seclude":
			if a != null:
				a["sbg"] = int(W.w["day"]) + int(_n(op.get("days", 10), inst, e))
		"xm":
			if a != null:
				a["smx"] = int(_n(op.get("set", 1), inst, e))
		"fav":
			if a != null:
				W.fav(a, int(_n(op.get("d", 0), inst, e)), e.say(op.get("mem", ""), inst, "fav", e._op_vars(op, inst)), int(_n(op.get("wt", 0), inst, e)))
		"ling":
			W._ling(int(_n(op.get("n", 0), inst, e)))
		"wu":
			W._wu(int(_n(op.get("n", 1), inst, e)))
		"pinj":
			W._inj(int(_n(op.get("days", 2), inst, e)))
		"pchron":
			W.chron(W.P(), e.say(op.get("text", ""), inst, "pc", e._op_vars(op, inst)))
		"mark":
			eng.st["vars"][e.say(String(op["key"]), inst)] = int(W.w["day"])
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
	return W.lifespan(int(a["lv"]))
func lf(a) -> float:
	return float(a["age"]) / float(W.lifespan(int(a["lv"])))
func player():
	return W.P()
func known(a) -> bool:
	return W.known(a)
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
