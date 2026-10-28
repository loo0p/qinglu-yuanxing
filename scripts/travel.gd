extends RefCounted
## v0.11 去处与游历（travel.gd）
## 世界是一张逐步展开的地图：一开始只认得青庐左近（后山、坊市），别处先是“传闻”。
## 解锁不排章节：修为够了、坊市买了舆图、熟人引路、插手过那里的事——哪条先到算哪条（风声只让她“耳闻”）。
## 到了一处地方，每天挑一个小去处游历；碰上谁，看的是眼下真在那里的人（人物按自己的念头在各地走动），
## 再加上几个过路的生面孔。地点只调权重，任何事都不绑死在某处。
## 全部状态是 world.w 里的可选键（unl / uwhy / heard / yl），旧档读入时按进度补齐，存档版本不变。

const TIDS = ["相逢", "引路"]
const HOME = "青庐"
const START = ["后山", "坊市"]
## 地图上的次序（也是“传闻”列表的次序）
const ORDER = ["后山", "坊市", "寒潭", "药王谷", "青云宗", "云梦泽", "玄霜谷", "落霞宫", "万剑门", "古战场", "秘境", "血煞门"]
const WILD = ["后山", "寒潭", "云梦泽", "古战场", "秘境"]
## d 离青庐几日；xy 世界图上的位置；bg 游历时的底图；spots 小去处 [名, 一句景, 出产]；hint 没去过时听来的传闻
const PL = {
	"后山": {"d": 1, "xy": [0.18, 0.78], "bg": "bg_houshan", "route": "houshan", "hint": "青庐背后的山，姑母年轻时常去采药。",
		"spots": [["山涧", "溪水绕石，背阴处长着青芝", "herb"], ["松林", "松针厚软，常有人在此打坐", "wu"], ["断崖", "崖上风大，挂着采药人的旧绳", "ls"]]},
	"坊市": {"d": 1, "xy": [0.80, 0.82], "bg": "bg_fangshi", "hint": "山下的坊市，散修们在那里换灵石、听消息。",
		"spots": [["茶肆", "说书人一拍醒木，满堂都是江湖事", "news"], ["拍卖行", "今日挂出来的东西，件件有来历", "ls"], ["巷尾", "旧货摊挤着旧货摊，什么人都有", "herb"]]},
	"寒潭": {"d": 2, "xy": [0.20, 0.60], "bg": "bg_hantan", "route": "hantan", "hint": "山北有一潭寒水，潭底住着一只老龟。",
		"spots": [["潭边石滩", "寒气扑面，石缝里偶有寒潭莲籽", "herb"], ["雾林", "白雾终日不散，走着走着便没了声音", "wu"], ["瀑下", "水声如雷，有人在瀑下淬体", "ls"]]},
	"药王谷": {"d": 2, "xy": [0.80, 0.60], "bg": "bg_chasi", "hint": "东边有个山谷，满谷药香，据说谷主医术通神。",
		"spots": [["药圃", "一畦一畦的灵草，看园的弟子打着哈欠", "herb"], ["丹房外", "炉火日夜不熄，丹香飘出半里", "wu"], ["谷口医棚", "求医的人排到了路边", "news"]]},
	"青云宗": {"d": 2, "xy": [0.50, 0.45], "bg": "bg_leitai", "hint": "北面云里有座青云宗，山门前九百级石阶。",
		"spots": [["山门", "知客弟子迎来送往，眼睛很尖", "news"], ["演武场", "剑光一道接一道，叫好声不断", "wu"], ["藏经阁外", "阁外的石凳上总有人在抄书", "wu"]]},
	"云梦泽": {"d": 3, "xy": [0.80, 0.37], "bg": "bg_yeyu", "hint": "往东三日，有一片望不到边的芦苇荡，渔人说水下有洞府。",
		"spots": [["芦荡", "芦花齐腰，风一过便是一片白浪", "herb"], ["渔村", "渔人晒着网，说起泽里的怪事", "news"], ["水下洞", "要憋一口长气才潜得下去", "ls"]]},
	"玄霜谷": {"d": 3, "xy": [0.18, 0.33], "bg": "bg_hantan", "hint": "西北有座终年落雪的山谷，谷里的人说话也冷。",
		"spots": [["冰瀑", "整面瀑布冻成了一块玉", "wu"], ["谷口", "守谷的弟子呵着白气", "news"], ["霜林", "树上挂着冰凌，一碰叮当作响", "herb"]]},
	"落霞宫": {"d": 3, "xy": [0.40, 0.26], "bg": "bg_chasi", "hint": "落霞宫建在晚霞里，宫中弟子多半善琴。",
		"spots": [["霞亭", "黄昏时整座亭子都是红的", "wu"], ["琴台", "琴声从台上传下来，听的人都不说话", "wu"], ["宫外集", "卖胭脂的、卖琴弦的挤在一处", "ls"]]},
	"万剑门": {"d": 3, "xy": [0.62, 0.21], "bg": "bg_leitai", "hint": "万剑门的山像一柄倒插的剑，门下弟子个个好斗。",
		"spots": [["试剑台", "台上台下都是剑痕", "wu"], ["剑冢", "插满了主人已不在的剑", "ls"], ["山门", "来挑战的人在门外排着", "news"]]},
	"古战场": {"d": 3, "xy": [0.82, 0.12], "bg": "bg_shandao", "hint": "极北有一处上古战场，断戟埋在土里，夜里有哭声。",
		"spots": [["断戟坡", "锈透的兵刃一直插到天边", "ls"], ["白骨沟", "阴风贴着地走，冷得刺骨", "wu"], ["残碑林", "碑上的字被风沙磨得只剩一半", "news"]]},
	"秘境": {"d": 3, "xy": [0.14, 0.11], "bg": "bg_dongfu", "hint": "有人说西边绝壁上有一道石门，几十年才开一回。",
		"spots": [["石门", "门上的禁制一明一暗", "ls"], ["灵池", "池水泛着淡淡的光", "wu"], ["残经室", "满地都是翻烂的竹简", "herb"]]},
	"血煞门": {"d": 4, "xy": [0.50, 0.07], "bg": "bg_yeyu", "hint": "最北边那座红山是血煞门的地盘，正道的人轻易不去。",
		"spots": [["黑石集", "魔修和亡命徒在这里做买卖", "ls"], ["血池外", "空气里有铁锈味", "wu"], ["山门下", "门口挂着几颗风干的人头", "news"]]},
}
## 解锁的几条路（哪条先到算哪条）：lay 修为到炼气几层；hl [风声条数, 起码几层]；guide 熟人引路；flag 存档旗标；ev 经历过的事
const UNL = {
	"寒潭": {"lay": 2, "hl": [2, 1], "flag": "hantan_visited"},
	"药王谷": {"lay": 4, "hl": [3, 2], "guide": true},
	"青云宗": {"lay": 5, "hl": [3, 2], "guide": true, "ev": ["宗门招徒", "入门试炼"]},
	"云梦泽": {"lay": 5, "hl": [3, 3], "guide": true},
	"玄霜谷": {"lay": 5, "hl": [3, 3], "guide": true},
	"落霞宫": {"lay": 5, "hl": [3, 3], "guide": true},
	"万剑门": {"lay": 5, "hl": [3, 3], "guide": true},
	"古战场": {"lay": 6, "hl": [4, 4], "guide": true},
	"秘境": {"lay": 7, "hl": [4, 4], "ev": ["秘境", "秘境请柬"]},
	"血煞门": {"lay": 8, "hl": [5, 5], "guide": true},
}
const LAYER_CN = ["一", "二", "三", "四", "五", "六", "七", "八", "九"]
## 人在做什么（看他眼下的念头）
const ACT = {
	"破境": ["盘膝坐在青石上，周身灵气一吞一吐", "对着石壁练剑，剑痕已深了半寸", "闭着眼，像在想一道过不去的坎"],
	"复仇": ["在打听一个人的下落，问得很细", "独自磨着一把剑，眼神发冷"],
	"求偶": ["手里攥着一支木簪，站着出神", "在摊前挑一样小玩意，挑了半天没挑定"],
	"求财": ["摆了个小摊，摊上几样灵草、两件旧法器", "正同人讨价还价，为三块灵石争得面红耳赤"],
	"护人": ["扶着一个受伤的同伴歇脚", "四下张望，像在等什么人"],
	"拜师": ["捧着一卷功法翻来覆去地看", "向一位前辈作揖，被人摆手打发了"],
	"报恩": ["揣着一包东西四处打听人", "在问路，说要去还一个人情"],
	"扬名": ["站在空地上扬声要找人比试", "刚赢了一场切磋，正被人围着叫好"],
	"叛门": ["换下了宗门的衣裳，压着斗笠", "把一块腰牌攥在手里，像要扔又没扔"],
	"探秘": ["摊开一张发黄的地图，对着山形比划", "在打听附近哪里有旧洞府"],
	"收徒": ["看几个孩子扎马步，时不时指点一句", "在人群里打量来往的年轻修士"],
	"压人": ["冷着脸听人说起某个对头的近况", "正同人争口舌，谁也不让谁"],
	"交游": ["同几个人坐着说笑", "提着一壶酒，见人便招呼", "正同人打听近来的新鲜事"],
	"疗伤": ["在给自己换药，布条上渗着血", "靠着树调息，脸色发白"],
	"赎过": ["提着礼物在一户人家门外踌躇", "在问一个人的下落，说是要去赔罪"],
	"后事": ["对着远山坐了许久", "把随身的东西一件件分给旁人"],
}
## 小去处的出产 → 偏好碰上什么念头的人（只调权重）
const SPOT_BIAS = {"news": ["交游", "复仇", "探秘", "护人"], "ls": ["求财", "探秘", "扬名"], "wu": ["破境", "拜师", "收徒", "压人"], "herb": ["疗伤", "求财", "探秘"]}

