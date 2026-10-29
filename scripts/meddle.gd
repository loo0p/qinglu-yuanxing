extends RefCounted
## 插手（v0.10）：人物的念头不再一冒出来就在幕后了结。
## 有些事（寻仇、截道、偷窃、夺宝、造谣、示好、叛门、讨债）要过几日才动手——这几日里，风声可能走漏：
## 坊市传闻里多一条“听说某某要……”，或者有人找到她、或她在路上听见。她可以去提醒、去护着、去帮一把、去说和、
## 抢先下手、去告一状，或者不管。她做了什么，结算还是走人物自主那一套（AG.npc_resolve，_win 读 edge 加成），
## 结果写回所有当事人的记忆、好感、动机，也会变成别人嘴里关于她的闲话。
## 状态全在 world.w["plots"]（整数与字符串，JSON 往返不变）；旧档没有这个键，读入后照常。
## 这里不 preload agency.gd（免得两个脚本互相引用），一律经 W.AG 调。

const PLOT_V = ["寻仇", "截杀", "偷窃", "夺宝", "造谣", "示好", "叛门", "讨债"]
const TIDS = ["风声", "插手"]
const HOSTILE = ["寻仇", "截杀", "偷窃", "夺宝", "造谣"]

static func plots(W) -> Array:
	if not W.w.has("plots"):
		W.w["plots"] = []
	return W.w["plots"]

static func get_plot(W, pid: int) -> Dictionary:
	for pt in plots(W):
		if int(pt["i"]) == pid:
			return pt
	return {}

## 还能不能插手：没了结、没被她放过、日子没到、人都还在
static func actable(W, pt: Dictionary) -> bool:
	if pt.is_empty() or int(pt["p"]) != 0 or int(pt.get("ig", 0)) == 1 or int(pt["due"]) <= int(W.w["day"]):
		return false
	var a: Dictionary = W.C(pt["a"])
	if a.is_empty() or not a["alive"]:
		return false
	if int(pt["b"]) > 0:
		var b: Dictionary = W.C(pt["b"])
		if b.is_empty() or not b["alive"]:
			return false
	return true

## 传闻条目 → 可插手的那件事（没有就 -1）
static func news_pid(W, it: Array) -> int:
	if it.size() < 5 or String(it[3]) != "谋":
		return -1
	var pt := get_plot(W, int(it[4]))
	return int(pt["i"]) if actable(W, pt) else -1

## 心事页：这个人眼下谋着、而且她已经知道的事
static func plot_of(W, c: Dictionary) -> int:
	for pt in plots(W):
		if int(pt["a"]) == int(c["id"]) and int(pt["k"]) == 1 and actable(W, pt):
			return int(pt["i"])
	return -1

static func _known_any(W, a: Dictionary, b: Dictionary) -> bool:
	return W.known(a) or (not b.is_empty() and W.known(b))

# ================================================================ 起念：要过几日才动手的事
## 由 AG.act 调：返回 true 表示这件事先搁着（几日后结算），不当场了结
static func plan(W, a: Dictionary, v: String, b: Dictionary, aid: int, force: bool = false) -> bool:
	if not (v in PLOT_V):
		return false
	if v != "叛门" and (b.is_empty() or b["player"]):
		return false
	var ps := plots(W)
	var live := 0
	for x in ps:
		if int(x["p"]) < 2:
			live += 1
			if int(x["a"]) == int(a["id"]):
				return false   # 一个人一回只谋一件事
	if live >= 6 and not force:
		return false
	var kn := _known_any(W, a, b)
	if not force and W.rng.randf() > (0.6 if kn else 0.22):
		return false
	var day := int(W.w["day"])
	var pid := int(W.w.get("pln", 0))
	W.w["pln"] = pid + 1
	var pt := {"i": pid, "a": int(a["id"]), "v": v, "b": int(b["id"]) if not b.is_empty() else 0, "d": day,
		"due": day + W.rng.randi_range(3, 6), "aid": aid, "p": 0, "k": 0, "e": 0, "pl": String(a["place"])}
	if v == "夺宝":
		pt["pr"] = String(W._ch(W.AG.TREASURE))
	if v == "讨债":
		pt["owe"] = maxi(1, int(W._rel(a, b).get("owe", 0)))
	if v == "叛门":
		pt["sect"] = String(a["sect"])
	ps.append(pt)
	# 风声走漏：她认识其中的人时多半听得到
	if W.rng.randf() < (0.8 if kn else 0.4):
		W.rumor(leak(W, pt), [a] if b.is_empty() else [a, b], "谋")
		W.w["news"][-1].append(pid)
		pt["k"] = 1
	if W.rng.randf() < (0.7 if kn else 0.25):
		var inf := _informant(W, a, b)
		if inf.is_empty() and not kn:
			return true
		var roles := {"B": int(inf["id"]) if not inf.is_empty() else int(a["id"]), "X": int(a["id"]), "V": int(pt["b"])}
		W.AG._queue(W, "风声", roles, {"pid": pid, "aid": aid, "ov": 1 if inf.is_empty() else 0})
	if ps.size() > 40:
		ps.pop_front()
	return true

## 报信的人：她认识的、和当事人有来往的第三个人
static func _informant(W, a: Dictionary, b: Dictionary) -> Dictionary:
	var best := {}
	var bv := -999.0
	for o in W.npcs():
		if o == a or o == b or not W.known(o):
			continue
		var v: float = W.opinion(o, W.P())
		if not b.is_empty() and b["rel"].has(str(int(o["id"]))):
			v += 20.0
		if a["rel"].has(str(int(o["id"]))):
			v += 8.0
		v += W.rng.randf() * 10.0
		if v > bv:
			bv = v
			best = o
	return best if bv > 5.0 else {}

