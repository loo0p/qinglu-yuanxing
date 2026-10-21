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
	"暗恋不舍": [1, -4, true, 99, 0, 0, 1.0], "怨偶": [1, 14, true, 99, 0, 0, 1.0], "旧友托梦": [1, 4, true, 99, 0, 0, 1.0],
	"仇家寻上门": [2, 25, true, 99, 0, 0, 1.0], "再问": [2, -8, true, 99, 0, 0, 1.0],
	# v0.7.2：江湖再添几味
	"宗门招徒": [1, 2, false, 2, 6, 20, 1.2], "入门试炼": [1, 6, true, 99, 0, 0, 1.0], "秘境请柬": [1, 4, false, 2, 10, 20, 1.2],
	"拍卖会": [0, 2, false, 99, 8, 18, 1.2], "劫修伏击": [2, 22, false, 2, 12, 25, 1.5], "师弟惹祸": [1, 6, false, 99, 6, 15, 1.2],
	"天材地宝": [1, 6, false, 99, 6, 18, 1.2], "宝地相争": [1, 10, true, 99, 0, 0, 1.0], "对手突破": [0, 4, false, 99, 10, 15, 1.2],
	"旧债上门": [1, 6, false, 99, 6, 18, 1.0], "节令": [0, -4, false, 99, 3, 14, 1.4],
	# 第三拍：对后话也说“不”的人
	"远方来信": [0, -4, true, 99, 0, 0, 1.0], "喜帖": [1, 2, true, 99, 0, 0, 1.0], "落难": [1, 8, true, 99, 0, 0, 1.0],
}
const FESTIVALS = ["上元", "清明", "端午", "七夕", "中秋", "重阳", "冬至"]
const TREASURES = ["千年雪莲", "一窝赤血灵芝", "一块天外陨铁", "九叶紫参", "一眼地火灵泉", "一株月下昙"]
const LOTS = ["一卷残缺的剑谱", "一枚上古传送符", "半张丹方", "一盏能照见心魔的琉璃灯", "一只来历不明的空储物镯"]
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
	_arc_setup()
	_save_rng()

func attach(gs, d: Dictionary) -> void:
	g = gs
	w = d
	rng.seed = int(w.get("rng_seed", 0))
	rng.state = String(w.get("rng", "0")).to_int()
	if not w.has("arc") and w.has("C"):
		# v0.6.0–0.6.5 的档没有故事线：读档时补种（从今天往后排），不动已有的人和事
		_arc_setup(int(w["day"]))
		_save_rng()

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
	# 单字名不用“子/少/之/小/满……”这类单独成名很怪的字（“谢少”“傅子”）
	var solo: Array = giv.filter(func(ch): return not (ch in ["子", "少", "之", "长", "起", "慎", "明", "行", "小", "满", "知", "听", "初", "若", "心", "念"]))
	# 双字名的第二个字也避开“小/长/起/初……”（“凝小”“寒长”读着别扭）
	var second: Array = giv.filter(func(ch): return not (ch in ["小", "长", "起", "慎", "明", "少", "初", "知", "听", "若", "念", "子"]))
	var c1: String = _ch(giv)
	var c2: String = _ch(second.filter(func(ch): return ch != c1))
	var nm: String = _ch(SURN) + (c1 + c2 if rng.randf() < 0.5 else _ch(solo))
	# 同名就再起一次（最多三回），免得两个“苏青”分不清
	for k in 3:
		var dup := false
		for o in w["C"].values():
			if o["name"] == nm:
				dup = true
		if not dup:
			break
		nm = _ch(SURN) + _ch(giv) + _ch(second)
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
		"alive": true, "asc": false, "inj": 0, "rel": {}, "mem": [], "log": [], "pseed": rng.randi() % 1000000000, "pv": 7, "born": int(w["day"])}
	w["C"][str(id)] = c
	return c

## 立绘：存种子与选项，显示时 Portrait5Lib.roll(seed, opts) 还原（确定性）
## v0.7 新增的立绘部件；旧存档里的人物不抽这些，免得读档后换了张脸
const PV7_NEW := ["hair_f11@base_f", "hair_f12@base_f", "hair_m11@base_m", "robe_f9@base_f", "robe_m9@base_m",
	"acc_f4@base_f", "huadian_moon", "mole_cheek", "huadian_drop"]
func portrait_opts(c: Dictionary) -> Dictionary:
	var o := {"sex": "f" if c["sex"] == "女" else "m", "elder": float(c["age"]) >= 75.0, "demonic": side(c) == "魔"}
	if int(c.get("pv", 0)) < 7:
		o["exclude"] = PV7_NEW
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
		c["age"] = snappedf(float(c["age"]) + 1.0 / 360.0, 0.0001)   # 取整到 4 位：JSON 往返不丢精度
		if int(c["inj"]) > 0:
			c["inj"] = int(c["inj"]) - 1
		c["xp"] = snappedf(float(c["xp"]) + rng.randf_range(0.6, 1.4) * (0.4 if int(c["inj"]) > 0 else 1.0), 0.0001)
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
	_arc_tick()
	if home and w["pending"].is_empty():
		storyteller()
	_save_rng()

func solo(c: Dictionary) -> void:
	var goal: String = c["goal"]
	_flag_add("solo:" + goal)
	chron(c, String(_ch(SOLO[goal])).format({"p": c["place"], "s": c["sect"]}))
	if goal == "炼一炉九转丹" and rng.randf() < 0.05:
		chron(c, "九转丹成。")
		c["lv"] = mini(18, int(c["lv"]) + 2)
		rumor("%s炼成了九转丹。" % c["name"], [c])
		c["goal"] = "求长生"
	if goal == "寻道侣" and partner(c) != null:
		c["goal"] = "求长生"

## 缘分线上那个人，在表白之前不让江湖把他写死或配给别人（重伤代替身死）
func _protected(c: Dictionary) -> bool:
	var arc: Dictionary = w.get("arc", {})
	return int(arc.get("fated", 0)) == int(c["id"]) and not arc.get("romance_done", false)

func die(c: Dictionary, how: String) -> void:
	if _protected(c) and not (pn() in how):
		c["inj"] = 25
		chron(c, "险些丧命，被人从%s抬了回来。" % c["place"])
		return
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
			if rng.randf() < 0.3:
				rumor(pv("争宝闻", ["听说%s在%s抢先得了一件宝物，%s空手而回。", "%s在%s和%s争一株灵草，争赢了。", "%s从%s带回一卷残图，据说是从%s手里截下的。"]) % [win["name"], place, lose["name"]], [win, lose])
		"斗法":
			var ab2 := [a, b] if int(a["lv"]) + rng.randf() * 5 > int(b["lv"]) + rng.randf() * 5 else [b, a]
			var win2: Dictionary = ab2[0]
			var lose2: Dictionary = ab2[1]
			R(lose2, win2)["g"] = int(R(lose2, win2)["g"]) + 30
			lose2["inj"] = 15
			chron(win2, String(_ch(VAR["斗法_w"])).format({"p": place, "o": lose2["name"]}))
			chron(lose2, String(_ch(VAR["斗法_l"])).format({"p": place, "o": win2["name"]}))
			lose2["place"] = SECT_HOME[lose2["sect"]]
			if rng.randf() < 0.5:
				var dv := pv("斗法闻", ["{w}与{l}在{p}斗法，{l}落败。", "{w}在{p}一剑挑伤了{l}。", "{l}在{p}输给了{w}，被抬回了山门。"])
				rumor(dv.format({"w": win2["name"], "l": lose2["name"], "p": place}), [win2, lose2])
			if int(win2["lv"]) - int(lose2["lv"]) >= 3 and (tag(win2, "阴狠") or side(win2) == "魔") and rng.randf() < 0.5:
				die(lose2, "死于%s之手" % win2["name"])
			else:
				remember(lose2, win2, "%s伤我" % win2["name"], -25)
		"结为道侣":
			if _protected(a) or _protected(b):
				ra["f"] = int(ra["f"]) + 5
				chron(a, "与%s在%s喝了一夜的酒。" % [b["name"], place])
				return
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
			if c.is_empty() or (not c["alive"] and not (k == "B" and it[1] in ["旧友死讯", "旧友托梦"])):
				ok = false
		if it[1] == "旧友死讯" and _flag("mourned:%d" % int(it[2]["B"])) > 0:
			ok = false
		if ok:
			var tid := _arc_adjust(String(it[1]), it[2], it[3])
			if tid != "":
				fire(tid, it[2], it[3])
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