# ---------------------------------------------------------------- 状态
static func ensure(W) -> void:
	if W.w.has("unl"):
		return
	W.w["unl"] = {}
	W.w["uwhy"] = {}
	W.w["heard"] = {}
	for p in START:
		W.w["unl"][p] = 0
		W.w["uwhy"][p] = "青庐左近，从小走熟的地方。"
	# 旧档：从已有的传闻里补记风声，再按进度一次补齐（不弹提示）
	for it in W.w.get("news", []):
		_hear_text(W, String(it[1]))
	check(W, true)

static func unlocked(W, p: String) -> bool:
	ensure(W)
	return p == HOME or W.w["unl"].has(p)

static func places(W) -> Array:
	ensure(W)
	var out := []
	for p in ORDER:
		if W.w["unl"].has(p):
			out.append(p)
	return out

static func locked(W) -> Array:
	ensure(W)
	var out := []
	for p in ORDER:
		if not W.w["unl"].has(p):
			out.append(p)
	return out

static func dist(a: String, b: String) -> int:
	if a == b:
		return 0
	if a == HOME:
		return int(PL.get(b, {"d": 1})["d"])
	if b == HOME:
		return int(PL.get(a, {"d": 1})["d"])
	if not PL.has(a) or not PL.has(b):
		return 1
	return maxi(1, absi(int(PL[a]["d"]) - int(PL[b]["d"])) + (1 if (a in WILD) != (b in WILD) else 0))

