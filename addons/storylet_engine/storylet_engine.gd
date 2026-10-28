extends RefCounted
## Storylet Engine — 数据驱动、可插拔的事件 / 叙事引擎（与具体游戏无关）
##
## 思路取自：StoryNexus / Fallen London 的 storylet + quality（QBN）；Valve L4D 的模糊规则匹配
## （同一信号下最具体 / 优先级最高的那条胜出）；CK3 事件（trigger / immediate / option / ai_chance）；
## RimWorld 的说书人节奏与 Tale；Caves of Qud 的“先发生、后成文”的生平生成；Tracery 变体语法
## （vendor/tracery.gd，来自 GDTracery，Apache-2.0）。
##
## 游戏只通过 adapter（鸭子类型的胶水对象）接入，见 README.md 的“Adapter 接口”。
## 引擎全部状态在 st（纯 Dictionary，可原样放进游戏存档 JSON）；随机数自带种子，存读档后可复现。

const Tracery = preload("res://addons/storylet_engine/vendor/tracery.gd")
const VERSION := "1.0.0"
const TRIGGERS := ["actor", "daily", "chain", "bio", "offer", "manual"]   # 另有 "on:<信号名>"

var adapter = null
var st: Dictionary = {}
var rng := RandomNumberGenerator.new()
var defs := {}            # id -> storylet
var order := []           # 载入顺序
var by_trig := {}         # trigger -> [id]
var grammar := {}         # 合并后的语法表
var packs := {}           # pack id -> pack
var cfg := {"family_decay": 6.0, "novelty": 0.0, "recent_frac": 0.5, "max_queue": 400}
var errors := []          # 运行期错误（表达式出错、缺变量……），给 lint / 测试看
var trace = null          # 设成 [] 就记下每次触发 [day, sid, oid, actor_id, text]
var _gram = null
var _exprs := {}
var _bio = null           # biography() 期间收集行
var _depth := 0

func _init(a = null, state = null, seed_v: int = 0) -> void:
	adapter = a
	bind_state({} if state == null else state, seed_v)

# ================================================================ 状态 / 存读
## 绑定（或新建）引擎状态。state 就是存档里那一块 Dictionary，引擎直接在上面读写。
func bind_state(state: Dictionary, seed_v: int = 0) -> void:
	st = state
	for k in ["flags", "fired", "last", "alast", "fam", "recent", "vars"]:
		if not st.has(k):
			st[k] = {}
	if not st.has("q"):
		st["q"] = []
	if st.has("rng"):
		rng.seed = int(st.get("seed", 0))
		rng.state = String(st["rng"]).to_int()
	else:
		st["seed"] = seed_v
		rng.seed = seed_v
		_sync()

func _sync() -> void:
	st["rng"] = str(rng.state)   # 64 位整数存成字符串：JSON 的浮点会丢精度

func save_state() -> Dictionary:
	_sync()
	return st

