extends RefCounted
## 江湖（v0.6）：程序生成的人物 + 世界自转 + 说书人 + 生平。
## 移植自 docs/design/sim/story_sim.py（design-v4 §3–§7），加了 sim 复核后的修正：
## 传闻冷却 20 日、同一对人 20 日内不重复相遇、玩家选项由真人来点。
## 全部状态都在 w（纯 Dictionary，随存档 JSON 保存）；g 是 game_state，只用来读主角境界、写伤势/感悟/灵石。

const SURN = ["苏", "林", "沈", "温", "叶", "顾", "陆", "白", "谢", "秦", "楚", "萧", "柳", "江", "宋", "云", "姜", "陈", "裴", "韩", "唐", "许", "程", "孟", "方", "傅", "慕容", "上官", "司徒", "欧阳"]
const F_GIV = ["青", "禾", "晚", "照", "知", "微", "小", "满", "清", "霜", "若", "雪", "凝", "烟", "婉", "宁", "素", "心", "月", "华", "听", "雨", "念", "初", "芷", "兰", "灵", "犀", "暮", "锦", "瑟"]
const M_GIV = ["长", "风", "子", "衡", "怀", "瑾", "承", "远", "墨", "白", "景", "行", "云", "起", "少", "游", "临", "川", "慎", "之", "明", "寒", "山", "逸", "尘", "砚", "秋"]
const SECTS = {"青云宗": "正", "玄霜谷": "正", "落霞宫": "正", "万剑门": "正", "药王谷": "正", "散修": "中", "血煞门": "魔", "阴骨教": "魔"}
const SECT_LIST = ["青云宗", "玄霜谷", "落霞宫", "万剑门", "药王谷", "散修", "血煞门", "阴骨教"]
const PLACES = ["青庐", "后山", "寒潭", "坊市", "青云宗", "玄霜谷", "落霞宫", "万剑门", "药王谷", "血煞门", "古战场", "云梦泽"]
const SECT_HOME = {"青云宗": "青云宗", "玄霜谷": "玄霜谷", "落霞宫": "落霞宫", "万剑门": "万剑门", "药王谷": "药王谷", "散修": "坊市", "血煞门": "血煞门", "阴骨教": "古战场"}
## 宗门袍色（立绘用）；散修随机
const SECT_TINT = {"青云宗": [72, 96, 130], "玄霜谷": [200, 214, 226], "落霞宫": [176, 120, 132], "万剑门": [112, 116, 124], "药王谷": [104, 140, 104], "血煞门": [120, 40, 40], "阴骨教": [60, 56, 70]}
const REALMS = ["炼气", "炼气", "炼气", "炼气", "炼气", "炼气", "炼气", "炼气", "炼气", "筑基", "筑基", "筑基", "金丹", "金丹", "金丹", "元婴", "元婴", "元婴", "化神"]
## 性格：倾向, 喜欢的性格, 厌恶的性格
const TRAITS = {
	"温柔": [["温柔", "侠义", "痴情"], ["嗜战", "阴狠"]], "傲气": [["傲气", "嗜战"], ["怯懦", "圆滑"]],
	"多疑": [["多疑", "淡泊"], ["圆滑", "贪财"]], "贪财": [["贪财", "圆滑"], ["淡泊", "侠义"]],
	"侠义": [["侠义", "温柔"], ["阴狠", "贪财"]], "痴情": [["痴情", "温柔"], ["薄情"]],
	"记仇": [["记仇"], ["圆滑"]], "淡泊": [["淡泊", "温柔"], ["贪财", "嗜战"]],
	"嗜战": [["嗜战", "傲气"], ["怯懦", "淡泊"]], "好奇": [["好奇"], ["多疑"]],
	"怯懦": [["温柔"], ["嗜战", "傲气"]], "圆滑": [["圆滑"], ["傲气", "记仇"]],
	"阴狠": [["阴狠"], ["侠义", "温柔"]], "薄情": [["淡泊"], ["痴情"]],
}
const CLASH = [["温柔", "阴狠"], ["痴情", "薄情"], ["怯懦", "嗜战"], ["淡泊", "贪财"], ["侠义", "阴狠"], ["温柔", "嗜战"], ["怯懦", "傲气"]]
const LIKES = ["桂花糕", "古琴", "好剑", "丹方", "灵茶", "旧书", "梅花", "烈酒", "星图", "木簪"]
const GOALS = ["求长生", "寻道侣", "振兴师门", "寻亲", "炼一炉九转丹", "收个好徒弟", "报仇", "游遍云梦泽"]

## 模板元数据：tier, tension, chain_only, max_n, min_day, cooldown, weight
const T = {
	"偶遇": [0, 2, false, 99, 0, 3, 3.0], "求助": [1, 8, false, 99, 3, 8, 2.0], "报恩": [1, -6, true, 99, 0, 0, 1.0],
	"仇人上门": [2, 25, true, 99, 0, 0, 1.0], "表白": [2, -10, false, 99, 0, 0, 4.0], "旧友死讯": [2, 10, false, 99, 0, 0, 6.0],
	"寻凶": [2, 20, true, 99, 0, 0, 1.0], "坊市传闻": [0, 0, false, 99, 4, 20, 2.5], "赠礼": [0, -3, false, 99, 0, 8, 1.0],
	"朱果之争": [1, 8, false, 99, 0, 10, 1.0], "站队": [1, 10, false, 99, 0, 10, 3.0], "拜师": [1, -4, false, 99, 6, 0, 1.0],
	"师父考验": [1, 0, true, 99, 0, 0, 1.0], "道侣遇险": [2, 20, false, 2, 0, 30, 3.0], "道侣口角": [0, 3, false, 99, 0, 10, 1.0],
	"心魔": [1, -15, false, 99, 0, 15, 4.0], "魔修袭镇": [2, 30, false, 1, 20, 0, 2.0], "秘境": [2, 15, false, 3, 8, 20, 1.5],
	"姑母来信": [0, -2, false, 99, 0, 8, 1.0], "夜雨": [0, -2, false, 99, 0, 8, 1.0], "灵田": [0, -2, false, 99, 0, 8, 1.0],
	"访客": [0, -2, false, 99, 0, 6, 1.0], "坊市欺客": [0, 4, false, 99, 0, 10, 1.0], "师门书信": [0, 4, false, 99, 0, 10, 1.0],
	"义结金兰": [0, -6, false, 99, 0, 6, 1.0], "飞升异象": [0, -2, false, 99, 0, 6, 1.0], "闭关小成": [0, -2, false, 99, 0, 8, 1.0],
	"旧物": [0, -2, false, 99, 0, 8, 1.0], "宗门大比": [0, 1, false, 99, 0, 25, 1.0], "劫修拦路": [1, 8, false, 99, 5, 12, 1.0],
}
const VAR = {
	"论道": ["在{p}与{o}论道半夜。", "与{o}在{p}煮茶谈剑，相见恨晚。", "在{p}得{o}指点，解了一处功法上的疑难。", "与{o}在{p}对弈一局，输了半子。", "和{o}在{p}比了一回剑，点到为止。", "在{p}替{o}挡了一场雨，两人聊到天明。"],
	"争宝_w": ["在{p}与{o}争一株灵草，得手。", "从{o}手里抢下一枚兽丹。", "在{p}比{o}先一步拓下残碑。", "在{p}的拍卖会上压了{o}一头，拍走一卷残图。", "赶在{o}之前收服了{p}的一只灵狐。"],
	"争宝_l": ["在{p}看中的灵草被{o}夺去。", "到手的兽丹被{o}截了。", "在{p}晚了{o}一步，残碑被拓走了。", "在{p}的拍卖会上叫价输给了{o}。", "眼看要收服的灵狐，被{o}抢了先。"],
	"斗法_w": ["在{p}与{o}斗法，胜。", "一剑挑落了{o}的发冠。", "在{p}把{o}逼退三十里。", "在{p}以一道符破了{o}的护体灵光。", "三十招后，{o}的剑断在{p}。"],
	"斗法_l": ["在{p}败于{o}手下，重伤。", "被{o}一掌震伤心脉。", "在{p}输给{o}，养了半月伤。", "在{p}被{o}的飞剑穿了肩。", "与{o}斗法落败，本命法器裂了一道缝。"],
}
const SOLO = {
	"求长生": ["在{p}闭了一回死关。", "寻到半部长生诀，读到天亮。", "在{p}的古洞里找到一具坐化的骸骨，拜了三拜。", "数了数自己的寿元，又多坐了一个周天。"],
	"寻道侣": ["在{p}的灯会上站了一夜，没等到人。", "托媒的信又退了回来。", "在{p}替人写了一封情书，自己的那封没寄。", "给不知是谁的人刻了一支木簪。"],
	"振兴师门": ["替{s}跑了三处坊市，换回一车灵材。", "把师门塌了的偏殿重新立了起来。", "替{s}收了两个新弟子。", "为{s}的护山大阵补了一角。"],
	"寻亲": ["在{p}打听到一点亲人的消息，又断了。", "梦见幼时的门槛。", "在{p}的旧户籍册里找到一个相近的名字。", "托人往北边送了一封不知寄给谁的信。"],
	"炼一炉九转丹": ["丹炉又炸了，眉毛燎去半边。", "炼出一炉三转丹，离九转还远。", "在{p}寻到一味主药。", "把丹方抄了第三遍，改了两处火候。"],
	"收个好徒弟": ["在{p}看了十几个孩子的根骨，摇头。", "捡了个孩子，养了三天又送回去了。", "在{p}听说有个放牛娃能引气入体，赶去时人已被收走。", "把自己的入门剑擦了又擦。"],
	"报仇": ["磨了一夜剑。", "在{p}打听仇人的下落。", "把仇人的名字写在符纸上，烧了。", "在{p}练了一整日的杀招。"],
	"游遍云梦泽": ["到了{p}，记下一页游记。", "在泽边看了一夜的萤火。", "在{p}的渡口等了三天的船。", "游记写满了第二本。"],
}
## 初见时的一句神态（按性格）
const HINT = {"温柔": "{ta}把伞往她这边偏了偏", "傲气": "{ta}只抬了抬眼", "好奇": "{ta}先问她从哪儿来", "贪财": "{ta}的目光在她的储物袋上停了一停",
	"多疑": "{ta}的手一直没离开剑柄", "淡泊": "{ta}让到路边，等她先过", "嗜战": "{ta}上下打量她，像在掂量能接几招", "侠义": "{ta}提醒她前面有段塌方",
	"阴狠": "{ta}笑了笑，笑意没到眼里", "痴情": "{ta}在等一个没来的人", "怯懦": "{ta}先往后退了半步", "圆滑": "{ta}先报了自家师门，又夸她的剑穗",
	"记仇": "{ta}记下了她的样子", "薄情": "{ta}看她一眼就移开了"}