static func _layer(W) -> int:
	return W.plv() + 1

static func spots(p: String) -> Array:
	return PL[p]["spots"]

# ---------------------------------------------------------------- 风声与解锁
## 传闻里提到哪个还没去过的地方，就记一笔风声
static func _hear_text(W, text: String) -> void:
	var h: Dictionary = W.w["heard"]
	for p in ORDER:
		if not W.w["unl"].has(p) and text.contains(p):
			h[p] = int(h.get(p, 0)) + 1

static func hear(W, text: String) -> void:
	if not W.w.has("unl"):
		return
	_hear_text(W, text)

static func heard_n(W, p: String) -> int:
	return int(W.w.get("heard", {}).get(p, 0))

## 现在能不能开：返回理由（空串 = 还不能）
static func why(W, p: String) -> String:
	var u: Dictionary = UNL.get(p, {})
	if u.is_empty():
		return ""
	var lay := _layer(W)
	if u.has("flag") and W.g != null and W.g.s["flags"].get(String(u["flag"]), false):
		return "去过一回，认得路了。"
	for e in u.get("ev", []):
		if int(W.w["fired"].get(e, 0)) > 0:
			return "经过那回%s，她知道%s在哪了。" % [e, p]
	if lay >= int(u["lay"]):
		return "修到炼气%s层，%s的路她走得了了。" % [LAYER_CN[mini(8, int(u["lay"]) - 1)], p]
	# v0.12.1：风声只让她“耳闻”（图上一个“？”），听得再多也不等于认得路（Gemini v5 P1#9）。
	# 认得要靠：修为够了、在坊市买一张舆图、熟人引路、或经历过那里的事（请柬、招徒…）
	return ""