# ================================================================ 内容包
func load_pack_file(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		errors.append("pack 打不开：" + path)
		return false
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		errors.append("pack 不是 JSON 对象：" + path)
		return false
	add_pack(d)
	return true

## 随时可加（热插拔）：同 id 的 storylet 后加的覆盖先加的；语法表合并（同名符号的候选拼在一起）
func add_pack(p: Dictionary) -> void:
	var pid := String(p.get("id", "pack%d" % packs.size()))
	packs[pid] = p
	for k in p.get("config", {}):
		cfg[k] = p["config"][k]
	for sym in p.get("grammar", {}):
		var alts = p["grammar"][sym]
		if not (alts is Array):
			alts = [alts]
		if grammar.has(sym) and String(sym) in p.get("override", []):
			grammar[sym] = alts.duplicate()
		elif grammar.has(sym):
			grammar[sym] = grammar[sym] + alts
		else:
			grammar[sym] = alts.duplicate()
	for s in p.get("storylets", []):
		var sid := String(s["id"])
		s["_pack"] = pid
		s["_names"] = role_names(s)
		if not defs.has(sid):
			order.append(sid)
		defs[sid] = s
	_reindex()
	_gram = null

## 一条 storylet 里可能出现的全部角色名（in / roles / cast 与 each 等 op 临时绑的）。
## 表达式里没绑上的角色当 null，这样 "M != null" 这种判断能写。
static func role_names(s: Dictionary) -> Array:
	var seen := {}
	for r in s.get("in", []):
		seen[String(r)] = true
	for r in s.get("roles", []):
		seen[String(r["name"])] = true
	_scan_names(s, seen)
	var out := seen.keys()
	out.sort()
	return out

static func _scan_names(v, seen: Dictionary) -> void:
	if v is Dictionary:
		var k := String(v.get("op", ""))
		if k in ["cast", "drop"] and v.has("name"):
			seen[String(v["name"])] = true
		if v.has("as") and k != "":
			seen[String(v["as"])] = true
		if v.has("cast") and v["cast"] is Dictionary:
			for ck in v["cast"]:
				seen[String(ck)] = true
		for x in v.values():
			if x is Dictionary or x is Array:
				_scan_names(x, seen)
	elif v is Array:
		for x in v:
			if x is Dictionary or x is Array:
				_scan_names(x, seen)

func remove_pack(pid: String) -> void:
	if not packs.has(pid):
		return
	packs.erase(pid)
	var keep := packs.values()
	defs.clear(); order.clear(); grammar.clear()
	for p in keep:
		add_pack(p)
	_reindex()

func _reindex() -> void:
	by_trig.clear()
	for sid in order:
		var t := String(defs[sid].get("trigger", "manual"))
		if not by_trig.has(t):
			by_trig[t] = []
		by_trig[t].append(sid)
	if by_trig.has("bio"):
		by_trig["bio"].sort_custom(func(a, b): return float(defs[a].get("order", 0)) < float(defs[b].get("order", 0)))

func has(sid: String) -> bool:
	return defs.has(sid)

# ================================================================ 实例 / 角色
## 一次事件实例：{sid, cast: {角色: id}, ctx: {}}；act 是临时缓存（不进存档）
func make_inst(sid: String, cast: Dictionary = {}, ctx: Dictionary = {}) -> Dictionary:
	var c := {}
	for k in cast:
		var v = cast[k]
		c[k] = _id(v) if v is Dictionary or v is Object else v
	return {"sid": sid, "cast": c, "ctx": ctx.duplicate(true), "act": {}}

func _id(a):
	return adapter.se_id(a)

## id 的规范字符串：JSON 读回来的 2.0 与 2 视为同一个人
static func _k(v) -> String:
	if v is float and v == floorf(v):
		return str(int(v))
	return str(v)

func actor(inst: Dictionary, role: String):
	if inst["act"].has(role):
		return inst["act"][role]
	if not inst["cast"].has(role):
		return null
	var a = adapter.se_actor(inst["cast"][role])
	inst["act"][role] = a
	return a

func _bind(inst: Dictionary, role: String, a) -> void:
	inst["cast"][role] = _id(a)
	inst["act"][role] = a

func _unbind(inst: Dictionary, role: String) -> void:
	inst["cast"].erase(role)
	inst["act"].erase(role)

## 按 roles 依次选角：from（候选表达式，缺省全体）/ where（含 SELF 的条件）/ weight（权重）/ optional / fixed
func cast_roles(s: Dictionary, inst: Dictionary) -> bool:
	for r in s.get("roles", []):
		var nm := String(r["name"])
		if inst["cast"].has(nm) or r.get("each", false):
			continue
		var a = _cast_one(r, inst)
		if a == null:
			if r.get("optional", false):
				continue
			return false
		_bind(inst, nm, a)
	return true

func _cands(r: Dictionary, inst: Dictionary) -> Array:
	var src = r.get("from", "")
	var pool: Array = adapter.se_actors() if String(src) == "" else _as_array(ev(src, inst))
	if r.has("fixed"):
		var f = ev(r["fixed"], inst)
		pool = [] if f == null else [f]
	var taken := {}
	if not r.get("allow_same", false):
		for k in inst["cast"]:
			taken[_k(inst["cast"][k])] = true
	var out := []
	for a in pool:
		if a == null or taken.has(_k(_id(a))):
			continue
		if r.has("where") and not truthy(ev(r["where"], inst, a)):
			continue
		out.append(a)
	return out

func _cast_one(r: Dictionary, inst: Dictionary):
	var cs := _cands(r, inst)
	if cs.is_empty():
		return null
	if not r.has("weight"):
		return cs[rng.randi() % cs.size()]
	var ws := []
	for a in cs:
		ws.append(maxf(0.0, num(ev(r["weight"], inst, a))))
	return _wpick(cs, ws)

func _as_array(v) -> Array:
	if v is Array:
		return v
	if v == null:
		return []
	return [v]

# ================================================================ 表达式（Godot Expression）
## 可用名字：g = adapter，se = 引擎，ctx = 本次实例变量，SELF = 选角候选，以及各角色名（A、B……）
func ev(src, inst: Dictionary, self_v = null):
	if src == null:
		return true
	if src is bool or src is int or src is float:
		return src
	var code := String(src).strip_edges()
	if code == "":
		return true
	var names := ["g", "se", "ctx", "SELF"]
	var vals := [adapter, self, inst["ctx"], self_v]
	var rset := {}
	for k in inst["cast"]:
		rset[String(k)] = true
	for k in defs.get(inst.get("sid", ""), {}).get("_names", []):
		rset[String(k)] = true
	var rs: Array = rset.keys()
	rs.sort()
	for k in rs:
		names.append(String(k))
		vals.append(actor(inst, String(k)) if inst["cast"].has(k) else null)
	var key := code + "|" + ",".join(names)
	var e: Expression = _exprs.get(key)
	if e == null:
		e = Expression.new()
		if e.parse(code, PackedStringArray(names)) != OK:
			errors.append("表达式解析失败 [%s]：%s — %s" % [inst.get("sid", ""), code, e.get_error_text()])
			_exprs[key] = null
			return null
		_exprs[key] = e
	var out = e.execute(vals, null, false)
	if e.has_execute_failed():
		_err("表达式执行失败 [%s]：%s — %s" % [inst.get("sid", ""), code, e.get_error_text()])
		return null
	return out

func _err(t: String) -> void:
	if errors.size() < 200:
		errors.append(t)

static func truthy(v) -> bool:
	if v == null:
		return false
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	if v is String:
		return v != ""
	if v is Array or v is Dictionary:
		return not v.is_empty()
	return true

static func num(v) -> float:
	if v is int or v is float:
		return float(v)
	if v is bool:
		return 1.0 if v else 0.0
	return 0.0

# ---- 表达式里可调用的引擎函数（se.xxx）
func now() -> int:
	return int(adapter.se_now())

func flag(k: String):
	return st["flags"].get(k, 0)

func fired(sid: String) -> int:
	return int(st["fired"].get(sid, 0))

func since(sid: String) -> int:
	return now() - int(st["last"].get(sid, -99999))

func asince(sid: String, a) -> int:
	return now() - int(st["alast"].get(sid + "@" + _k(_id(a)), -99999))

func fsince(fam: String) -> int:
	return now() - int(st["fam"].get(fam, -99999))

func chance(p: float) -> bool:
	return rng.randf() < p

func roll(a: float, b: float) -> float:
	return rng.randf_range(a, b)

func ri(a: int, b: int) -> int:
	return rng.randi_range(a, b)

func var_get(k: String, d = 0):
	return st["vars"].get(k, d)

# ================================================================ 文本
func _grammar():
	if _gram == null:
		_gram = Tracery.Grammar.new(grammar)
		_gram.set_rng(rng)
		_gram.picker = _pick_alt
	return _gram

## 不重复挑：避开该符号最近用过的一半（recent_frac）
func _pick_alt(sym: String, n: int) -> int:
	if n <= 1:
		return 0
	var dq: Array = st["recent"].get(sym, [])
	var cand := []
	for i in n:
		if not (float(i) in dq or i in dq):
			cand.append(i)
	if cand.is_empty():
		cand = range(n)
	var i: int = cand[rng.randi() % cand.size()]
	dq.append(i)
	while dq.size() > maxi(1, int(n * float(cfg.get("recent_frac", 0.5)))):
		dq.pop_front()
	st["recent"][sym] = dq
	return i

## 文本：字符串 / 数组（数组先挑一条）→ Tracery 展开 #符号# → 填 {变量}
## {X}：X 是角色名 → adapter.se_name；ctx / vars 里有 → 值；否则问 adapter.se_var(X, inst)
func say(t, inst: Dictionary, key: String = "", vars: Dictionary = {}) -> String:
	if t == null:
		return ""
	if t is Array:
		if t.is_empty():
			return ""
		t = t[_pick_alt("@" + inst.get("sid", "") + ":" + key, t.size())]
	var s := _fill(String(t), inst, vars)   # 先填变量：允许 "#d_like_{like}#" 这种按变量选语法符号
	if "#" in s:
		s = _fill(_grammar().flatten(s), inst, vars)
	return s

func _fill(s: String, inst: Dictionary, vars: Dictionary) -> String:
	if not "{" in s:
		return s
	var out := ""
	var i := 0
	while i < s.length():
		var j := s.find("{", i)
		if j < 0:
			out += s.substr(i)
			break
		var k := s.find("}", j)
		if k < 0:
			out += s.substr(i)
			break
		out += s.substr(i, j - i)
		out += _var(s.substr(j + 1, k - j - 1), inst, vars)
		i = k + 1
	return out

func _var(nm: String, inst: Dictionary, vars: Dictionary) -> String:
	if vars.has(nm):
		var v = vars[nm]
		if v is String and inst["cast"].has(v):
			return String(adapter.se_name(actor(inst, v)))
		return _vstr(v)
	if inst["cast"].has(nm):
		return String(adapter.se_name(actor(inst, nm)))
	if inst["ctx"].has(nm):
		return _vstr(inst["ctx"][nm])
	if adapter.has_method("se_var"):
		var v2 = adapter.se_var(nm, inst, self)
		if v2 != null:
			return _vstr(v2)
	_err("缺变量 {%s} [%s]" % [nm, inst.get("sid", "")])
	return "{" + nm + "}"

func _vstr(v) -> String:
	if v is float and v == floorf(v):
		return str(int(v))
	if v is Dictionary and adapter != null:
		return String(adapter.se_name(v))
	return str(v)

## op 里的 vars：{"o": "B"}（角色名）或表达式（"=g.place(A)"）或字面量
func _op_vars(op: Dictionary, inst: Dictionary) -> Dictionary:
	var out := {}
	var vs: Dictionary = op.get("vars", {})
	for k in vs:
		var v = vs[k]
		if v is String and v.begins_with("="):
			out[k] = ev(v.substr(1), inst)
		else:
			out[k] = v
	return out

# ================================================================ 选择 / 节奏
func _wpick(items: Array, ws: Array):
	var tot := 0.0
	for x in ws:
		tot += float(x)
	if tot <= 0.0:
		return items[rng.randi() % items.size()]
	var r := rng.randf() * tot
	for i in items.size():
		r -= float(ws[i])
		if r <= 0.0:
			return items[i]
	return items[items.size() - 1]

## 门槛：max / cooldown / actor_cooldown / family_gap / min_day
func gate(s: Dictionary, a = null) -> bool:
	var sid := String(s["id"])
	if s.has("max") and fired(sid) >= int(s["max"]):
		return false
	if s.has("min_day") and now() < int(s["min_day"]):
		return false
	if s.has("cooldown") and since(sid) < int(s["cooldown"]):
		return false
	if a != null and s.has("actor_cooldown") and asince(sid, a) < int(s["actor_cooldown"]):
		return false
	if s.has("family") and s.has("family_gap") and fsince(String(s["family"])) < int(s["family_gap"]):
		return false
	return true

## 显著度 salience：weight × 新鲜度（同一条刚出过就淡些）× 同族衰减
func salience(s: Dictionary, inst: Dictionary) -> float:
	var w := num(ev(s.get("weight", 1.0), inst))
	if w <= 0.0:
		return 0.0
	var nov := float(s.get("novelty", cfg.get("novelty", 0.0)))
	if nov > 0.0 and st["last"].has(String(s["id"])):
		w *= 1.0 - exp(-float(since(String(s["id"]))) / nov)
	if s.has("family"):
		var fd := float(cfg.get("family_decay", 6.0))
		if fd > 0.0 and st["fam"].has(String(s["family"])):
			w *= 1.0 - 0.6 * exp(-float(fsince(String(s["family"]))) / fd)
	return w

## 某个触发器下，给定预先绑好的角色，挑一条可发的 storylet（加权）；返回实例或 {}
func draw(trigger: String, cast: Dictionary = {}, ctx: Dictionary = {}, filter: Callable = Callable()) -> Dictionary:
	var cands := []
	var ws := []
	var a0 = null
	if cast.has("A"):
		a0 = cast["A"] if cast["A"] is Dictionary or cast["A"] is Object else adapter.se_actor(cast["A"])
	for sid in by_trig.get(trigger, []):
		var s: Dictionary = defs[sid]
		if filter.is_valid() and not filter.call(s):
			continue
		if not gate(s, a0):
			continue
		var inst := make_inst(sid, cast, ctx)
		if not truthy(ev(s.get("when", ""), inst)):
			continue
		var w := salience(s, inst)
		if w <= 0.0:
			continue
		cands.append(inst)
		ws.append(w)
	if cands.is_empty():
		return {}
	# 选中后再选角（选角失败就换下一条）
	while not cands.is_empty():
		var inst: Dictionary = _wpick(cands, ws)
		var i := cands.find(inst)
		if cast_roles(defs[inst["sid"]], inst) and truthy(ev(defs[inst["sid"]].get("cast_when", ""), inst)):
			return inst
		cands.remove_at(i)
		ws.remove_at(i)
	return {}

# ================================================================ 触发
## 每日：到期的连锁 → daily（世界级）→ 由游戏决定何时对每个人物调 beat()
func tick_due() -> int:
	var n := 0
	var d := now()
	var due := []
	for it in st["q"]:
		if int(it[0]) <= d:
			due.append(it)
	for it in due:
		st["q"].erase(it)
		var sid := String(it[1])
		if not defs.has(sid):
			continue
		var inst := make_inst(sid, it[2], it[3])
		var ok := true
		for k in inst["cast"]:
			if actor(inst, k) == null:
				ok = false
		if ok and adapter.has_method("se_alive"):
			for k in inst["cast"]:
				if not defs[sid].get("dead_ok", []).has(k) and not adapter.se_alive(actor(inst, k)):
					ok = false
		if not ok or not gate(defs[sid]) or not truthy(ev(defs[sid].get("when", ""), inst)):
			continue
		if not cast_roles(defs[sid], inst):
			continue
		run(inst)
		n += 1
	_sync()
	return n

func tick_world() -> int:
	var n := 0
	for sid in by_trig.get("daily", []):
		var s: Dictionary = defs[sid]
		if not gate(s):
			continue
		if s.has("p") and rng.randf() >= num(ev(s["p"], make_inst(sid))):
			continue
		var inst := make_inst(sid)
		if not truthy(ev(s.get("when", ""), inst)) or not cast_roles(s, inst):
			continue
		run(inst)
		n += 1
	_sync()
	return n

## 一个人物的一拍：从 trigger="actor" 的 storylet 里按显著度挑一条（A = 这个人）
func beat(a, ctx: Dictionary = {}) -> String:
	var inst := draw("actor", {"A": a}, ctx)
	if inst.is_empty():
		_sync()
		return ""
	run(inst)
	_sync()
	return String(inst["sid"])

## 信号（模糊规则匹配）：所有 trigger="on:<sig>" 且条件成立的都发；同一 family 里只发 priority 最高的
## （同分加权）——这就是 L4D 规则库“最具体者胜出”的做法，具体程度由作者写进 priority。
func emit(sig: String, cast: Dictionary = {}, ctx: Dictionary = {}) -> int:
	var groups := {}
	var a0 = null
	if cast.has("A"):
		a0 = cast["A"] if cast["A"] is Dictionary or cast["A"] is Object else adapter.se_actor(cast["A"])
	for sid in by_trig.get("on:" + sig, []):
		var s: Dictionary = defs[sid]
		if not gate(s, a0):
			continue
		var inst := make_inst(sid, cast, ctx)
		if not truthy(ev(s.get("when", ""), inst)):
			continue
		var fam := String(s.get("family", "@" + sid))
		var pr := float(s.get("priority", 0))
		if not groups.has(fam) or pr > float(groups[fam][0]):
			groups[fam] = [pr, [inst], [salience(s, inst)]]
		elif pr == float(groups[fam][0]):
			groups[fam][1].append(inst)
			groups[fam][2].append(salience(s, inst))
	var n := 0
	var fams := groups.keys()
	fams.sort()
	for fam in fams:
		var g = groups[fam]
		var insts: Array = g[1]
		var ws: Array = g[2]
		while not insts.is_empty():
			var inst: Dictionary = _wpick(insts, ws)
			var i := insts.find(inst)
			if cast_roles(defs[inst["sid"]], inst):
				run(inst)
				n += 1
				break
			insts.remove_at(i)
			ws.remove_at(i)
	_sync()
	return n

## 直接发一条（chain / manual）。返回是否发成
func fire(sid: String, cast: Dictionary = {}, ctx: Dictionary = {}) -> bool:
	if not defs.has(sid):
		_err("没有这条 storylet：" + sid)
		return false
	var inst := make_inst(sid, cast, ctx)
	if not truthy(ev(defs[sid].get("when", ""), inst)) or not cast_roles(defs[sid], inst):
		return false
	run(inst)
	_sync()
	return true

func schedule(days: int, sid: String, cast: Dictionary, ctx: Dictionary = {}) -> void:
	var c := {}
	for k in cast:
		c[k] = _id(cast[k]) if cast[k] is Dictionary or cast[k] is Object else cast[k]
	st["q"].append([now() + days, sid, c, ctx.duplicate(true)])
	while st["q"].size() > int(cfg.get("max_queue", 400)):
		st["q"].pop_front()

func _log(s: Dictionary, inst: Dictionary) -> void:
	var sid := String(s["id"])
	st["fired"][sid] = fired(sid) + 1
	st["last"][sid] = now()
	if s.has("family"):
		st["fam"][String(s["family"])] = now()
	var a = actor(inst, "A")
	if a != null:
		st["alast"][sid + "@" + _k(_id(a))] = now()

## 运行一个实例：先 effects（CK3 的 immediate），再按 outcomes 挑一个结果执行。
## 有 choices 的（给玩家选的）不在这里结算：交给 adapter.se_offer，由游戏 present/choose。
func run(inst: Dictionary) -> String:
	var s: Dictionary = defs[inst["sid"]]
	_log(s, inst)
	_depth += 1
	if _depth > 12:
		_depth -= 1
		_err("连锁太深，停在 " + String(inst["sid"]))
		return ""
	_each_role(s, inst, func(): _do(s.get("effects", []), inst))
	var box := [""]   # lambda 里改不了外层局部变量，用数组带出来
	if s.has("choices"):
		if adapter.has_method("se_offer"):
			adapter.se_offer(inst, self)
		box[0] = "@offer"
	elif s.has("outcomes"):
		_each_role(s, inst, func():
			var o := pick_outcome(s["outcomes"], inst)
			if not o.is_empty():
				box[0] = String(o.get("id", ""))
				_do(o.get("effects", []), inst)
				_stat(inst, String(box[0])))
	else:
		_stat(inst, "")
	_depth -= 1
	return String(box[0])

## each 角色：对每个候选各跑一遍（比如每个徒弟都为师尊守灵）
func _each_role(s: Dictionary, inst: Dictionary, f: Callable) -> void:
	var er = null
	for r in s.get("roles", []):
		if r.get("each", false):
			er = r
	if er == null or inst["cast"].has(String(er["name"])):
		f.call()
		return
	var cs := _cands(er, inst)
	var lim := int(er.get("limit", 6))
	for a in cs.slice(0, lim):
		_bind(inst, String(er["name"]), a)
		f.call()
	_unbind(inst, String(er["name"]))

func _stat(inst: Dictionary, oid: String) -> void:
	var k := String(inst["sid"]) + "/" + oid
	st["fired"]["@" + k] = int(st["fired"].get("@" + k, 0)) + 1

## 多结果：先按 when 过滤，再按 weight（可写性格 / 关系 / 数值 / 骰子）加权；
## "first": true 的结果按顺序取第一个成立的（优先级分支）
func pick_outcome(list: Array, inst: Dictionary) -> Dictionary:
	var cands := []
	var ws := []
	for o in list:
		if not truthy(ev(o.get("when", ""), inst)):
			continue
		if o.get("first", false):
			return o
		var w := num(ev(o.get("weight", 1.0), inst))
		if w > 0.0:
			cands.append(o)
			ws.append(w)
	if cands.is_empty():
		return {}
	return _wpick(cands, ws)

# ================================================================ 玩家面对的事件（choices）
## {speaker: 角色 id 或 0, text, opts: [[id, label]]}
func present(inst: Dictionary) -> Dictionary:
	var s: Dictionary = defs.get(inst["sid"], {})
	if s.is_empty():
		return {"speaker": 0, "text": "……", "opts": [["ok", "罢了"]]}
	_do(s.get("present_effects", []), inst)
	var opts := []
	for c in s.get("choices", []):
		if truthy(ev(c.get("when", ""), inst)):
			opts.append([String(c["id"]), say(c.get("label", c["id"]), inst, "L" + String(c["id"]))])
	if opts.is_empty():
		opts.append(["ok", "罢了"])
	var sp = 0
	if s.has("speaker") and inst["cast"].has(String(s["speaker"])):
		sp = inst["cast"][String(s["speaker"])]
	var text := say(s.get("text", ""), inst, "T")
	_sync()
	return {"speaker": sp, "text": text, "opts": opts}

func choose(inst: Dictionary, cid: String) -> String:
	var s: Dictionary = defs.get(inst["sid"], {})
	for c in s.get("choices", []):
		if String(c["id"]) == cid:
			_do(c.get("effects", []), inst)
			var o := pick_outcome(c.get("outcomes", []), inst)
			_stat(inst, cid + ":" + String(o.get("id", "")))
			var txt := ""
			if not o.is_empty():
				_do(o.get("effects", []), inst)
				txt = say(o.get("text", ""), inst, "R" + cid + String(o.get("id", "")))
			elif c.has("text"):
				txt = say(c["text"], inst, "R" + cid)
			_sync()
			return txt
	_sync()
	return ""

# ================================================================ 生平（Qud 式：先定事件，再成文）
## 给一个人物生成“入局之前”的经历：trigger="bio" 的 storylet 按 order 依次判断，
## 年龄 age=[最小, 最大]（表达式），逐条递增。用独立种子，不扰动主随机序列。返回 [[岁数, 文本]]
func biography(a, seed_v: int, ctx0: Dictionary = {}) -> Array:
	var keep_state := rng.state
	var keep_seed := rng.seed
	var keep_recent: Dictionary = st["recent"]
	st["recent"] = {}
	rng.seed = seed_v
	var inst := make_inst("", {"A": a}, ctx0)
	inst["ctx"]["age"] = int(inst["ctx"].get("age0", 6))
	_bio = []
	for sid in by_trig.get("bio", []):
		var s: Dictionary = defs[sid]
		inst["sid"] = sid
		if not truthy(ev(s.get("when", ""), inst)):
			continue
		if s.has("p") and rng.randf() >= num(ev(s["p"], inst)):
			continue
		var base_age := int(inst["ctx"]["age"])
		var free: bool = s.get("free_age", false)   # 插曲：年纪随意落在区间里，不推进“当前年纪”，最后按年纪排序
		if s.has("age"):
			var lo := int(num(ev(s["age"][0], inst)))
			var hi := int(num(ev(s["age"][1], inst)))
			if not free:
				lo = maxi(lo, base_age)
			if hi < lo:
				continue
			inst["ctx"]["age"] = rng.randi_range(lo, hi)
		if not cast_roles(s, inst):
			inst["ctx"]["age"] = base_age
			continue
		_do(s.get("effects", []), inst)
		var o := pick_outcome(s.get("outcomes", []), inst)
		if not o.is_empty():
			_do(o.get("effects", []), inst)
		for r in s.get("roles", []):
			if not r.get("keep", false):
				_unbind(inst, String(r["name"]))
		if free:
			inst["ctx"]["age"] = base_age
	var out: Array = _bio
	var idx := []
	for i in out.size():
		idx.append([int(out[i][0]), i])
	idx.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	var sorted := []
	for e in idx:
		sorted.append(out[e[1]])
	out = sorted
	_bio = null
	st["recent"] = keep_recent
	rng.seed = keep_seed
	rng.state = keep_state
	return out

# ================================================================ 效果（可组合的 op）
func _do(ops: Array, inst: Dictionary) -> void:
	for op in ops:
		_op(op, inst)

func _who(w, inst: Dictionary) -> Array:
	var out := []
	for r in _as_array(w):
		var a = actor(inst, String(r)) if inst["cast"].has(String(r)) else null
		if a == null and String(r).begins_with("="):
			for x in _as_array(ev(String(r).substr(1), inst)):
				out.append(x)
		elif a != null:
			out.append(a)
	return out

func _op(op: Dictionary, inst: Dictionary) -> void:
	var kind := String(op.get("op", ""))
	if op.has("when") and kind != "if" and not truthy(ev(op["when"], inst)):
		return
	match kind:
		"chron", "log":
			# 写履历：who 可以是一个或几个角色；vars 把 {o} 之类映射到角色 / 表达式
			var vars := _op_vars(op, inst)
			for a in _who(op.get("who", "A"), inst):
				inst["ctx"]["_who"] = _id(a)
				var text := say(op.get("text", ""), inst, String(op.get("key", "c")), vars)
				if _bio != null:
					_bio.append([int(inst["ctx"].get("age", 0)), text])
				else:
					adapter.se_chronicle(a, text, inst, self)
					if trace != null:
						trace.append([now(), String(inst["sid"]), String(op.get("key", "")), _id(a), text])
			inst["ctx"].erase("_who")
		"var", "say":
			inst["ctx"][String(op["name"])] = say(op.get("text", ""), inst, String(op["name"]), _op_vars(op, inst))
		"set":
			inst["ctx"][String(op["name"])] = ev(op.get("value", 0), inst)
		"flag":
			var k := say(String(op["key"]), inst, "", _op_vars(op, inst))
			if op.has("set"):
				st["flags"][k] = ev(op["set"], inst)
			else:
				st["flags"][k] = num(st["flags"].get(k, 0)) + num(ev(op.get("add", 1), inst))
		"gvar":
			st["vars"][String(op["name"])] = ev(op.get("value", 0), inst)
		"schedule", "chain":
			var lo := 1
			var hi := 1
			if op.has("in"):
				var iv = op["in"]
				if iv is Array:
					lo = int(num(ev(iv[0], inst))); hi = int(num(ev(iv[1], inst)))
				else:
					lo = int(num(ev(iv, inst))); hi = lo
			var cast := _map_cast(op, inst)
			var ctx := _carry(op, inst)
			schedule(rng.randi_range(lo, maxi(lo, hi)), String(op["id"]), cast, ctx)
		"run":
			var c2 := _map_cast(op, inst)
			var ctx2 := _carry(op, inst)
			fire(String(op["id"]), c2, ctx2)
		"emit":
			var ctx3 := _carry(op, inst)
			emit(String(op["signal"]), _map_cast(op, inst), ctx3)
		"offer":
			# 把一件“要玩家来选”的事交给游戏（游戏自己排队、在合适的时候 present）
			var c4 := _map_cast(op, inst)
			var ctx4 := _carry(op, inst)
			var inst2 := make_inst(String(op["id"]), c4, ctx4)
			if defs.has(inst2["sid"]) and gate(defs[inst2["sid"]]) and truthy(ev(defs[inst2["sid"]].get("when", ""), inst2)) and cast_roles(defs[inst2["sid"]], inst2):
				_log(defs[inst2["sid"]], inst2)
				_do(defs[inst2["sid"]].get("effects", []), inst2)
				if adapter.has_method("se_offer"):
					adapter.se_offer(inst2, self)
		"if":
			_do(op.get("then", []) if truthy(ev(op.get("when", ""), inst)) else op.get("else", []), inst)
		"chance":
			_do(op.get("then", []) if rng.randf() < num(ev(op.get("p", 0.5), inst)) else op.get("else", []), inst)
		"pick":
			var o := pick_outcome(op.get("options", []), inst)
			if not o.is_empty():
				_do(o.get("effects", []), inst)
		"cast":
			# 中途补一个角色（比如秘境里随机碰上的人）
			var a = _cast_one(op, inst)
			if a != null:
				_bind(inst, String(op["name"]), a)
			else:
				_do(op.get("else", []), inst)
		"drop":
			# 放下一个临时角色（比如 each 循环里每轮重新 cast 的“同行者”）
			_unbind(inst, String(op.get("name", "")))
		"each":
			var lst := _as_array(ev(op.get("from", "[]"), inst))
			var nm := String(op.get("as", "X"))
			var lim := int(op.get("limit", 99))
			for a in lst.slice(0, lim):
				_bind(inst, nm, a)
				_do(op.get("effects", []), inst)
			_unbind(inst, nm)
		"":
			_err("op 缺 op 字段 [%s]" % inst.get("sid", ""))
		_:
			if adapter.has_method("se_op"):
				adapter.se_op(op, inst, self)
			else:
				_err("adapter 不认识 op=%s" % kind)

## 带给下一条事件的 ctx：keep 列出的原样带上，ctx 里的按表达式算（run / emit / offer / schedule 通用）
func _carry(op: Dictionary, inst: Dictionary) -> Dictionary:
	var out := {}
	for k in op.get("keep", []):
		if inst["ctx"].has(k):
			out[k] = inst["ctx"][k]
	for k in op.get("ctx", {}):
		out[k] = ev(op["ctx"][k], inst)
	return out

## cast 映射：{"新角色": "旧角色"} 或 {"新角色": "=表达式"}；缺省原样带上全部角色
func _map_cast(op: Dictionary, inst: Dictionary) -> Dictionary:
	if not op.has("cast"):
		return inst["cast"].duplicate()
	var out := {}
	for k in op["cast"]:
		var v = op["cast"][k]
		if v is String and v.begins_with("="):
			var a = ev(v.substr(1), inst)
			if a != null:
				out[k] = _id(a)
		elif inst["cast"].has(String(v)):
			out[k] = inst["cast"][String(v)]
	return out

# ================================================================ 统计
func outcome_counts() -> Dictionary:
	var out := {}
	for k in st["fired"]:
		if String(k).begins_with("@"):
			out[String(k).substr(1)] = int(st["fired"][k])
	return out