# ---------------------------------------------------------------- 故事线（v0.6.4）
## 一局 40–45 日、其中约一半在青庐，纯随机很难凑齐几条大线。开局给每局定下：
## ① 一段缘（一个“命里该遇见”的人：偶遇 → 访客 → 表白 → 若应下，道侣遇险）
## ② 一场离别（第 14–26 日，认识的人被魔修/阴狠之人所害 → 旧友死讯 → 收殓则寻凶）
## 事件仍走说书人的队列，与随机事件交错；条件不成立（人死了、结了仇、已有道侣）就自然作罢。
func _arc_setup(from_day: int = 0) -> void:
	var p := P()
	var cands := npcs().filter(func(c): return c["sex"] != p["sex"] and side(c) != "魔" and int(c["lv"]) <= 10 and partner(c) == null and not ("报仇" == c["goal"]) and int(R(c, p)["g"]) < 20)
	var arc := {"death_day": from_day + (rng.randi_range(14, 20) if from_day == 0 else rng.randi_range(5, 10)), "death_done": false}
	if partner(p) != null:
		cands = []
	if not cands.is_empty():
		var f: Dictionary = _ch(cands)
		arc["fated"] = int(f["id"])
		schedule(rng.randi_range(2, 5), "偶遇", {"B": int(f["id"])}, {"arc": "romance"})
	w["arc"] = arc

## 队列里的故事线事件到期时再核一遍条件；返回实际要发的模板（"" = 作罢）
func _arc_adjust(tid: String, roles: Dictionary, ctx: Dictionary) -> String:
	if ctx.get("arc", "") != "romance":
		return tid
	var p := P()
	var n := C(roles["B"])
	match tid:
		"偶遇":
			if known(n):
				fav(n, 4)
				schedule(rng.randi_range(6, 10), "表白", {"B": int(n["id"])}, {"arc": "romance"})
				return "访客"
			schedule(rng.randi_range(4, 7), "访客", {"B": int(n["id"])}, {"arc": "romance"})
			return "偶遇"
		"访客":
			if int(R(n, p)["g"]) >= 20:
				return ""
			fav(n, 4)
			schedule(rng.randi_range(6, 10), "表白", {"B": int(n["id"])}, {"arc": "romance"})
			return "访客"
		"表白", "再问":
			if partner(p) != null or partner(n) != null or int(R(n, p)["g"]) >= 20 or int(R(n, p)["f"]) < 0 or not n["alive"]:
				return ""
			return tid
		"暗恋不舍", "怨偶":
			return tid if partner(p) == null or tid == "怨偶" else ""
		"远方来信", "喜帖", "落难":
			return tid if n["alive"] else ""
		"道侣遇险":
			return "道侣遇险" if partner(p) == n else ""
	return tid

func _arc_tick() -> void:
	var arc: Dictionary = w.get("arc", {})
	if arc.is_empty() or arc.get("death_done", true) or int(w["day"]) < int(arc["death_day"]) or int(w["day"]) > int(arc["death_day"]) + 14:
		return
	var p := P()
	var fated := int(arc.get("fated", 0))
	var victims := npcs().filter(func(c): return known(c) and int(c["id"]) != fated and partner(c) == null and int(R(p, c)["g"]) < 15 and not ("师" in R(p, c)["t"]))
	if victims.is_empty():
		return
	victims.sort_custom(func(a, b): return int(R(p, a)["f"]) > int(R(p, b)["f"]))
	var v: Dictionary = victims[0]
	var killers := npcs().filter(func(c): return c != v and (side(c) == "魔" or tag(c, "阴狠")) and int(c["lv"]) >= int(v["lv"]))
	if killers.is_empty():
		killers = npcs().filter(func(c): return c != v and int(c["id"]) != fated and (side(c) == "魔" or tag(c, "阴狠") or tag(c, "嗜战")))
	if killers.is_empty():
		return
	var k: Dictionary = _ch(killers)
	arc["death_done"] = true
	if int(R(p, v)["f"]) < 6:
		R(p, v)["f"] = 6
	chron(k, "在%s截杀了%s。" % [v["place"], v["name"]])
	die(v, "死于%s之手" % k["name"])
	schedule(rng.randi_range(1, 3), "旧友死讯", {"B": int(v["id"])})

## 婉拒之后：痴情/温柔/怯懦的人放不下（暗恋不舍），傲气/记仇/阴狠/薄情的人记恨（怨偶）
func _after_refusal(n: Dictionary, ctx: Dictionary) -> void:
	if ctx.get("second", false):
		# 第二回也拒了：对方另择良缘（或远走），喜帖/辞行是第三拍
		var mates := npcs().filter(func(c): return c != n and c["sex"] != n["sex"] and partner(c) == null and not _protected(c) and side(c) == side(n))
		var ctx2 := {"arc": "romance"}
		if not mates.is_empty():
			var m: Dictionary = _ch(mates)
			R(n, m)["t"].append("道侣")
			R(m, n)["t"].append("道侣")
			chron(n, "与%s结为道侣。" % m["name"])
			chron(m, "与%s结为道侣。" % n["name"])
			ctx2["spouse"] = m["name"]
		schedule(rng.randi_range(10, 16), "喜帖", {"B": int(n["id"])}, ctx2)
		return
	var sour := tag(n, "傲气") or tag(n, "记仇") or tag(n, "阴狠") or tag(n, "薄情") or tag(n, "嗜战")
	if sour:
		schedule(rng.randi_range(6, 11), "怨偶", {"B": int(n["id"])}, {"arc": "romance"})
	else:
		schedule(rng.randi_range(5, 10), "暗恋不舍", {"B": int(n["id"])}, {"arc": "romance"})