## 耳闻：听过风声、还不认得路
static func heard_only(W, p: String) -> bool:
	return not unlocked(W, p) and heard_n(W, p) > 0

## 舆图：坊市里有卖，听过风声、修为也够得上那一带（hl[1]）才买得到；越远越贵
static func map_cost(p: String) -> int:
	return 3 + 3 * int(PL.get(p, {"d": 2})["d"])

static func can_buy_map(W, p: String) -> String:
	var u: Dictionary = UNL.get(p, {})
	if u.is_empty() or unlocked(W, p):
		return "不必"
	if not unlocked(W, "坊市"):
		return "还不认得坊市"
	if heard_n(W, p) < 1:
		return "没听说过那里"
	if _layer(W) < int(u["hl"][1]):
		return "修为还到不了那一带（炼气%s层）" % LAYER_CN[mini(8, int(u["hl"][1]) - 1)]
	if W.g != null and int(W.g.s.get("lingshi", 0)) < map_cost(p):
		return "灵石不够（要 %d）" % map_cost(p)
	return ""

static func buy_map(W, p: String) -> bool:
	if can_buy_map(W, p) != "":
		return false
	W._ling(-map_cost(p))
	unlock(W, p, "在坊市的旧货摊上买了一张去%s的舆图。" % p)
	return true

## 还差什么（给“传闻”卡片看）
static func need(W, p: String) -> String:
	var u: Dictionary = UNL.get(p, {})
	var bits := []
	bits.append("修到炼气%s层" % LAYER_CN[mini(8, int(u.get("lay", 1)) - 1)])
	var hl: Array = u.get("hl", [9, 9])
	bits.append("修到炼气%s层后在坊市买张舆图" % LAYER_CN[mini(8, int(hl[1]) - 1)])
	if u.get("guide", false):
		bits.append("有熟人引路")
	return "或".join(bits)

static func unlock(W, p: String, reason: String, quiet: bool = false) -> void:
	ensure(W)
	if W.w["unl"].has(p) or not PL.has(p):
		return
	W.w["unl"][p] = int(W.w["day"])
	W.w["uwhy"][p] = reason
	if quiet:
		return
	W.chron(W.P(), "知道了去%s的路。" % p)
	if W.g != null:
		W.g.notice("新去处：%s——%s" % [p, reason])
		W.g._log("新去处：%s。%s" % [p, reason])

static func check(W, quiet: bool = false) -> void:
	for p in ORDER:
		if W.w["unl"].has(p):
			continue
		var r := why(W, p)
		if r != "":
			unlock(W, p, r, quiet)

## 插手过的事发生在没去过的地方：顺着这件事，她认得了那里
static func on_meddle(W, pid: int) -> void:
	var pt: Dictionary = W.MD.get_plot(W, pid)
	if pt.is_empty() or int(pt.get("ig", 0)) == 1:
		return
	var pl := String(pt.get("pl", ""))
	if PL.has(pl) and not unlocked(W, pl):
		unlock(W, pl, "管过%s那桩事，顺着线索，她找到了%s。" % [pl, pl])

## 熟人引路：认识的人里，谁的家（或眼下所在）是一处她还没去过的地方
static func _guide_pick(W) -> Array:
	var p: Dictionary = W.P()
	var best := []
	for c in W.npcs():
		if c["player"] or not W.known(c) or int(c["inj"]) > 12:
			continue
		var op: float = W.opinion(c, p)
		if op < 20.0 and not W._close_p(c):
			continue
		for pl in [String(W.SECT_HOME.get(c["sect"], "")), String(c["place"])]:
			# v0.12.1：引路的人得真处得来，也不把修为还够不上那一带的她领过去
			if PL.has(pl) and not unlocked(W, pl) and bool(UNL.get(pl, {}).get("guide", false)) and _layer(W) >= int(UNL[pl]["hl"][1]):
				best.append([c, pl])
				break
	return best