static func _fmt(W, pt: Dictionary) -> Dictionary:
	var a: Dictionary = W.C(pt["a"])
	var b: Dictionary = W.C(pt["b"]) if int(pt["b"]) > 0 else {}
	return {"a": a["name"], "b": b.get("name", ""), "pl": String(pt.get("pl", a["place"])), "pr": String(pt.get("pr", "")),
		"sect": String(pt.get("sect", a["sect"])), "k": str(int(pt.get("owe", 0))), "ta": W.ta(a), "tb": W.ta(b) if not b.is_empty() else "",
		"n": str(maxi(1, int(pt["due"]) - int(W.w["day"])))}

## 坊市里传的那句话（按起念的人的性子挑）
static func leak(W, pt: Dictionary) -> String:
	var a: Dictionary = W.C(pt["a"])
	var t := ""
	match String(pt["v"]):
		"寻仇":
			t = W.AG.fl(W, "谋仇闻", a, {
				"傲": ["听说{a}放了话，要当着人面同{b}把旧账算清。", "{a}在{pl}说：{b}欠的那笔，几日之内亲手讨。"],
				"慎": ["有人见{a}在{pl}一带打听{b}的行踪，问得很细。", "听说{a}这几日一直远远跟着{b}，不近不远。"],
				"仇": ["{a}在{pl}的铁匠铺磨了一夜的剑，嘴里念的是{b}的名字。", "听说{a}还记着{b}那件事，这回是要见血的。"],
				"平": ["听说{a}要去寻{b}报仇，就在这几日。", "{a}在{pl}四处打听{b}的下落，剑没离过手。", "茶棚里有人压低了声音：{a}和{b}那笔账，怕是要了了。"]})
		"截杀":
			t = W.pv("谋劫闻", ["{pl}的山道口有人在等{b}落单，听口音像是{a}。", "听说{a}盯上了{b}的储物袋，这几日总在{pl}转悠。", "有人看见{a}在{pl}的岔路口蹲了两夜，问的都是{b}几时过路。", "{pl}的脚夫说，{a}出钱打听{b}走哪条道，出手很阔。"])
		"偷窃":
			t = W.pv("谋窃闻", ["{a}近来常在{b}的住处附近晃，眼睛总往人腰间瞟。", "坊市里有人说，{a}看上了{b}的灵石匣，正寻机会下手。", "{a}这几日同{b}走得很近，近得有些不寻常。", "听说{a}手头紧，又打听过{b}的住处。"])
		"夺宝":
			t = W.pv("谋宝闻", ["{pl}出了{pr}，{a}和{b}都盯上了，谁先到算谁的。", "听说{a}打听到{pl}有{pr}，要抢在{b}前头去取。", "{pl}那边的{pr}快熟了，{a}已经动身，{b}还不知道。", "有人说{a}为了{pl}的{pr}，连闭关都停了——{b}也在打它的主意。", "{a}和{b}在坊市里差点为{pr}的消息吵起来，各自走了。"])
		"造谣":
			t = W.AG.fl(W, "谋谣闻", a, {
				"妒": ["{a}在茶棚里提起{b}，话只说半句，剩下半句叫人去猜。", "听说{a}见不得{b}风光，正四处编排{tb}的旧事。"],
				"傲": ["{a}说{b}那点修为，是拿丹药堆出来的。这话已经传到第三家茶棚了。"],
				"仇": ["{a}记着{b}的仇，近来逢人便说{tb}当年的事，添油加醋。"],
				"平": ["听说{a}正四处说{b}的闲话，还没传开。", "{a}在{pl}同人嚼{b}的舌根，说得有鼻子有眼。", "有人说{b}的坏话，追根究底，源头像是{a}。"]})
		"示好":
			t = W.AG.fl(W, "谋情闻", a, {
				"痴": ["听说{a}这些日子总往{b}那边跑，回来时耳根都是红的。", "{a}托人打听{b}喜欢什么，问得很仔细，问完又不许人说。"],
				"傲": ["{a}说自己不过是顺路，可这个月顺了{b}门前七回。"],
				"平": ["{a}托人打听{b}喜欢什么，打听得很仔细。", "听说{a}想约{b}去{pl}看灯，还没开口。", "{a}在{pl}挑了半日的簪子，说是送人，没说送谁——旁人都猜是{b}。"]})
		"叛门":
			t = W.pv("谋叛闻", ["{a}在{sect}很不顺心，有人见{ta}夜里收拾行囊。", "听说{a}想离开{sect}，只差一个下山的机会。", "{a}这一年在{sect}的月例被扣了两回，话里已经有了去意。", "有人见{a}在{pl}同别派的人喝茶，喝到很晚。"])
		"讨债":
			t = W.pv("谋债闻", ["{a}在算旧账，说{b}欠的{k}块灵石，这回非讨回来不可。", "听说{a}要上门找{b}讨那{k}块灵石，话说得很难听。", "{a}把{b}当年写的欠条翻了出来，{k}块灵石，一块不能少。", "{pl}有人听{a}念叨：{b}拖了这么久，再不还就别怪{ta}不讲情面。"])
	return t.format(_fmt(W, pt))