func _killer_of(how: String) -> Variant:
	for x in npcs():
		if ("死于%s" % x["name"]) in how or ("被%s" % x["name"]) in how:
			return x
	return null

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
			return _r1(_pick(func(c): return known(c) and c["sex"] != p["sex"] and int(R(c, p)["f"]) > 38 and partner(c) == null))
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
			return _r1(_pick(func(c): return int(c["lv"]) >= pl + 6 and side(c) != "魔" and int(R(c, p)["f"]) >= 0 and partner(p) != c))
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
		"宗门招徒":
			if _flag("in_sect") > 0:
				return null
			var pl3 := plv()
			return _r1(_pick(func(c): return side(c) == "正" and c["sect"] != "散修" and int(c["lv"]) >= pl3 + 4 and int(R(c, p)["g"]) < 10))
		"秘境请柬":
			return _r1(_pick(func(c): return known(c) and int(R(c, p)["f"]) > 12 and int(R(c, p)["g"]) < 10 and partner(p) != c))
		"拍卖会":
			return _r1(_pick(func(c): return int(c["lv"]) >= 3, func(c): return 1.0 + float(tag(c, "贪财")) * 3.0 + float(known(c))))
		"劫修伏击":
			var pl4 := plv()
			return _r1(_pick(func(c): return side(c) == "魔" and int(c["lv"]) >= pl4))
		"师弟惹祸":
			var pl5 := plv()
			return _r1(_pick(func(c): return known(c) and int(c["lv"]) <= pl5 + 1 and int(R(c, p)["f"]) >= 8 and partner(p) != c and master_of(p) != c))
		"天材地宝":
			return {}
		"对手突破":
			var pl6 := plv()
			return _r1(_pick(func(c): return known(c) and int(c["lv"]) < 17 and (int(R(c, p)["g"]) >= 10 or int(R(p, c)["g"]) >= 10 or absi(int(c["lv"]) - pl6) <= 2)))
		"旧债上门":
			return _r1(_pick(func(c): return int(c["lv"]) >= 2 and int(R(c, p)["g"]) < 30, func(c): return 1.0 + float(tag(c, "贪财") or tag(c, "圆滑")) * 3.0))
		"节令":
			return {}
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
			return String(HINT[t]).format({"ta": "对方" if n["sex"] == "女" else ta(n)})   # 女修用“对方”，免得一句里两个“她”
	return ("对方" if n["sex"] == "女" else ta(n)) + "点了点头"

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
			return {"speaker": int(n["id"]), "anon": true, "text": "%s躺着一个人，%s的服色，%s%s" % [where2, n["sect"], pv("求助伤", ["胸前一道剑伤还在渗血", "嘴唇发紫，像中了毒", "灵气乱窜，经脉一跳一跳", "一条腿压在落石下", "背上插着半截断箭"]),
				(pv("求助认熟", ["。她认得这张脸——%s。", "。凑近了看，是%s。"]) if known(n) else pv("求助认", ["。是%s。", "。那人勉强抬起头：“……%s。”", "。腰牌上刻着名字：%s。"])) % nm],
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
			return {"speaker": 0, "text": pv("寻凶起", ["打听到{n}在{p}。丹炉底下刻着的那个名字，该去问一问了。", "有人在{p}见过{n}。她把剑擦了一夜。", "坊市的消息：{n}近来在{p}落脚。她把要带的东西收进了一只小包袱。"]).format({"n": nm, "p": n["place"]}),
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
			ctx["news"] = String(it[1]).trim_prefix("听说")
			return {"speaker": 0, "text": pv("传闻", ["坊市茶摊上听人说：%s", "说书先生今天讲的是：%s", "药铺伙计压低声音告诉她：%s", "过路的散修提了一句：%s", "姑母的信末添了一句：%s"]) % ctx["news"], "opts": ok}
		"赠礼":
			var gs := _sample(LIKES, 3)
			return {"speaker": 0, "text": pv("赠起", ["去坊市换盐时，她想起%s。摊上有几样东西，带一样去？", "听说%s近来闭关，她想托人捎点东西去。", "坊市新到了一批货。%s会喜欢哪一样？", "她在货摊前站了很久，想着%s。"]) % nm,
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
			var tasks := ["“去寒潭边坐满七日，不许起身。”", "“把这卷经抄一百遍，抄错一个字，从头来。”", "“守着这炉火，三日三夜，火不能灭。”", "“后山那头青牛，你去把它牵回来。不许伤它。”"]
			var k := rng.randi() % tasks.size()
			ctx["k"] = k
			return {"speaker": int(n["id"]), "text": tasks[k],
				"opts": [_o("do", "照做"), _o("skip", "推说有事")]}
		"道侣遇险":
			return {"speaker": 0, "text": pv("遇险", ["%s去云梦泽采药，七日没有回信。", "%s的命灯忽明忽暗。", "有人捎来%s的半截剑穗，说是在泽边捡到的。"]) % nm,
				"opts": [_o("go", "去寻"), _o("wait", "等消息")]}
		"道侣口角":
			var op := opinion(n, P())
			ctx["good"] = op >= 30
			return {"speaker": int(n["id"]), "text": pv("口角", ["“你又熬夜守炉子。”", "“说好一起去坊市的。”", "“那人送你的东西，你还留着？”", "“出门也不说一声，我找了你半座山。”", "“你的伤还没好，又要去寒潭？”"]),
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
			var inv := C(ctx.get("inviter", 0))
			if not inv.is_empty() and inv["alive"] and not (inv in party):
				party[0] = inv
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
			return {"speaker": 0, "text": pv("夜雨", ["檐下滴了一夜的水。她数着数着，想到了%s。", "夜雨敲窗。她想起%s。", "灯花爆了一下。她没来由地想起%s。", "山里起雾，像那年和%s走过的那段路。", "听见檐下风铃响，以为是%s来了。", "梦见%s站在桂树下，醒来记不清说了什么。"]) % _ch(ks), "opts": ok}
		"灵田":
			return {"speaker": 0, "text": pv("灵田", ["田垄上落了一只白鹭，站了半个时辰才走。", "灵田里冒了一株不认识的苗。", "鸟啄了半垄青芝。", "今年的青芝结得密。", "夜里下了霜，她给灵田盖了草帘。", "田埂边的野兔又来了，她没赶它。", "引水的竹管裂了，修了一下午。"]), "opts": ok}
		"访客":
			var tail: String = {"好奇": "问了很多丹炉的事。", "淡泊": "喝完就走了。", "傲气": "嫌她的茶淡。", "温柔": "走前替她把晾的衣裳收了。", "贪财": "眼睛在灵田上转了好几圈。", "侠义": "顺手把塌了的篱笆扶正了。", "痴情": "说起一个人，说了一半又停了。", "多疑": "坐下前先看了看四下。", "嗜战": "非要同她比划两招才肯走。", "阴狠": "笑着夸她的灵田长得好。", "怯懦": "说话声音很轻，喝完茶就告辞了。", "圆滑": "把坊市的新鲜事讲了个遍。", "记仇": "说起一个旧仇人，咬着牙笑。", "薄情": "喝了半碗就走了。"}.get(n["traits"][0], pv("访客尾", ["坐了一刻。", "看了一会儿她的灵田。", "临走前替她添了灶里的柴。"]))
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
		"暗恋不舍":
			return {"speaker": int(n["id"]), "text": pv("暗恋", [
				"柴门外又放着一包新炒的松子，没有留名。她知道是谁。",
				"%s还是常来，只在篱笆外站一站，问一句灵田的收成，就走。" % nm,
				"坊市里撞见%s。%s远远看见她，拐进了另一条巷子，又折回来，塞给她一把伞：“要下雨了。”" % [nm, ta(n)],
				"窗台上多了一盏莲花灯，灯芯是新换的。%s那晚在山道上站到很晚。" % nm]),
				"opts": [_o("cut", "把话说清楚"), _o("keep", "收下这份心意")]}
		"再问":
			return {"speaker": int(n["id"]), "text": pv("再问", [
				"%s又来了。这回什么也没带，站在桂树下：“上回的话，我想再问一遍。”" % nm,
				"雨停的傍晚，%s在檐下收了伞：“我等了些日子。你……可想好了？”" % nm]),
				"opts": [_o("yes", "应下"), _o("no", "仍是婉拒")]}
		"怨偶":
			return {"speaker": int(n["id"]), "text": pv("怨偶", [
				"坊市里传开一句闲话：青庐那个女修，眼界高得很。传话的人说，是%s讲的。" % nm,
				"%s在坊市口拦住她，笑得很淡：“我倒要看看，你那条道能走多远。”" % nm,
				"药铺掌柜不肯再卖她青芝了，支支吾吾，说是%s打过招呼。" % nm]),
				"opts": [_o("let", "随他去"), _o("ask", "当面问个明白")]}
		"旧友托梦":
			var k := C(roles["K"])
			return {"speaker": int(n["id"]), "text": pv("托梦", [
				"夜里梦见%s，站在当年同行的山道上，衣襟湿透。%s张了张嘴，只说了一个名字：%s。" % [nm, ta(n), k["name"]],
				"灯下打了个盹，%s推门进来，像往常一样讨碗茶。茶还没倒，%s低声道：“是%s。”醒来时灯芯已经烧尽了。" % [nm, ta(n), k["name"]],
				"梦里桂花落了满院。%s坐在石阶上，背对着她：“别替我难过。只是……%s还活着。”" % [nm, k["name"]]]),
				"opts": [_o("name", "记下那个名字"), _o("let", "烧一炷香，送%s走" % ta(n))]}
		"仇家寻上门":
			var fr: String = ctx.get("friend", "那人")
			return {"speaker": int(n["id"]), "text": pv("仇家", [
				"院里的鸡忽然不叫了。%s站在灵田边上：“%s死前，把一样东西交给了你。交出来，我就走。”" % [nm, fr],
				"%s找上了青庐。“听说你和%s交情不浅。”剑在鞘里轻轻响了一声。" % [nm, fr],
				"柴门被推开，进来的是%s。“%s的东西，在你这儿吧？”" % [nm, fr]]),
				"opts": [_o("fight", "迎战"), _o("give", "说没有，任%s搜" % ta(n)), _o("run", "从后窗走")]}
		"宗门招徒":
			return {"speaker": int(n["id"]), "text": pv("招徒", [
				"%s开山门收外门弟子的告示贴到了坊市口。%s站在告示下，看了她一眼：“你也来试试？”" % [n["sect"], nm],
				"%s的%s路过青庐，看她练了一趟剑，留下一块木牌：“%s下月考外门，拿着这个去。”" % [n["sect"], nm, n["sect"]],
				"“%s缺人。”%s开门见山，“散修苦，你心里清楚。”" % [n["sect"], nm]]),
				"opts": [_o("go", "去应试"), _o("no", "婉谢")]}
		"入门试炼":
			var trials := ["山门前九百级石阶，背着一筐石头走上去。", "进幻阵，走出来就算过。", "同另一个应试的人比一场剑，点到为止。"]
			var k3 := rng.randi() % trials.size()
			ctx["k"] = k3
			return {"speaker": int(n["id"]), "text": "%s的外门考核：%s%s" % [n["sect"], trials[k3], pv("试炼尾", ["执事打了个哈欠。", "旁边站着一排和她差不多大的年轻人。", "%s站在台阶顶上，没有看她。" % nm])],
				"opts": [_o("all", "全力以赴"), _o("hide", "藏三分")]}
		"秘境请柬":
			return {"speaker": int(n["id"]), "text": pv("请柬", [
				"%s托人捎来一张折成方胜的纸：“北边的秘境要开了，缺一个信得过的人。”" % nm,
				"“三日后，古战场。”%s把一枚玉符放在她桌上，“你来，我分你三成。”" % nm,
				"%s在篱笆外喊她：“有个地方，我一个人进不去。”" % nm]),
				"opts": [_o("go", "赴约"), _o("no", "推辞")]}
		"拍卖会":
			var lot: String = pv("拍品", LOTS)
			ctx["lot"] = lot
			var o3 := []
			if lingshi() >= 12:
				o3.append(_o("bid", "出价 12 灵石"))
			if lingshi() >= 18:
				o3.append(_o("raise", "一口价 18 灵石"))
			o3.append(_o("watch", "只看不买" if not o3.is_empty() else "囊中羞涩，只看看"))
			return {"speaker": 0, "text": pv("拍卖", ["坊市的拍卖会上，压轴的是%s。%s在前排坐着，已经举了牌。", "拍卖会开到第七件：%s。她身边的%s坐直了身子。", "锣响三声，台上掀开红布——%s。%s低声骂了一句“贵”，还是举了手。"]) % [lot, nm],
				"opts": o3}
		"劫修伏击":
			return {"speaker": int(n["id"]), "text": pv("伏击", [
				"从坊市回来的路上，两侧林子里同时亮起了火把。为首的是%s：“等你半天了。”" % nm,
				"雾里有铃铛响。她刚停下脚，三道人影已经围了上来，%s站在最后。" % nm,
				"山道拐角，一张网从天上落下来。%s拍着手从石头后头走出来。" % nm]),
				"opts": [_o("fight", "拔剑突围"), _o("talisman", "撒一把符，趁乱走"), _o("drop", "丢下货物")]}
		"师弟惹祸":
			var trouble: String = pv("惹祸", ["在坊市赌输了一大笔，债主堵在门口", "顺手拿了药王谷晾在外头的一株药，被人认了出来", "同血煞门的人吵了一架，打伤了对方", "替人作保，那人跑了"])
			ctx["trouble"] = trouble
			return {"speaker": int(n["id"]), "text": "%s——那个总喊她“姐姐”的%s——%s。%s" % [nm, "小师妹" if n["sex"] == "女" else "小师弟", trouble, pv("惹祸尾", ["人缩在青庐柴门后，不敢抬头。", "来的时候脸上还挂着一块青。", "开口第一句是：“就这一回。”"])],
				"opts": [_o("cover", "替%s担下" % ta(n)), _o("drag", "押着%s去赔罪" % ta(n)), _o("let", "让%s自己担" % ta(n))]}
		"天材地宝":
			var tr: String = pv("宝物", TREASURES)
			var where3: String = pv("宝地", ["后山雪线上", "寒潭底下", "古战场的断崖边", "云梦泽的一座孤岛上"])
			ctx["item"] = tr
			ctx["where"] = where3
			return {"speaker": 0, "text": pv("宝传", ["坊市里都在传：%s出了%s。", "樵夫说，%s夜里冒红光，像是%s要成熟了。", "药铺掌柜神神秘秘地告诉她：%s有%s，知道的人还不多。"]) % [where3, tr],
				"opts": [_o("go", "去碰碰运气"), _o("no", "不去凑热闹")]}
		"宝地相争":
			var it2: String = ctx.get("item", "那株灵草")
			return {"speaker": int(n["id"]), "text": pv("宝争", ["%s还在，可%s先到了一步，正蹲在旁边看。" % [it2, nm], "她赶到时，%s的剑已经插在%s旁边的土里：“先来后到。”" % [nm, it2], "%s和她几乎同时伸了手。两人都停在半空。" % nm]),
				"opts": [_o("fight", "各凭本事"), _o("share", "提议一人一半"), _o("give", "让给%s" % ta(n))]}
		"对手突破":
			n["lv"] = mini(17, int(n["lv"]) + 1)
			chron(n, "破境，入%s。" % realm(n))
			return {"speaker": int(n["id"]), "text": pv("破境", ["%s破境了，入了%s。坊市里有人说，那一夜%s的天是青的。", "听说%s闭关四十九日，出关已是%s，%s的灵气被抽空了一大片。", "%s的%s之境，是在%s的雷雨里破的。"]) % [nm, realm(n), n["place"]],
				"opts": [_o("train", "回去闭关"), _o("visit", "登门道贺"), _o("shrug", "一笑置之")]}
		"旧债上门":
			return {"speaker": int(n["id"]), "text": pv("旧债", [
				"%s拿着一张发黄的借据找上门：姑母年轻时向%s借过三块灵石，“连本带利，六块。”" % [nm, ("%s的师父" % ta(n)) if String(n["sect"]) == "散修" else String(n["sect"])],
				"“你家姑母欠我一炉丹。”%s把借据拍在桌上，“十年了。”" % nm,
				"%s在柴门外站着，手里捏着一张旧契：“这青庐的地，原先是租我家的。”" % nm]),
				"opts": [_o("pay", "认了，还钱"), _o("dan", "提出炼一炉丹抵债"), _o("deny", "不认这笔账")]}
		"节令":
			var fest: String = FESTIVALS[int(int(w["day"]) / 14) % FESTIVALS.size()]
			ctx["fest"] = fest
			var fx: String = {"上元": "镇上挂满了灯", "清明": "山下飘着纸钱的灰", "端午": "河边在赛龙舟", "七夕": "镇上的姑娘都在穿针乞巧", "中秋": "月亮大得像要落进灵田", "重阳": "坊市有人卖茱萸和菊花酒", "冬至": "姑母信里说包了饺子"}[fest]
			return {"speaker": 0, "text": "%s到了，%s。%s" % [fest, fx, pv("节尾", ["青庐里只有她一个人。", "她站在院里听了一会儿山下的动静。", "灶上的水开了，她没去管。"])],
				"opts": [_o("town", "下山凑个热闹"), _o("home", "在青庐守着"), _o("aunt", "给姑母捎点东西（2 灵石）")]}
		"远方来信":
			return {"speaker": int(n["id"]), "text": pv("远信", [
				"一封从南边来的信，字迹她认得，是%s的。信里说%s在泽边开了间小药铺，问她灵田今年收成如何，一句也没提旧事。" % [nm, ta(n)],
				"%s的信到了。%s如今在北边一座小城替人看病，信尾画了一枝梅花。" % [nm, ta(n)]]),
				"opts": [_o("reply", "回一封信"), _o("keep", "把信收好，不回")]}
		"喜帖":
			var who2: String = ctx.get("spouse", "")
			var xt := "%s托人捎来一句话：要出远门了，往后不必挂念。" % nm
			if who2 != "":
				xt = pv("喜帖", ["一张大红的喜帖压在青庐门槛上：{n}与{m}，下月初八。", "{n}要成亲了，对方是{m}。喜帖是{n}亲手写的，字很端正。"]).format({"n": nm, "m": who2})
			return {"speaker": int(n["id"]), "text": xt,
				"opts": [_o("go", "去喝杯喜酒") if who2 != "" else _o("go", "去送一程"), _o("gift", "托人送份礼（3 灵石）"), _o("no", "不去")]}
		"落难":
			return {"speaker": int(n["id"]), "text": pv("落难", [
				"坊市后巷里，%s被人堵在墙角，储物袋已经被翻了出来。%s看见了她，别开了脸。" % [nm, ta(n)],
				"山道边躺着一个人，衣裳被剑气割得一条一条的。是%s——当初在坊市说她闲话的那个。" % nm,
				"%s欠了血煞门的账，被押着往北走。经过青庐时，%s抬头看了她一眼。" % [nm, ta(n)]]),
				"opts": [_o("help", "出手"), _o("pass", "当作没看见")]}
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
				out = "%s。%s自称%s。" % [pv("偶遇同行", ["结伴走了一程", "同行到岔路口才分开", "一起避了场雨，说了些各自的来处", "她分了半块干粮，对方回了一句谢", "一路无话，到岔口时对方先开了口", "对方教她认了两种路边的药草", "过独木桥时，对方回身扶了她一把", "两人在破庙里烤干了衣裳，聊到雨停"]), "对方" if n["sex"] == "女" else ta(n), nm]
				chron(n, "山道上遇见%s，同行一程。" % pn())
				chron(p, pv("偶遇记", ["与%s同行到岔路口。", "和%s一起避了场雨。", "路上结识%s，同行了一程。", "与%s结伴走过一段山路。"]) % nm)
			else:
				out = "%s。%s" % [pv("偶遇别", ["各自赶路", "她拱了拱手，没多停", "彼此点头，擦肩而过", "她侧身让了路"]), pv("偶遇别名", ["后来才知道，那人叫%s。", "后来在坊市听人提起，才知那是%s。", "那人走远了，她才想起腰牌上的字：%s。"]) % nm]
				chron(p, pv("偶遇别记", ["路上与%s擦肩而过。", "在路上见过%s一面，没有搭话。", "与%s点头而过。"]) % nm)
		"求助":
			meet(n)
			if oid == "help":
				_inj(2)
				fav(n, 25, "重伤时%s救了我" % pn(), 30)
				out = pv("求助救", ["她守了一夜，渡了三日修为。%s醒来，只说了一句：“记下了。”", "她把人背回青庐，灵气渡了一遍又一遍。天亮时%s睁开眼，看了她很久。", "她以指尖逼出毒血，又守着药炉熬到三更。%s醒来第一句是：“你不该救我。”"]) % nm + "\n（经脉微损：闭关炼化减半 2 日）"
				chron(p, "%s救下重伤的%s，耗了三日修为。" % [ctx.get("where", "寒潭边"), nm])
				chron(n, "重伤倒在%s，被%s所救。" % [ctx.get("where", "寒潭边"), pn()])
				schedule(rng.randi_range(8, 25), "报恩", {"B": int(n["id"])}, {"where": ctx.get("where", "寒潭边")})
			elif oid == "half":
				fav(n, 8, "%s留过一瓶药" % pn(), 8)
				var tb := "对方" if n["sex"] == "女" else ta(n)
				out = pv("求助半", ["她把一瓶伤药放在%s手边，走了。" % tb, "她撕下半幅衣襟替%s扎紧伤口，留下药瓶，没等人醒。" % tb, "她喂%s服了一粒丹，把人挪到背风处，才转身离开。" % tb, "她在%s身旁折了根树枝做记号，药瓶挂在枝头。" % tb])
				chron(p, pv("求助半记", ["给%s留了一瓶伤药。", "替重伤的%s扎了伤口，没等人醒。", "把重伤的%s挪到背风处，留了药。", "路遇重伤的%s，留下一粒丹。"]) % nm)
			else:
				var got := _ling(rng.randi_range(8, 14))
				fav(n, -50, "%s趁我重伤劫了我" % pn(), -45)
				R(n, p)["g"] = int(R(n, p)["g"]) + 60
				out = pv("求助劫", ["储物袋里有 %d 块灵石。她没回头。", "她解下那只储物袋，掂了掂，%d 块灵石。身后的人连骂都骂不出声。"]) % got
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
			chron(p, pv("报恩记", ["%s找到青庐，还了当初的人情。", "当年救下的%s来青庐道谢。", "%s登门，还了那份救命的情。"]) % nm)
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
			if int(w.get("arc", {}).get("fated", 0)) == int(n["id"]):
				w["arc"]["romance_done"] = true
			if oid == "yes":
				R(n, p)["t"].append("道侣")
				R(p, n)["t"].append("道侣")
				out = pv("表白应", ["她说好。%s笑了，像是松了一口气。" % nm, "她没说话，只把那支木簪插进了发髻。", "“好。”她答得很轻。%s却像听见了很响的一声。" % nm])
				chron(p, "与%s结为道侣。" % nm)
				chron(n, "与%s结为道侣。" % pn())
				rumor("%s与%s结为道侣。" % [pn(), nm], [n])
				schedule(rng.randi_range(7, 12), "道侣遇险", {"B": int(n["id"])}, {"arc": "romance"})
			else:
				fav(n, -10, "%s拒了我" % pn(), -5)
				out = pv("表白拒", ["她说，道还长。%s没再说什么。" % nm, "她把木簪轻轻放回%s掌心：“我还没想好往后的路。”" % nm, "她沉默了很久，只说：“对不住。”%s点点头，像是早就知道。" % nm])
				chron(p, pv("表白拒记", ["%s问她愿不愿意同修。她说，道还长。", "婉拒了%s。", "%s向她表明心意，她没有应。"]) % nm)
				_after_refusal(n, ctx)
		"旧友死讯":
			var how: String = ctx.get("how", "")
			if oid == "bury":
				out = pv("收殓", ["她赶去，替%s立了块无字碑。" % nm, "她赶了三天路，亲手把%s葬在一棵老松下。" % nm, "她替%s合上眼，在坟前坐到天黑。" % nm])
				var killer = null
				for x in npcs():
					if ("死于%s" % x["name"]) in how or ("被%s" % x["name"]) in how:
						killer = x
				if killer != null:
					R(p, killer)["g"] = int(R(p, killer)["g"]) + 40
					remember(p, killer, "%s杀了%s" % [killer["name"], nm], -30)
					schedule(rng.randi_range(4, 9), "寻凶", {"B": int(killer["id"])})
					out += "碑前，她记下了一个名字：%s。" % killer["name"]
			else:
				out = pv("遥拜", ["她朝那方向拜了三拜。", "她在院里点了一盏灯，一夜没熄。", "她把那封信折好，压在丹炉底下。"])
				var k2 = _killer_of(how)
				if k2 != null:
					# 没去收殓：故人不肯走，凶手也没忘了她
					schedule(rng.randi_range(2, 5), "旧友托梦", {"B": int(n["id"]), "K": int(k2["id"])})
			remember(p, n, "%s不在了" % nm, -8)
			chron(p, "听说%s——%s。%s" % [nm, how, out])
		"寻凶":
			if oid == "go":
				if _roll(pl, float(n["lv"]), 6, 4):
					out = pv("寻凶胜", ["与{n}在{p}一战，斩之。", "在{p}找到{n}。一剑过后，她收剑入鞘，没有回头。", "{p}的雨下了一夜。天亮时，{n}倒在了她剑下。"]).format({"n": nm, "p": n["place"]})
					chron(p, pv("寻凶胜记", ["在{p}斩了{n}。", "寻到{n}，了结了这桩事。"]).format({"n": nm, "p": n["place"]}))
					die(n, "被%s所斩" % pn())
				else:
					_inj(4)
					R(n, p)["g"] = int(R(n, p)["g"]) + 20
					out = pv("寻凶败", ["与%s一战，败，伤了根基。", "%s比传闻里更狠。她拼着挨了一掌才脱身。", "她的剑断在%s手里，人是被过路的樵夫背回来的。"]) % nm + "\n（重伤：闭关炼化减半 4 日）"
					chron(p, pv("寻凶败记", ["寻%s报仇，败了，伤了根基。", "与%s一战，重伤而回。"]) % nm)
			else:
				out = pv("寻凶缓", ["她把%s的名字刻在丹炉底下。" % nm, "她没有去。只是从那天起，每天多练一个时辰的剑。", "她把打听来的消息写在纸上，压进了经卷。"])
				chron(p, pv("寻凶缓记", ["决定先修到能赢%s再说。", "把%s的名字记下，暂且按住了剑。"]) % nm)
				schedule(40, "寻凶", {"B": int(n["id"])})
		"再问":
			ctx["second"] = true
			return resolve("表白", roles, ctx, oid)
		"暗恋不舍":
			if oid == "cut":
				fav(n, -6, "%s把话说绝了" % pn(), -6)
				out = pv("暗恋断", ["她说：“你值得更好的人。”%s点点头，第二日便出了远门。" % nm, "她把松子还了回去，话说得很轻，也很清楚。%s没再来过。" % nm])
				chron(p, "同%s把话说清楚了。" % nm)
				chron(n, "放下了一段心事，出门远游。")
				schedule(rng.randi_range(14, 22), "远方来信", {"B": int(n["id"])}, {"arc": "romance"})
			else:
				fav(n, 10, "%s收下了我的心意" % pn(), 8)
				out = pv("暗恋收", ["她没推辞。%s的耳根红了，嘴上只说：“顺路。”" % nm, "她收下了，回赠一包自己晒的青芝。%s捧着走了很远才敢打开。" % nm])
				chron(p, "收下了%s的一份心意。" % nm)
				schedule(rng.randi_range(9, 15), "再问", {"B": int(n["id"])}, {"arc": "romance", "second": true})
		"怨偶":
			if oid == "let":
				_wu(6)
				out = "她照旧去坊市买她的盐。闲话传了半个月，自己散了。\n（心境沉静：感悟 +6）"
				chron(p, "%s在外头说她的闲话，她没理会。" % nm)
				schedule(rng.randi_range(12, 20), "落难", {"B": int(n["id"])}, {"arc": "romance"})
			elif tag(n, "阴狠") or tag(n, "记仇"):
				R(n, p)["g"] = int(R(n, p)["g"]) + 30
				remember(n, p, "%s当众给我难堪" % pn(), -20)
				out = "话说僵了。%s拂袖而去，留下一句：“你记着。”" % nm
				chron(p, "与%s当面说破，不欢而散。" % nm)
				schedule(rng.randi_range(12, 20), "仇人上门", {"B": int(n["id"])})
			else:
				fav(n, 8, "%s肯当面同我把话说开" % pn(), 6)
				R(n, p)["g"] = maxi(0, int(R(n, p)["g"]) - 10)
				out = "两人在茶棚下坐了一刻。%s最后说：“是我小气了。”" % nm
				chron(p, "与%s在茶棚下把话说开了。" % nm)
		"旧友托梦":
			var k := C(roles["K"])
			if oid == "name":
				R(p, k)["g"] = int(R(p, k)["g"]) + 40
				remember(p, k, "%s杀了%s" % [k["name"], nm], -30)
				out = "她起身点灯，在丹炉底下刻了一个名字：%s。" % k["name"]
				chron(p, "梦见%s，醒来记下了%s的名字。" % [nm, k["name"]])
				schedule(rng.randi_range(4, 8), "寻凶", {"B": int(k["id"])})
			else:
				_wu(8)
				out = "香烧完的时候，院里起了一阵风。她觉得%s是走了。\n（感悟 +8）" % nm
				chron(p, "梦见%s，烧了一炷香送%s走。" % [nm, ta(n)])
				schedule(rng.randi_range(6, 10), "仇家寻上门", {"B": int(k["id"])}, {"friend": nm})
		"仇家寻上门":
			var fr2: String = ctx.get("friend", "那人")
			if oid == "fight":
				if _roll(pl, float(n["lv"]), 6, 4):
					out = "一剑落下，%s倒在灵田边上。她想，%s可以安心了。" % [nm, fr2]
					chron(p, "%s寻上青庐，被她斩于院中，算是替%s了了这桩事。" % [nm, fr2])
					die(n, "被%s所斩" % pn())
				else:
					_inj(3)
					R(n, p)["g"] = int(R(n, p)["g"]) + 15
					out = "她败了。%s翻遍青庐，什么也没找到，临走踢翻了丹炉。\n（受伤：闭关炼化减半 3 日）" % nm
					chron(p, "%s寻上青庐，她不敌，丹炉被踢翻。" % nm)
			elif oid == "give":
				var lost := _ling(-mini(8, lingshi()))
				out = "%s把青庐翻了个底朝天，什么也没找到，顺手拿走了 %d 块灵石。" % [nm, -lost]
				chron(p, "%s来青庐翻找%s的遗物，一无所获。" % [nm, fr2])
			else:
				out = "她从后窗走了，在山里躲了两夜。回来时，柴门上多了一道剑痕。"
				chron(p, "%s寻上门时，她从后窗走了。" % nm)
				schedule(rng.randi_range(15, 25), "寻凶", {"B": int(n["id"])})
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
				out = pv("拜师应", ["她跪下，磕了三个头。%s受了。" % nm, "她奉上一盏茶。%s接过去，喝了。" % nm])
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
				out = ["第七日黄昏，她站起来时腿已经没了知觉。师父多看了她一眼。", "第一百遍抄完，天刚亮。师父翻了翻，在最后一页点了个朱点。", "第三夜，炉火映着她的脸，一下也没有暗过。师父往炉里添了一块炭，走了。", "她跟了青牛三天，第四天它自己低头跟她回来了。师父笑了。"][int(ctx.get("k", 0)) % 4] + "\n（感悟 +20）"
				chron(p, "受了师父%s的考验，过了。" % nm)
			elif oid == "do":
				fav(n, -4)
				out = ["第五日，寒气透骨，她到底站了起来。师父没说什么，只是转身走了。", "抄到第六十三遍，她错了一个字，手却再也提不起笔。师父收起经卷，走了。", "第三夜三更，她打了个盹，炉火灭了。师父没说什么，重新生了火。", "青牛把她顶进了溪里。师父在岸上看了一会儿，摇摇头。"][int(ctx.get("k", 0)) % 4]
				chron(p, "师父%s的考验，没过。" % nm)
			else:
				fav(n, -8)
				out = "她推说有事。师父看了她很久。"
				chron(p, "推掉了师父%s的考验。" % nm)
		"道侣遇险":
			if oid == "go":
				_inj(3)
				fav(n, 20, "%s来寻我" % pn(), 25)
				out = pv("遇险寻", ["她寻了九天，在一处浅滩找到人。", "她循着命灯的余光走进泽里，第七日找到了昏在芦苇丛中的%s。" % nm, "她背着%s蹚出沼泽时，两个人都只剩半条命。" % nm]) + "\n（奔波受伤：闭关炼化减半 3 日）"
				chron(p, "%s在云梦泽失了消息，她寻了九天，找回了人。" % nm)
			elif rng.randf() < 0.4:
				out = pv("遇险失", ["消息再没有来。", "命灯在第九夜熄了。她守着那盏灯，坐到天亮。"])
				die(n, "在云梦泽失踪，再没回来")
				chron(p, "道侣%s在云梦泽失踪了。" % nm)
			else:
				fav(n, -15, "我出事时%s没来" % pn(), -20)
				out = "半月后%s自己回来了，没提路上的事。" % ta(n)
				chron(p, "%s在云梦泽失了消息，半月后自己回来了。" % nm)
		"道侣口角":
			if ctx.get("good", false) or oid == "soft":
				fav(n, 3)
				out = pv("口角和", ["第二天，灶上多了一碗粥。", "她先笑了。%s绷了一会儿，也绷不住了。" % nm, "夜里，%s把她的剑穗重新编好了。" % nm])
				chron(p, pv("口角和记", ["与%s拌了两句嘴，第二天灶上多了一碗粥。", "与%s小吵了一回，很快和好了。"]) % nm)
			else:
				fav(n, -10)
				out = pv("口角僵", ["争了半夜，谁也没服谁。", "%s摔门出去，三天没回来。" % nm, "两人隔着一盏灯坐了半夜，谁也没先开口。"])
				chron(p, pv("口角僵记", ["与%s为一件小事争了半夜。", "与%s置了几天气。"]) % nm)
		"心魔":
			if oid == "face" and rng.randf() < 0.6:
				_wu(10)
				out = pv("心魔破", ["她看着它，看到它散了。", "她对它说：“我记得。”它便不再说话。", "她没有躲。天亮时，那团影子薄得像一层雾。"]) + "\n（感悟 +10）"
			elif oid == "face":
				_inj(1)
				out = pv("心魔败", ["它没有散。出关后三日不想说话。", "她败下阵来，吐了一口血，在静室里躺了一日。", "它笑她。她没能还嘴。"])
			else:
				out = pv("心魔诵", ["经诵到第七遍，灯影平了。", "她闭着眼，把姑母教的那段经一字一字念完。", "木鱼敲了一夜，到鸡鸣才停。"])
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
				out = ("她守在镇口，%s闻讯赶来。" % "、".join(hn) if not hn.is_empty() else pv("袭镇守", ["她一个人守在镇口。", "镇口只剩她一个人和一把剑。"])) + pv("袭镇明", ["天亮时，火灭了。", "鸡叫头遍，北边的人退了。"]) + "\n（受伤：闭关炼化减半 3 日）"
				chron(p, "%s带人袭镇，她守在镇口。" % nm)
			else:
				remember(p, n, "小镇那夜的火光", -20)
				out = pv("袭镇躲", ["她背着姑母进了后山。回头时，半边天是红的。", "她拉着姑母钻进后山的石缝，听了一夜的哭喊。"])
				chron(p, "%s血洗小镇那夜，她背着姑母进了后山。" % nm)
			rumor("%s血洗了后山下的小镇。" % nm, [n])
		"秘境":
			var party := []
			for i in ctx.get("party", []):
				party.append(C(i))
			if oid == "out":
				out = pv("秘境守", ["她在外面守了三日，等来的是一身伤的%s。", "她在阵口生了一堆火。第二夜，%s从里面爬了出来。", "她守着阵口，替众人看着退路。出来时，%s朝她点了点头。"]) % _ch(party)["name"]
				chron(p, pv("秘境守记", ["秘境开时，她守在外面。", "替进秘境的人守了三日阵口。"]))
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
					out = pv("秘境推", ["出秘境时，%s在背后推了她一把，险些把她推回塌陷的阵眼。", "分宝时，%s的剑尖抵在了她背心。她把东西让了，自己留下的那半卷残图却没人看得上。", "阵眼塌下来那一刻，%s抢先踩着她的肩跃了出去。"]) % a2["name"] + "\n（残阵里的感悟 +15）"
				else:
					var b2: Dictionary = _ch(party)
					fav(b2, 12, "秘境里一起逃出来", 15)
					out = pv("秘境救", ["秘境塌时，%s拉了她一把。", "她被困在断桥上，是%s折回来接的她。", "%s把最后一枚避水珠塞给了她。"]) % b2["name"] + "\n（感悟 +15）"
				chron(p, pv("秘境记", ["探了秘境。", "进了一回秘境。", "随众人闯了秘境。"]) + out.split("\n")[0])
		"闭关小成":
			_wu(6)
			chron(p, pv("闭关记", ["闭关略有小成。", "在静室坐通了一处关窍。", "周天走顺了，修为又厚了一分。", "炉火边想通了一处火候。"]))
		"访客":
			fav(n, 5)
			chron(p, pv("访客记", ["%s来青庐坐了坐。", "%s来讨了碗茶。", "%s路过，在青庐歇了个脚。", "与%s在檐下说了半日话。", "%s来过，留下半袋新茶。"]) % nm)
		"坊市欺客":
			meet(n)
			R(p, n)["g"] = int(R(p, n)["g"]) + 10
			chron(p, pv("欺客记", ["在坊市吃了%s的亏。", "被%s坑了几块灵石。", "从%s手里买到了假货。"]) % nm)
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
				out = pv("劫给", ["%s掂了掂，让开了路。" % nm, "%s数了两遍，嫌少，到底还是让开了。" % nm])
				chron(p, pv("劫给记", ["被%s拦路，交了买路钱。", "山口遇上%s，破财消灾。"]) % nm)
			elif _roll(pl, float(n["lv"])):
				R(n, p)["g"] = int(R(n, p)["g"]) + 15
				out = pv("劫胜", ["三招过后，%s退进了林子。" % nm, "她一剑削断了%s的刀穗。对方愣了愣，转身就跑。" % nm, "剑光一闪，%s捂着手腕退开：“算你狠。”" % nm])
				chron(p, "被%s拦路，拔剑逼退了%s。" % [nm, ta(n)])
			else:
				_inj(2)
				_ling(-int(ctx.get("cost", 0)))
				R(p, n)["g"] = int(R(p, n)["g"]) + 25
				out = pv("劫败", ["她没打过。灵石被搜走了。", "剑被挑飞，储物袋也被扯了去。", "她退到崖边，只好松手交出灵石。"]) + "\n（受伤：闭关炼化减半 2 日）"
				chron(p, pv("劫败记", ["被%s拦路，没打过。", "在山口吃了%s的亏，灵石被劫。", "夜路上遇见%s，伤了，灵石也没保住。"]) % nm)
		"宗门招徒":
			meet(n)
			if oid == "go":
				out = pv("招徒应", ["她把木牌收进了袖里。", "她说，去试试。%s点了点头，报了个日子。" % nm])
				chron(p, "%s的%s邀她去应%s外门的考核。" % [n["sect"], nm, n["sect"]])
				schedule(rng.randi_range(2, 4), "入门试炼", {"B": int(n["id"])})
			else:
				fav(n, -2)
				out = pv("招徒拒", ["她说，散修也有散修的走法。%s没再劝。" % nm, "她把木牌还了回去。%s看了她一会儿：“可惜了。”" % nm])
				chron(p, "婉谢了%s的招揽。" % n["sect"])
		"入门试炼":
			var sect: String = n["sect"]
			var k4 := int(ctx.get("k", 0)) % 3
			if oid == "all":
				if _roll(pl, 5.0, 6, 4):
					_flag_add("in_sect")
					R(p, n)["t"].append("同门")
					R(n, p)["t"].append("同门")
					_wu(10)
					fav(n, 8)
					out = ["她走到第九百级时，筐里的石头一块没少。执事在名册上添了她的名字。", "幻阵里她看见了姑母，看见了青庐，最后看见了自己。她走了出来。", "第七招，她的剑停在对方喉前一寸。"][k4] + "
她成了%s的外门弟子。（感悟 +10）" % sect
					chron(p, "过了%s的外门考核，挂名为外门弟子。" % sect)
				else:
					_inj(1)
					_wu(4)
					out = ["第六百级上她腿一软，石头滚了一地。", "幻阵里她在青庐门口站了一夜，没能迈出去。", "她输了半招。对方收剑时说：“明年再来。”"][k4] + "
（落选；吃了些苦头：闭关炼化减半 1 日，感悟 +4）"
					chron(p, "去考%s外门，落选了。" % sect)
			else:
				_wu(5)
				remember(n, p, "%s考核时藏了拙" % pn(), 4)
				out = pv("藏拙", ["她只用了七分力，过得不显山不露水。%s在台阶顶上多看了她一眼。" % nm, "她故意慢了半拍。执事挥手让她下去，%s却记住了她的名字。" % nm]) + "
（没挂名，学到了些门道：感悟 +5）"
				chron(p, "去%s应试，藏了三分，没入门。" % sect)
		"秘境请柬":
			meet(n)
			if oid == "go":
				fav(n, 6, "%s肯同我进秘境" % pn(), 6)
				out = pv("请柬应", ["她把玉符收好：“几时走？”", "她回了两个字：“我去。”"])
				chron(p, "应了%s的秘境之约。" % nm)
				schedule(rng.randi_range(2, 4), "秘境", {}, {"inviter": int(n["id"])})
			else:
				fav(n, -3)
				out = pv("请柬拒", ["她说这回不去了。%s没多问。" % nm, "她把玉符还了回去。%s笑了笑：“那下回。”" % nm])
				chron(p, "推辞了%s的秘境之约。" % nm)
		"拍卖会":
			var lot2: String = ctx.get("lot", "那件东西")
			if oid == "raise":
				_ling(-18)
				_wu(14)
				R(n, p)["g"] = int(R(n, p)["g"]) + 12
				out = "她一口叫到十八。满堂静了一静，%s放下了牌子。
（得%s，参悟所得：感悟 +14）" % [nm, lot2]
				chron(p, "在拍卖会上以十八灵石拍下%s，压了%s一头。" % [lot2, nm])
			elif oid == "bid":
				if rng.randf() < (0.55 if tag(n, "贪财") else 0.3):
					out = "她出到十二，%s又加了一手。她没再跟。" % nm
					chron(p, "拍卖会上与%s争%s，没争过。" % [nm, lot2])
				else:
					_ling(-12)
					_wu(10)
					R(n, p)["g"] = int(R(n, p)["g"]) + 5
					out = "十二灵石，落槌。%s回头看了她一眼。
（得%s：感悟 +10）" % [nm, lot2]
					chron(p, "在拍卖会上拍下%s。" % lot2)
			else:
				_wu(2)
				out = pv("拍卖看", ["%s被%s拍走了。她看了一下午，学会了怎么看货。" % [lot2, nm], "她坐在后排看完了一整场，记下了几样东西的行情。"]) + "
（感悟 +2）"
				chron(p, "去拍卖会看了一场，%s归了%s。" % [lot2, nm])
		"劫修伏击":
			meet(n)
			if oid == "fight":
				if _roll(pl, float(n["lv"]) + 2.0, 6, 4):
					_wu(10)
					R(n, p)["g"] = int(R(n, p)["g"]) + 20
					out = pv("伏胜", ["她一剑劈开火把，从缺口里冲了出去。身后%s的骂声追了半里地。" % nm, "三个人倒了两个。%s扶着树退开，没敢再追。" % nm]) + "
（死里逃生：感悟 +10）"
					chron(p, "被%s伏击，杀出了重围。" % nm)
				else:
					_inj(4)
					var lost2 := _ling(-mini(10, lingshi()))
					R(p, n)["g"] = int(R(p, n)["g"]) + 30
					out = "她没冲出去。醒来时躺在路边，储物袋空了，少了 %d 块灵石。
（重伤：闭关炼化减半 4 日）" % -lost2
					chron(p, "被%s伏击，重伤，灵石被劫。" % nm)
			elif oid == "talisman":
				if _roll(pl + 2.0, float(n["lv"]), 5, 4):
					out = pv("伏符", ["符火炸开，林子里一片白。等烟散了，她已经在三里外。", "她撒出去的不是什么好符，但够乱。她钻进了来时的小路。"])
					chron(p, "被%s伏击，撒符脱身。" % nm)
				else:
					_inj(2)
					out = "符烧到一半就灭了。她挨了一刀才脱身。
（受伤：闭关炼化减半 2 日）"
					chron(p, "被%s伏击，带伤脱身。" % nm)
			else:
				var lost3 := _ling(-mini(6, lingshi()))
				R(p, n)["g"] = int(R(p, n)["g"]) + 10
				out = "她把包袱往地上一扔，转身就走。%s没追。（损失 %d 灵石的货）" % [nm, -lost3]
				chron(p, "被%s伏击，弃货保命。" % nm)
		"师弟惹祸":
			var tb2 := "小师妹" if n["sex"] == "女" else "小师弟"
			if oid == "cover":
				var lost4 := _ling(-mini(6, lingshi()))
				fav(n, 15, "%s替我担了事" % pn(), 18)
				out = "她替%s把事了了，花了 %d 块灵石。%s跟在她后头，一路没说话。" % [nm, -lost4, ta(n)]
				chron(p, "替%s%s担了一回事。" % [tb2, nm])
			elif oid == "drag":
				if _roll(pl, 4.0):
					fav(n, 8, "%s押着我去赔了罪" % pn(), 6)
					out = "她押着%s挨家赔了罪。对方看在她的面子上，没再追究。%s回来的路上哭了一场。" % [nm, ta(n)]
					chron(p, "押着%s去赔罪，事情了了。" % nm)
				else:
					_inj(1)
					fav(n, 3)
					out = "对方不认这个面子，动了手。她护着%s退出来，胳膊上挂了彩。
（受伤：闭关炼化减半 1 日）" % nm
					chron(p, "带%s去赔罪，没谈拢，动了手。" % nm)
			else:
				fav(n, -10, "那回%s没管我" % pn(), -8)
				n["inj"] = 8
				_wu(3)
				out = "她说，自己的事自己担。%s愣了很久，转身走了。（感悟 +3）" % nm
				chron(p, "%s惹了祸来找她，她没管。" % nm)
		"天材地宝":
			var it3: String = ctx.get("item", "灵草")
			var wh: String = ctx.get("where", "后山")
			if oid == "no":
				out = pv("宝不去", ["她照旧去灵田浇水。后来听说，那地方打死了两个人。", "她没去。夜里那边亮了一下，又暗了。"])
				chron(p, "听说%s出了%s，没去。" % [wh, it3])
			else:
				var rv = _pick(func(c): return int(c["lv"]) >= plv() - 2 and int(c["lv"]) <= plv() + 5)
				if rv != null and rng.randf() < 0.55:
					out = "她连夜收拾了行囊，往%s去了。" % wh
					schedule(rng.randi_range(1, 2), "宝地相争", {"B": int(rv["id"])}, {"item": it3})
				elif rng.randf() < 0.5:
					_wu(12)
					out = "她在%s找了两天，真找着了。%s入了丹炉。
（感悟 +12）" % [wh, it3]
					chron(p, "在%s寻到%s。" % [wh, it3])
				else:
					out = pv("宝空", ["她在%s转了三天，只找到一圈被人踩烂的土。" % wh, "到了%s，只剩一个坑。有人先来过。" % wh])
					chron(p, "去%s寻%s，扑了个空。" % [wh, it3])
		"宝地相争":
			meet(n)
			var it4: String = ctx.get("item", "灵草")
			if oid == "fight":
				if _roll(pl, float(n["lv"])):
					_wu(15)
					R(n, p)["g"] = int(R(n, p)["g"]) + 15
					remember(n, p, "%s抢了我的%s" % [pn(), it4], -12)
					out = "她抢先一步。%s到手，%s的脸沉了下来。
（感悟 +15）" % [it4, nm]
					chron(p, "与%s争%s，得手。" % [nm, it4])
				else:
					_inj(2)
					out = "%s的剑比她快。%s归了%s。
（受伤：闭关炼化减半 2 日）" % [nm, it4, ta(n)]
					chron(p, "与%s争%s，落败。" % [nm, it4])
			elif oid == "share":
				_wu(8)
				fav(n, 10, "%s肯和我分%s" % [pn(), it4], 10)
				out = "两人把%s一分为二。%s说：“你这人，有点意思。”
（感悟 +8）" % [it4, nm]
				chron(p, "与%s平分了%s。" % [nm, it4])
			else:
				fav(n, 6)
				out = "她收了手。%s道了声谢，倒有几分意外。" % nm
				chron(p, "把%s让给了%s。" % [it4, nm])
		"对手突破":
			if oid == "train":
				_wu(8)
				out = pv("破境练", ["她把门一关，三天没出静室。（感悟 +8）", "她在寒潭边坐到半夜，心里那口气慢慢沉了下去。（感悟 +8）"])
				chron(p, "听说%s破境，回去闭了关。" % nm)
			elif oid == "visit":
				meet(n)
				fav(n, 6, "%s来道过贺" % pn(), 6)
				R(n, p)["g"] = maxi(0, int(R(n, p)["g"]) - 8)
				out = "她提了一坛酒去道贺。%s愣了愣，到底让她进了门。" % nm
				chron(p, "去给%s贺破境。" % nm)
			else:
				_wu(3)
				out = "她笑了笑。道是自己的，快慢也是自己的。（感悟 +3）"
				chron(p, "听说%s破境，没放在心上。" % nm)
		"旧债上门":
			meet(n)
			if oid == "pay":
				var lost5 := _ling(-mini(6, lingshi()))
				fav(n, 5)
				out = "她把 %d 块灵石数给%s。借据当着她的面撕了，扔进了灶膛。" % [-lost5, nm]
				chron(p, "替姑母还了%s一笔旧账。" % nm)
			elif oid == "dan":
				if _roll(pl, 4.0):
					fav(n, 8, "%s炼丹抵了债" % pn(), 6)
					_wu(4)
					out = "她守着丹炉熬了一夜。%s捧着那炉丹，脸色缓了下来：“两清。”（感悟 +4）" % nm
					chron(p, "给%s炼了一炉丹，抵了旧债。" % nm)
				else:
					var lost6 := _ling(-mini(3, lingshi()))
					out = "丹炼糊了。%s捏着鼻子，又要走了 %d 块灵石。" % [nm, -lost6]
					chron(p, "想用丹抵%s的债，炼糊了。" % nm)
			else:
				R(n, p)["g"] = int(R(n, p)["g"]) + 15
				rumor("%s说青庐那个女修赖账。" % nm, [n])
				out = "她说，姑母没提过这事。%s把借据收回去，冷笑一声走了。" % nm
				chron(p, "%s来讨旧债，她没认。" % nm)
		"节令":
			var fest2: String = ctx.get("fest", "中秋")
			if oid == "town":
				var friends := acquaintances().filter(func(c): return c["alive"] and int(R(c, p)["f"]) > 5 and int(R(c, p)["g"]) < 15)
				if not friends.is_empty():
					var f2: Dictionary = friends[rng.randi() % mini(3, friends.size())]
					fav(f2, 5, "%s那天一起过的" % fest2, 5)
					out = pv("节遇", ["人堆里有人拍她的肩，是%s。两人挤在桥头看了半夜。", "她在糖人摊前撞见了%s，买了两个，一人一个。", "%s也来了。两人找了家小铺子，吃到打烊。"]) % f2["name"]
					chron(p, "%s下山，和%s一起过的。" % [fest2, f2["name"]])
				else:
					_wu(2)
					out = "她在人堆里走了一圈，买了包糖炒栗子，一个人吃完了。（感悟 +2）"
					chron(p, "%s下山逛了一圈。" % fest2)
			elif oid == "home":
				_wu(5)
				out = pv("节守", ["她给灵田浇了水，给丹炉添了炭，早早睡了。（感悟 +5）", "她在院里坐着，听山下的鞭炮响到半夜。（感悟 +5）"])
				chron(p, "%s在青庐过的。" % fest2)
			else:
				_ling(-mini(2, lingshi()))
				out = "她托人给姑母捎了一包新茶和两块灵石。回信说，钱留着，茶收了。"
				chron(p, "%s给姑母捎了东西。" % fest2)
		"远方来信":
			if oid == "reply":
				fav(n, 5)
				out = "她回了一封信，写灵田、写丹炉、写院里那棵桂树。写完一看，一个字也没提自己。"
				chron(p, "给远方的%s回了一封信。" % nm)
			else:
				_wu(3)
				out = "她把信折好，夹进了经卷里。（感悟 +3）"
				chron(p, "收到%s的信，没有回。" % nm)
		"喜帖":
			var who3: String = ctx.get("spouse", "")
			if oid == "go":
				_wu(4)
				fav(n, 6, "%s来喝了我的喜酒" % pn() if who3 != "" else "%s来送了我一程" % pn(), 6)
				out = ("她去了，喝了一杯，坐了一刻。%s敬酒到她这桌时，两人都笑了。（感悟 +4）" % nm) if who3 != "" else ("她送%s到渡口。船开出去很远，%s还站在船头。（感悟 +4）" % [nm, ta(n)])
				chron(p, "去喝了%s的喜酒。" % nm if who3 != "" else "去渡口送了%s一程。" % nm)
			elif oid == "gift":
				_ling(-mini(3, lingshi()))
				fav(n, 3)
				out = "她托人送去一对玉扣，没写名字。%s一看就知道是谁送的。" % nm
				chron(p, "托人给%s送了份礼。" % nm)
			else:
				_wu(2)
				out = "那天她在灵田里待了一整日。晚上，山下隐约有锣鼓声。（感悟 +2）"
				chron(p, "%s那天，她没去。" % ("%s成亲" % nm if who3 != "" else "%s远行" % nm))
		"落难":
			meet(n)
			if oid == "help":
				_inj(1)
				fav(n, 30, "落难时%s救了我" % pn(), 30)
				R(n, p)["g"] = 0
				out = pv("落难救", ["她拔剑上前。人散了之后，%s低着头说了一句：“那些话，是我嘴贱。”" % nm, "她把%s扶回青庐，上了药。%s一夜没睡，天亮时留下一句“对不住”就走了。" % [nm, ta(n)]]) + "
（受了点伤：闭关炼化减半 1 日）"
				chron(p, "%s落难，她出了手。旧怨就此了了。" % nm)
				chron(n, "落难时被%s所救。" % pn())
			else:
				_wu(3)
				n["inj"] = 15
				out = "她从旁边走了过去，没回头。夜里想起这事，也说不上痛快。（感悟 +3）"
				chron(p, "见%s落难，没有出手。" % nm)
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