static func daily(W) -> void:
	ensure(W)
	for c in W.npcs():
		move(W, c)
	check(W)
	# 引路：一次只排一件；排了 16 日没碰上就作罢
	var yl: Dictionary = W.w.get("yl", {})
	if not yl.is_empty() and int(W.w["day"]) - int(yl["d"]) > 16:
		yl = {}
	if not yl.is_empty() and unlocked(W, String(yl["pl"])):
		yl = {}
	if yl.is_empty() and W.rng.randf() < 0.1:
		var cs := _guide_pick(W)
		if not cs.is_empty():
			var it: Array = W._ch(cs)
			yl = {"pl": String(it[1]), "b": int(it[0]["id"]), "d": int(W.w["day"])}
			W.AG._queue(W, "引路", {"B": int(it[0]["id"])}, {"pl": String(it[1])})
	W.w["yl"] = yl

# ---------------------------------------------------------------- 人在各地走动
## 按念头去该去的地方：寻仇的追着仇人走，求财的往坊市，探秘的往野地，疗伤的去药王谷……
static func dest(W, c: Dictionary) -> String:
	var home := String(W.SECT_HOME.get(c["sect"], "坊市"))
	var dr: Dictionary = c.get("dr", {})
	var k := String(dr.get("k", ""))
	var t: Dictionary = W.C(dr["t"]) if int(dr.get("t", 0)) > 0 else {}
	if k in ["复仇", "护人", "求偶", "报恩", "赎过", "压人"] and not t.is_empty() and t["alive"]:
		if not t["player"]:
			return String(t["place"])
		var h := String(W.w.get("here", HOME))
		return h if h != HOME else home
	match k:
		"求财", "交游":
			return "坊市" if W.rng.randf() < 0.5 else String(W._ch(WILD.slice(0, 4)))
		"探秘":
			return String(W._ch(WILD))
		"疗伤":
			return "药王谷" if W.rng.randf() < 0.5 else home
		"叛门":
			return String(W._ch(["坊市", "古战场", "云梦泽"]))
		"扬名":
			return String(W._ch(["万剑门", "青云宗", "坊市", home]))
	return home

static func move(W, c: Dictionary) -> void:
	if W.rng.randf() >= 0.12 or int(c["inj"]) > 15:
		return
	var to := dest(W, c) if W.rng.randf() < 0.75 else String(W._ch(ORDER))
	if PL.has(to):
		c["place"] = to

## 眼下在某处的人（她认识的在前）
static func present_at(W, p: String) -> Array:
	var cs := []
	for c in W.npcs():
		if not c["player"] and String(c["place"]) == p:
			cs.append(c)
	cs.sort_custom(func(a, b): return (1 if W.known(a) else 0) > (1 if W.known(b) else 0) or ((1 if W.known(a) else 0) == (1 if W.known(b) else 0) and int(a["id"]) < int(b["id"])))
	return cs

## 她认识的人里，谁在哪（世界图上标“熟人在此”）
static func known_at(W, p: String) -> Array:
	var out := []
	for c in present_at(W, p):
		if W.known(c):
			out.append(c)
	return out

