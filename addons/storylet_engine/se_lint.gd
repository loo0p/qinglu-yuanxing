extends RefCounted
## 内容包校验（lint）：表达式能否解析、#符号# 是否存在、{变量} 有没有来处、连锁目标在不在、op 认不认识。
## 用法：var r = SELint.lint([pack_dict, ...])  → {"errors": [...], "warnings": [...], "stats": {...}}
## 命令行：godot --headless -s res://addons/storylet_engine/tools/lint_cli.gd -- data/packs/*.json

const BUILTIN_OPS := ["chron", "log", "var", "say", "set", "flag", "gvar", "schedule", "chain", "run", "emit", "offer", "if", "chance", "pick", "cast", "each", "drop"]
const TRIG := ["actor", "daily", "chain", "bio", "offer", "manual"]

static func lint(packs: Array) -> Dictionary:
	var errs := []
	var warns := []
	var gram := {}
	var defs := {}
	var host_vars := []
	var host_ops := []
	var host_names := []
	var signals := {}
	for p in packs:
		for k in p.get("grammar", {}):
			gram[k] = true
		host_vars += p.get("host_vars", [])
		host_ops += p.get("host_ops", [])
		host_names += p.get("host_names", [])
		for s in p.get("storylets", []):
			if not s.has("id"):
				errs.append("[%s] 有一条 storylet 没写 id" % p.get("id", "?"))
				continue
			if defs.has(s["id"]):
				warns.append("storylet 重名（后者覆盖前者）：" + String(s["id"]))
			defs[s["id"]] = s
			var t := String(s.get("trigger", "manual"))
			if t.begins_with("on:"):
				signals[t.substr(3)] = true
			elif not t in TRIG:
				errs.append("[%s] trigger 不认识：%s" % [s["id"], t])
	# 语法表内部引用
	for p in packs:
		for k in p.get("grammar", {}):
			var alts = p["grammar"][k]
			for a in (alts if alts is Array else [alts]):
				for r in _refs(String(a)):
					if not gram.has(r):
						errs.append("语法 #%s# 里引用了不存在的 #%s#" % [k, r])
	var n_out := 0
	var n_choice := 0
	for sid in defs:
		var s: Dictionary = defs[sid]
		var t := String(s.get("trigger", "manual"))
		var roles := []
		for r in s.get("in", ["A"] if t in ["actor", "bio"] or t.begins_with("on:") else []):
			roles.append(String(r))
		for r in s.get("roles", []):
			if not r.has("name"):
				errs.append("[%s] 有个角色没写 name" % sid)
				continue
			roles.append(String(r["name"]))
		var vars := {}
		_collect_vars(s, vars)
		for k in s.get("ctx_in", []):
			vars[k] = true
		var names := ["g", "se", "ctx", "SELF"] + roles + host_names
		var ctxv := {"sid": sid, "names": names, "roles": roles, "vars": vars, "gram": gram, "host_vars": host_vars,
			"host_ops": host_ops, "defs": defs, "signals": signals, "errs": errs, "warns": warns}
		for key in ["when", "weight", "p", "cast_when"]:
			if s.has(key):
				_expr(s[key], ctxv, key)
		if s.has("age"):
			_expr(s["age"][0], ctxv, "age"); _expr(s["age"][1], ctxv, "age")
		for r in s.get("roles", []):
			for key in ["from", "where", "weight", "fixed"]:
				if r.has(key):
					_expr(r[key], ctxv, "roles." + String(r.get("name", "?")) + "." + key)
		_text(s.get("text", ""), ctxv, "text")
		_ops(s.get("effects", []), ctxv)
		_ops(s.get("present_effects", []), ctxv)
		if s.has("choices"):
			for c in s["choices"]:
				n_choice += 1
				_expr(c.get("when", ""), ctxv, "choice.when")
				_text(c.get("label", ""), ctxv, "label")
				_ops(c.get("effects", []), ctxv)
				if c.get("outcomes", []).is_empty() and not c.has("text"):
					warns.append("[%s] 选项 %s 没有结果" % [sid, c.get("id", "?")])
				for o in c.get("outcomes", []):
					n_out += 1
					_outcome(o, ctxv)
		elif s.has("outcomes"):
			if s["outcomes"].is_empty():
				warns.append("[%s] outcomes 为空" % sid)
			for o in s["outcomes"]:
				n_out += 1
				_outcome(o, ctxv)
		elif s.get("effects", []).is_empty():
			warns.append("[%s] 既没有 outcomes 也没有 effects" % sid)
	return {"errors": errs, "warnings": warns, "stats": {"storylets": defs.size(), "outcomes": n_out, "choices": n_choice, "symbols": gram.size()}}