## 事情本身（风声、插手的开场里用）
static func _desc(W, pt: Dictionary) -> String:
	var a: Dictionary = W.C(pt["a"])
	var t := ""
	match String(pt["v"]):
		"寻仇":
			t = W.AG.fl(W, "谋仇述", a, {
				"傲": ["{a}放了话，要当着人面同{b}把旧账算清，不出{n}日", "{a}说了，{n}日之内，要{b}拔剑"],
				"慎": ["{a}已经跟了{b}好几日，只等{tb}落单", "{a}把{b}的去处摸清了，{n}日里就要动手"],
				"仇": ["{a}一直记着{b}那件事，这回是要见血的", "{a}磨了一夜的剑，说{b}躲不过这{n}日"],
				"平": ["{a}要去寻{b}报仇，就在这{n}日里", "{a}要找{b}算一笔旧账，约莫还有{n}日"]})
		"截杀":
			t = W.pv("谋劫述", ["{a}在{pl}的山道口等着，要截{b}的储物袋", "{a}盯上了{b}，打算在{pl}的岔路口下手"])
		"偷窃":
			t = W.pv("谋窃述", ["{a}看上了{b}的灵石匣，这几日要下手", "{a}常在{b}的住处附近转，像是在踩点"])
		"夺宝":
			t = W.pv("谋宝述", ["{pl}出了{pr}，{a}要抢在{b}前头去取", "{a}和{b}都盯着{pl}的{pr}，{a}打算先下手"])
		"造谣":
			t = W.pv("谋谣述", ["{a}在编排{b}的旧事，要叫{tb}在{pl}抬不起头", "{a}四处说{b}的闲话，说得有鼻子有眼"])
		"示好":
			t = W.pv("谋情述", ["{a}心里装着{b}，想寻个由头开口", "{a}托人打听{b}的喜好，看样子是动了心"])
		"叛门":
			t = W.pv("谋叛述", ["{a}想叛出{sect}，这几日夜里就要下山", "{a}在{sect}待不下去了，行囊已经收好"])
		"讨债":
			t = W.pv("谋债述", ["{a}要上门找{b}讨那{k}块灵石，{b}手头正紧", "{a}放了话，{b}再不还那{k}块灵石，就要闹到坊市去"])
	return t.format(_fmt(W, pt))

# ================================================================ 她面前：风声（有人告诉她 / 她听见了）、插手（她从传闻或心事里找回这件事）
static func _o(id: String, label: String) -> Array:
	return [id, label]

static func present(W, tid: String, roles: Dictionary, ctx: Dictionary) -> Dictionary:
	var pt := get_plot(W, int(ctx.get("pid", -1)))
	if not actable(W, pt):
		ctx["stale"] = 1
		return {"speaker": 0, "text": W.pv("风声迟", ["她赶去时，事情已经过去了。", "等她想起这件事，传闻里已经有了下文。"]), "opts": [_o("ok", "知道了")]}
	pt["k"] = 1
	var desc := _desc(W, pt)
	var at: String = W.AG._at(W, ctx, tid)
	var text := ""
	var sp := 0
	if tid == "风声":
		var inf: Dictionary = W.C(roles["B"])
		if int(ctx.get("ov", 0)) == 1:
			text = W.pv("风声闻", ["{at}，隔着一道竹帘，她听见有人在说：{d}。", "{at}歇脚时，邻桌两个散修在嚼舌根：{d}。", "{at}，有人从她身边走过，同伴问了一句，那人答：{d}。"]).format({"at": at, "d": desc})
		else:
			sp = int(inf["id"])
			text = W.AG.fl(W, "风声语", inf, {
				"慎": ["{i}在{at}拉住她，先看了看四下：“{d}。这话我只同你说。”"],
				"善": ["{i}在{at}等她，脸上有些急：“{d}。你认得的，能不能想想法子？”"],
				"侠": ["“{d}。”{i}在{at}说，“这种事，我看不过眼。”"],
				"贪": ["{i}在{at}凑过来，像是卖一个消息：“{d}。这话值一壶茶。”"],
				"平": ["{at}，{i}欲言又止，到底还是说了：“{d}。”", "{i}托人捎来一张字条，字写得很急：{d}。"]}).format({"i": inf["name"], "at": at, "d": desc})
	else:
		text = W.pv("插手开", ["她把那句传闻又想了一遍：{d}。离那日子，大约还有{n}日。", "那件事她一直搁在心上——{d}。算来还有{n}日。"]).format({"d": desc, "n": _fmt(W, pt)["n"]})
	return {"speaker": sp, "text": text, "opts": options(W, pt)}

static func options(W, pt: Dictionary) -> Array:
	var f := _fmt(W, pt)
	var a: Dictionary = W.C(pt["a"])
	var b: Dictionary = W.C(pt["b"]) if int(pt["b"]) > 0 else {}
	var ls: int = W.lingshi()
	var o := []
	var close_b: bool = not b.is_empty() and W._close_p(b)
	var close_a: bool = W._close_p(a)
	match String(pt["v"]):
		"寻仇", "截杀":
			o.append(_o("warn", ("给%s递个话" if W.known(b) else "托人给%s捎个信（1 灵石）") % f["b"]))
			o.append(_o("guard", "赶去%s身边（要走 2 个月）" % f["b"]))
			if String(pt["v"]) == "寻仇":
				o.append(_o("mediate", ("去找%s说和" % f["a"]) if ls < 5 else "备一份礼去找%s说和（5 灵石）" % f["a"]))
			elif String(a["sect"]) != "散修":
				o.append(_o("report", "去%s告%s一状" % [a["sect"], f["a"]]))
			else:
				o.append(_o("report", "去坊市管事那里报信"))
			if not close_b:
				o.append(_o("join", "帮%s一把" % f["a"]))
		"偷窃":
			o.append(_o("warn", "提醒%s看好灵石匣" % f["b"]))
			o.append(_o("catch", "守在暗处，当场拿住%s（要走 1 个月）" % f["a"]))
			o.append(_o("report", "去%s告%s一状" % [a["sect"] if String(a["sect"]) != "散修" else "坊市管事那里", f["a"]]))
		"夺宝":
			o.append(_o("first", "抢先去%s取宝（要走 1 个月）" % f["pl"]))
			o.append(_o("warn", "给%s递个话" % f["b"]))
			o.append(_o("mediate", "劝两边各退一步，宝物对半"))
			if not close_b:
				o.append(_o("join", "帮%s去抢" % f["a"]))
		"造谣":
			o.append(_o("warn", "告诉%s，早做防备" % f["b"]))
			o.append(_o("refute", "当众替%s说句公道话" % f["b"]))
			if not close_b:
				o.append(_o("join", "跟着添两句"))
		"示好":
			o.append(_o("match", "替%s在%s面前说几句好话" % [f["a"], f["b"]]))
			o.append(_o("spoil", "提醒%s：%s这人……" % [f["b"], f["a"]]))
		"叛门":
			o.append(_o("persuade", "去劝%s再想想" % f["a"]))
			o.append(_o("help", "替%s引开巡山的人（要走 1 个月）" % f["a"]))
			o.append(_o("report", "去%s报信" % f["sect"]))
		"讨债":
			var k := int(pt.get("owe", 1))
			if ls >= k:
				o.append(_o("pay", "替%s还了这%s块灵石" % [f["b"], W.cnum(k)]))
			o.append(_o("mediate", "劝%s宽限几日" % f["a"]))
	o.append(_o("ignore", "不插手"))
	if close_a and String(pt["v"]) in HOSTILE:
		# 自己人要做坏事：头一个选项是“去拦着”
		o.push_front(_o("stopfriend", "去拦着%s" % f["a"]))
		if o.size() > 5:
			o.remove_at(o.size() - 2)
	return o