# ---------------------------------------------------------------- 游历的一日
## 先算出产，再看碰不碰得上人。返回 {"text", "items", "ls", "wu"}；物品与灵石由 game_state 记账
static func roam_day(W, p: String, si: int) -> Dictionary:
	ensure(W)
	var sp: Array = spots(p)[clampi(si, 0, spots(p).size() - 1)]
	var out := {"text": "", "items": {}, "ls": 0, "wu": 0}
	var y := String(sp[2])
	var rich := 1 if int(PL[p]["d"]) >= 3 else 0
	match y:
		"herb":
			if W.rng.randf() < 0.65:
				var id := "herb_xugucao" if W.rng.randf() < 0.15 else "herb_qingzhi"
				var n: int = 1 if id == "herb_xugucao" else W.rng.randi_range(1, 2 + rich)
				out["items"][id] = n
				out["text"] = "在%s转了一日，采到%s ×%d。" % [sp[0], "续骨草" if id == "herb_xugucao" else "青芝", n]
		"ls":
			if W.rng.randf() < 0.6:
				out["ls"] = W.rng.randi_range(1, 3 + rich * 2)
				out["text"] = "在%s帮人搭了把手，得了%s块灵石。" % [sp[0], W.cnum(int(out["ls"]))]
		"wu":
			out["wu"] = W.rng.randi_range(2, 4 + rich)
			out["text"] = "在%s静坐半日，心里有些明白了（感悟 +%d）。" % [sp[0], int(out["wu"])]
		"news":
			var lk := locked(W)
			if not lk.is_empty() and W.rng.randf() < 0.6:
				var q: String = W._ch(lk)
				W.w["heard"][q] = heard_n(W, q) + 1
				out["text"] = "在%s听人说起%s：%s" % [sp[0], q, PL[q]["hint"]]
			else:
				out["wu"] = 2
				out["text"] = "在%s听了一日闲话（感悟 +2）。" % sp[0]
	if out["text"] == "":
		out["text"] = "在%s走了一日，%s。" % [sp[0], sp[1]]
	# 碰上人：她这天没被别的事缠住时
	if W.pending().is_empty():
		var day := int(W.w["day"])
		var pr := 0.35 if int(W.w.get("last_ev", -9)) >= day - 1 else 0.72
		if int(W.w.get("last_ev", -9)) >= day - 1 and int(W.w.get("last_ev2", -9)) >= day - 2:
			pr = 0.0
		if W.rng.randf() < pr:
			var c := pick_meet(W, p, y)
			if not c.is_empty():
				W.fire("相逢", {"B": int(c["id"])}, {"pl": p, "sp": String(sp[0])})
	W._save_rng()
	return out

## 挑一个碰上的人：眼下在这里的人为主，偶尔来个过路的生面孔
static func pick_meet(W, p: String, y: String) -> Dictionary:
	var here := present_at(W, p)
	var crowded: bool = W.active_bonds() >= 4
	if here.is_empty() or W.rng.randf() < 0.25:
		var c := passerby(W, p)
		if not c.is_empty():
			return c
	if here.is_empty():
		return {}
	var ws := []
	for c in here:
		var k := String(c.get("dr", {}).get("k", ""))
		var wt := (1.6 if W.known(c) else (0.5 if crowded else 1.0)) * (0.6 + float(c.get("dr", {}).get("u", 0.3)))
		if k in SPOT_BIAS.get(y, []):
			wt *= 1.8
		if int(W.w.get("last_who", {}).get(str(int(c["id"])), -99)) >= int(W.w["day"]) - 3:
			wt *= 0.25
		ws.append(wt)
	return W._wch(here, ws)

## 过路人：新入江湖的（人不多时），或从别处走过来的一个生面孔
static func passerby(W, p: String) -> Dictionary:
	if W.npcs().size() < 30:
		var sect := ""
		for s in W.SECT_HOME:
			if String(W.SECT_HOME[s]) == p:
				sect = s
		var c: Dictionary = W._new_char("", sect, W.rng.randi_range(0, 4))
		c["place"] = p
		W.chron(c, ("初入仙途，拜入%s。" % c["sect"]) if c["sect"] != "散修" else "初入仙途，做了散修。")
		return c
	var cs := []
	for c in W.npcs():
		if not c["player"] and not W.known(c):
			cs.append(c)
	if cs.is_empty():
		return {}
	var c2: Dictionary = W._ch(cs)
	c2["place"] = p
	return c2

## 她自己走上前去（游历页“今日在此”里点一个人）：一天一回
static func approach(W, id: int, p: String, sp: String) -> bool:
	var c: Dictionary = W.C(id)
	if c.is_empty() or not c["alive"] or String(c["place"]) != p or not W.pending().is_empty():
		return false
	if int(W.w.get("appr", -1)) == int(W.w["day"]):
		return false
	W.w["appr"] = int(W.w["day"])
	W.fire("相逢", {"B": id}, {"pl": p, "sp": sp, "me": 1})
	return true

static func can_approach(W) -> bool:
	return int(W.w.get("appr", -1)) != int(W.w["day"])