var w: Dictionary = {}
var g = null
var rng := RandomNumberGenerator.new()

# ================================================================ 生成 / 存读
func create(seed_v: int, pname: String, gs = null, n_npc: int = 20) -> void:
	g = gs
	rng.seed = seed_v
	w = {"v": 1, "day": 0, "C": {}, "next": 1, "news": [], "queue": [], "fired": {}, "last": {}, "pair_cd": {},
		"tension": 10, "since_major": 0, "flags": {}, "recent": {}, "pending": {}, "events": [], "rng_seed": seed_v}
	var p := _new_char("女", "散修", 0, true)
	p["name"] = pname
	p["place"] = "青庐"
	p["goal"] = "求长生"
	for i in n_npc:
		_new_char()
	var ns := npcs()
	for a in ns:
		for b in ns:
			if a == b:
				continue
			if a["sect"] == b["sect"] and a["sect"] != "散修":
				var r := R(a, b)
				r["f"] = int(r["f"]) + rng.randi_range(5, 25)
				r["m"] = 1
		if a["goal"] == "报仇":
			var others := ns.filter(func(x): return x != a)
			var t: Dictionary = _ch(others)
			a["gt"] = int(t["id"])
			R(a, t)["g"] = 60
			remember(a, t, "%s害过我的亲人" % t["name"], -30)
	chron(P(), "自姑母家出来，住进后山脚下的青庐。")
	_save_rng()

func attach(gs, d: Dictionary) -> void:
	g = gs
	w = d
	rng.seed = int(w.get("rng_seed", 0))
	rng.state = String(w.get("rng", "0")).to_int()

func _save_rng() -> void:
	w["rng"] = str(rng.state)   # 64 位整数：存成字符串，JSON 的浮点会丢精度

# ================================================================ 小工具
func _ch(a: Array):
	return a[rng.randi() % a.size()]