# ---------------------------------------------------------------- 写回
static func _m(W, c: Dictionary, text: String, wt: int, kind: String, aid: int) -> void:
	W.AG.mem(W, c, W.P(), text, wt, kind, aid)
	c["rt"] = 1   # 记下了她，就重想一回念头（谢她、记恨她、或者换个对象）

## 她做的事传开：认识当事人的几个人跟着改了对她的看法
static func _gossip(W, who: Array, text: String, mtext: String, d: int, aid: int) -> void:
	if W.rng.randf() < 0.55:
		W.rumor(text, who, "她")
	var seen := {}
	var pool := []
	for c in who:
		if c.is_empty():
			continue
		seen[int(c["id"])] = 1
		for k in W._ids(c["rel"]):
			var o: Dictionary = W.C(k)
			if not o.is_empty() and o["alive"] and not o["player"] and not seen.has(int(o["id"])):
				seen[int(o["id"])] = 1
				pool.append(o)
	for o in W._sample(pool, 3):
		var r: Dictionary = W.R(o, W.P())
		r["f"] = int(r["f"]) + d
		W.remember(o, W.P(), mtext, d, "闻", aid)

static func _found_out(W, a: Dictionary, base: float) -> bool:
	return W.rng.randf() < base + 0.4 * W.AG.px(a, "慎")