# ---------------------------------------------------------------- 事件：相逢 / 引路
static func _o(id: String, label: String) -> Array:
	return [id, label]

static func _who(W, n: Dictionary) -> String:
	if W.known(n):
		return String(n["name"])
	# v0.11.1：不写“男修/女修”，生面孔也直接给名字（画像也是这个人的）
	return ("散修%s" if n["sect"] == "散修" else String(n["sect"]) + "的%s") % String(n["name"])

static func present(W, tid: String, roles: Dictionary, ctx: Dictionary) -> Dictionary:
	var n: Dictionary = W.C(roles["B"])
	var pl := String(ctx.get("pl", W.w.get("here", HOME)))
	match tid:
		"引路":
			return {"speaker": int(n["id"]), "text": W.pv("引路式", ["{n}说起{p}：“{h}”又道：“哪日你想去，报我的名字便是。”", "闲谈间{n}提到{p}，“{h}”说着画了一张路线给她。", "{n}笑道：“{p}你还没去过？{h}改日我领你去。”"]).format({"n": n["name"], "p": pl, "h": PL[pl]["hint"]}),
				"opts": [_o("yes", "多谢，记下了"), _o("no", "我这点修为，还是算了")]}
		"相逢":
			var k := String(n.get("dr", {}).get("k", "交游"))
			var act := String(W.pv("相逢:" + k, ACT.get(k, ACT["交游"])))
			var sp := String(ctx.get("sp", pl))
			var f := {"sp": sp, "w": _who(W, n), "a": act}
			var lead: String = "在{sp}，她看见{w}{a}，便走了过去。" if int(ctx.get("me", 0)) == 1 else W.pv("相逢起", ["她到{sp}时，{w}{a}。", "在{sp}，她看见{w}{a}。", "{sp}一带，{w}{a}。"])
			var text := "%s%s。" % [lead.format(f), W._hint(n)]
			var opts := [_o("talk", "上前攀谈")]
			opts.append(_o("ask", "打听风声"))
			if k in ["求财", "交游"] and W.g != null:
				opts.append(_o("trade", "看看手里的东西（4灵石）"))
			elif k in ["扬名", "破境", "压人"] or W.rng.randf() < 0.4:
				opts.append(_o("spar", "讨教几招"))
			elif W.known(n) and W.opinion(n, W.P()) > 5:
				opts.append(_o("join", "结伴走走"))
			opts.append(_o("bye", "点个头走开"))
			return {"speaker": int(n["id"]), "text": text, "opts": opts}
	return {"speaker": 0, "text": "", "opts": [_o("ok", "知道了")]}