func _sample(a: Array, k: int) -> Array:
	var b := a.duplicate()
	for i in range(b.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = b[i]; b[i] = b[j]; b[j] = t
	return b.slice(0, mini(k, b.size()))

func _wch(items: Array, ws: Array):
	var tot := 0.0
	for x in ws:
		tot += float(x)
	var r := rng.randf() * tot
	for i in items.size():
		r -= float(ws[i])
		if r <= 0.0:
			return items[i]
	return items[items.size() - 1]

## 变体挑选：避开该 key 最近用过的一半
func pv(key: String, opts: Array) -> String:
	var dq: Array = w["recent"].get(key, [])
	var cand := []
	for i in opts.size():
		if not (float(i) in dq or i in dq):
			cand.append(i)
	if cand.is_empty():
		cand = range(opts.size())
	var i: int = _ch(cand)
	dq.append(i)
	while dq.size() > int(opts.size() / 2):
		dq.pop_front()
	w["recent"][key] = dq
	return opts[i]

func C(id) -> Dictionary:
	return w["C"].get(str(int(id)), {})

func P() -> Dictionary:
	return w["C"]["1"]

## 按 id 数字顺序遍历（JSON 存档会把键排成字典序，不排序的话读档后随机序列会变）
static func _ids(d: Dictionary) -> Array:
	var ks := d.keys()
	ks.sort_custom(func(a, b): return int(a) < int(b))
	return ks

func npcs(alive: bool = true) -> Array:
	var out := []
	for k in _ids(w["C"]):
		var c: Dictionary = w["C"][k]
		if not c["player"] and (c["alive"] or not alive):
			out.append(c)
	return out

static func realm_name(lv: int) -> String:
	if lv < 9:
		return "炼气%s层" % ["一", "二", "三", "四", "五", "六", "七", "八", "九"][lv]
	if lv >= 18:
		return "化神"
	return REALMS[lv] + ["初期", "中期", "后期"][(lv - 9) % 3]

static func lifespan(lv: int) -> int:
	return 100 if lv < 9 else (200 if lv < 12 else (500 if lv < 15 else 1000))

func realm(c: Dictionary) -> String:
	return realm_name(int(c["lv"]))

func side(c: Dictionary) -> String:
	return SECTS.get(c["sect"], "中")

func tag(c: Dictionary, t: String) -> bool:
	return t in c["traits"]

func ta(c: Dictionary) -> String:
	return "她" if c["sex"] == "女" else "他"

func R(a: Dictionary, b: Dictionary) -> Dictionary:
	var k := str(int(b["id"]))
	if not a["rel"].has(k):
		a["rel"][k] = {"f": 0, "g": 0, "t": [], "m": 0}
	return a["rel"][k]

func rel_tags(a: Dictionary, b: Dictionary) -> Array:
	var k := str(int(b["id"]))
	return a["rel"][k]["t"] if a["rel"].has(k) else []

func known(c: Dictionary) -> bool:
	var k := str(int(c["id"]))
	return P()["rel"].has(k) and int(P()["rel"][k]["m"]) == 1

func partner(c: Dictionary) -> Variant:
	for k in _ids(c["rel"]):
		if "道侣" in c["rel"][k]["t"]:
			var o := C(k)
			if not o.is_empty() and o["alive"]:
				return o
	return null

func master_of(c: Dictionary) -> Variant:
	for k in _ids(c["rel"]):
		if "师" in c["rel"][k]["t"]:
			return C(k)
	return null

func opinion(a: Dictionary, o: Dictionary) -> float:
	var r := R(a, o)
	var v := float(r["f"]) - float(r["g"]) * 1.2
	for t in o["traits"]:
		for mine in a["traits"]:
			if t in TRAITS[mine][0]:
				v += 6
			if t in TRAITS[mine][1]:
				v -= 8
	for m in a["mem"]:
		if int(m[1]) == int(o["id"]):
			v += float(m[3])
	if side(a) != side(o) and side(a) != "中" and side(o) != "中":
		v -= 10
	return v

func remember(c: Dictionary, o, text: String, wt: int) -> void:
	c["mem"].append([int(w["day"]), int(o["id"]) if o is Dictionary and not o.is_empty() else 0, text, wt])
	if c["mem"].size() > 24:
		var d := int(w["day"])
		c["mem"].sort_custom(func(x, y): return absf(float(x[3])) - (d - float(x[0])) * 0.05 < absf(float(y[3])) - (d - float(y[0])) * 0.05)
		c["mem"].pop_front()

func chron(c: Dictionary, text: String) -> void:
	c["log"].append([int(w["day"]), text])
	if c["log"].size() > 80:
		c["log"].pop_front()

func rumor(text: String, who: Array = []) -> void:
	var ids := []
	for c in who:
		ids.append(int(c["id"]))
	w["news"].append([int(w["day"]), text, ids])
	if w["news"].size() > 60:
		w["news"].pop_front()

func schedule(delay: int, tid: String, roles: Dictionary, ctx: Dictionary = {}) -> void:
	w["queue"].append([int(w["day"]) + delay, tid, roles, ctx])

func _pair(a: Dictionary, b: Dictionary) -> String:
	var x := int(a["id"])
	var y := int(b["id"])
	return "%d:%d" % [mini(x, y), maxi(x, y)]

func _flag(k: String) -> int:
	return int(w["flags"].get(k, 0))

func _flag_add(k: String, d: int = 1) -> void:
	w["flags"][k] = _flag(k) + d

func _new_char(sex: String = "", sect: String = "", lv: int = -1, player: bool = false) -> Dictionary:
	var id := int(w["next"])
	w["next"] = id + 1
	if sex == "":
		sex = _ch(["女", "女", "男"])
	var giv: Array = F_GIV if sex == "女" else M_GIV
	var nm: String = _ch(SURN) + "".join(_sample(giv, _ch([1, 2])))
	# 同名就再起一次（最多三回），免得两个“苏青”分不清
	for k in 3:
		var dup := false
		for o in w["C"].values():
			if o["name"] == nm:
				dup = true
		if not dup:
			break
		nm = _ch(SURN) + "".join(_sample(giv, 2))
	if sect == "":
		sect = _ch(SECT_LIST)
	if lv < 0:
		lv = mini(17, int(-log(1.0 - rng.randf() * 0.999) * 4.5))
	var traits: Array
	while true:
		traits = _sample(TRAITS.keys(), 2)
		var bad := false
		for cl in CLASH:
			if traits[0] in cl and traits[1] in cl:
				bad = true
		if not bad:
			break
	var likes := _sample(LIKES, 2)
	var rest := LIKES.filter(func(x): return not (x in likes))
	var c := {"id": id, "player": player, "sex": sex, "name": nm, "sect": sect, "lv": lv, "xp": 0.0,
		"age": float(rng.randi_range(16, 30) + lv * 6), "traits": traits, "likes": likes, "dislikes": [_ch(rest)],
		"goal": _ch(GOALS), "gt": 0, "place": SECT_HOME[sect] if rng.randf() < 0.6 else _ch(PLACES.slice(1)),
		"alive": true, "asc": false, "inj": 0, "rel": {}, "mem": [], "log": [], "pseed": rng.randi() % 1000000000, "born": int(w["day"])}
	w["C"][str(id)] = c
	return c

## 立绘：存种子与选项，显示时 Portrait5Lib.roll(seed, opts) 还原（确定性）
func portrait_opts(c: Dictionary) -> Dictionary:
	var o := {"sex": "f" if c["sex"] == "女" else "m", "elder": float(c["age"]) >= 75.0, "demonic": side(c) == "魔"}
	if SECT_TINT.has(c["sect"]):
		o["robe_tint"] = SECT_TINT[c["sect"]]
	return o

# ================================================================ 主角同步（境界来自青庐的修为）
func plv() -> int:
	if g == null:
		return int(P()["lv"])
	if g.s.get("ending", "") == "zhuji":
		return 9
	return g.layer() - 1

func _sync_player() -> void:
	var p := P()
	p["lv"] = plv()
	if g != null:
		p["name"] = String(g.s.get("name", p["name"]))

func _inj(days: int) -> void:
	if g != null:
		g.s["injured"] = maxi(int(g.s.get("injured", 0)), days)

func _wu(n: int) -> void:
	if g != null:
		g.add_wu(n)
	else:
		P()["xp"] = float(P()["xp"]) + n

func _ling(n: int) -> int:
	if g == null:
		return n
	var before := int(g.s.get("lingshi", 0))
	g.s["lingshi"] = maxi(0, before + n)
	return int(g.s["lingshi"]) - before

func lingshi() -> int:
	return int(g.s.get("lingshi", 0)) if g != null else 20

# ================================================================ 世界自转（每日）
## home=false 时（路上）只让世界过日子，说书人不出事件；回家后再说
func tick(home: bool = true) -> void:
	w["day"] = int(w["day"]) + 1
	_sync_player()
	for c in npcs():
		c["age"] = float(c["age"]) + 1.0 / 360.0
		if int(c["inj"]) > 0:
			c["inj"] = int(c["inj"]) - 1
		c["xp"] = float(c["xp"]) + rng.randf_range(0.6, 1.4) * (0.4 if int(c["inj"]) > 0 else 1.0)
		var lv := int(c["lv"])
		if float(c["xp"]) >= 8.0 * pow(1.35, lv):
			c["xp"] = 0.0
			var big: bool = lv in [8, 11, 14, 17]
			if big and rng.randf() < 0.45:
				c["inj"] = 20
				chron(c, "冲击%s失败，经脉受损。" % REALMS[lv + 1])
				if rng.randf() < 0.15:
					die(c, "冲关走火入魔，身死道消")
				continue
			c["lv"] = lv + 1
			if big:
				chron(c, "破境，入%s。" % realm(c))
				rumor("%s（%s）突破至%s。" % [c["name"], c["sect"], realm(c)], [c])
		if float(c["age"]) > lifespan(int(c["lv"])) and rng.randf() < 0.02:
			die(c, "寿元耗尽，坐化")
			continue
		if int(c["lv"]) >= 18 and rng.randf() < 0.01:
			ascend(c)
			continue
		if rng.randf() < 0.06:
			c["place"] = SECT_HOME[c["sect"]] if rng.randf() < 0.4 else _ch(PLACES.slice(1))
	var byp := {}
	for c in npcs():
		if not byp.has(c["place"]):
			byp[c["place"]] = []
		byp[c["place"]].append(c)
	for place in byp:
		var cs: Array = byp[place]
		if cs.size() >= 2 and rng.randf() < minf(0.5, 0.12 * cs.size()):
			var ab := _sample(cs, 2)
			var a: Dictionary = ab[0]
			var b: Dictionary = ab[1]
			var key := _pair(a, b)
			if int(w["day"]) - int(w["pair_cd"].get(key, -99)) >= 20:
				w["pair_cd"][key] = int(w["day"])
				world_event(a, b, place)
	for c in npcs():
		if rng.randf() < 0.012:
			solo(c)
	if rng.randf() < 0.04 and npcs().size() < 30:
		newcomer()
	if home and w["pending"].is_empty():
		storyteller()
	_save_rng()

func solo(c: Dictionary) -> void:
	var goal: String = c["goal"]
	_flag_add("solo:" + goal)
	chron(c, String(_ch(SOLO[goal])).format({"p": c["place"], "s": c["sect"]}))
	if goal == "炼一炉九转丹" and rng.randf() < 0.08:
		chron(c, "九转丹成。")
		c["lv"] = mini(18, int(c["lv"]) + 2)
		rumor("%s炼成了九转丹。" % c["name"], [c])
		c["goal"] = "求长生"
	if goal == "寻道侣" and partner(c) != null:
		c["goal"] = "求长生"

func die(c: Dictionary, how: String) -> void:
	c["alive"] = false
	chron(c, how + "。")
	rumor("%s%s。" % [c["name"], how], [c])
	for o in w["C"].values():
		if o["alive"] and o["rel"].has(str(int(c["id"]))):
			var r: Dictionary = o["rel"][str(int(c["id"]))]
			if "道侣" in r["t"] or int(r["f"]) > 40:
				remember(o, c, "%s死了" % c["name"], -10)
				chron(o, "听闻%s%s，三日不语。" % [c["name"], how])
				if not o["player"] and (tag(o, "记仇") or tag(o, "痴情")):
					o["goal"] = "报仇"

func ascend(c: Dictionary) -> void:
	c["alive"] = false
	c["asc"] = true
	chron(c, "渡劫成功，白日飞升。")
	rumor("天现异象：%s渡劫飞升。" % c["name"], [c])

func newcomer() -> void:
	var c := _new_char("", "", rng.randi_range(0, 3))
	chron(c, ("初入仙途，拜入%s。" % c["sect"]) if c["sect"] != "散修" else "初入仙途，做了散修。")

func world_event(a: Dictionary, b: Dictionary, place: String) -> void:
	var oa := opinion(a, b)
	var ob := opinion(b, a)
	var ra := R(a, b)
	var rb := R(b, a)
	ra["m"] = 1
	rb["m"] = 1
	var ks := ["论道"]
	var ws := [3.0 + maxf(0.0, (oa + ob) / 20.0)]
	ks.append("争宝"); ws.append(1.5 + (int(tag(a, "贪财")) + int(tag(b, "贪财"))) * 2 + int(place in ["古战场", "云梦泽"]) * 2)
	if oa < -20 or ob < -20 or (side(a) != side(b) and side(a) != "中" and side(b) != "中"):
		ks.append("斗法"); ws.append(2.0 + maxf(0.0, -(oa + ob) / 15.0))
	var single: bool = partner(a) == null and partner(b) == null
	if a["sex"] != b["sex"] and oa > 28 and ob > 28 and single:
		ks.append("结为道侣"); ws.append(6.0)
	var has_shi := false
	for t in ra["t"]:
		if "师" in t or "徒" in t:
			has_shi = true
	if absi(int(a["lv"]) - int(b["lv"])) >= 5 and oa > 25 and ob > 25 and not has_shi:
		ks.append("收徒"); ws.append(4.0)
	if a["sex"] == b["sex"] and oa > 40 and ob > 40 and not ("结义" in ra["t"]):
		ks.append("结义"); ws.append(2.0)
	if partner(a) == b and (tag(a, "薄情") or tag(a, "阴狠")) and rng.randf() < 0.3:
		ks.append("背弃"); ws.append(3.0)
	if a["goal"] == "报仇" and int(a["gt"]) == int(b["id"]):
		ks.append("复仇"); ws.append(12.0)
	if a["sex"] != b["sex"] and a["sect"] == b["sect"] and int(ra["f"]) > 20 and int(rb["f"]) > 20 and single and ("寻道侣" in [a["goal"], b["goal"]]):
		ks.append("结为道侣"); ws.append(5.0)
	var k: String = _wch(ks, ws)
	_flag_add("w:" + k)
	match k:
		"论道":
			var d := rng.randi_range(6, 15)
			ra["f"] = int(ra["f"]) + d
			rb["f"] = int(rb["f"]) + d
			chron(a, String(_ch(VAR["论道"])).format({"p": place, "o": b["name"]}))
			chron(b, String(_ch(VAR["论道"])).format({"p": place, "o": a["name"]}))
		"争宝":
			var ab := [a, b] if int(a["lv"]) + rng.randf() * 4 > int(b["lv"]) + rng.randf() * 4 else [b, a]
			var win: Dictionary = ab[0]
			var lose: Dictionary = ab[1]
			R(win, lose)["g"] = int(R(win, lose)["g"]) + 5
			R(lose, win)["g"] = int(R(lose, win)["g"]) + 20
			remember(lose, win, "%s抢了我在%s看中的灵物" % [win["name"], place], -15)
			chron(win, String(_ch(VAR["争宝_w"])).format({"p": place, "o": lose["name"]}))
			chron(lose, String(_ch(VAR["争宝_l"])).format({"p": place, "o": win["name"]}))
		"斗法":
			var ab2 := [a, b] if int(a["lv"]) + rng.randf() * 5 > int(b["lv"]) + rng.randf() * 5 else [b, a]
			var win2: Dictionary = ab2[0]
			var lose2: Dictionary = ab2[1]
			R(lose2, win2)["g"] = int(R(lose2, win2)["g"]) + 30
			lose2["inj"] = 15
			chron(win2, String(_ch(VAR["斗法_w"])).format({"p": place, "o": lose2["name"]}))
			chron(lose2, String(_ch(VAR["斗法_l"])).format({"p": place, "o": win2["name"]}))
			lose2["place"] = SECT_HOME[lose2["sect"]]
			if int(win2["lv"]) - int(lose2["lv"]) >= 3 and (tag(win2, "阴狠") or side(win2) == "魔") and rng.randf() < 0.5:
				die(lose2, "死于%s之手" % win2["name"])
			else:
				remember(lose2, win2, "%s伤我" % win2["name"], -25)
		"结为道侣":
			ra["t"].append("道侣")
			rb["t"].append("道侣")
			chron(a, "与%s结为道侣。" % b["name"])
			chron(b, "与%s结为道侣。" % a["name"])
			rumor("%s与%s结为道侣，在%s摆了三桌素席。" % [a["name"], b["name"], place], [a, b])
		"收徒":
			var m: Dictionary = a if int(a["lv"]) > int(b["lv"]) else b
			var d2: Dictionary = b if m == a else a
			R(m, d2)["t"].append("徒")
			R(d2, m)["t"].append("师")
			chron(m, "收%s为徒。" % d2["name"])
			chron(d2, "拜%s为师。" % m["name"])
			if d2["sect"] != m["sect"] and m["sect"] != "散修":
				d2["sect"] = m["sect"]
		"结义":
			ra["t"].append("结义")
			rb["t"].append("结义")
			chron(a, "与%s义结金兰。" % b["name"])
			chron(b, "与%s义结金兰。" % a["name"])
		"背弃":
			ra["t"].erase("道侣")
			rb["t"].erase("道侣")
			rb["g"] = int(rb["g"]) + 60
			remember(b, a, "%s负我" % a["name"], -40)
			chron(a, "弃了道侣%s，独自远走。" % b["name"])
			chron(b, "被%s所负。" % a["name"])
			rumor("听说%s负了%s。" % [a["name"], b["name"]], [a, b])
			if tag(b, "记仇") or tag(b, "痴情"):
				b["goal"] = "报仇"
				b["gt"] = int(a["id"])
		"复仇":
			if int(a["lv"]) + rng.randf() * 4 > int(b["lv"]) + rng.randf() * 3:
				chron(a, "在%s寻到%s，了结旧仇。" % [place, b["name"]])
				die(b, "被%s寻仇所杀" % a["name"])
				a["goal"] = _ch(GOALS.slice(0, 6))
			else:
				a["inj"] = 25
				chron(a, "寻%s报仇不成，负伤遁走。" % b["name"])
				R(b, a)["g"] = int(R(b, a)["g"]) + 30

# ================================================================ 说书人
func storyteller() -> void:
	w["since_major"] = int(w["since_major"]) + 1
	var day := int(w["day"])
	var due := []
	for it in w["queue"]:
		if int(it[0]) <= day:
			due.append(it)
	for it in due:
		w["queue"].erase(it)
		var ok := true
		for k in it[2]:
			var c := C(it[2][k])
			if c.is_empty() or not c["alive"]:
				ok = false
		if ok:
			fire(String(it[1]), it[2], it[3])
			return
	var p_event := 0.35 + int(w["since_major"]) * 0.012
	if rng.randf() > p_event:
		w["tension"] = maxi(0, int(w["tension"]) - 2)
		return
	var want: int
	if int(w["since_major"]) > 14 and rng.randf() < 0.5:
		want = 2
	elif int(w["tension"]) > 60:
		want = 0
	else:
		want = _ch([0, 1, 1])
	var cands := []
	var cws := []
	for tid in T:
		var m: Array = T[tid]
		if m[2] or absi(int(m[0]) - want) > 1 or int(w["fired"].get(tid, 0)) >= int(m[3]) or day < int(m[4]):
			continue
		if w["last"].has(tid) and day - int(w["last"][tid]) < int(m[5]):
			continue
		var roles = bind(tid)
		if roles == null:
			continue
		var wt := weight(tid, roles) * (1.0 if int(m[0]) == want else 0.25)
		if w["last"].has(tid):
			wt *= 1.0 - exp(-(day - int(w["last"][tid])) / 12.0)
		if wt > 0:
			cands.append([tid, roles])
			cws.append(wt)
	if cands.is_empty():
		return
	var pick: Array = _wch(cands, cws)
	fire(pick[0], pick[1], {})

func _log_fire(tid: String) -> void:
	w["fired"][tid] = int(w["fired"].get(tid, 0)) + 1
	w["last"][tid] = int(w["day"])
	w["events"].append(tid)
	if w["events"].size() > 300:
		w["events"].pop_front()
	w["tension"] = clampi(int(w["tension"]) + int(T[tid][1]), 0, 100)
	if int(T[tid][0]) >= 2:
		w["since_major"] = 0

func _pick(f: Callable, key: Callable = Callable()) -> Variant:
	var cs := npcs().filter(f)
	if cs.is_empty():
		return null
	if key.is_valid():
		var ws := []
		for c in cs:
			ws.append(key.call(c))
		return _wch(cs, ws)
	return _ch(cs)

func _mem_about_p(c: Dictionary) -> bool:
	for m in c["mem"]:
		if int(m[1]) == 1:
			return true
	return false

func _r1(c) -> Variant:
	return {"B": int(c["id"])} if c != null else null

## 返回 roles（{角色: id}）或 null
func bind(tid: String) -> Variant:
	var p := P()
	match tid:
		"偶遇":
			return _r1(_pick(func(c): return not known(c)))
		"求助":
			var c = _pick(func(c): return int(c["inj"]) > 0 and not _mem_about_p(c))
			if c == null:
				c = _pick(func(c): return not _mem_about_p(c))
			return _r1(c)
		"表白":
			if partner(p) != null:
				return null
			return _r1(_pick(func(c): return known(c) and c["sex"] != p["sex"] and int(R(c, p)["f"]) > 45 and partner(c) == null))
		"旧友死讯":
			for c in npcs(false):
				if not c["alive"] and not c["asc"] and known(c) and int(R(p, c)["f"]) > 5 and _flag("mourned:%d" % int(c["id"])) == 0:
					return {"B": int(c["id"])}
			return null
		"坊市传闻":
			return {} if not w["news"].is_empty() else null
		"赠礼":
			return _r1(_pick(func(c): return known(c) and int(R(p, c)["f"]) > 10))
		"朱果之争":
			return _r1(_pick(func(c): return c["place"] in ["后山", "寒潭", "古战场"]))
		"站队":
			for a in npcs():
				for k in _ids(a["rel"]):
					var b := C(k)
					if b.is_empty() or b["player"] or not b["alive"]:
						continue
					if int(a["rel"][k]["g"]) >= 30 and (known(a) or known(b)) and _flag("side:" + _pair(a, b)) == 0:
						return {"A": int(a["id"]), "B": int(b["id"])}
			return null
		"拜师":
			if master_of(p) != null:
				return null
			var pl := plv()
			return _r1(_pick(func(c): return int(c["lv"]) >= pl + 6 and side(c) != "魔" and int(R(c, p)["f"]) >= 0))
		"道侣遇险", "道侣口角":
			return _r1(partner(p))
		"心魔":
			return {} if int(w["tension"]) > 45 else null
		"魔修袭镇":
			var pl2 := plv()
			return _r1(_pick(func(c): return side(c) == "魔" and int(c["lv"]) >= pl2 + 2))
		"秘境":
			return {} if npcs().size() >= 3 else null
		"姑母来信", "夜雨", "灵田", "闭关小成":
			return {}
		"访客":
			return _r1(_pick(func(c): return known(c) and int(R(c, p)["f"]) > 0))
		"坊市欺客":
			return _r1(_pick(func(c): return tag(c, "贪财") or tag(c, "圆滑")))
		"师门书信":
			var m = master_of(p)
			return {"B": int(m["id"])} if m != null and m["alive"] else null
		"义结金兰":
			return _r1(_pick(func(c): return known(c) and c["sex"] == p["sex"] and opinion(c, p) > 45 and not ("结义" in R(p, c)["t"])))
		"飞升异象":
			for c in npcs(false):
				if c["asc"] and int(c["log"][-1][0]) > int(w["day"]) - 5 and _flag("asc_seen:%d" % int(c["id"])) == 0:
					return {"B": int(c["id"])}
			return null
		"旧物":
			return _r1(_pick(func(c): return known(c) and int(R(p, c)["f"]) > 20))
		"宗门大比":
			return _r1(_pick(func(c): return c["sect"] != "散修" and int(c["lv"]) >= 6, func(c): return 1.0 + float(known(c)) * 4.0))
		"劫修拦路":
			return _r1(_pick(func(c): return side(c) == "魔" or tag(c, "阴狠")))
	return null

func weight(tid: String, roles: Dictionary) -> float:
	var wt := float(T[tid][6])
	if tid == "求助" and int(C(roles["B"])["inj"]) > 0:
		wt += 3.0
	if tid == "朱果之争" and tag(C(roles["B"]), "贪财"):
		wt += 2.0
	return wt

# ================================================================ 玩家看到的事件
func meet(c: Dictionary) -> bool:
	var p := P()
	var r := R(p, c)
	var first := int(r["m"]) == 0
	r["m"] = 1
	R(c, p)["m"] = 1
	if first:
		var who: String = c["sect"] if c["sect"] == "散修" else c["sect"] + "修士"
		chron(p, "初识%s——%s，%s，%s、%s。" % [c["name"], who, realm(c), c["traits"][0], c["traits"][1]])
	return first

func fav(c: Dictionary, d: int, mem: String = "", wt: int = 0) -> void:
	var p := P()
	R(c, p)["f"] = int(R(c, p)["f"]) + d
	R(p, c)["f"] = int(R(p, c)["f"]) + int(d / 2)
	if mem != "":
		remember(c, p, mem, wt)

func pn() -> String:
	return String(P()["name"])

func fire(tid: String, roles: Dictionary, ctx: Dictionary) -> void:
	_log_fire(tid)
	var ev := present(tid, roles, ctx)
	ev["tid"] = tid
	ev["roles"] = roles
	ev["ctx"] = ctx
	ev["stage"] = "ask"
	ev["day"] = int(w["day"])
	w["pending"] = ev
	_save_rng()

func pending() -> Dictionary:
	return w.get("pending", {})

## 玩家点了选项：结算，返回结果文字（空串 = 直接关闭）
func choose(oid: String) -> String:
	var ev: Dictionary = w["pending"]
	if ev.is_empty() or ev.get("stage", "") != "ask":
		return ""
	var res := resolve(String(ev["tid"]), ev["roles"], ev["ctx"], oid)
	if res == "":
		w["pending"] = {}
	else:
		ev["stage"] = "result"
		ev["result"] = res
	_save_rng()
	return res

func close() -> void:
	w["pending"] = {}

func _o(id: String, label: String) -> Array:
	return [id, label]

func _hint(n: Dictionary) -> String:
	for t in n["traits"]:
		if HINT.has(t):
			return String(HINT[t]).format({"ta": ta(n)})
	return ta(n) + "点了点头"

## 呈现：{speaker: id(0=旁白), text, opts:[[id,label]]}
func present(tid: String, roles: Dictionary, ctx: Dictionary) -> Dictionary:
	var n: Dictionary = C(roles["B"]) if roles.has("B") else {}
	var nm: String = n.get("name", "")
	var ok := [_o("ok", "知道了")]
	match tid:
		"偶遇":
			var where := pv("偶遇地", ["山道上", "溪边石桥上", "坊市口", "雨后的竹林里", "去寒潭的小路上", "茶棚檐下", "镇口的老槐树下", "渡口的石阶上"])
			var who: String = ("一个散修" if n["sect"] == "散修" else "一个%s的%s" % [n["sect"], "女修" if n["sex"] == "女" else "男修"])
			return {"speaker": int(n["id"]), "anon": true, "text": "%s，她遇见%s，%s。%s。" % [where, who, realm(n), _hint(n)],
				"opts": [_o("go", "结伴走一程"), _o("bye", "拱手别过")]}
		"求助":
			var where2 := pv("求助地", ["寒潭边", "青庐柴门外", "后山的山涧里", "坊市后巷", "去镇上的半路"])
			ctx["where"] = where2
			return {"speaker": int(n["id"]), "anon": true, "text": "%s躺着一个人，%s的服色，%s。是%s。" % [where2, n["sect"], pv("求助伤", ["胸前一道剑伤还在渗血", "嘴唇发紫，像中了毒", "灵气乱窜，经脉一跳一跳", "一条腿压在落石下"]), nm],
				"opts": [_o("help", "渡一口灵气给%s" % ta(n)), _o("half", "留下伤药就走"), _o("rob", "搜走储物袋")]}
		"报恩":
			var gift: String = _ch(n["likes"])
			ctx["gift"] = gift
			return {"speaker": int(n["id"]), "text": pv("报恩语", ["“那日%s的事，我记着。”" % ctx.get("where", "寒潭边"), "“欠你的。”%s放下一份%s，没再多说。" % [ta(n), gift], "“路过。”%s在院里坐了半日，走时留下一份%s。" % [ta(n), gift], "“那条命是你捡回来的。”"]),
				"opts": [_o("take", "收下"), _o("tea", "留%s喝碗茶" % ta(n))]}
		"仇人上门":
			return {"speaker": int(n["id"]), "text": pv("仇上门", ["“储物袋的账，今日算。”", "柴门被一脚踹开。“还记得我吗？”", "院里的鸡忽然不叫了。%s站在灵田边上，剑已出鞘。" % nm]),
				"opts": [_o("fight", "迎战"), _o("pay", "赔礼（10 灵石）") if lingshi() >= 10 else _o("beg", "低头赔礼"), _o("run", "从后窗走")]}
		"表白":
			return {"speaker": int(n["id"]), "text": pv("表白", ["%s在桂树下站了很久，才开口：“你……愿不愿意同修？”" % nm, "“我想了一路。”%s把一支木簪放在她掌心，“往后的路，一起走吧。”" % nm, "灯下，%s忽然不说话了。半晌：“我想同你结为道侣。”" % nm]),
				"opts": [_o("yes", "应下"), _o("no", "婉拒")]}
		"旧友死讯":
			_flag_add("mourned:%d" % int(n["id"]))
			var how := String(n["log"][-1][1]).trim_suffix("。")
			ctx["how"] = how
			return {"speaker": 0, "text": pv("死讯起", ["坊市有人说起%s——%s。", "一封没有落款的信：%s，%s。", "过路的散修说，%s%s。她手里的茶凉了。"]) % [nm, how],
				"opts": [_o("bury", "去收殓"), _o("bow", "遥遥一拜")]}
		"寻凶":
			return {"speaker": 0, "text": "打听到%s在%s。丹炉底下刻着的那个名字，该去问一问了。" % [nm, n["place"]],
				"opts": [_o("go", "去讨个说法"), _o("wait", "先修到能赢再说")]}
		"坊市传闻":
			var news := []
			for x in w["news"]:
				if int(x[0]) > int(w["day"]) - 15 and not x[2].is_empty():
					for i in x[2]:
						if known(C(i)):
							news.append(x)
							break
			if news.is_empty():
				news = w["news"].slice(-5)
			var it: Array = _ch(news)
			ctx["news"] = it[1]
			return {"speaker": 0, "text": pv("传闻", ["坊市茶摊上听人说：%s", "说书先生今天讲的是：%s", "药铺伙计压低声音告诉她：%s", "过路的散修提了一句：%s", "姑母的信末添了一句：%s"]) % it[1], "opts": ok}
		"赠礼":
			var gs := _sample(LIKES, 3)
			return {"speaker": 0, "text": "去坊市换盐时，她想起%s。摊上有几样东西，带一样去？" % nm,
				"opts": [_o("g:" + gs[0], gs[0]), _o("g:" + gs[1], gs[1]), _o("g:" + gs[2], gs[2])]}
		"朱果之争":
			return {"speaker": int(n["id"]), "text": "%s崖上的朱果熟了，正要伸手，%s也到了。%s" % [n["place"] if n["place"] != "古战场" else "古战场", nm, pv("朱果话", ["“先到不算先得。”", "“这果子，我盯了三个月。”", "“让给我，我记你一个人情。”"])],
				"opts": [_o("give", "让给%s" % ta(n)), _o("fight", "各凭本事")]}
		"站队":
			var a := C(roles["A"])
			var b := C(roles["B"])
			_flag_add("side:" + _pair(a, b))
			return {"speaker": 0, "text": pv("站队起", ["她撞见%s与%s对峙。", "%s和%s在坊市后巷拔了剑。", "林子里，%s在骂%s，话很难听。", "%s堵住了%s的去路。"]) % [a["name"], b["name"]],
				"opts": [_o("a", "帮%s" % a["name"]), _o("b", "帮%s" % b["name"]), _o("none", "不掺和")]}
		"拜师":
			return {"speaker": int(n["id"]), "text": pv("拜师起", ["%s看了她练剑，开口：“根骨尚可。可愿做我的记名弟子？”" % nm, "%s替她理顺了一处岔了的经脉，淡淡道：“明日卯时，来我这里。”" % nm, "“你这一路走得笨，倒也踏实。”%s顿了顿，“跟我学吧。”" % nm]),
				"opts": [_o("yes", "拜师"), _o("no", "谢过")]}
		"师父考验":
			return {"speaker": int(n["id"]), "text": pv("考验", ["“去寒潭边坐满七日，不许起身。”", "“把这卷经抄一百遍，抄错一个字，从头来。”", "“守着这炉火，三日三夜，火不能灭。”"]),
				"opts": [_o("do", "照做"), _o("skip", "推说有事")]}
		"道侣遇险":
			return {"speaker": 0, "text": pv("遇险", ["%s去云梦泽采药，七日没有回信。", "%s的命灯忽明忽暗。", "有人捎来%s的半截剑穗，说是在泽边捡到的。"]) % nm,
				"opts": [_o("go", "去寻"), _o("wait", "等消息")]}
		"道侣口角":
			var op := opinion(n, P())
			ctx["good"] = op >= 30
			return {"speaker": int(n["id"]), "text": pv("口角", ["“你又熬夜守炉子。”", "“说好一起去坊市的。”", "“那人送你的东西，你还留着？”"]),
				"opts": [_o("soft", "先服个软"), _o("hard", "不肯让")]}
		"心魔":
			var bad: Array = P()["mem"].filter(func(m): return int(m[3]) < 0)
			var m: Array = _ch(bad) if not bad.is_empty() else [0, 0, "那盏灯", 0]
			return {"speaker": 0, "text": pv("心魔起", ["闭关时心魔起，幻出的是：%s。", "夜半入定，眼前又是%s。", "灯影里浮出旧事——%s。"]) % m[2],
				"opts": [_o("face", "直视它"), _o("chant", "闭目诵经")]}
		"魔修袭镇":
			return {"speaker": int(n["id"]), "text": "%s的人从北边下来了，山下小镇起了火。%s" % [n["sect"], pv("袭镇", ["钟声敲到第三下就断了。", "姑母家就在镇东头。", "风里全是焦味。"])],
				"opts": [_o("guard", "护着镇口"), _o("hide", "带姑母进山躲")]}
		"秘境":
			var pool := npcs().filter(func(x): return int(x["lv"]) < 12)
			if pool.size() < 3:
				pool = npcs()
			var party := _sample(pool, 3)
			var ids := []
			var names := []
			for x in party:
				ids.append(int(x["id"]))
				names.append(x["name"])
			ctx["party"] = ids
			return {"speaker": 0, "text": pv("秘境", ["古战场秘境开了。门口等着的有%s。", "云梦泽深处的秘境浮出了水面，%s都去了。", "一道残阵在后山裂开，%s约她一同进去。"]) % "、".join(names),
				"opts": [_o("in", "结伴进去"), _o("out", "守在外面")]}
		"姑母来信":
			return {"speaker": 0, "text": pv("姑母", ["姑母来信，说镇上的桂花开了，问她吃饭没有。", "姑母托人捎来一罐腌菜，罐底压着十个铜板。", "姑母来信，只写了“冷了加衣”四个字。", "姑母说隔壁王婶的孙子会走路了，又问她何时回。", "姑母的信被雨打湿了一半，剩下那半是叮嘱。", "姑母信里说梦见她小时候爬树，摔了也不哭。"]), "opts": ok}
		"夜雨":
			var ks := []
			for k in _ids(P()["rel"]):
				if int(P()["rel"][k]["m"]) == 1:
					ks.append(C(k)["name"])
			if ks.is_empty():
				ks = ["姑母"]
			return {"speaker": 0, "text": pv("夜雨", ["夜雨敲窗。她想起%s。", "灯花爆了一下。她没来由地想起%s。", "山里起雾，像那年和%s走过的那段路。", "听见檐下风铃响，以为是%s来了。", "梦见%s站在桂树下，醒来记不清说了什么。"]) % _ch(ks), "opts": ok}
		"灵田":
			return {"speaker": 0, "text": pv("灵田", ["灵田里冒了一株不认识的苗。", "鸟啄了半垄青芝。", "今年的青芝结得密。", "夜里下了霜，她给灵田盖了草帘。", "田埂边的野兔又来了，她没赶它。", "引水的竹管裂了，修了一下午。"]), "opts": ok}
		"访客":
			var tail: String = {"好奇": "问了很多丹炉的事。", "淡泊": "喝完就走了。", "傲气": "嫌她的茶淡。", "温柔": "走前替她把晾的衣裳收了。", "贪财": "眼睛在灵田上转了好几圈。", "侠义": "顺手把塌了的篱笆扶正了。", "痴情": "说起一个人，说了一半又停了。"}.get(n["traits"][0], "坐了一刻。")
			return {"speaker": int(n["id"]), "text": pv("访客", ["%s路过青庐，讨了一碗茶，", "%s顺路来看她，带了半袋新茶，", "%s在柴门外喊了她一声，进来坐了坐，", "%s来借丹炉，还的时候擦得锃亮，"]) % nm + tail, "opts": ok}
		"坊市欺客":
			return {"speaker": 0, "text": pv("欺客", ["%s卖她一株灵草，回来才发现是染了色的。", "在%s的摊上买了张符，一用就碎了。", "%s称灵米的秤，少了三两。", "%s卖的“百年参”，根须是粘上去的。"]) % nm, "opts": ok}
		"师门书信":
			return {"speaker": int(n["id"]), "text": pv("师信", ["师父%s从%s来信，说师门近来不太平。", "师父%s捎信来：%s要开山门大比，问她去不去。", "师父%s的信里只问她修到哪了，末尾提了一句%s的长老病了。"]) % [nm, n["sect"]], "opts": ok}
		"义结金兰":
			return {"speaker": int(n["id"]), "text": pv("金兰", ["%s拉她在桂树下撮土为香：“从今往后，你我姐妹相称。”", "%s拉她在山神庙里磕了三个头，从此以姐妹相称。", "和%s喝光一坛酒，约定此后有难同当。"]) % nm, "opts": ok}
		"飞升异象":
			_flag_add("asc_seen:%d" % int(n["id"]))
			return {"speaker": 0, "text": pv("飞升", ["夜里天边亮了一道光，听说是%s飞升了。她在院里站了很久。", "山那边雷云聚了三日，散时满天霞光。是%s。"]) % nm, "opts": ok}
		"闭关小成":
			return {"speaker": 0, "text": pv("闭关", ["静室里坐了一夜，丹田里那团气凝实了些。", "在寒潭边坐了一夜，周天走得比往常顺。", "读通了功法里卡了半月的一句。", "打坐到天亮，灵气在指尖绕了一圈才散。", "炉火噼啪一声，她忽然想通了一处火候。"]) + "（感悟 +6）", "opts": ok}
		"旧物":
			return {"speaker": 0, "text": pv("旧物", ["整理行囊时翻出一件旧物，是%s当初给的。", "窗台上那只纸鹤，是%s折的。", "那把伞还靠在门后，是%s借的，一直没还。", "灶边那只缺口的碗，%s来时用过。"]) % nm, "opts": ok}
		"宗门大比":
			return {"speaker": 0, "text": pv("大比", ["%s在%s的大比中夺魁，名声传到了坊市。", "听说%s在%s大比上一剑败了三人。", "坊市都在押%s能不能进%s大比前三。"]) % [nm, n["sect"]], "opts": ok}
		"劫修拦路":
			var cost := mini(8, maxi(0, int(lingshi() / 3)))
			ctx["cost"] = cost
			return {"speaker": int(n["id"]), "text": pv("劫修", ["去坊市的路上，%s横剑拦住了她：“留下买路钱。”", "山口，%s从树后转出来，笑：“灵石，还是命？”", "夜路上，%s截住了她。"]) % nm,
				"opts": [_o("pay", "交出 %d 灵石" % cost) if cost > 0 else _o("pay", "摊开空储物袋"), _o("fight", "拔剑")]}
	return {"speaker": 0, "text": "", "opts": ok}

func _roll(mine: float, theirs: float, a: float = 5.0, b: float = 5.0) -> bool:
	return mine + rng.randf() * a > theirs + rng.randf() * b

func resolve(tid: String, roles: Dictionary, ctx: Dictionary, oid: String) -> String:
	var p := P()
	var n: Dictionary = C(roles["B"]) if roles.has("B") else {}
	var nm: String = n.get("name", "")
	var pl := float(plv())
	var out := ""
	match tid:
		"偶遇":
			meet(n)
			if oid == "go":
				fav(n, 8, "同行过一段山路", 5)
				out = "%s。%s自称%s。" % [pv("偶遇同行", ["结伴走了一程", "同行到岔路口才分开", "一起避了场雨，说了些各自的来处", "她分了半块干粮，对方回了一句谢"]), ta(n), nm]
				chron(n, "山道上遇见%s，同行一程。" % pn())
				chron(p, "遇见%s，%s。" % [nm, "同行了一程"])
			else:
				out = "%s。后来才知道，那人叫%s。" % [pv("偶遇别", ["各自赶路", "她拱了拱手，没多停", "彼此点头，擦肩而过"]), nm]
				chron(p, "路上与%s擦肩而过。" % nm)
		"求助":
			meet(n)
			if oid == "help":
				_inj(2)
				fav(n, 25, "重伤时%s救了我" % pn(), 30)
				out = "她守了一夜，渡了三日修为。%s醒来，只说了一句：“记下了。”\n（经脉微损：闭关炼化减半 2 日）" % nm
				chron(p, "%s救下重伤的%s，耗了三日修为。" % [ctx.get("where", "寒潭边"), nm])
				chron(n, "重伤倒在%s，被%s所救。" % [ctx.get("where", "寒潭边"), pn()])
				schedule(rng.randi_range(8, 25), "报恩", {"B": int(n["id"])}, {"where": ctx.get("where", "寒潭边")})
			elif oid == "half":
				fav(n, 8, "%s留过一瓶药" % pn(), 8)
				out = "她把一瓶伤药放在%s手边，走了。" % ta(n)
				chron(p, "给%s留了一瓶伤药。" % nm)
			else:
				var got := _ling(rng.randi_range(8, 14))
				fav(n, -50, "%s趁我重伤劫了我" % pn(), -45)
				R(n, p)["g"] = int(R(n, p)["g"]) + 60
				out = "储物袋里有 %d 块灵石。她没回头。" % got
				chron(p, "搜走了%s的储物袋，得灵石 %d。" % [nm, got])
				chron(n, "重伤时被%s劫了储物袋。" % pn())
				schedule(rng.randi_range(15, 40), "仇人上门", {"B": int(n["id"])})
		"报恩":
			var gift: String = ctx.get("gift", "灵茶")
			if oid == "tea":
				fav(n, 14, "%s留我喝了碗茶" % pn(), 6)
				out = "两人对着灶火坐了半日。%s走时，回头看了一眼青庐。" % nm
			else:
				fav(n, 10)
				out = "她收下了%s。%s点点头，走了。" % [gift, nm]
			_ling(5)
			out += "\n（%s另留下 5 块灵石）" % ta(n)
			chron(p, "%s找到青庐，还了当初的人情。" % nm)
			chron(n, "去青庐还了%s的人情。" % pn())
			if int(R(n, p)["f"]) > 50 and n["sex"] != p["sex"] and partner(n) == null:
				schedule(rng.randi_range(10, 20), "表白", {"B": int(n["id"])})
		"仇人上门":
			if oid == "fight":
				if _roll(pl, float(n["lv"]), 5, 4):
					n["inj"] = 10
					R(n, p)["g"] = int(R(n, p)["g"]) + 20
					out = "她在院里把%s打退了。灵田踩坏了半垄。" % nm
					chron(p, "%s寻上青庐，被她在院里打退。" % nm)
					chron(n, "寻%s报仇，败退。" % pn())
				else:
					_inj(3)
					R(n, p)["g"] = int(R(n, p)["g"]) - 30
					out = "她败了。丹炉被砸出一道裂。%s出了这口气，扬长而去。\n（受伤：闭关炼化减半 3 日）" % nm
					chron(p, "%s寻上青庐，她败了，丹炉被砸。" % nm)
					chron(n, "砸了%s的丹炉。" % pn())
			elif oid == "pay" or oid == "beg":
				if oid == "pay":
					_ling(-10)
				R(n, p)["g"] = int(R(n, p)["g"]) - 25
				out = ("她把灵石奉还，又添了一成。" if oid == "pay" else "她低头认了错。") + "%s冷哼一声，收了剑。" % nm
				chron(p, "%s寻上门，她赔了礼。" % nm)
			else:
				out = "她从后窗走了。青庐空了三天，回来时柴门上多了一道剑痕。"
				chron(p, "%s寻上门时，她已从后窗走了。" % nm)
				schedule(20, "仇人上门", {"B": int(n["id"])})
		"表白":
			meet(n)
			if oid == "yes":
				R(n, p)["t"].append("道侣")
				R(p, n)["t"].append("道侣")
				out = "她说好。%s笑了，像是松了一口气。" % nm
				chron(p, "与%s结为道侣。" % nm)
				chron(n, "与%s结为道侣。" % pn())
				rumor("%s与%s结为道侣。" % [pn(), nm], [n])
			else:
				fav(n, -10, "%s拒了我" % pn(), -5)
				out = "她说，道还长。%s没再说什么。" % nm
				chron(p, "%s问她愿不愿意同修。她说，道还长。" % nm)
		"旧友死讯":
			var how: String = ctx.get("how", "")
			if oid == "bury":
				out = "她赶去，替%s立了块无字碑。" % ta(n)
				var killer = null
				for x in npcs():
					if ("死于%s" % x["name"]) in how or ("被%s" % x["name"]) in how:
						killer = x
				if killer != null:
					R(p, killer)["g"] = int(R(p, killer)["g"]) + 40
					remember(p, killer, "%s杀了%s" % [killer["name"], nm], -30)
					schedule(rng.randi_range(5, 15), "寻凶", {"B": int(killer["id"])})
					out += "碑前，她记下了一个名字：%s。" % killer["name"]
			else:
				out = "她朝那方向拜了三拜。"
			remember(p, n, "%s不在了" % nm, -8)
			chron(p, "听说%s——%s。%s" % [nm, how, out])
		"寻凶":
			if oid == "go":
				if _roll(pl, float(n["lv"]), 6, 4):
					out = "与%s在%s一战，斩之。" % [nm, n["place"]]
					chron(p, out)
					die(n, "被%s所斩" % pn())
				else:
					_inj(4)
					R(n, p)["g"] = int(R(n, p)["g"]) + 20
					out = "与%s一战，败，伤了根基。\n（重伤：闭关炼化减半 4 日）" % nm
					chron(p, out.split("\n")[0])
			else:
				out = "她把%s的名字刻在丹炉底下。" % nm
				chron(p, out)
				schedule(40, "寻凶", {"B": int(n["id"])})
		"坊市传闻":
			chron(p, "听说：%s" % ctx.get("news", ""))
		"赠礼":
			var gift2 := oid.trim_prefix("g:")
			if gift2 in n["likes"]:
				fav(n, 15, "%s记得我喜欢%s" % [pn(), gift2], 12)
				out = pv("赠中", ["托人给%s捎去%s。回信只有两个字：“正好。”", "给%s送了%s，%s当场就收进了袖里。", "%s收到%s，回了她一封很长的信。"]).replace("%s当场", ta(n) + "当场") % [nm, gift2]
				n["known_like"] = true
			elif gift2 in n["dislikes"]:
				fav(n, -6)
				out = pv("赠厌", ["给%s送了%s。东西被原样退回。", "%s看了一眼她送的%s，没说话。"]) % [nm, gift2]
			else:
				fav(n, 4)
				out = pv("赠平", ["给%s送了%s。", "托人给%s捎了%s，听说收下了。", "顺手给%s带了%s。"]) % [nm, gift2]
			chron(p, out)
		"朱果之争":
			meet(n)
			if oid == "fight":
				if _roll(pl, float(n["lv"])):
					_wu(15)
					R(n, p)["g"] = int(R(n, p)["g"]) + 20
					remember(n, p, "%s抢了我的朱果" % pn(), -15)
					out = pv("朱果胜", ["她先摘到了。%s的脸色很难看。", "%s的手慢了半寸，朱果落在她掌心。", "绕着朱果树斗了三合，她摘了果子就走。"]).replace("%s", nm) + "\n（朱果入腹：感悟 +15）"
				else:
					_inj(2)
					out = pv("朱果败", ["她挨了%s一掌，朱果没了。", "朱果被%s摘走，她肩上青了一块。", "被%s一道剑气削了半截袖子。"]) % nm + "\n（受伤：闭关炼化减半 2 日）"
			else:
				fav(n, 5)
				out = pv("朱果让", ["她把朱果让给了%s。", "她退了一步，朱果归了%s。", "%s道了声承让，她笑了笑。"]) % nm
			chron(p, "与%s争朱果——%s" % [nm, out.split("\n")[0]])
		"站队":
			var a := C(roles["A"])
			var b := C(roles["B"])
			if oid == "none":
				out = pv("站队避", ["她绕路走了。", "她只当没看见。", "她在远处站了一会儿，走了。"])
				chron(p, "撞见%s与%s相争，没有掺和。" % [a["name"], b["name"]])
			else:
				var x: Dictionary = a if oid == "a" else b
				var y: Dictionary = b if oid == "a" else a
				meet(x)
				meet(y)
				fav(x, 15, "%s帮过我" % pn(), 15)
				R(y, p)["g"] = int(R(y, p)["g"]) + 25
				remember(y, p, "%s帮%s对付我" % [pn(), x["name"]], -20)
				out = pv("站队选", ["她站到了%s身边。", "她替%s挡了一剑。", "她开口替%s说了句话。"]) % x["name"] + "%s记住了她。" % y["name"]
				chron(p, "%s与%s相争，她帮了%s。" % [a["name"], b["name"], x["name"]])
		"拜师":
			meet(n)
			if oid == "yes":
				R(n, p)["t"].append("徒")
				R(p, n)["t"].append("师")
				out = "她跪下，磕了三个头。%s受了。" % nm
				chron(p, "拜%s为师，做了记名弟子。" % nm)
				chron(n, "收%s为记名弟子。" % pn())
				schedule(rng.randi_range(15, 30), "师父考验", {"B": int(n["id"])})
			else:
				out = "她谢过了。%s也不强求。" % nm
				chron(p, "%s想收她为徒，她谢过了。" % nm)
		"师父考验":
			if oid == "do" and rng.randf() < 0.5 + pl * 0.05:
				_wu(20)
				fav(n, 10)
				out = "她做到了。师父多看了她一眼。\n（感悟 +20）"
				chron(p, "受了师父%s的考验，过了。" % nm)
			elif oid == "do":
				fav(n, -4)
				out = "第五日，她撑不住了。师父没说什么，只是转身走了。"
				chron(p, "师父%s的考验，没过。" % nm)
			else:
				fav(n, -8)
				out = "她推说有事。师父看了她很久。"
				chron(p, "推掉了师父%s的考验。" % nm)
		"道侣遇险":
			if oid == "go":
				_inj(3)
				fav(n, 20, "%s来寻我" % pn(), 25)
				out = "她寻了九天，在一处浅滩找到人。\n（奔波受伤：闭关炼化减半 3 日）"
				chron(p, "%s在云梦泽失了消息，她寻了九天，找回了人。" % nm)
			elif rng.randf() < 0.4:
				out = "消息再没有来。"
				die(n, "在云梦泽失踪，再没回来")
				chron(p, "道侣%s在云梦泽失踪了。" % nm)
			else:
				fav(n, -15, "我出事时%s没来" % pn(), -20)
				out = "半月后%s自己回来了，没提路上的事。" % ta(n)
				chron(p, "%s在云梦泽失了消息，半月后自己回来了。" % nm)
		"道侣口角":
			if ctx.get("good", false) or oid == "soft":
				fav(n, 3)
				out = "第二天，灶上多了一碗粥。"
				chron(p, "与%s拌了两句嘴，第二天灶上多了一碗粥。" % nm)
			else:
				fav(n, -10)
				out = "争了半夜，谁也没服谁。"
				chron(p, "与%s为一件小事争了半夜。" % nm)
		"心魔":
			if oid == "face" and rng.randf() < 0.6:
				_wu(10)
				out = "她看着它，看到它散了。\n（感悟 +10）"
			elif oid == "face":
				_inj(1)
				out = "它没有散。出关后三日不想说话。"
			else:
				out = "经诵到第七遍，灯影平了。"
			chron(p, "心魔起，" + out.split("\n")[0])
		"魔修袭镇":
			var helpers := npcs().filter(func(x): return side(x) == "正" and int(R(x, p)["f"]) > 20).slice(0, 2)
			if oid == "guard":
				var hn := []
				for h in helpers:
					fav(h, 10, "一起守过镇子", 15)
					chron(h, "与%s同守小镇。" % pn())
					hn.append(h["name"])
				R(n, p)["g"] = int(R(n, p)["g"]) + 30
				_inj(3)
				out = "她守在镇口%s。天亮时，火灭了。\n（受伤：闭关炼化减半 3 日）" % (("，" + "、".join(hn) + "闻讯赶来") if not hn.is_empty() else "，一个人")
				chron(p, "%s带人袭镇，她守在镇口。" % nm)
			else:
				remember(p, n, "小镇那夜的火光", -20)
				out = "她背着姑母进了后山。回头时，半边天是红的。"
				chron(p, "%s血洗小镇那夜，她背着姑母进了后山。" % nm)
			rumor("%s血洗了后山下的小镇。" % nm, [n])
		"秘境":
			var party := []
			for i in ctx.get("party", []):
				party.append(C(i))
			if oid == "out":
				out = "她在外面守了三日，等来的是一身伤的%s。" % _ch(party)["name"]
				chron(p, "秘境开时，她守在外面。")
			else:
				for x in party:
					x["place"] = "古战场"
					meet(x)
				_wu(15)
				if rng.randf() < 0.5:
					var a2: Dictionary = _ch(party)
					R(a2, p)["g"] = int(R(a2, p)["g"]) + 10
					remember(p, a2, "秘境里%s推我" % a2["name"], -20)
					R(p, a2)["g"] = int(R(p, a2)["g"]) + 30
					out = "出秘境时，%s在背后推了她一把。\n（感悟 +15）" % a2["name"]
				else:
					var b2: Dictionary = _ch(party)
					fav(b2, 12, "秘境里一起逃出来", 15)
					out = "秘境塌时，%s拉了她一把。\n（感悟 +15）" % b2["name"]
				chron(p, "探了秘境。" + out.split("\n")[0])
		"闭关小成":
			_wu(6)
			chron(p, "闭关略有小成。")
		"访客":
			fav(n, 5)
			chron(p, "%s来青庐坐了坐。" % nm)
		"坊市欺客":
			meet(n)
			R(p, n)["g"] = int(R(p, n)["g"]) + 10
			chron(p, "在坊市吃了%s的亏。" % nm)
		"义结金兰":
			R(p, n)["t"].append("结义")
			R(n, p)["t"].append("结义")
			chron(p, "与%s义结金兰。" % nm)
			chron(n, "与%s义结金兰。" % pn())
		"劫修拦路":
			meet(n)
			if oid == "pay":
				_ling(-int(ctx.get("cost", 0)))
				R(p, n)["g"] = int(R(p, n)["g"]) + 15
				out = "%s掂了掂，让开了路。" % nm
				chron(p, "被%s拦路，交了买路钱。" % nm)
			elif _roll(pl, float(n["lv"])):
				R(n, p)["g"] = int(R(n, p)["g"]) + 15
				out = "三招过后，%s退进了林子。" % nm
				chron(p, "被%s拦路，拔剑逼退了%s。" % [nm, ta(n)])
			else:
				_inj(2)
				_ling(-int(ctx.get("cost", 0)))
				R(p, n)["g"] = int(R(p, n)["g"]) + 25
				out = "她没打过。灵石被搜走了。\n（受伤：闭关炼化减半 2 日）"
				chron(p, "被%s拦路，没打过。" % nm)
		"姑母来信", "夜雨", "灵田", "飞升异象", "旧物", "宗门大比", "师门书信":
			pass
	return out

# ================================================================ 供界面读取
## 玩家认识的人（按关系深浅排序）
func acquaintances() -> Array:
	var out := []
	for k in _ids(P()["rel"]):
		var r: Dictionary = P()["rel"][k]
		if int(r["m"]) == 1:
			out.append(C(k))
	out.sort_custom(func(a, b): return _depth(a) > _depth(b))
	return out

func _depth(c: Dictionary) -> float:
	var r := R(P(), c)
	var o := R(c, P())
	return absf(float(r["f"])) + float(r["g"]) + absf(float(o["f"])) + float(o["g"]) + r["t"].size() * 60 + (0 if c["alive"] else -500)

## 关系一词：道侣 / 师父 / 金兰 / 仇 / 故交 / 相识
func rel_word(c: Dictionary) -> String:
	var r := R(P(), c)
	var o := R(c, P())
	if "道侣" in r["t"]:
		return "道侣"
	if "师" in r["t"]:
		return "师父"
	if "结义" in r["t"]:
		return "金兰"
	if int(o["g"]) >= 40 or int(r["g"]) >= 40:
		return "仇"
	if int(o["g"]) >= 15 or int(r["g"]) >= 15:
		return "有隙"
	if int(o["f"]) >= 30:
		return "故交"
	if int(o["f"]) >= 10:
		return "相熟"
	return "相识"

func status(c: Dictionary) -> String:
	if c.get("asc", false):
		return "已飞升"
	if not c["alive"]:
		return "已故"
	return realm(c)

## NPC 记得主角的事
func memories_of_p(c: Dictionary) -> Array:
	return c["mem"].filter(func(m): return int(m[1]) == 1)

func recent_news(days: int = 30) -> Array:
	return w["news"].filter(func(x): return int(x[0]) > int(w["day"]) - days)

# ================================================================ 测试用：自动选项的模拟
func auto_choose() -> void:
	var ev := pending()
	if ev.is_empty():
		return
	if ev["stage"] == "ask":
		var o: Array = _ch(ev["opts"])
		choose(String(o[0]))
	if not pending().is_empty():
		close()