## 结算：返回结果文字
static func resolve(W, tid: String, roles: Dictionary, ctx: Dictionary, oid: String) -> String:
	var pt := get_plot(W, int(ctx.get("pid", -1)))
	if int(ctx.get("stale", 0)) == 1 or not actable(W, pt):
		return ""
	var p: Dictionary = W.P()
	var a: Dictionary = W.C(pt["a"])
	var b: Dictionary = W.C(pt["b"]) if int(pt["b"]) > 0 else {}
	var f := _fmt(W, pt)
	var aid := int(pt["aid"])
	var v := String(pt["v"])
	var pl: float = float(W.plv()) + W.Gear.edge(W, {})   # v0.14：她的法宝（插手时对面是谁不定，只算她这边）
	var pn: String = W.pn()
	var out := ""
	pt["o"] = oid
	if tid == "风声" and int(ctx.get("ov", 0)) == 0 and int(roles["B"]) != int(a["id"]):
		var inf: Dictionary = W.C(roles["B"])
		if not inf.is_empty() and oid != "ignore":
			W.radd(inf, p, 2)   # 报信的人看她肯管事
	match oid:
		"ignore":
			pt["ig"] = 1
			out = W.pv("插手不管", ["她没有动。江湖上的事，各有各的因果。", "她把这件事放下了。过些时候，自会有下文。", "她听过就罢了，回去照旧炼她的丹。"])
			W.chron(p, "听说%s的事，没有插手。" % f["a"])
			return out
		"warn":
			if not W.known(b):
				W._ling(-1)
			pt["p"] = 1
			pt["e"] = 3
			pt["h"] = 1
			_m(W, b, "%s提醒过我小心%s" % [pn, f["a"]] if v != "夺宝" else "%s告诉我%s要抢先去取%s" % [pn, f["a"], f["pr"]], 10, "恩", aid)
			out = W.pv("插手警", ["她托人给{b}带了一句话。回信只有四个字：“知道了，谢。”", "她把话递到了。{b}沉默了一会儿，说：“我欠你一回。”", "那封信送到{b}手里时，{b}正要出门。{tb}把门又关上了。"]).format(f)
			if v == "偷窃" or v == "造谣":
				out += "\n" + W.pv("插手警后", ["往后如何，就看{b}自己了。", "过些时候自有分晓。"]).format(f)
			else:
				out += "\n（%s有了防备；%s那边过些时候见分晓）" % [f["b"], f["a"]]
			if _found_out(W, a, 0.2):
				_m(W, a, "%s给%s通风报信，坏了我的事" % [pn, f["b"]], -10, "怨", aid)
				out += "\n" + W.pv("插手警露", ["{a}那边，像是知道了是谁递的话。", "后来听说，{a}在打听是谁走漏的风声。"]).format(f)
			W.chron(p, "听说%s要对%s下手，给%s递了话。" % [f["a"], f["b"], W.ta(b)])
		"guard":
			W.meet(b)
			W._away(2, String(b.get("place", "")))
			pt["p"] = 2
			var win: bool = W._roll(pl + float(b["lv"]) * 0.3, float(a["lv"]), 5, 4)
			W.meet(a)
			if win:
				a["inj"] = maxi(int(a["inj"]), 12)
				out = W.pv("插手护胜", ["她在{b}门外守了两夜。第三夜{a}来了，两柄剑在月下碰了七次，{a}捂着肩退进了林子。", "{a}的剑刚出鞘，她已经挡在{b}身前。斗了二十余合，{a}恨恨地走了。"]).format(f)
				_m(W, b, "%s替我挡下了%s" % [pn, f["a"]], 18, "救", aid)
				_m(W, a, "%s护着%s，伤了我" % [pn, f["b"]], -16, "伤", aid)
				W.chron(b, "%s来寻仇，%s挡在了前头。" % [f["a"], pn])
				W.chron(a, "去找%s，被%s拦下，负伤而回。" % [f["b"], pn])
				_gossip(W, [b, a], "听说%s替%s挡了%s的剑。" % [pn, f["b"], f["a"]], "听说%s肯替人出头" % pn, 3, aid)
			else:
				W._inj(3)
				b["inj"] = maxi(int(b["inj"]), 10)
				out = W.pv("插手护败", ["她挡在{b}身前，挨了{a}一掌。{a}没再追，只说：“看在她的面上，今日先到这里。”", "两个人都没占到便宜。{b}伤得不重，她的袖子上全是血。"]).format(f) + "\n（受伤：闭关炼化减半 3 个月）"
				_m(W, b, "%s为我挨了%s一掌" % [pn, f["a"]], 20, "救", aid)
				_m(W, a, "%s多管闲事" % pn, -8, "怨", aid)
				W.chron(b, "%s寻上门来，%s拼着受伤护住了自己。" % [f["a"], pn])
				W.chron(a, "去找%s，%s挡在前头，没能得手。" % [f["b"], pn])
			W.radd(a, b, 0, -5)
			W.chron(p, "赶去%s身边，挡下了%s。" % [f["b"], f["a"]] if win else "赶去护着%s，与%s斗了一场。" % [f["b"], f["a"]])
			if not win:
				W._away(-1)   # 打输了早一个月回来养伤（伤另算）
		"join":
			W.meet(a)
			pt["p"] = 2
			W.w["edge"] = {str(int(a["id"])): 3}
			var bi := int(b["inj"])
			var bls: int = W.AG._ls(b)
			var balive: bool = b["alive"]
			if v == "造谣":
				for o in W._sample(W.npcs().filter(func(x): return x != a and x != b), 4):
					W.radd(o, b, -4)
				W.AG.npc_resolve(W, a, v, b, aid)
			else:
				W.AG.npc_resolve(W, a, v, b, aid)
			W.w.erase("edge")
			var won: bool = int(b["inj"]) > bi or W.AG._ls(b) < bls or (balive and not b["alive"]) or v == "造谣"
			_m(W, a, "%s帮我对付过%s" % [pn, f["b"]], 12, "助", aid)
			if b["alive"] and (_found_out(W, b, 0.45) or v != "造谣"):
				_m(W, b, "%s帮着%s对付我" % [pn, f["a"]], -18, "伤" if v in ["寻仇", "截杀"] else "怨", aid)
				W.radd(b, p, 0, 15)
			if won and v in ["截杀", "夺宝"]:
				var cut: int = W._ling(4 + W.rng.randi_range(0, 4))
				out = W.pv("插手助劫", ["她从侧里截住{b}的退路。事成后{a}分了她一份：“爽快。下回还找你。”", "{b}没料到会多一个人。{a}把东西掂了掂，丢给她一份。"]).format(f) + "（+%d 灵石）" % cut
			elif won:
				out = W.pv("插手助成", ["有她在旁，{a}这回没有失手。{b}看她的那一眼，她记了很久。", "她帮{a}了了这件事。{a}拱了拱手，没多说什么。"]).format(f)
			else:
				W._inj(2)
				out = W.pv("插手助败", ["两个人一起去，还是没讨到便宜。{a}骂了一句，她肩上挂了彩。", "{b}早有防备。她和{a}各自带伤退走。"]).format(f) + "\n（受伤：闭关炼化减半 2 个月）"
			_gossip(W, [b, a], "听说%s帮着%s对付%s。" % [pn, f["a"], f["b"]], "听说%s帮人做过不光彩的事" % pn, -3, aid)
			W.chron(p, "帮%s对付了%s。" % [f["a"], f["b"]])
		"mediate":
			W.meet(a)
			var paid := false
			if v == "寻仇" and W.lingshi() >= 5:
				W._ling(-5)
				paid = true
			var ch: float = 0.25 + 0.35 * W.AG.px(a, "善") + 0.2 * W.AG.px(a, "慎") - 0.4 * W.AG.px(a, "仇") + (0.15 if paid else 0.0) + (0.15 if W._close_p(a) else 0.0)
			if v == "讨债":
				ch += 0.25
			if W.rng.randf() < ch:
				pt["p"] = 2
				match v:
					"寻仇":
						W.radd(a, b, 0, -30)
						W.AG._settle(a, int(b["id"]), [])
						out = W.pv("插手和仇", ["她陪{a}坐了一个下午，没劝，只听。日头落山时，{a}把剑放回了鞘里。", "她把两边的话都说了一遍。{a}半晌才道：“……看在你的面上。”"]).format(f)
						_m(W, b, "%s替我化解了与%s的旧怨" % [pn, f["a"]], 12, "恩", aid)
					"夺宝":
						W.AG._add_ls(a, 4)
						W.AG._add_ls(b, 4)
						out = W.pv("插手和宝", ["她把{pr}一分为二。{a}嫌少，{b}嫌少，到底谁也没动手。", "{a}和{b}都瞪着她，最后还是各拿了一半走了。"]).format(f)
						_m(W, b, "%s劝{a}分了我一半".format(f) % pn, 6, "恩", aid)
					"讨债":
						W.R(a, b)["owe"] = maxi(0, int(W._rel(a, b).get("owe", 0)) / 2)
						out = W.pv("插手和债", ["她替{b}说了几句软话。{a}哼了一声：“看你的面子，先还一半。”", "{a}把账本合上：“宽限一个月。再拖，谁说都没用。”"]).format(f)
						_m(W, b, "%s替我向%s求过情" % [pn, f["a"]], 8, "恩", aid)
				_m(W, a, "%s来说和，说得在理" % pn, 6, "解", aid)
				W.chron(a, "经%s说和，对%s的事作罢。" % [pn, f["b"]])
				W.chron(p, "替%s与%s说和，说成了。" % [f["a"], f["b"]])
				if v != "讨债":
					_gossip(W, [a, b], "听说%s从中说和，%s与%s的事算是了了。" % [pn, f["a"], f["b"]], "听说%s会做人" % pn, 2, aid)
			else:
				out = W.AG.fl(W, "插手和败", a, {
					"傲": ["“你算什么人？”{a}连门都没让她进。"],
					"仇": ["{a}听完，只问了一句：“那我受的呢？”她答不上来。"],
					"平": ["{a}客客气气送她出门，什么也没应。", "话说了一半，{a}已经起身送客。"]}).format(f)
				pt["p"] = 1   # 说过了，没说成：事情照旧到日子了结，她也不再去第二回
				if paid:
					out += "（礼收下了，事没成）"
				_m(W, a, "%s来替%s说情，多管闲事" % [pn, f["b"]], -5, "怨", aid)
				W.chron(p, "去找%s说和，没说成。" % f["a"])
		"report":
			W.meet(a)
			pt["p"] = 2
			var sect := String(pt.get("sect", a["sect"]))
			if v == "叛门":
				a["inj"] = maxi(int(a["inj"]), 10)
				a["rt"] = 1
				out = W.pv("插手告叛", ["{sect}的人当夜就封了山门。{a}被押回去时看见了她，什么也没说。", "她把话递到{sect}。三日后听说，{a}被罚面壁一年。"]).format(f)
				_m(W, a, "%s到%s告发了我" % [pn, sect], -22, "辱", aid)
				for o in W.npcs():
					if o != a and String(o["sect"]) == sect and W.rng.randf() < 0.5:
						W.radd(o, p, 4)
				W.chron(a, "想离开%s，被人告发，罚了面壁。" % sect)
			else:
				a["inj"] = maxi(int(a["inj"]), 8)
				W.AG._add_ls(a, -4)
				out = W.pv("插手告状", ["她去{s}说了这件事。{a}被叫去问了一夜的话，那几日哪也没去成。", "管事的听完，派人去{a}的住处走了一趟。事情就此搁下了。"]).format({"s": sect if sect != "散修" else "坊市管事那里", "a": f["a"]})
				if _found_out(W, a, 0.35):
					_m(W, a, "%s背后告了我一状" % pn, -14, "辱", aid)
					out += "\n" + W.pv("插手告露", ["{a}后来知道了是谁去告的。", "听说{a}在打听，到底是谁多的嘴。"]).format(f)
				if not b.is_empty():
					_m(W, b, "%s替我出过头" % pn, 8, "恩", aid)
				W.chron(a, "图谋%s的事，被人告到%s，作罢。" % [f["b"], sect if sect != "散修" else "坊市"])
			W.chron(p, "把%s的事报给了%s。" % [f["a"], sect if sect != "散修" else "坊市管事"])
		"catch":
			W.meet(a)
			W._away(1, String(b.get("place", "")) if not b.is_empty() else "")
			pt["p"] = 2
			if W._roll(pl + 1.0, float(a["lv"]), 5, 4):
				out = W.pv("插手捉贼", ["第二夜，一只手伸进了{b}的灵石匣。她按住那只手，{a}的脸白了。", "{a}刚翻过墙头，就看见她坐在院里喝茶。"]).format(f)
				_m(W, b, "%s替我拿住了%s" % [pn, f["a"]], 12, "助", aid)
				W.radd(b, a, 0, 12)
				W.remember(b, a, "%s想偷我的东西" % f["a"], -10, "窃", aid)
				_m(W, a, "%s当场拿住了我" % pn, -12, "辱", aid)
				W.AG.drift(a, "慎", 0.04)
				W.chron(a, "去%s那里顺东西，被%s当场拿住。" % [f["b"], pn])
				_gossip(W, [b, a], "听说%s在%s的院里拿住了一个贼，是%s。" % [pn, f["b"], f["a"]], "听说%s眼睛很尖" % pn, 2, aid)
			else:
				W.AG.npc_resolve(W, a, "偷窃", b, aid)
				_m(W, b, "%s替我守过一夜灵石匣" % pn, 6, "助", aid)
				out = W.pv("插手捉空", ["她守了一夜，只听见一声瓦响。等她追出去，人已经没影了。", "{a}比她想的机灵。第二天{b}发现灵石匣空了一半。"]).format(f)
			W.chron(p, "替%s守了一夜灵石匣。" % f["b"])
		"first":
			W._away(1, String(f.get("pl", "")))
			pt["p"] = 2
			W.meet(a)
			if W._roll(pl + 1.0, float(a["lv"]), 5, 4):
				W._wu(8)
				var g2: int = W._ling(3)
				out = W.pv("插手先取", ["她连夜赶到{pl}，{pr}还带着露水。走出去半里，迎面撞上了{a}。", "她到时{pr}正好熟透。收进袖里时，身后的林子里有人骂了一声，是{a}。"]).format(f) + "（感悟 +8，灵石 +%d）" % g2
				_m(W, a, "%s抢在我前头取走了%s" % [pn, f["pr"]], -14, "夺", aid)
				if not b.is_empty():
					W.remember(b, p, "%s取走了%s，没落到%s手里" % [pn, f["pr"], f["a"]], 3, "闻", aid)
				W.chron(a, "去%s取%s，被%s抢了先。" % [f["pl"], f["pr"], pn])
			else:
				W.AG.npc_resolve(W, a, "夺宝", b, aid)
				_m(W, a, "%s也去抢过%s" % [pn, f["pr"]], -4, "夺", aid)
				out = W.pv("插手先空", ["她赶到{pl}，只看见一截新断的枝子。有人先到了。", "{pl}的雾太大，她绕了半夜，等找到地方，那里只剩一个土坑。"]).format(f)
			W.chron(p, "去%s抢%s。" % [f["pl"], f["pr"]])
		"refute":
			pt["p"] = 2
			W.meet(b)
			W.chron(a, "说%s的闲话，被%s当众驳了回去。" % [f["b"], pn])
			_m(W, b, "%s当众替我说过话" % pn, 12, "恩", aid)
			if W.AG.px(a, "傲") > 0.5 or W.AG.px(a, "妒") > 0.55:
				_m(W, a, "%s当众驳我" % pn, -12, "辱", aid)
			else:
				_m(W, a, "被%s说得没了话" % pn, -5, "辱", aid)
			out = W.pv("插手辟谣", ["茶棚里有人又说起{b}，她放下茶碗：“那年的事，我在场。”满座都不说话了。", "她当着{a}的面把话一句句驳了。{a}脸上挂不住，起身走了。"]).format(f)
			_gossip(W, [b, a], "听说%s当众替%s说了句公道话。" % [pn, f["b"]], "听说%s说话公道" % pn, 3, aid)
		"match":
			pt["p"] = 1
			W.meet(b)
			W.radd(b, a, 10)
			pt["e"] = 0
			_m(W, a, "%s替我在%s面前说过好话" % [pn, f["b"]], 10, "助", aid)
			out = W.pv("插手撮合", ["她同{b}喝茶时，状似无意地说起{a}：“那人倒是个实心眼的。”{b}低头笑了笑。", "她只说了一句{a}的好。{b}没接话，耳根却红了。"]).format(f)
			W.chron(p, "在%s面前替%s说了几句好话。" % [f["b"], f["a"]])
		"spoil":
			pt["p"] = 1
			W.meet(b)
			W.radd(b, a, -10)
			_m(W, b, "%s提醒过我当心%s" % [pn, f["a"]], 4, "恩", aid)
			out = W.pv("插手拆", ["她提了一句{a}从前的事。{b}没说什么，只是把茶盏放下了。", "“{a}么，”她顿了一顿，“你自己当心些。”{b}点了点头。"]).format(f)
			if _found_out(W, a, 0.25):
				_m(W, a, "%s在%s面前坏我的事" % [pn, f["b"]], -12, "怨", aid)
				out += "\n" + W.pv("插手拆露", ["后来{a}知道了这话是谁说的。", "{a}再见她时，眼神冷了。"]).format(f)
			W.chron(p, "提醒%s当心%s。" % [f["b"], f["a"]])
		"persuade":
			W.meet(a)
			var ch2: float = 0.3 + 0.3 * W.AG.px(a, "慎") + 0.2 * W.AG.px(a, "善") - 0.35 * W.AG.px(a, "野") + (0.2 if W._close_p(a) else 0.0)
			pt["p"] = 2
			if W.rng.randf() < ch2:
				a["dr"] = {"k": "破境", "t": 0, "u": 0.6, "d": int(W.w["day"]), "why": "%s劝我先把修为练上去" % pn, "src": aid}
				_m(W, a, "%s劝我留在%s" % [pn, f["sect"]], 8, "恩", aid)
				out = W.pv("插手劝留", ["她陪{a}在山门外坐到天亮。{a}最后把行囊解开了：“再忍一年。”", "{a}听她说完，看了很久的山门：“……那就再待些日子。”"]).format(f)
				W.chron(a, "本想离开%s，听了%s的话，留了下来。" % [f["sect"], pn])
			else:
				W.AG.npc_resolve(W, a, "叛门", {}, aid)
				_m(W, a, "%s来劝过我" % pn, 4, "恩", aid)
				out = W.pv("插手劝不留", ["{a}谢了她，第二天还是走了。", "“你说的我都懂。”{a}把行囊背上，“可我待不下去了。”"]).format(f)
			W.chron(p, "去劝%s留在%s。" % [f["a"], f["sect"]])
		"help":
			W.meet(a)
			W._away(1)
			pt["p"] = 2
			W.AG.npc_resolve(W, a, "叛门", {}, aid)
			_m(W, a, "%s帮我下了山" % pn, 16, "助", aid)
			var caught: bool = W.rng.randf() < 0.35
			if caught:
				W._away(2)
				for o in W.npcs():
					if o != a and String(o["sect"]) == String(pt.get("sect", "")) and W.rng.randf() < 0.5:
						W.remember(o, p, "%s放走了叛门的%s" % [pn, f["a"]], -8, "怨", aid)
						W.radd(o, p, 0, 6)
				out = W.pv("插手助叛露", ["她引着巡山的人绕了半座山。{a}下了山，她却被认了出来。", "{a}走了。第二天{sect}的人找到青庐，问她那夜在哪。"]).format(f)
			else:
				out = W.pv("插手助叛", ["她在后山点了一把火。巡山的人都往那边去了，{a}从另一头下了山。", "那夜很黑。她在山门外学了三声鸟叫，{a}的影子就消失在了石阶尽头。"]).format(f)
			W.chron(p, "帮%s下了%s的山。" % [f["a"], f["sect"]])
		"pay":
			var k2 := int(pt.get("owe", 1))
			W._ling(-k2)
			pt["p"] = 2
			W.R(a, b)["owe"] = 0
			W.AG._add_ls(a, k2)
			_m(W, b, "%s替我还了欠%s的灵石" % [pn, f["a"]], 14, "助", aid)
			_m(W, a, "%s替%s还了账，是个爽快人" % [pn, f["b"]], 4, "恩", aid)
			out = W.pv("插手还债", ["她把{k}块灵石放在{a}面前。{a}数了两遍，收了。{b}知道后，红着眼来道谢。", "她替{b}把账清了。{b}说：“这钱我记着，一定还。”"]).format(f) + "（−%d 灵石）" % k2
			W.chron(p, "替%s还了欠%s的%s块灵石。" % [f["b"], f["a"], W.cnum(k2)])
		"stopfriend":
			W.meet(a)
			pt["p"] = 2
			var ch3: float = 0.45 + 0.25 * W.AG.px(a, "善") - 0.3 * W.AG.px(a, "仇") + 0.2
			if W.rng.randf() < ch3:
				W.AG._settle(a, int(b["id"]), [])
				W.radd(a, b, 0, -15)
				_m(W, a, "%s拦着我，没让我做错事" % pn, 8, "恩", aid)
				out = W.pv("插手拦友", ["她按住{a}的手腕：“不值得。”{a}的手抖了一下，慢慢松开了。", "她一句话没说，只是挡在门口。{a}看了她很久，转身回屋了。"]).format(f)
				W.chron(a, "本要对%s下手，被%s拦下了。" % [f["b"], pn])
			else:
				W.AG.npc_resolve(W, a, v, b, aid)
				_m(W, a, "%s拦我，没拦住" % pn, -3, "怨", aid)
				out = W.pv("插手拦友败", ["“这回你别管。”{a}推开她，走进了夜里。", "{a}只说：“你不懂。”第二日一早，人已经不见了。"]).format(f)
			W.chron(p, "去拦%s。" % f["a"])
	a["rt"] = 1
	if not b.is_empty():
		b["rt"] = 1
	return out