static func resolve(W, tid: String, roles: Dictionary, ctx: Dictionary, oid: String) -> String:
	var n: Dictionary = W.C(roles["B"])
	var p: Dictionary = W.P()
	var nm := String(n["name"])
	var pl := String(ctx.get("pl", W.w.get("here", HOME)))
	match tid:
		"引路":
			W.meet(n)
			if oid == "yes":
				W.fav(n, 3, "给她指过去%s的路" % pl, 3)
				unlock(W, pl, "%s给她指了去%s的路。" % [nm, pl])
				return "她把路记在心里。%s的样子，好像已经能看见了。" % pl
			W.w["heard"][pl] = heard_n(W, pl) + 1
			return "%s也不勉强：“那等你哪日想去了再说。”" % nm
		"相逢":
			var first: bool = W.meet(n)
			var k := String(n.get("dr", {}).get("k", "交游"))
			match oid:
				"talk":
					W.fav(n, 3 if first else 2, "在%s同她说过一回话" % pl, 2)
					var t := "%s。" % W.pv("攀谈", ["两人说了好一会儿话", "对方起先有些拘谨，后来话也多了", "一盏茶的工夫，倒像认识了许久"])
					if first:
						t += "对方自称%s。" % nm
					var why := String(n.get("dr", {}).get("why", ""))
					t += "%s说起近来%s%s。" % [W.ta(n) if n["sex"] != "女" else "对方", String(W.AG.DRIVE_WORD.get(k, "四处走动")), ("——" + why) if why != "" and why.length() < 24 and not why.contains(W.pn()) and k in ["复仇", "求偶", "护人", "报恩", "赎过", "叛门", "疗伤", "压人", "破境"] else ""]
					var pid := _reveal_plot(W, n)
					if pid >= 0:
						t += "她听出话里有话：%s" % _plot_line(W, pid)
					var hp := String(W.SECT_HOME.get(n["sect"], ""))
					if PL.has(hp) and not unlocked(W, hp):
						W.w["heard"][hp] = heard_n(W, hp) + 1
					W.chron(p, "在%s同%s攀谈。" % [pl, nm])
					return t
				"ask":
					W.fav(n, 1)
					var lk := locked(W)
					var t2 := ""
					var pid2 := _reveal_plot(W, null)
					if pid2 >= 0:
						t2 = "%s压低声音说：%s" % [nm, _plot_line(W, pid2)]
					elif not lk.is_empty():
						var q: String = W._ch(lk)
						W.w["heard"][q] = heard_n(W, q) + 2
						t2 = "%s说起%s：%s" % [nm, q, PL[q]["hint"]]
					else:
						var ns: Array = W.recent_news(20)
						t2 = ("%s说：“%s”" % [nm, String(ns[-1][1])]) if not ns.is_empty() else "%s摇摇头：近来太平得很。" % nm
					return t2
				"trade":
					if W.lingshi() < 4:
						return "她摸了摸钱袋，只好笑着摆摆手。"
					W._ling(-4)
					var gd: Array = W._ch(W.AG.GOODS)
					W.g.add_item(String(gd[0]), int(gd[1]))
					W.AG._add_ls(n, 4)
					W.fav(n, 2)
					return "她用四块灵石换了%s。%s收了灵石，又多送了一句吉利话。" % [gd[2], nm]
				"spar":
					var win: bool = W._roll(float(W.plv()), float(n["lv"]) * 0.8, 5.0, 5.0)
					if win:
						W._wu(5)
						if W.tag(n, "傲气") or k == "压人":
							W.remember(n, p, "在%s切磋输给了她" % pl, -4, "辱")
							W.R(n, p)["g"] = int(W.R(n, p)["g"]) + 4
							return "几招下来，她占了上风（感悟 +5）。%s收了剑，脸色不大好看。" % nm
						W.fav(n, 4, "在%s同她切磋过，服气" % pl, 3)
						return "几招下来，她占了上风（感悟 +5）。%s抱拳道：“领教了。”" % nm
					W._wu(3)
					W._inj(1)
					W.fav(n, 2, "在%s指点过她几招" % pl, 2)
					return "她被逼得连退几步，手腕发麻（感悟 +3，带了点轻伤）。%s倒没为难她，还指点了两句。" % nm
				"join":
					W.fav(n, 6, "在%s同她结伴走过一程" % pl, 4)
					W._wu(2)
					W.chron(n, "在%s同%s结伴走了一程。" % [pl, W.pn()])
					W.chron(p, "在%s同%s结伴走了一程。" % [pl, nm])
					return "两人一道把%s走了一遍，说的话比路还长（感悟 +2）。" % pl
			return ""
	return ""

## 找一件她还不知道、眼下还能管的谋划（c 为空 = 随便哪件；优先发生在此地的）
static func _reveal_plot(W, c) -> int:
	var here := String(W.w.get("here", HOME))
	var best := -1
	for pt in W.MD.plots(W):
		if int(pt["k"]) != 0 or not W.MD.actable(W, pt):
			continue
		if c != null and int(pt["a"]) != int(c["id"]):
			continue
		best = int(pt["i"])
		if String(pt.get("pl", "")) == here:
			break
	if best >= 0:
		var pt2: Dictionary = W.MD.get_plot(W, best)
		pt2["k"] = 1
		var a: Dictionary = W.C(pt2["a"])
		var b: Dictionary = W.C(pt2["b"]) if int(pt2["b"]) > 0 else {}
		W.rumor(W.MD.leak(W, pt2), [a] if b.is_empty() else [a, b], "谋")
		W.w["news"][-1].append(best)
	return best

static func _plot_line(W, pid: int) -> String:
	var it: Array = W.w["news"][-1]
	return String(it[1]) + "（可在江湖页插手）"