static func _outcome(o: Dictionary, c: Dictionary) -> void:
	_expr(o.get("when", ""), c, "outcome.when")
	_expr(o.get("weight", ""), c, "outcome.weight")
	_text(o.get("text", ""), c, "outcome.text")
	_ops(o.get("effects", []), c)

static func _collect_vars(x, vars: Dictionary) -> void:
	if x is Dictionary:
		if x.get("op", "") in ["var", "say", "set"] and x.has("name"):
			vars[String(x["name"])] = true
		if x.get("op", "") in ["cast", "each"]:
			vars["@role:" + String(x.get("name", x.get("as", "X")))] = true
		for k in x:
			if k == "vars" and x[k] is Dictionary:
				for v in x[k]:
					vars[String(v)] = true
			_collect_vars(x[k], vars)
	elif x is Array:
		for y in x:
			_collect_vars(y, vars)

static func _expr(src, c: Dictionary, where: String) -> void:
	if not (src is String) or String(src).strip_edges() == "":
		return
	var names: Array = c["names"].duplicate()
	for v in c["vars"]:
		if String(v).begins_with("@role:"):
			names.append(String(v).substr(6))
	var e := Expression.new()
	if e.parse(String(src), PackedStringArray(names)) != OK:
		c["errs"].append("[%s] %s 表达式解析失败：%s — %s" % [c["sid"], where, src, e.get_error_text()])

static func _refs(t: String) -> Array:
	var out := []
	var re := RegEx.new()
	re.compile("#([^#\\[\\]\\.]+?)(\\.[A-Za-z]+)*#")
	for m in re.search_all(t):
		out.append(m.get_string(1))
	return out

static func _text(t, c: Dictionary, where: String, extra: Dictionary = {}) -> void:
	var lst: Array = t if t is Array else [t]
	for x in lst:
		var s := String(x)
		for r in _refs(s):
			if "{" in r:
				# 按变量拼出来的符号（#d_like_{like}#）：至少要有一个以前缀开头的符号
				var pre: String = String(r).substr(0, r.find("{"))
				var any := false
				for gk in c["gram"]:
					if String(gk).begins_with(pre):
						any = true
						break
				if not any:
					c["errs"].append("[%s] %s 的动态符号 #%s# 没有任何 %s* 符号" % [c["sid"], where, r, pre])
			elif not c["gram"].has(r):
				c["errs"].append("[%s] %s 引用了不存在的符号 #%s#" % [c["sid"], where, r])
		var re := RegEx.new()
		re.compile("\\{([^{}]+)\\}")
		for m in re.search_all(s):
			var v := m.get_string(1)
			if not (v in c["roles"] or c["vars"].has(v) or v in c["host_vars"] or extra.has(v) or c["vars"].has("@role:" + v)):
				c["warns"].append("[%s] %s 里的 {%s} 没有来处（不是角色、ctx 变量或 host_vars）" % [c["sid"], where, v])

static func _ops(ops, c: Dictionary) -> void:
	if not (ops is Array):
		c["errs"].append("[%s] effects 不是数组" % c["sid"])
		return
	for op in ops:
		if not (op is Dictionary):
			c["errs"].append("[%s] op 不是对象" % c["sid"])
			continue
		var k := String(op.get("op", ""))
		if k == "":
			c["errs"].append("[%s] op 缺 op 字段" % c["sid"])
			continue
		if not (k in BUILTIN_OPS or k in c["host_ops"]):
			c["errs"].append("[%s] 不认识的 op：%s（若是游戏自定义，请写进 pack 的 host_ops）" % [c["sid"], k])
		if op.has("when"):
			_expr(op["when"], c, "op.when")
		for key in ["value", "p", "from", "where", "weight", "set", "add"]:
			if op.has(key) and op[key] is String:
				_expr(op[key], c, "op." + k + "." + key)
		if op.has("text"):
			var ex := {}
			for v in op.get("vars", {}):
				ex[v] = true
			_text(op["text"], c, "op." + k, ex)
		if k in ["schedule", "chain", "run", "offer"]:
			if not c["defs"].has(op.get("id", "")):
				c["errs"].append("[%s] %s 指向不存在的 storylet：%s" % [c["sid"], k, op.get("id", "")])
		if k == "emit" and not c["signals"].has(op.get("signal", "")):
			c["warns"].append("[%s] emit 的信号 %s 没有任何 on:%s 监听" % [c["sid"], op.get("signal", ""), op.get("signal", "")])
		for sub in ["then", "else", "effects"]:
			if op.has(sub):
				_ops(op[sub], c)
		if op.has("options"):
			for o in op["options"]:
				_expr(o.get("weight", ""), c, "pick.weight")
				_expr(o.get("when", ""), c, "pick.when")
				_ops(o.get("effects", []), c)