# ================================================================ 每日：到了日子的事结算
static func daily(W) -> void:
	var day := int(W.w["day"])
	for pt in plots(W):
		if int(pt["p"]) < 2 and int(pt["due"]) <= day:
			_fire(W, pt)
	# 过期的风声：事情了结了就不再端出来
	var keep := []
	for it in W.w.get("agq", []):
		if String(it[1]) == "风声" and not actable(W, get_plot(W, int(it[3].get("pid", -1)))):
			continue
		keep.append(it)
	W.w["agq"] = keep
	var ps := plots(W)
	while ps.size() > 30 and int(ps[0]["p"]) == 2:
		ps.pop_front()

static func _fire(W, pt: Dictionary) -> void:
	var prev := int(pt["p"])
	pt["p"] = 2
	var a: Dictionary = W.C(pt["a"])
	var b: Dictionary = W.C(pt["b"]) if int(pt["b"]) > 0 else {}
	if a.is_empty() or not a["alive"] or (int(pt["b"]) > 0 and (b.is_empty() or not b["alive"])):
		return
	var v := String(pt["v"])
	var aid := int(pt["aid"])
	var f := _fmt(W, pt)
	var warned: bool = prev == 1 and int(pt.get("h", 0)) == 1
	if v == "叛门" and String(a["sect"]) != String(pt.get("sect", a["sect"])):
		return
	if warned and v in ["偷窃", "造谣"]:
		if v == "偷窃":
			W.remember(b, a, "%s想偷我的东西" % f["a"], -10, "窃", aid)
			W.radd(b, a, 0, 10)
			W.chron(b, "灵石匣上了锁，夜里%s来摸，扑了个空。" % f["a"])
			W.chron(a, "去%s那里顺东西，扑了个空。" % f["b"])
			pt["r"] = "空"
		else:
			W.chron(b, "早有防备，%s的几句闲话没传开。" % f["a"])
			W.chron(a, "说%s的闲话，没人信。" % f["b"])
			W.AG.drift(a, "妒", 0.02)
			pt["r"] = "空"
		if W.rng.randf() < 0.6:
			W.rumor(W.pv("插手果空", ["{b}早得了信，{a}那件事落了空。", "听说{a}这回扑了个空——{b}像是早知道。"]).format(f), [b, a], "果")
		return
	if warned and v in ["寻仇", "截杀", "夺宝"] and W.rng.randf() < 0.45:
		# 得了信的人躲开了
		if v != "夺宝":
			b["place"] = W.SECT_HOME[b["sect"]]
		W.chron(b, "得了%s的信，避开了%s。" % [W.pn(), f["a"]])
		W.chron(a, "去%s寻%s，扑了个空。" % [f["pl"], f["b"]])
		pt["r"] = "空"
		if W.rng.randf() < 0.6:
			W.rumor(W.pv("插手果避", ["{a}在{pl}等了三日，{b}一直没露面。", "听说{b}早得了信，{a}扑了个空。"]).format(f), [b, a], "果")
		return
	var bi: int = int(b["inj"]) if not b.is_empty() else 0
	var bls: int = W.AG._ls(b) if not b.is_empty() else 0
	if int(pt["e"]) != 0 and not b.is_empty():
		W.w["edge"] = {str(int(b["id"])): int(pt["e"])}
	W.AG.npc_resolve(W, a, v, b, aid)
	W.w.erase("edge")
	if not b.is_empty():
		var hurt: bool = int(b["inj"]) > bi or W.AG._ls(b) < bls or not b["alive"]
		pt["r"] = "成" if hurt else "败"
		if warned and not hurt and W.rng.randf() < 0.7:
			W.rumor(W.pv("插手果胜", ["{a}找上{b}，反被打退。听说{b}早有防备。", "{b}早得了信，{a}没讨到便宜。"]).format(f), [b, a], "果")
			W.remember(b, W.P(), "多亏%s那句话" % W.pn(), 6, "恩", aid)
	else:
		pt["r"] = "成"

## 她自己从传闻 / 心事里找回这件事（不算说书人的节奏：不记 last_ev，不占“同一个人别天天来”）
static func open(W, pid: int) -> bool:
	var pt := get_plot(W, pid)
	if not actable(W, pt) or not W.pending().is_empty():
		return false
	var roles := {"B": int(pt["a"]), "X": int(pt["a"]), "V": int(pt["b"])}
	var ctx := {"pid": pid, "aid": int(pt["aid"])}
	var ev := present(W, "插手", roles, ctx)
	ev["tid"] = "插手"
	ev["roles"] = roles
	ev["ctx"] = ctx
	ev["stage"] = "ask"
	ev["day"] = int(W.w["day"])
	W.w["pending"] = ev
	W._save_rng()
	return true
