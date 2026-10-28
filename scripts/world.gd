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
const PLACES = ["青庐", "后山", "寒潭", "坊市", "青云宗", "玄霜谷", "落霞宫", "万剑门", "药王谷", "血煞门", "古战场", "云梦泽", "秘境"]
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
	"朱果之争": [1, 8, false, 99, 0, 10, 1.0], "站队": [1, 10, false, 99, 0, 12, 2.2], "拜师": [1, -4, false, 99, 6, 0, 1.0],
	"师父考验": [1, 0, true, 99, 0, 0, 1.0], "道侣遇险": [2, 20, false, 2, 0, 30, 3.0], "道侣口角": [0, 3, false, 99, 0, 10, 1.0],
	"心魔": [1, -15, false, 99, 0, 15, 4.0], "魔修袭镇": [2, 30, false, 1, 20, 0, 2.0], "秘境": [2, 15, false, 3, 8, 20, 1.5],
	"家书": [0, -2, false, 99, 0, 8, 1.0], "夜雨": [0, -2, false, 99, 0, 8, 1.0], "灵田": [0, -2, false, 99, 0, 8, 1.0],
	"访客": [0, -2, false, 99, 0, 6, 1.0], "坊市欺客": [0, 4, false, 99, 0, 10, 1.0], "师门书信": [0, 4, false, 99, 0, 10, 1.0],
	"义结金兰": [0, -6, false, 99, 0, 6, 1.0], "飞升异象": [0, -2, false, 99, 0, 6, 1.0], "闭关小成": [0, -2, false, 99, 0, 8, 1.0],
	"旧物": [0, -2, false, 99, 0, 8, 1.0], "宗门大比": [0, 1, false, 99, 0, 25, 1.0], "劫修拦路": [1, 8, false, 99, 5, 12, 1.0],
	"暗恋不舍": [1, -4, true, 99, 0, 0, 1.0], "怨偶": [1, 14, true, 99, 0, 0, 1.0], "旧友托梦": [1, 4, true, 99, 0, 0, 1.0],
	"仇家寻上门": [2, 25, true, 99, 0, 0, 1.0], "再问": [2, -8, true, 99, 0, 0, 1.0],
	# v0.7.2：江湖再添几味
	"宗门招徒": [1, 2, false, 2, 6, 20, 1.8], "入门试炼": [1, 6, true, 99, 0, 0, 1.0], "秘境请柬": [1, 4, false, 2, 10, 20, 1.5],
	"拍卖会": [0, 2, false, 99, 8, 18, 1.5], "劫修伏击": [2, 22, false, 2, 12, 25, 2.2], "师弟惹祸": [1, 6, false, 99, 6, 15, 1.1],
	"天材地宝": [1, 6, false, 99, 6, 18, 1.5], "宝地相争": [1, 10, true, 99, 0, 0, 1.0], "对手突破": [0, 4, false, 99, 10, 15, 1.2],
	"旧债上门": [1, 6, false, 99, 6, 18, 1.0], "节令": [0, -4, true, 99, 0, 0, 1.0],
	# 第三拍：对后话也说“不”的人
	"远方来信": [0, -4, true, 99, 0, 0, 1.0], "喜帖": [1, 2, true, 99, 0, 0, 1.0], "落难": [1, 8, true, 99, 0, 0, 1.0],
	# v0.8：信物、两难、暗涌、道途殊归、境界差重逢、故人白首、青庐主场（借庐避祸 / 一念点化）
	"坊市认物": [1, 8, false, 3, 0, 15, 3.0], "两难": [2, 18, false, 1, 18, 0, 2.5], "暗涌": [0, -4, false, 4, 8, 12, 1.4],
	"道途殊归": [2, 6, false, 1, 30, 0, 1.0], "重逢": [0, -2, false, 4, 12, 12, 1.6], "白首": [1, -4, false, 1, 15, 0, 1.6],
	"借庐": [1, 10, false, 2, 10, 25, 1.3], "点化": [0, -3, false, 1, 8, 0, 1.0], "点化回响": [1, -6, true, 99, 0, 0, 1.0],
	# v0.9：人物自己找上门的事（agency.gd 产生；说书人不主动绑角色，只从人物的念头里来）
	"寻仇": [2, 18, true, 99, 0, 0, 1.0], "截道": [1, 10, true, 99, 0, 0, 1.0], "失窃": [0, 4, true, 99, 0, 0, 1.0],
	"示好": [0, -5, true, 99, 0, 0, 1.0], "馈赠": [0, -4, true, 99, 0, 0, 1.0], "结伴": [0, -3, true, 99, 0, 0, 1.0],
	"交易": [0, 0, true, 99, 0, 0, 1.0], "讨债": [0, 5, true, 99, 0, 0, 1.0], "求援": [1, 10, true, 99, 0, 0, 1.0],
	"示警": [1, 6, true, 99, 0, 0, 1.0], "求教": [0, -4, true, 99, 0, 0, 1.0], "还情": [0, -6, true, 99, 0, 0, 1.0],
	"挑战": [1, 6, true, 99, 0, 0, 1.0], "流言": [0, 6, true, 99, 0, 0, 1.0], "叛门": [1, 10, true, 99, 0, 0, 1.0],
	"劝和": [0, -6, true, 99, 0, 0, 1.0], "夺宝": [1, 8, true, 99, 0, 0, 1.0], "邀游": [1, 4, true, 99, 0, 0, 1.0],
	"撞见": [1, 10, true, 99, 0, 0, 1.0],
	# v0.9.1：求药 / 赔罪 / 托付 / 问道
	"求药": [0, 2, true, 99, 0, 0, 1.0], "赔罪": [0, -6, true, 99, 0, 0, 1.0], "托付": [1, -4, true, 99, 0, 0, 1.0], "问道": [0, -5, true, 99, 0, 0, 1.0],
	# v0.10：插手（meddle.gd）——风声是找上门的消息，插手是她从传闻/心事里自己去管
	"风声": [1, 4, true, 99, 0, 0, 1.0], "插手": [1, 2, true, 99, 0, 0, 1.0],
	# v0.11：游历中碰上的人（travel.gd）、熟人引路
	"相逢": [0, 0, true, 999, 0, 0, 1.0], "引路": [0, -3, true, 99, 0, 0, 1.0],
}
## 信物（v0.8）：结下深交时双方各留一件旧物；人没了，东西可能流落坊市
const KEEPSAKES = ["半截断玉簪", "一卷写满批注的旧丹经", "一枚墨麟片", "一只旧铜铃", "一方绣了兰草的帕子", "一枚刻了字的桃木符",
	"半块合璧玉佩", "一支竹笛", "一颗磨圆了的剑穗玉珠", "一只缺了口的小瓷瓶", "一枚褪色的同心结", "一柄只有巴掌长的木剑"]
const MY_KS = ["她亲手编的剑穗", "一只装着青芝籽的小布囊", "外门发的一枚旧腰牌", "一支她削的木簪", "一块青庐桂树下捡的青石", "一张她画的寒潭路书"]
## 人物的记号（v0.8）：由立绘的花钿/痣/疤与喜好派生，出场时带一句，帮着记住人
const SIG_MARK = {"huadian_plum": ["梅花花钿", "眉心点着一朵梅花花钿"], "huadian_flame": ["火焰花钿", "眉心一簇火焰花钿"], "huadian_dots": ["三点花钿", "眉间三点朱砂"],
	"huadian_moon": ["月牙花钿", "眉心一弯红月牙"], "huadian_drop": ["青水滴花钿", "眉心一点青水滴"], "mole_eye": ["泪痣", "眼角一颗泪痣"], "mole_eye2": ["泪痣", "眼下一颗小痣"],
	"mole_lip": ["唇边小痣", "唇边一颗小痣"], "mole_cheek": ["颊上小痣", "颊上一颗小痣"], "demon_slit": ["额上魔纹", "额上一道竖纹"], "demon_veins": ["脸侧黑纹", "脸侧爬着几道黑纹"],
	"demon_crest": ["额上魔纹", "额上一道暗红的纹"], "scar_cheek": ["颊上旧疤", "颊上一道旧疤"], "scar_brow": ["眉骨上的疤", "眉骨上一道疤"], "sect_flame": ["额上火纹", "额上一道火纹"], "scar_nose": ["鼻梁上的疤", "鼻梁上一道疤"]}
const SIG_LIKE = {"桂花糕": ["桂花糕香", "袖里总揣着一包桂花糕"], "古琴": ["那张旧琴", "背上负着一张旧琴"], "好剑": ["新换的剑穗", "剑穗总是新换的"], "丹方": ["一身药香", "身上一股淡淡的药香"],
	"灵茶": ["小茶罐", "腰间挂着一只小茶罐"], "旧书": ["袖口的墨迹", "袖口总沾着墨"], "梅花": ["衣角的梅", "衣角绣着一枝梅"], "烈酒": ["酒葫芦", "腰间挂着一只酒葫芦"],
	"星图": ["望天的习惯", "走着走着总要抬头看天"], "木簪": ["那支木簪", "发间一支旧木簪"]}
const CLOSE_TAGS = ["道侣", "师", "徒", "结义", "亲"]
const FESTIVALS = ["上元", "清明", "端午", "七夕", "中秋", "重阳", "冬至"]
## 历法：第 1 日是正月初一，每月 30 日（与「她的生平」的月份分组一致）。节令按月日落在真实的日子上
## （清明、冬至是节气，这里取农历里大致的日子：三月初五、冬月二十）。
const FEST_DATES = {"上元": [1, 15], "清明": [3, 5], "端午": [5, 5], "七夕": [7, 7], "中秋": [8, 15], "重阳": [9, 9], "冬至": [11, 20]}
const MONTH_NAMES = ["正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "腊月"]

## v0.13：一回合 = 一个月。回合 → [年(0 起), 月(1–12), 日(取 1，兼容旧调用)]；第 0、1 回合都是元年正月
static func cal(day: int) -> Array:
	var d := maxi(day, 1) - 1
	return [d / 12, d % 12 + 1, 1]

const SEASONS = ["春", "春", "春", "夏", "夏", "夏", "秋", "秋", "秋", "冬", "冬", "冬"]
static func season(day: int) -> String:
	return SEASONS[int(cal(day)[1]) - 1]

static func cn_num(n: int) -> String:
	var d := ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
	if n < 10:
		return d[n]
	if n < 20:
		return "十" + ("" if n == 10 else d[n % 10])
	if n < 100:
		return d[n / 10] + "十" + ("" if n % 10 == 0 else d[n % 10])
	if n < 1000:
		var r := n % 100
		return d[n / 100] + "百" + ("" if r == 0 else (("零" + d[r]) if r < 10 else (("一" if r < 20 else "") + cn_num(r))))
	if n < 10000:
		var r2 := n % 1000
		return d[n / 1000] + "千" + ("" if r2 == 0 else (("零" if r2 < 100 else "") + (("一" + cn_num(r2)) if r2 >= 10 and r2 < 20 else cn_num(r2))))
	return str(n)

static func year_name(y: int) -> String:
	return "元年" if y <= 0 else cn_num(y + 1) + "年"

## “青庐元年正月”“青庐三十二年冬月”
static func cal_text(day: int) -> String:
	var c := cal(day)
	return "青庐" + year_name(int(c[0])) + MONTH_NAMES[c[1] - 1]

## 短写：“三十二年冬月”（列表里用）
static func cal_short(day: int) -> String:
	var c := cal(day)
	return year_name(int(c[0])) + MONTH_NAMES[c[1] - 1]

## v0.12.1：给玩家看的叙述里一律用汉字数目（“第七回”“十二块灵石”），按钮上的数值注记（−3 灵石、感悟 +2）照旧用数字
static func cnum(n: int) -> String:
	var d := ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
	if n < 0:
		return "负" + cnum(-n)
	if n < 10:
		return d[n]
	if n < 20:
		return "十" + ("" if n == 10 else d[n % 10])
	if n < 100:
		return d[n / 10] + "十" + ("" if n % 10 == 0 else d[n % 10])
	if n < 1000:
		var r := n % 100
		var t: String = d[n / 100] + "百"
		if r == 0:
			return t
		return t + ("零" + d[r] if r < 10 else cnum(r))
	if n < 10000:
		var r2 := n % 1000
		var t2: String = d[n / 1000] + "千"
		if r2 == 0:
			return t2
		return t2 + ("零" + cnum(r2) if r2 < 100 else cnum(r2))
	return str(n)

static func cn_day(n: int) -> String:
	var d := ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
	if n <= 10:
		return "初" + d[n]
	if n < 20:
		return "十" + d[n - 10]
	if n == 20:
		return "二十"
	if n < 30:
		return "廿" + d[n - 20]
	return "三十"

## 今天（或前两天）是不是某个节令；返回节名，不是返回 ""
## v0.13：按月过以后，七个节一年里占了七个月，太密。改成每年只有一个“今年过的节”
## （按年份和人物种子轮换，几年下来七个节都轮得到），在它那个月、在青庐才会过上
func festival_today() -> String:
	var c := cal(int(w["day"]))
	var f := year_festival(int(c[0]))
	if int(FEST_DATES[f][0]) != int(c[1]):
		return ""
	if w.get("fest_done", {}).has("%d:%s" % [c[0], f]):
		return ""
	return f

func year_festival(y: int) -> String:
	var base := 0
	for c in w["C"].values():
		if c.get("player", false):
			base = int(c.get("pseed", 0))
	return FESTIVALS[posmod(y * 3 + base, FESTIVALS.size())]
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
const HINT = {"温柔": ["{ta}把伞往她这边偏了偏", "{ta}说话时声音放得很轻", "{ta}见她鞋湿了，指了指路边干些的石头"],
	"傲气": ["{ta}只抬了抬眼", "{ta}负手而立，连剑都懒得握", "{ta}报了师门，等她先行礼"],
	"好奇": ["{ta}先问她从哪儿来", "{ta}盯着她腰间的药篓看了半天", "{ta}问她剑穗上的结是怎么打的"],
	"贪财": ["{ta}的目光在她的储物袋上停了一停", "{ta}问她手里的青芝怎么卖", "{ta}袖口露出一角算盘"],
	"多疑": ["{ta}的手一直没离开剑柄", "{ta}隔着三丈就停了步", "{ta}问话前先看了看她身后"],
	"淡泊": ["{ta}让到路边，等她先过", "{ta}手里捏着一枝野花，像是随手折的", "{ta}看了看天色，说要下雨了"],
	"嗜战": ["{ta}上下打量她，像在掂量能接几招", "{ta}剑鞘上全是新磕的印子", "{ta}问她敢不敢过两招"],
	"侠义": ["{ta}提醒她前面有段塌方", "{ta}肩上还背着别人的包袱", "{ta}说前头林子里有劫修，叫她绕着走"],
	"阴狠": ["{ta}笑了笑，笑意没到眼里", "{ta}指甲缝里有洗不净的黑", "{ta}说话时一直看着她的脖子"],
	"痴情": ["{ta}在等一个没来的人", "{ta}手里攥着一封磨毛了边的信", "{ta}看她的眼神，像在认一个旧人"],
	"怯懦": ["{ta}先往后退了半步", "{ta}说话前清了三回嗓子", "{ta}的剑握反了，又悄悄换过来"],
	"圆滑": ["{ta}先报了自家师门，又夸她的剑穗", "{ta}一开口就是三声“道友”", "{ta}递来一块桂花糕，说是顺手买多了"],
	"记仇": ["{ta}记下了她的样子", "{ta}问了她的名字，又问了一遍", "{ta}说起前日有人踩了自家的药圃，眼神发冷"],
	"薄情": ["{ta}看她一眼就移开了", "{ta}连名字也懒得问", "{ta}从她身边过去，像过一棵树"]}

## v0.9 人物自主：性格 × 动机 × 记忆 → 每日行动（见 scripts/agency.gd）
const AG = preload("res://scripts/agency.gd")
const MD = preload("res://scripts/meddle.gd")
const TV = preload("res://scripts/travel.gd")
const Gear = preload("res://scripts/gear.gd")   # v0.14：行囊装备
const SG = preload("res://scripts/saga.gd")   # v0.12：可插拔事件引擎的胶水层（内容在 data/packs）
## 路上也能出的旧模板（其余在家才说得通的：访客、仇人上门、节令……到了路上先压着，回家再说，不丢）
## v0.12.1（Gemini v5 评审）：所有“要处多久 / 隔多久 / 见过几回”的门槛都在这一张表里，
## 时间一格是一“步”（v0.13 起 1 步 = 1 个月，取第二列；原来 1 步 = 1 日时取第一列）。
## 次数类（见过几回、好感多少）两列相同，与时间单位无关。
const UNIT := "month"   # v0.13：回合=月
const PACE := {
	"apology_gap": [10, 12],      # 赔罪：那件事过去多少步，才说得出“当年”
	"friend_n": [3, 5],           # 旧友：一同经历过几件事
	"friend_f": [15, 25],         # 旧友：她对他的好感
	"crush_known": [14, 24],      # 暗涌：相识多少步
	"crush_n": [3, 4],
	"crush_f": [30, 30],
	"romance_known": [30, 36],    # 表白：相识多少步
	"romance_n": [6, 8],
	"romance_f": [55, 65],        # 表白的人对她
	"romance_pf": [30, 50],       # 她对表白的人
	"romance_cd": [20, 24],       # 被拒之后、再问之前至少隔多少步
	"sworn_known": [20, 24],      # 结义
	"sworn_n": [5, 6],
	"debt_elder": [15, 15],       # 旧债上门：债主至少比她年长几岁（替前人讨旧账）
	"grudge_recent": [40, 24],    # 借庐：这么多步之内伤过她，算“前嫌未消”
	"defeat_cd": [30, 36],        # 寻仇 / 挑战落败后，境界没追上之前的冷却
	"hunt_mark": [20, 6],         # 寻凶：打听到的落脚处在世界图上标多久
	"hunt_nag": [25, 12],         # 寻凶：同一个人两条线索之间至少隔多久
	"wealth_decay": [12, 6],      # 露财：多少步后消一半
}

static func pace(k: String) -> int:
	return int(PACE[k][0 if UNIT == "day" else 1])

const ROAD_OK = ["偶遇", "求助", "朱果之争", "劫修拦路", "劫修伏击", "天材地宝", "秘境", "重逢", "宝地相争", "寻凶", "坊市传闻", "旧友死讯", "暗涌", "报恩"]
var w: Dictionary = {}
var g = null
var rng := RandomNumberGenerator.new()
var se_ad = null

## v0.12：事件引擎（懒建；状态在 w["se"]，随存档走）
func saga():
	if se_ad == null:
		se_ad = SG.new(self)
		se_ad.boot()
	return se_ad

# ================================================================ 生成 / 存读
func create(seed_v: int, pname: String, gs = null, n_npc: int = 20) -> void:
	g = gs
	se_ad = null
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
	chron(P(), "十六岁，青云宗外门落选，租下后山脚下的旧洞府青庐，做了散修。")
	for c in npcs():
		c["pre"] = saga().bio(c)   # v0.12 前尘：入局之前的履历（带年岁），也会结下师承、旧情
	# v0.12.1：不再开局指定“命定之人”与一场排好日子的离别（Gemini v5 P0#3）；缘分与生死都从人自己的来往里长出来
	_save_rng()

func attach(gs, d: Dictionary) -> void:
	g = gs
	w = d
	se_ad = null
	rng.seed = int(w.get("rng_seed", 0))
	rng.state = String(w.get("rng", "0")).to_int()
	# v0.12.1：旧档里的故事线（w.arc）照旧读进来，但不再补种、不再免死、不再排离别；队列里剩下的缘分事件过选角门槛才发

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
## 取整成“规范”的浮点：int/10^k 与 JSON 读回的值逐位相同，存读档后行为不变
static func qz(x: float, d: float) -> float:
	return float(roundi(x * d)) / d

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
	return 100 if lv < 9 else (200 if lv < 12 else (500 if lv < 15 else (1000 if lv < 18 else 2000)))

func realm(c: Dictionary) -> String:
	return realm_name(int(c["lv"]))

## 事件对话框上的说话人：认得的写“名字 · 宗门”，不知名的写“宗门 · 境界”——不再写“陌生人”（Gemini v5 P1#10.4）
func speaker_title(ev: Dictionary) -> String:
	var sid := int(ev.get("speaker", 0))
	if sid <= 0:
		return ""
	var c := C(sid)
	if c.is_empty():
		return ""
	if ev.get("anon", false) and String(ev.get("stage", "ask")) == "ask":
		return "%s · %s" % [c["sect"], realm(c)]
	var sub := String(c["sect"]) if String(c["sect"]) != "散修" else realm(c)
	return "%s · %s" % [c["name"], sub]

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

## 道侣（死活不论）：哀悼时用
func partner_any(c: Dictionary) -> Variant:
	for k in c["rel"]:
		if "道侣" in c["rel"][k]["t"]:
			var o := C(int(k))
			if not o.is_empty():
				return o
	return null

## v0.12 前尘：旧档的人没有 pre，第一次看时按种子补写（只成文，不新建关系）
func pre_of(c: Dictionary) -> Array:
	if not c.has("pre") and not c.get("player", false):
		c["pre"] = saga().bio(c, true)
	return c.get("pre", [])

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
	# v0.8：记忆只给 ±25 的加成（以前一次救命 = 好感 +25 再加记忆 +30，一面之缘就跨过结侣门槛）
	var mv := 0.0
	for m in a["mem"]:
		if int(m[1]) == int(o["id"]):
			mv += float(m[3])
	v += clampf(mv, -25.0, 25.0)
	if side(a) != side(o) and side(a) != "中" and side(o) != "中":
		v -= 10
	return v

func remember(c: Dictionary, o, text: String, wt: int, kind: String = "", aid: int = -1) -> void:
	var m := [int(w["day"]), int(o["id"]) if o is Dictionary and not o.is_empty() else 0, text, wt]
	if kind != "":
		m.append(kind)   # v0.9：记忆的种类（救/劫/辱/欠……）与来由动作，可缺省
		m.append(aid)
	c["mem"].append(m)
	if c["mem"].size() > 24:
		var d := int(w["day"])
		c["mem"].sort_custom(func(x, y): return absf(float(x[3])) - (d - float(x[0])) * 0.05 < absf(float(y[3])) - (d - float(y[0])) * 0.05)
		c["mem"].pop_front()

const PLOG_CAP := 300   # v0.14：她自己的履历留得长些（几十年闭关也写进去）；别人仍是 120
func chron(c: Dictionary, text: String) -> void:
	c["log"].append([int(w["day"]), text])
	if c["log"].size() > (PLOG_CAP if c.get("player", false) else 120):
		c["log"].pop_front()

func rumor(text: String, who: Array = [], kind: String = "") -> void:
	var ids := []
	for c in who:
		ids.append(int(c["id"]))
	w["news"].append([int(w["day"]), text, ids, kind])
	TV.hear(self, text)
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
		"alive": true, "asc": false, "inj": 0, "rel": {}, "mem": [], "log": [], "pseed": rng.randi() % 1000000000, "pv": 10, "born": int(w["day"])}
	w["C"][str(id)] = c
	return c

## 立绘：存种子与选项，显示时 Portrait5Lib.roll(seed, opts) 还原（确定性）
## v0.7 新增的立绘部件；旧存档里的人物不抽这些，免得读档后换了张脸
const PV7_NEW := ["hair_f11@base_f", "hair_f12@base_f", "hair_m11@base_m", "robe_f9@base_f", "robe_m9@base_m",
	"acc_f4@base_f", "huadian_moon", "mole_cheek", "huadian_drop"]
func portrait_opts(c: Dictionary) -> Dictionary:
	# v0.8：pv≥9 的人物按“骨龄比”（年纪 / 本境界寿元）显老，过了七成五才白发；金丹修士百岁仍是青年模样。旧人物仍按 75 岁
	var old: bool = float(c["age"]) >= 75.0
	if int(c.get("pv", 0)) >= 9:
		old = float(c["age"]) / float(lifespan(int(c["lv"]))) > 0.75 or int(c.get("frail", 0)) == 1
	var o := {"sex": "f" if c["sex"] == "女" else "m", "elder": old, "demonic": side(c) == "魔"}
	if int(c.get("pv", 0)) < 7:
		o["exclude"] = PV7_NEW
	if int(c.get("pv", 0)) >= 8:
		o["demon_mix"] = true   # v0.7.4 起的新人物：魔门中人不再一律穿同一件黑袍（旧人物不变）
	if int(c.get("pv", 0)) >= 8 and int(c.get("young", 0)) == 1:
		o["no_beard"] = true   # v0.7.7：现生的小师弟/小师妹（14–24 岁）不长胡子；旧人物没有 young 键，脸不变
	if int(c.get("pv", 0)) >= 10:
		o["robe_v"] = 10   # v0.9.3 新人物：可穿新绘的宗门服（剑修/药师/僧衣/蓑衣/甲胄…），按宗门加权；旧人物不变
		o["sect"] = c["sect"]
	if SECT_TINT.has(c["sect"]):
		o["robe_tint"] = SECT_TINT[c["sect"]]
	return o

## v0.12.1 立绘的画时修正（Gemini v5 P2#12）：只改“怎么画”，不改抽签与存档——同一个人每次看都一样，旧档人物也跟着变顺眼
## - 36 岁以下（且非老相）：不用方长脸底模 base_m5、不长胡子（“嗜战”的粗人除外可留短须）
## - 袍色：宗门各有一组色（青云月白/青、药王竹青、万剑玄黑/银、落霞绯、血煞暗红…），散修只取素白、鸦青、赭石、竹青、浅灰这些低饱和色
## - 胸前阴阳鱼补子那件袍（robe_f8）换成同形的素袍 robe_f9：在 Portrait5View.render_spec 里改，主角也算
## 发型（刘海、鬓发）与脸型不动：不新加高额头、不换五官
const SECT_PAL = {
	"青云宗": [[226, 230, 226], [112, 150, 128], [190, 208, 196]],
	"玄霜谷": [[200, 214, 226], [222, 230, 236], [150, 170, 190]],
	"落霞宫": [[196, 128, 136], [214, 168, 170], [168, 104, 116]],
	"万剑门": [[52, 54, 60], [170, 174, 182], [96, 100, 110]],
	"药王谷": [[104, 140, 104], [140, 170, 126], [86, 118, 92]],
	"血煞门": [[110, 34, 36], [80, 28, 30], [132, 52, 50]],
	"阴骨教": [[60, 56, 70], [84, 78, 92], [44, 42, 52]],
	"散修": [[228, 224, 214], [62, 72, 82], [138, 114, 94], [112, 140, 112], [176, 176, 172]],
}
const YOUNG_BASE_TO = ["base_m", "base_m2", "base_m3"]

func portrait_spec(c: Dictionary) -> Dictionary:
	var o := portrait_opts(c)
	var sp: Dictionary = Portrait5Lib.roll(int(c["pseed"]), o)
	return portrait_fix(c, sp, o)

func portrait_fix(c: Dictionary, sp: Dictionary, o: Dictionary = {}) -> Dictionary:
	if o.is_empty():
		o = portrait_opts(c)
	var h := absi(int(c["pseed"]) * 2654435761) % 997
	if not o["elder"] and float(c["age"]) < 36.0:
		if str(sp.get("base")) == "base_m5":
			sp["base"] = YOUNG_BASE_TO[h % YOUNG_BASE_TO.size()]
		if sp.get("beard") != null and (not tag(c, "嗜战") or str(sp["beard"]) == "beard_m5@base_m5"):
			sp["beard"] = null
	var pal: Array = SECT_PAL.get(String(c["sect"]), [])
	if not pal.is_empty():
		sp["robe_tint"] = pal[h % pal.size()]
	return sp

# ================================================================ 主角同步（境界来自青庐的修为）
func plv() -> int:
	if g == null:
		return int(P()["lv"])
	if g.s.get("ending", "") == "zhuji":
		return 9
	return g.plv_now() if g.has_method("plv_now") else g.layer() - 1

func _sync_player() -> void:
	var p := P()
	p["lv"] = plv()
	if g != null:
		p["name"] = String(g.s.get("name", p["name"]))
		if g.has_method("age_m"):
			p["age"] = qz(g.age_m() / 12.0, 10000.0)

func _inj(days: int) -> void:
	if g != null:
		days = Gear.on_injury(g, days)   # v0.14：法衣减伤、护身符挡一回、法宝法衣磨损
		g.s["injured"] = maxi(int(g.s.get("injured", 0)), days)

func _wu(n: int) -> void:
	if g != null:
		g.add_wu(n)
	else:
		P()["xp"] = float(P()["xp"]) + n

func _ling(n: int) -> int:
	if g == null:
		return n
	if n >= 15:
		w["wx"] = int(w["day"])   # 一下进账不少，坊市里有人看见了
	var before := int(g.s.get("lingshi", 0))
	g.s["lingshi"] = maxi(0, before + n)
	return int(g.s["lingshi"]) - before

func lingshi() -> int:
	return int(g.s.get("lingshi", 0)) if g != null else 20

# ================================================================ 世界自转（每日）
## home=false 时（路上）只让世界过日子，说书人不出事件；回家后再说
func tick(home: bool = true, road: bool = true) -> void:
	w["day"] = int(w["day"]) + 1
	_sync_player()
	# v0.9：她在哪（青庐 / 路上的某处）。只用来微调“谁会碰上她”的权重，不挡任何事
	w["here"] = "青庐" if home or (g != null and String(g.s.get("loc", "")) in ["home", "xinmo", "ending"]) else _road_place()
	P()["place"] = w["here"]
	for c in npcs():
		c["age"] = qz(float(c["age"]) + 1.0 / 12.0, 10000.0)   # v0.13：一回合一个月；取整到 4 位：JSON 往返不丢精度
		if int(c["inj"]) > 0:
			c["inj"] = int(c["inj"]) - 1
		c["xp"] = qz(float(c["xp"]) + rng.randf_range(0.6, 1.4) * (0.4 if int(c["inj"]) > 0 else 1.0) * (1.8 if c.has("dh") else 1.0), 10000.0)
		var lv := int(c["lv"])
		if float(c["xp"]) >= 8.0 * pow(1.35, lv):
			c["xp"] = 0.0
			var big: bool = lv in [8, 11, 14, 17]
			if big and rng.randf() < 0.45:
				c["inj"] = 20
				saga().emit("break_fail", c, {"r": REALMS[lv + 1]})   # 冲关失败：文字、心魔都在内容包里
				if c["alive"] and rng.randf() < 0.15:
					die(c, "冲关走火入魔，身死道消")
				continue
			c["lv"] = lv + 1
			saga().emit("break", c, {"big": 1 if big else 0})
		if float(c["age"]) > lifespan(int(c["lv"])) and rng.randf() < (0.06 if int(c.get("frail", 0)) == 1 else 0.02):
			die(c, saga().old_how(c))
			continue
		if int(c["lv"]) >= 18 and rng.randf() < 0.01:
			ascend(c)
			continue
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
		if c["alive"] and rng.randf() < 0.08:
			saga().beat(c)   # v0.12：各人按自己的性子、念头、关系出一件小事（含旧的“独行”）
	if rng.randf() < 0.04 and npcs().size() < NPC_CAP:
		newcomer()
	_generations()
	AG.daily(self)
	TV.daily(self)   # v0.11：人按念头在各地走动；她的去处逐步解锁
	saga().daily()   # v0.12：到期的连锁事件 + 世界级的大比、秘境
	_arc_tick()
	_hunt_tick()
	if (home or road) and w["pending"].is_empty():
		storyteller(home)
	_save_rng()

# ---------------------------------------------------------------- v0.13 世代：生子、收徒、掌门继位、旧人压缩
const NPC_CAP := 36
const BIRTH_P := 0.0025     # 道侣每月生子
const PUPIL_P := 0.0015     # 筑基以上每月收徒
const POP_FLOOR := 25       # 在世的人少于这个数，每半年补人
const HEAD_SECTS := ["青云宗", "玄霜谷", "落霞宫", "万剑门", "药王谷", "血煞门", "阴骨教"]

func _generations() -> void:
	if not w.has("gen"):
		w["gen"] = {"kids": [], "heads": {}, "n_birth": 0, "n_come": 0, "n_pupil": 0, "n_succ": 0, "n_pruned": 0}
	var gen: Dictionary = w["gen"]
	var now := int(w["day"])
	# ① 道侣生子：记进父母履历，十六年（192 月）后入仙途
	var seen := {}
	for c in npcs():
		if c["player"]:
			continue
		var pt = partner(c)
		if pt == null or not pt["alive"] or pt["player"] or seen.has(int(c["id"])):
			continue
		seen[int(pt["id"])] = true
		if float(c["age"]) > lifespan(int(c["lv"])) * 0.8 or float(pt["age"]) > lifespan(int(pt["lv"])) * 0.8:
			continue
		if rng.randf() < BIRTH_P:
			var mo: Dictionary = c if String(c["sex"]) == "女" else pt
			var fa: Dictionary = pt if mo == c else c
			var sx: String = "女" if rng.randf() < 0.5 else "男"
			var nm: String = String(fa["name"]).substr(0, _surn_len(String(fa["name"]))) + _ch(F_GIV if sx == "女" else M_GIV) + (_ch(F_GIV if sx == "女" else M_GIV) if rng.randf() < 0.6 else "")
			gen["kids"].append({"due": now + 192, "name": nm, "sex": sx, "sect": String(_ch([fa, mo])["sect"]), "fa": int(fa["id"]), "mo": int(mo["id"])})
			gen["n_birth"] = int(gen["n_birth"]) + 1
			var kid_t := "%s添了一个%s，取名%s。" % [cal_text(now), "女儿" if sx == "女" else "儿子", nm]
			chron(fa, kid_t)
			chron(mo, kid_t)
			if known(fa) or known(mo):
				rumor("%s与%s添了个%s，名叫%s。" % [fa["name"], mo["name"], "女儿" if sx == "女" else "儿子", nm], [fa, mo], "子")
	# ② 孩子长大，入仙途
	var keep := []
	for k in gen["kids"]:
		if int(k["due"]) > now:
			keep.append(k)
			continue
		if npcs().size() >= NPC_CAP + 4:
			k["due"] = now + 12
			keep.append(k)
			continue
		var sect := String(k["sect"])
		var c := _new_char(String(k["sex"]), sect, 0)
		c["name"] = String(k["name"])
		c["age"] = 16.0
		gen["n_come"] = int(gen["n_come"]) + 1
		var pa := []
		for pid in [int(k["fa"]), int(k["mo"])]:
			var o := C(pid)
			if o.is_empty():
				continue
			pa.append(o)
			R(c, o)["f"] = 60
			R(o, c)["f"] = 60
			R(c, o)["t"].append("亲")
			R(o, c)["t"].append("亲")
		var who := "、".join(pa.map(func(o): return String(o["name"]) + ("（已故）" if not o["alive"] else "")))
		chron(c, ("%s之后。" % who if who != "" else "") + ("十六岁入仙途，拜入%s。" % sect if sect != "散修" else "十六岁入仙途，做了散修。"))
		var pk := false
		for o in pa:
			pk = pk or known(o)
		if pk:
			rumor("%s家的孩子%s长大了，入了仙途。" % [String(pa[0]["name"]), c["name"]], [c] + pa, "子")
	gen["kids"] = keep
	# ③ 收徒：筑基以上，没有在世徒弟的，偶尔收一个新人
	if npcs().size() < NPC_CAP:
		for c in npcs():
			if c["player"] or int(c["lv"]) < 9 or rng.randf() >= PUPIL_P:
				continue
			var has_pupil := false
			for k2 in c["rel"]:
				var o2 := C(int(k2))
				if not o2.is_empty() and o2["alive"] and "徒" in c["rel"][k2]["t"]:
					has_pupil = true
			if has_pupil:
				continue
			var pu := _new_char("", String(c["sect"]), rng.randi_range(0, 2))
			R(c, pu)["t"].append("徒")
			R(pu, c)["t"].append("师")
			R(c, pu)["f"] = 40
			R(pu, c)["f"] = 50
			chron(pu, "初入仙途，拜在%s门下。" % c["name"])
			chron(c, "%s收%s为徒。" % [cal_text(now), pu["name"]])
			gen["n_pupil"] = int(gen["n_pupil"]) + 1
			if known(c):
				rumor("%s收了个徒弟，叫%s。" % [c["name"], pu["name"]], [c, pu], "徒")
			break
	# ④ 掌门：每宗修为最高者；掌门不在了，次月继位
	if true:
		for sect in HEAD_SECTS:
			var hid := int(gen["heads"].get(sect, 0))
			var h := C(hid) if hid > 0 else {}
			if not h.is_empty() and h["alive"] and String(h["sect"]) == sect:
				continue
			var best = null
			for c in npcs():
				if c["player"] or String(c["sect"]) != sect:
					continue
				if best == null or int(c["lv"]) > int(best["lv"]) or (int(c["lv"]) == int(best["lv"]) and float(c["age"]) > float(best["age"])):
					best = c
			if best == null:
				continue
			gen["heads"][sect] = int(best["id"])
			if hid > 0:
				gen["n_succ"] = int(gen["n_succ"]) + 1
				chron(best, "%s继任%s掌门。" % [cal_text(now), sect])
				rumor("%s掌门%s之后，%s继任掌门。" % [sect, ("%s不在了" % h["name"]) if not h.is_empty() else "出缺", best["name"]], [best], "继")
			else:
				chron(best, "为%s掌门。" % sect)
	# ⑤ 旧人压缩：死了 30 年以上、她不认识的，只留名字、宗门、境界和最后几条履历
	if now % 12 == 0:
		for id in _ids(w["C"]):
			var c: Dictionary = w["C"][id]
			if c["alive"] or c["player"] or c.has("pz") or known(c):
				continue
			var dd := int(c["log"][-1][0]) if not c["log"].is_empty() else 0
			if now - dd < 360:
				continue
			c["pz"] = 1
			c["mem"] = []
			c["log"] = c["log"].slice(maxi(0, c["log"].size() - 3))
			var keep_rel := {}
			for k3 in c["rel"]:
				var o3 := C(int(k3))
				if not o3.is_empty() and (o3["alive"] or known(o3)):
					var r3: Dictionary = c["rel"][k3]
					if not r3["t"].is_empty():
						keep_rel[k3] = r3
			c["rel"] = keep_rel
			gen["n_pruned"] = int(gen["n_pruned"]) + 1
	# ⑥ 新人补位（v0.13）：在世的人少于 POP_FLOOR，每半年有两个新人入江湖（拜宗门或做散修），
	#    免得百年之后江湖只剩她一个——生子、收徒太慢，补不上寿尽和横死
	var alive_n := npcs().size()
	#    只在人少时补：开局那几十个月本来就够热闹，按五年定时补会让“连着有事”变长（travel_test ④ 4.4 → 5.0）
	if alive_n < POP_FLOOR and now % 6 == 0:
		var nn := 2
		for _i in nn:
			var sect2: String = _ch(HEAD_SECTS + ["散修", "散修"])
			var nc := _new_char("", sect2, rng.randi_range(0, 3))
			nc["age"] = float(rng.randi_range(16, 24))
			chron(nc, "%s，%s。" % [cal_text(now), ("拜入%s" % sect2) if sect2 != "散修" else "初入江湖，做了散修"])
			gen["n_new"] = int(gen.get("n_new", 0)) + 1

func _surn_len(nm: String) -> int:
	for sn in SURN:
		if String(sn).length() == 2 and nm.begins_with(sn):
			return 2
	return 1

func head_of(sect: String) -> Dictionary:
	var hid := int(w.get("gen", {}).get("heads", {}).get(sect, 0))
	return C(hid) if hid > 0 else {}

func _road_place() -> String:
	if g != null and String(g.s.get("loc", "")) == "roam":
		return String(g.s.get("roam", {}).get("pl", "后山"))
	if g != null:
		var rid := String(g.s.get("trip", {}).get("route", ""))
		if rid != "" and g.routes.has(rid):
			return {"houshan": "后山", "hantan": "寒潭"}.get(rid, String(g.routes[rid].get("place", g.routes[rid]["name"])))
	return "后山" if int(w["day"]) % 2 == 0 else "寒潭"

## 旧的“独行”入口（测试和旧代码可能还在调）：交给内容包的 solo_goal
func solo(c: Dictionary) -> void:
	saga().eng.fire("solo_goal", {"A": c}, {})

## 缘分线上那个人，在表白之前不让江湖把他写死或配给别人（重伤代替身死）
func _protected(c: Dictionary) -> bool:
	return false   # v0.12.1：取消“命定之人”的免死（旧档里的 w.arc.fated 也不再护着）

func die(c: Dictionary, how: String) -> void:
	if _protected(c) and not (pn() in how):
		c["inj"] = 25
		chron(c, "险些丧命，被人从%s抬了回来。" % c["place"])
		return
	c["alive"] = false
	chron(c, how + "。")
	rumor("%s%s。" % [c["name"], how], [c], "死")
	var killer = _killer_of(how)
	var near := {}   # v0.12：道侣、徒弟由内容包写更细的哀悼，这里不再写“三日不语”
	var pt = partner_any(c)
	if pt != null:
		near[int(pt["id"])] = true
	for o in npcs():
		if o.has("dr") and int(o["dr"]["t"]) == int(c["id"]):
			o["rt"] = 1   # v0.9：念头里的那个人没了，重想
		if killer != null and o != killer and o["rel"].has(str(int(c["id"]))):
			var r0: Dictionary = o["rel"][str(int(c["id"]))]
			if "道侣" in r0["t"] or "师" in r0["t"] or "徒" in r0["t"] or "结义" in r0["t"] or int(r0["f"]) > 40:
				remember(o, killer, "%s害了%s" % [killer["name"], c["name"]], -28, "仇")
				R(o, killer)["g"] = int(R(o, killer)["g"]) + 30
				o["rt"] = 1
	for o in w["C"].values():
		if o["alive"] and o["rel"].has(str(int(c["id"]))):
			var r: Dictionary = o["rel"][str(int(c["id"]))]
			if "道侣" in r["t"] or int(r["f"]) > 40:
				remember(o, c, "%s死了" % c["name"], -10)
				if not (near.has(int(o["id"])) or "师" in r["t"]):
					chron(o, "听闻%s%s，三日不语。" % [c["name"], how])
				if not o["player"] and (tag(o, "记仇") or tag(o, "痴情")):
					o["goal"] = "报仇"
	Gear.on_death(self, c)   # v0.14：遗物给道侣 / 徒弟，没人接就落在死处
	saga().emit("death", c, {"how": how})

func ascend(c: Dictionary) -> void:
	c["alive"] = false
	c["asc"] = true
	saga().emit("ascend", c, {})

func newcomer() -> void:
	var c := _new_char("", "", rng.randi_range(0, 3))
	c["pre"] = saga().bio(c)
	saga().emit("newcomer", c, {})

## v0.12：两人相遇。见面计数留在这里，“见面会怎样”交给内容包 qinglu_core 的 on:meet（论道/争宝/斗法/结道侣/收徒/结义/背弃/复仇，每种多个结局）
func world_event(a: Dictionary, b: Dictionary, place: String) -> void:
	var ra := R(a, b)
	var rb := R(b, a)
	ra["m"] = 1
	rb["m"] = 1
	ra["n"] = int(ra.get("n", 0)) + 1
	rb["n"] = int(rb.get("n", 0)) + 1
	saga().meet(a, b, place)

# ================================================================ 说书人
func storyteller(home: bool = true) -> void:
	w["since_major"] = int(w["since_major"]) + 1
	var day := int(w["day"])
	var due := []
	for it in w["queue"]:
		if int(it[0]) <= day and (home or String(it[1]) in ROAD_OK):
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
		if ok and _vetoed(String(it[1]), it[2], it[3]):
			ok = false
		if ok:
			var tid := _arc_adjust(String(it[1]), it[2], it[3])
			if tid != "":
				fire(tid, it[2], it[3])
				return
	if not home:
		_road_teller()
		return
	# 节令：到了日子（当天或之后两天里）在青庐，多半会过上这个节
	if festival_today() != "" and rng.randf() < 0.7:
		fire("节令", {}, {})
		return
	# v0.9：连着两天都有事，第三天歇一歇（路上的事也算在内）
	if int(w.get("last_ev", -9)) >= day - 1 and int(w.get("last_ev2", -9)) >= day - 2:
		return
	# v0.12.1：排好日子的缘分线拿掉后，在家的事少了一成，底数从 0.35 提到 0.40 补回来
	var p_event := 0.40 + int(w["since_major"]) * 0.012
	# 喘口气（v0.7.3）：昨天刚出过事，今天随机事件的机会减半多（故事线、节令不受影响），免得回到青庐天天有人敲门
	if int(w.get("last_ev", -9)) >= day - 1:
		p_event *= 0.45
	if rng.randf() > p_event:
		w["tension"] = maxi(0, int(w["tension"]) - 2)
		return
	# v0.9：先看有没有人自己找上门来（人物的念头），没有再由说书人从模板里挑
	if rng.randf() < 0.5:
		var it2: Array = AG.take(self, false)
		if not it2.is_empty() and not _vetoed(String(it2[1]), it2[2], it2[3]):
			fire(String(it2[1]), it2[2], it2[3])
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
	# v0.8 焦点社交圈：近 30 日来往密切的人已有 4 个时，引来新面孔的事件权重 ×0.15，把熟人的故事往深里推
	var crowded := active_bonds() >= 4
	for tid in T:
		var m: Array = T[tid]
		if m[2] or absi(int(m[0]) - want) > 1 or int(w["fired"].get(tid, 0)) >= int(m[3]) or day < int(m[4]):
			continue
		if w["last"].has(tid) and day - int(w["last"][tid]) < int(m[5]):
			continue
		var roles = bind(tid)
		if roles == null or cast_veto(tid, roles, {}) != "":
			continue
		var wt := weight(tid, roles) * (1.0 if int(m[0]) == want else 0.25)
		if crowded and roles is Dictionary and (roles.has("new") or (roles.has("B") and not known(C(roles["B"])))):
			wt *= 0.15
		if w["last"].has(tid):
			wt *= 1.0 - exp(-(day - int(w["last"][tid])) / 12.0)
		if wt > 0:
			cands.append([tid, roles])
			cws.append(wt)
	if cands.is_empty():
		return
	var pick: Array = _wch(cands, cws)
	fire(pick[0], pick[1], {})

## 选角不成立就作罢，记一笔（w.veto[模板] 次数，给测试与调试看）
func _vetoed(tid: String, roles: Dictionary, ctx: Dictionary) -> bool:
	var why := cast_veto(tid, roles, ctx)
	if why == "":
		return false
	if not w.has("veto"):
		w["veto"] = {}
	w["veto"][tid] = int(w["veto"].get(tid, 0)) + 1
	return true

## 路上：两三站碰上一件事。先看谁惦记着她，再看附近谁按自己的念头会冲着这个过路的女修来，最后才是路上的旧模板
func _road_teller() -> void:
	var day := int(w["day"])
	if int(w.get("last_ev", -9)) >= day - 1:
		return
	if rng.randf() > 0.36:
		return
	var it: Array = AG.take(self, true)
	if it.is_empty() and rng.randf() < 0.6:
		it = AG.crossing(self)
	if not it.is_empty() and _vetoed(String(it[1]), it[2], it[3]):
		it = []
	if not it.is_empty():
		fire(String(it[1]), it[2], it[3])
		return
	var cands := []
	var cws := []
	for tid in ROAD_OK:
		var m: Array = T[tid]
		if m[2] or int(w["fired"].get(tid, 0)) >= int(m[3]) or day < int(m[4]):
			continue
		if w["last"].has(tid) and day - int(w["last"][tid]) < int(m[5]):
			continue
		var roles = bind(tid)
		if roles == null or cast_veto(tid, roles, {}) != "":
			continue
		cands.append([tid, roles])
		cws.append(weight(tid, roles))
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
				schedule(rng.randi_range(3, 5), "暗涌", {"B": int(n["id"])}, {"arc": "romance"})
				return "访客"
			schedule(rng.randi_range(4, 7), "访客", {"B": int(n["id"])}, {"arc": "romance"})
			return "偶遇"
		"访客":
			if int(R(n, p)["g"]) >= 20:
				return ""
			fav(n, 4)
			schedule(rng.randi_range(3, 5), "暗涌", {"B": int(n["id"])}, {"arc": "romance"})   # v0.8：先暗涌，再表白
			return "访客"
		"暗涌":
			if partner(p) != null or partner(n) != null or int(R(n, p)["g"]) >= 20:
				return ""
			return "暗涌"
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
	return   # v0.12.1：不再按日子安排“认识的人被害”；旧友死讯只来自江湖里真发生的死
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
	var killers := npcs().filter(func(c): return c != v and not _close_p(c) and (side(c) == "魔" or tag(c, "阴狠")) and int(c["lv"]) >= int(v["lv"]))
	if killers.is_empty():
		killers = npcs().filter(func(c): return c != v and int(c["id"]) != fated and not _close_p(c) and (side(c) == "魔" or tag(c, "阴狠") or tag(c, "嗜战")))
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
	var meta: Array = T[tid] if T.has(tid) else saga().meta(tid)
	w["tension"] = clampi(int(w["tension"]) + int(meta[1]), 0, 100)
	if int(meta[0]) >= 2:
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

# ---------------------------------------------------------------- v0.8 小工具
## 不新建关系条目地读一眼 a 对 b 的关系
func _rel(a: Dictionary, b: Dictionary) -> Dictionary:
	return a["rel"].get(str(int(b["id"])), {"f": 0, "g": 0, "t": [], "m": 0})

## 与她亲近的人（好感 > 25，或道侣/师/徒/结义）：日常恶意模板（劫修、欺客、争果、截杀……）不拿他们当施害者，
## 除非先有一件专门的事（道途殊归、背弃）把这层关系拿掉
func _close_p(c: Dictionary) -> bool:
	var p := P()
	for t in _rel(p, c)["t"] + _rel(c, p)["t"]:
		if t in CLOSE_TAGS:
			return true
	if not c["rel"].has("1"):
		return false
	return opinion(c, p) > 25.0 or int(_rel(c, p)["f"]) > 25

## 近 30 日有来往、且有些分量的人（焦点社交圈）
func active_bonds() -> int:
	var p := P()
	var d := int(w["day"])
	var n := 0
	for k in _ids(p["rel"]):
		var r: Dictionary = p["rel"][k]
		if int(r["m"]) != 1 or d - int(r.get("d", -99)) > 30:
			continue
		var c := C(k)
		if c.is_empty() or not c["alive"]:
			continue
		var o := _rel(c, p)
		if absi(int(o["f"])) > 15 or int(o["g"]) > 15 or not r["t"].is_empty():
			n += 1
	return n

## 家里的东西（灵田/丹炉产出）：路上只算随身的，在家算仓 + 行囊
func _has(id: String, n: int = 1) -> bool:
	return g != null and g.avail_n(id) >= n

func _use(id: String, n: int = 1) -> bool:
	if not _has(id, n):
		return false
	g.consume(id, n)
	if id == "pill_juqi":
		# 送出去的聚气丹不算在“已炼满 8 颗”的软上限里（与老龟赔罪同一个口径）
		g.s["flags"]["juqi_given"] = int(g.s["flags"].get("juqi_given", 0)) + n
	return true

## 女修用“对方”，免得一句里两个“她”
func _tb(n: Dictionary) -> String:
	return "对方" if n["sex"] == "女" else "他"

## 人物记号 [短语, 整句]：先看立绘上的花钿/痣/疤，没有就用喜好；按人物种子定，不耗世界的随机数
func sig(c: Dictionary) -> Array:
	if c.has("sig"):
		return c["sig"]
	var out: Array = SIG_LIKE.get(c["likes"][0], ["那双眼睛", "眼神很静"])
	var sp: Dictionary = portrait_spec(c)
	if not sp["marks"].is_empty() and SIG_MARK.has(sp["marks"][0]) and (int(c["pseed"]) % 3) != 0:
		out = SIG_MARK[sp["marks"][0]]
	c["sig"] = out
	return out

## 结下深交：交换信物（各一件，一人一生只换一回）；返回一句可接在结果后面的话
func _swap_ks(c: Dictionary) -> String:
	var p := P()
	var mine := R(p, c)
	if mine.has("ks") or not c["alive"]:
		return ""
	var used: Array = w.get("ks_used", [])
	var pool := KEEPSAKES.filter(func(x): return not (x in used))
	if pool.is_empty():
		pool = KEEPSAKES.duplicate()
	var ks: String = _ch(pool)
	used.append(ks)
	w["ks_used"] = used
	var my: String = _ch(MY_KS)
	mine["ks"] = ks
	R(c, p)["ks"] = my
	return pv("换信物", ["\n临别，%s把%s放进她掌心；她回了%s。" % [c["name"], ks, my], "\n%s留下%s，说是信物。她想了想，把%s给了%s。" % [c["name"], ks, my, _tb(c)],
		"\n两人换了信物：她收下%s，%s收下%s。" % [ks, c["name"], my]])

## 返回 roles（{角色: id}）或 null
# ---------------------------------------------------------------- v0.12.1 选角硬前提（Gemini v5 P0#2）
## 她与 c 初识至今多少步（-1 = 没见过；旧档没有 m0 = 早就认识，从第 0 步算）
func met_ago(c: Dictionary) -> int:
	var r := _rel(P(), c)
	if int(r.get("m", 0)) != 1:
		return -1
	return int(w["day"]) - int(r.get("m0", 0))

## c 与她一同经历过几件事（说书人每把 c 写进一件她的事 +1，含初识那件）
func shared_n(c: Dictionary) -> int:
	return int(_rel(c, P()).get("n", 0))

## c 在 within 步之内伤过她（她记着 c 的坏事，或对 c 有怨）；within < 0 = 不限
func hurt_p(c: Dictionary, within: int = -1) -> bool:
	var p := P()
	var cid := int(c["id"])
	for m in p["mem"]:
		if int(m[1]) == cid and float(m[3]) < 0 and (within < 0 or int(w["day"]) - int(m[0]) <= within):
			return true
	return int(_rel(p, c)["g"]) > 0 and within < 0

## c 心里真有一件“对不住她”的事：她记着 c 的坏事、且那件事已过去 apology_gap 步
func wronged_p(c: Dictionary) -> bool:
	var p := P()
	var cid := int(c["id"])
	for m in p["mem"]:
		if int(m[1]) == cid and float(m[3]) < 0 and int(w["day"]) - int(m[0]) >= pace("apology_gap"):
			return true
	return false

## 一起扛过一件有分量的事（救命 / 护人 / 结伴 / 赠重礼 / 照拂……）
func deep_tie(c: Dictionary) -> bool:
	var p := P()
	for m in c["mem"]:
		if int(m[1]) == int(p["id"]) and float(m[3]) >= 8:
			return true
	for m in p["mem"]:
		if int(m[1]) == int(c["id"]) and float(m[3]) >= 8:
			return true
	return false

func romance_ok(c: Dictionary) -> bool:
	var p := P()
	return known(c) and c["sex"] != p["sex"] and partner(c) == null and not c.has("dz") and met_ago(c) >= pace("romance_known") \
		and shared_n(c) >= pace("romance_n") and int(_rel(c, p)["f"]) >= pace("romance_f") and int(_rel(p, c)["f"]) >= pace("romance_pf") \
		and int(_rel(c, p)["g"]) < 15 and deep_tie(c)

func crush_ok(c: Dictionary) -> bool:
	var p := P()
	return known(c) and c["sex"] != p["sex"] and partner(c) == null and not c.has("dz") and met_ago(c) >= pace("crush_known") \
		and shared_n(c) >= pace("crush_n") and int(_rel(c, p)["f"]) >= pace("crush_f") and int(_rel(c, p)["g"]) < 15

func old_friend_ok(c: Dictionary) -> bool:
	var p := P()
	return known(c) and shared_n(c) >= pace("friend_n") and int(_rel(p, c)["f"]) >= pace("friend_f")

## 道侣（或 c）眼下真有险：负了伤、或有人正冲着他去
func in_danger(c: Dictionary) -> String:
	if not c["alive"]:
		return ""
	var hs: Array = AG.hunters_of(self, c)
	if not hs.is_empty():
		return "盯:%d" % int(hs[0]["id"])
	if int(c["inj"]) > 0:
		return "伤"
	return ""

## 侠义之人（性格“侠”> 0.6 或带“侠义”）只对血海深仇下死手（Gemini v5 P1#6）
## 露财：刚得了一笔（wealth_decay 内渐淡），或身上灵石多到藏不住；0..1
func exposed() -> float:
	var x := 0.0
	if w.has("wx"):
		x = clampf(1.0 - float(int(w["day"]) - int(w["wx"])) / float(pace("wealth_decay")), 0.0, 1.0)
	if g != null:
		x = maxf(x, clampf((float(g.s.get("lingshi", 0)) - 80.0) / 200.0, 0.0, 1.0))
	return x

func xia(c: Dictionary) -> bool:
	return tag(c, "侠义") or (not c["player"] and AG.px(c, "侠") > 0.6)

func may_kill(k: Dictionary, v: Dictionary) -> bool:
	if not xia(k):
		return true
	if int(_rel(k, v)["g"]) >= 50:
		return true
	for m in k["mem"]:
		if int(m[1]) == int(v["id"]) and float(m[3]) <= -25:
			return true
	return false

## 寻仇 / 挑战落败：记下败给了谁、那时对方几层；冷却期内、境界没追上，不再一头撞上去
func note_defeat(a: Dictionary, b: Dictionary) -> void:
	if cowed(a, b):
		w["rash"] = int(w.get("rash", 0)) + 1   # 冷却期内、修为没长又去撞——测试盯着这个数为 0
	var bt: Dictionary = a.get("beat", {})
	bt[str(int(b["id"]))] = [int(w["day"]), plv() if b["player"] else int(b["lv"]), int(a["lv"])]
	a["beat"] = bt

func cowed(a: Dictionary, b: Dictionary) -> bool:
	var bt: Dictionary = a.get("beat", {})
	var k := str(int(b["id"]))
	if not bt.has(k):
		return false
	var it: Array = bt[k]
	return int(w["day"]) - int(it[0]) < pace("defeat_cd") and int(a["lv"]) <= int(it[2])

## 寻凶的进度（w.hunt[凶手 id] = {st: 0 打听中 / 1 按住剑等修为 / 2 了结, k: 第几条线索, d: 上回哪步, rd: 已提醒“修为已成”}）
func hunt(cid: int) -> Dictionary:
	if not w.has("hunt"):
		w["hunt"] = {}
	var k := str(cid)
	if not w["hunt"].has(k):
		w["hunt"][k] = {"st": 0, "k": 0, "d": -999}
	return w["hunt"][k]

## 世界图上标着的仇人：{地名: [名字…]}（打听到线索后 hunt_mark 步内，跟着人走）
func hunt_marks() -> Dictionary:
	var out := {}
	for k in w.get("hunt", {}):
		var h: Dictionary = w["hunt"][k]
		var c := C(int(k))
		if c.is_empty() or not c["alive"] or int(h.get("st", 0)) == 2 or int(w["day"]) > int(h.get("mk", -1)):
			continue
		var pl := String(c["place"])
		if not out.has(pl):
			out[pl] = []
		out[pl].append(String(c["name"]))
	return out

func _hunt_tick() -> void:
	for k in w.get("hunt", {}):
		var h: Dictionary = w["hunt"][k]
		var c := C(int(k))
		if c.is_empty() or not c["alive"] or int(h.get("st", 0)) != 1 or int(h.get("rd", 0)) == 1:
			continue
		if plv() >= int(c["lv"]):
			h["rd"] = 1
			schedule(rng.randi_range(1, 3), "寻凶", {"B": int(c["id"])}, {"ready": 1})

## 选角与时机的硬前提：返回不成立的理由（"" = 可以发）。说书人的队列、模板候选、人物自己找上门的事都要过这一关
func cast_veto(tid: String, roles: Dictionary, ctx: Dictionary) -> String:
	var p := P()
	var n: Dictionary = C(roles["B"]) if roles.has("B") else {}
	if n.is_empty():
		return ""
	match tid:
		"吊唁":
			# v0.12 引擎交来的丧事：“{D}走前说过你的好”——得真同{D}处过（Gemini v5 P0#2）
			var dd := C(roles.get("D", -1))
			if dd.is_empty() or met_ago(dd) < 0 or shared_n(dd) < 2:
				return "没同亡者处过"
		"赔罪":
			if met_ago(n) < pace("apology_gap"):
				return "没见过 / 刚认识"
			if not wronged_p(n):
				return "没有那件旧事"
		"旧友死讯":
			if not old_friend_ok(n):
				return "不是旧友"
		"旧债上门":
			if float(n["age"]) < float(p["age"]) + float(pace("debt_elder")) and int(_rel(n, p).get("owe", 0)) <= 0:
				return "债主太年轻、也没借过她东西"
		"讨债":
			if int(_rel(n, p).get("owe", 0)) <= 0:
				return "她没欠"
		"表白", "再问":
			if partner(p) != null or not romance_ok(n):
				return "还没处到那一步"
			if tid == "再问" and int(w["day"]) - int(w["last"].get("表白", -999)) < pace("romance_cd"):
				return "刚拒过"
		"暗涌":
			if partner(p) != null or not crush_ok(n):
				return "还不熟"
		"义结金兰":
			if met_ago(n) < pace("sworn_known") or shared_n(n) < pace("sworn_n"):
				return "还不熟"
		"道侣遇险":
			if partner(p) != n or in_danger(n) == "":
				return "道侣好好的"
		"白首":
			if shared_n(n) < 2:
				return "只见过一面"
		"还情":
			if not known(n):
				return "没见过"
		"仇人上门", "寻仇":
			if cowed(n, p):
				return "上回败了，还没追上"
		"寻凶":
			var h := hunt(int(n["id"]))
			if int(h["st"]) == 2:
				return "已了结"
			if ctx.get("ready", 0) == 1:
				return ""
			if int(h["st"]) == 1 and plv() < int(n["lv"]):
				return "按住了剑，修为还没追上"
			if int(w["day"]) - int(h["d"]) < pace("hunt_nag") or int(h["k"]) >= 3:
				return "刚打听过 / 线索断了"
	return ""

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
			# v0.12.1：慢得多——相识够久、同历够多、彼此好感都高，且一起扛过一件有分量的事（PACE 表）
			return _r1(_pick(func(c): return romance_ok(c)))
		"旧友死讯":
			for c in npcs(false):
				if not c["alive"] and not c["asc"] and old_friend_ok(c) and _flag("mourned:%d" % int(c["id"])) == 0:
					return {"B": int(c["id"])}
			return null
		"坊市传闻":
			return {} if not w["news"].is_empty() else null
		"赠礼":
			return _r1(_pick(func(c): return known(c) and int(R(p, c)["f"]) > 10))
		"朱果之争":
			return _r1(_pick(func(c): return c["place"] in ["后山", "寒潭", "古战场"] and not _close_p(c)))
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
		"道侣遇险":
			var pt0 = partner(p)
			return _r1(pt0) if pt0 != null and in_danger(pt0) != "" else null
		"道侣口角":
			return _r1(partner(p))
		"心魔":
			return {} if int(w["tension"]) > 45 else null
		"魔修袭镇":
			var pl2 := plv()
			return _r1(_pick(func(c): return side(c) == "魔" and int(c["lv"]) >= pl2 + 2 and not _close_p(c) and not xia(c)))
		"秘境":
			return {} if npcs().size() >= 3 else null
		"家书", "夜雨", "灵田", "闭关小成":
			return {}
		"访客":
			return _r1(_pick(func(c): return known(c) and int(R(c, p)["f"]) > 0))
		"坊市欺客":
			return _r1(_pick(func(c): return (tag(c, "贪财") or tag(c, "圆滑")) and not _close_p(c)))
		"师门书信":
			var m = master_of(p)
			return {"B": int(m["id"])} if m != null and m["alive"] else null
		"义结金兰":
			return _r1(_pick(func(c): return known(c) and c["sex"] == p["sex"] and opinion(c, p) > 45 and not ("结义" in R(p, c)["t"]) and met_ago(c) >= pace("sworn_known") and shared_n(c) >= pace("sworn_n")))
		"飞升异象":
			for c in npcs(false):
				if c["asc"] and int(c["log"][-1][0]) > int(w["day"]) - 5 and _flag("asc_seen:%d" % int(c["id"])) == 0:
					return {"B": int(c["id"])}
			return null
		"旧物":
			return _r1(_pick(func(c): return known(c) and int(R(p, c)["f"]) > 20, func(c): return 1.0 + float(R(p, c).has("ks")) * 3.0))
		"宗门大比":
			return _r1(_pick(func(c): return c["sect"] != "散修" and int(c["lv"]) >= 6, func(c): return 1.0 + float(known(c)) * 4.0))
		"劫修拦路":
			return _r1(_pick(func(c): return (side(c) == "魔" or tag(c, "阴狠")) and not _close_p(c) and not xia(c)))
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
			return _r1(_pick(func(c): return side(c) == "魔" and int(c["lv"]) >= pl4 and not _close_p(c) and not xia(c)))
		"师弟惹祸":
			# v0.7.5/v0.7.7：“小师弟/小师妹”只给看着年轻（立绘无胡子、非老者）、比她小或境界比她低的熟人；没有合适的人，fire 时现生一个年轻的
			var c5 = _pick(func(c): return _shidi_ok(c))
			return _r1(c5) if c5 != null else {"new": 1}
		"天材地宝":
			return {}
		"对手突破":
			var pl6 := plv()
			return _r1(_pick(func(c): return known(c) and int(c["lv"]) < 17 and (int(R(c, p)["g"]) >= 10 or int(R(p, c)["g"]) >= 10 or absi(int(c["lv"]) - pl6) <= 2)))
		"旧债上门":
			# v0.12.1：替前人讨旧账的得是长辈（比她大 debt_elder 岁以上），或真借过她东西的人
			return _r1(_pick(func(c): return int(c["lv"]) >= 2 and int(_rel(c, p)["g"]) < 30 and not _close_p(c) and (float(c["age"]) >= float(p["age"]) + float(pace("debt_elder")) or int(_rel(c, p).get("owe", 0)) > 0), func(c): return 1.0 + float(tag(c, "贪财") or tag(c, "圆滑")) * 3.0))
		"节令":
			return {} if festival_today() != "" else null
		"坊市认物":
			for c in npcs(false):
				if not c["alive"] and not c["asc"] and known(c) and _rel(c, p).has("ks") and _flag("ks_seen:%d" % int(c["id"])) == 0:
					return {"B": int(c["id"])}
			return null
		"两难":
			# 两个都待她不薄的人（好感 ≥ 20）结了死仇，先后找上青庐。没有现成的仇，就让她们为一件救命的东西翻脸
			var fr := npcs().filter(func(c): return known(c) and int(_rel(c, p)["f"]) >= 20 and partner(p) != c and not ("道侣" in _rel(c, p)["t"]))
			if fr.size() < 2:
				return null
			for a in fr:
				for b in fr:
					if a != b and int(_rel(a, b)["g"]) >= 25:
						return {"A": int(a["id"]), "B": int(b["id"])}
			return {"A": int(fr[0]["id"]), "B": int(fr[1]["id"]), "made": 1}
		"暗涌":
			if partner(p) != null:
				return null
			return _r1(_pick(func(c): return crush_ok(c) and int(_rel(c, p)["f"]) <= 80))
		"道途殊归":
			var pt = partner(p)
			var cand := []
			if pt != null:
				cand.append(pt)
			for c in npcs():
				if "结义" in _rel(p, c)["t"]:
					cand.append(c)
			cand = cand.filter(func(c): return (tag(c, "淡泊") or tag(c, "薄情") or c["goal"] == "求长生") and int(c["lv"]) >= plv() and int(w["day"]) - int(_rel(p, c).get("bd", 0)) >= 20)
			return _r1(_ch(cand)) if not cand.is_empty() else null
		"重逢":
			var pl7 := plv()
			return _r1(_pick(func(c): return known(c) and _rel(p, c).has("lv0") and int(_rel(p, c)["lv0"][0]) - int(_rel(p, c)["lv0"][1]) >= 3 and pl7 >= int(c["lv"]) and _flag("reunion:%d" % int(c["id"])) == 0))
		"白首":
			return _r1(_pick(func(c): return known(c) and shared_n(c) >= 2 and int(_rel(c, p)["f"]) >= 8 and partner(p) != c and float(c["age"]) / float(lifespan(int(c["lv"]))) >= 0.68))
		"借庐":
			var v = _pick(func(c): return int(c["lv"]) <= plv() + 6 and partner(p) != c and int(_rel(c, p)["g"]) < 15)
			if v == null:
				return null
			var hs := npcs().filter(func(c): return c != v and not _close_p(c) and (int(_rel(c, v)["g"]) >= 25 or (side(c) == "魔" and side(v) != "魔") or (side(v) == "魔" and side(c) == "正")))
			if hs.is_empty():
				return null
			return {"B": int(v["id"]), "H": int(_ch(hs)["id"])}
		"点化":
			return {"new": 1}
	return null

func weight(tid: String, roles: Dictionary) -> float:
	var wt := float(T[tid][6])
	if tid == "求助" and int(C(roles["B"])["inj"]) > 0:
		wt += 3.0
	if tid == "朱果之争" and tag(C(roles["B"]), "贪财"):
		wt += 2.0
	if tid == "两难" and roles.has("made"):
		wt *= 0.5
	return wt

# ================================================================ 玩家看到的事件
func meet(c: Dictionary) -> bool:
	var p := P()
	var r := R(p, c)
	var first := int(r["m"]) == 0
	r["m"] = 1
	R(c, p)["m"] = 1
	if first:
		r["m0"] = int(w["day"])   # v0.12.1：哪一步初识（选角门槛看“相识多久”；旧档没有这个键 = 早就认识）
		r["lv0"] = [int(c["lv"]), plv()]   # v0.8：初见时彼此的境界（日后“昔日仰望，今日平视”）
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

## 能当“小师弟/小师妹”的人：认识、看着年轻（不到 36 岁、不是老者立绘）、比她年纪小或境界比她低
func _shidi_ok(c: Dictionary) -> bool:
	var p := P()
	if not known(c) or partner(p) == c or master_of(p) == c or int(R(c, p)["f"]) < 4:
		return false
	if float(c["age"]) >= 36.0:
		return false
	if not (float(c["age"]) < float(p["age"]) or int(c["lv"]) < plv()):
		return false
	return not looks_old(c)

## 立绘看着老：老者底模或带胡子（v0.7.7：17 岁带山羊胡的人不该被叫“小师弟”）
func looks_old(c: Dictionary) -> bool:
	var o := portrait_opts(c)
	if o["elder"]:
		return true
	return portrait_fix(c, Portrait5Lib.roll(int(c["pseed"]), o), o)["beard"] != null

## 没有合适的熟人时，现生一个年轻、境界不高于她的后辈（早就认识，总喊她“姐姐”）
func _spawn_shidi() -> Dictionary:
	var p := P()
	var pl := plv()
	var sect: String = _ch(SECT_LIST.filter(func(x): return SECTS.get(x, "中") != "魔"))
	var c := _new_char(_ch(["男", "男", "女"]), sect, rng.randi_range(0, maxi(0, pl - 1)))
	c["age"] = float(clampi(int(float(p["age"])) - rng.randi_range(1, 5), 14, 24))
	c["young"] = 1   # v0.7.7：立绘不抽胡子（见 portrait_opts）
	c["place"] = p["place"]
	R(p, c)["m"] = 1   # 早就认识（不记“初识”）
	R(c, p)["m"] = 1
	R(c, p)["f"] = 10
	R(p, c)["f"] = 6
	chron(c, ("初入仙途，拜入%s。" % sect) if sect != "散修" else "初入仙途，做了散修。")
	return c

## 一念点化：柴门外蹲着一个引气三年还没入门的孩子
func _spawn_kid() -> Dictionary:
	var sect: String = _ch(["散修", "散修", "青云宗", "药王谷"])
	var c := _new_char(_ch(["男", "女"]), sect, 0)
	c["age"] = float(rng.randi_range(14, 16))
	c["young"] = 1
	c["place"] = "青庐"
	c["traits"] = ["怯懦", _ch(["痴情", "淡泊", "侠义", "好奇"])]
	chron(c, "引气三年，还没入一层。")
	return c

func fire(tid: String, roles: Dictionary, ctx: Dictionary) -> void:
	# v0.13：一回合一个月，选角到出事可能隔了好几个月，被选的人可能已经长了岁数/破了境——出事时再核一遍，不合就现生一个
	if tid == "师弟惹祸" and (not roles.has("B") or C(roles["B"]).is_empty() or not _shidi_ok(C(roles["B"]))):
		roles = {"B": int(_spawn_shidi()["id"])}
	if tid == "点化" and not roles.has("B"):
		roles = {"B": int(_spawn_kid()["id"])}
	# v0.8：一同经历过的事（n）与最近来往的日子（d）：慢热的门槛、焦点社交圈都看它
	for rk in ["A", "B"]:
		if roles.has(rk):
			var rc := C(roles[rk])
			if not rc.is_empty():
				R(rc, P())["n"] = int(R(rc, P()).get("n", 0)) + 1
				R(P(), rc)["d"] = int(w["day"])
	_log_fire(tid)
	if int(w.get("last_ev", -9)) != int(w["day"]):
		w["last_ev2"] = int(w.get("last_ev", -9))
	w["last_ev"] = int(w["day"])
	if roles.has("B"):
		var lw: Dictionary = w.get("last_who", {})
		lw[str(int(roles["B"]))] = int(w["day"])
		w["last_who"] = lw
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
	# v0.13：选项写着“赶去 / 结伴走 / 进山躲”的，真的要过这些月
	for o in ev.get("opts", []):
		if String(o[0]) == oid:
			for k in AWAY_LABEL:
				if String(o[1]).begins_with(k):
					_away(int(AWAY_LABEL[k]), String(ev["ctx"].get("pl", "")) if ev["ctx"] is Dictionary else "")
					break
	var am := int(w.get("away", {}).get("m", 0))
	if am > 0 and res != "":
		res += "\n（这一去就是 %s 个月）" % cn_num(am)
	if res == "":
		w["pending"] = {}
		_settle_away()
	else:
		ev["stage"] = "result"
		ev["result"] = res
	_save_rng()
	return res

func close() -> void:
	w["pending"] = {}
	_settle_away()

## ---- v0.13 真实耗时（Gemini 评审 P0#5）：事件里说“赶去、躲、护送”的，关掉事件后真的过 N 个月；
## 这段日子她不在静室（不炼化、不出别的家中事件），在外游历的话人跟着到事发的地方
const AWAY_LABEL := {"结伴走一程": 1, "去收殓": 1, "去讨个说法": 1, "去寻": 2, "揣上驱瘴丹进泽": 2,
	"带镇上的老人孩子进山躲": 2, "结伴进去": 3, "去应试": 1, "去碰碰运气": 1, "去喝杯喜酒": 1, "去送一程": 1}
func _away(months: int, pl: String = "") -> void:
	var a: Dictionary = w.get("away", {"m": 0, "pl": ""})
	a["m"] = int(a.get("m", 0)) + months
	if pl != "":
		a["pl"] = pl
	w["away"] = a

func _settle_away() -> void:
	var a: Dictionary = w.get("away", {})
	w.erase("away")
	if a.is_empty() or int(a.get("m", 0)) <= 0:
		return
	if g != null and g.has_method("spend_away"):
		g.spend_away(int(a["m"]), String(a.get("pl", "")))

func _o(id: String, label: String) -> Array:
	return [id, label]

func _hint(n: Dictionary) -> String:
	for t in n["traits"]:
		if HINT.has(t):
			return pv("神态:" + t, HINT[t]).format({"ta": "对方" if n["sex"] == "女" else ta(n)})   # 女修用“对方”，免得一句里两个“她”
	return ("对方" if n["sex"] == "女" else ta(n)) + "点了点头"

## 呈现：{speaker: id(0=旁白), text, opts:[[id,label]]}
func present(tid: String, roles: Dictionary, ctx: Dictionary) -> Dictionary:
	if saga().is_tid(tid):
		return saga().present(tid, roles, ctx)
	if tid in TV.TIDS:
		return TV.present(self, tid, roles, ctx)
	if tid in MD.TIDS:
		return MD.present(self, tid, roles, ctx)
	if tid in AG.TIDS:
		return AG.present(self, tid, roles, ctx)
	var n: Dictionary = C(roles["B"]) if roles.has("B") else {}
	var nm: String = n.get("name", "")
	var ok := [_o("ok", "知道了")]
	match tid:
		"偶遇":
			var where := pv("偶遇地", ["山道上", "溪边石桥上", "坊市口", "雨后的竹林里", "去寒潭的小路上", "茶棚檐下", "镇口的老槐树下", "渡口的石阶上", "古松底下", "落了薄雪的石阶上", "坊市的书摊前"])
			var who: String = TV._who(self, n)
			return {"speaker": int(n["id"]), "text": pv("偶遇式", ["{w}，她遇见{who}，{r}。{h}。", "{w}，迎面来了{who}，看气息是{r}。{h}。", "{w}，有人同她打了个照面：{who}，{r}。{h}。", "她在{w}歇脚，来了{who}，{r}。{h}。"]).format({"w": where, "who": who, "r": realm(n), "h": _hint(n)}),
				"opts": [_o("go", "结伴走一程"), _o("bye", "拱手别过")]}
		"求助":
			var where2 := pv("求助地", ["寒潭边", "青庐柴门外", "后山的山涧里", "坊市后巷", "去镇上的半路"]) if String(w.get("here", "青庐")) == "青庐" else pv("求助路", ["%s的山涧里", "%s路边的草窠里", "%s的一块大石后头", "去%s的半路上"]) % String(w["here"])
			ctx["where"] = where2
			return {"speaker": int(n["id"]), "anon": true, "text": "%s%s，%s的服色，%s%s" % [where2, pv("求助起", ["躺着一个人", "有人倒在草里", "伏着一个人，一动不动", "传来极轻的一声呻吟——是个受了伤的人"]), n["sect"], pv("求助伤", ["胸前一道剑伤还在渗血", "嘴唇发紫，像中了毒", "灵气乱窜，经脉一跳一跳", "一条腿压在落石下", "背上插着半截断箭", "眉心一缕黑气，是挨了魔修的掌", "半边身子结了一层薄霜"]),
				(("。她先认出了%s，才认出人——%%s。" % sig(n)[0]) if known(n) and rng.randf() < 0.5 else (pv("求助认熟", ["。她认得这张脸——%s。", "。凑近了看，是%s。"]) if known(n) else pv("求助认", ["。是%s。", "。那人勉强抬起头：“……%s。”", "。腰牌上刻着名字：%s。"]))) % nm],
				"opts": [_o("help", "渡一口灵气给%s" % ta(n))] + ([_o("pill", "喂一粒自炼的驱瘴丹")] if _has("pill_quzhang") else ([_o("pill", "喂一粒自炼的聚气丹")] if _has("pill_juqi") else [])) + [_o("half", "留下伤药就走"), _o("rob", "搜走储物袋")]}
		"报恩":
			var gift: String = _ch(n["likes"])
			ctx["gift"] = gift
			return {"speaker": int(n["id"]), "text": pv("报恩语", ["“那日%s的事，我记着。”" % ctx.get("where", "寒潭边"), "“欠你的。”%s放下一份%s，没再多说。" % [ta(n), gift], "“路过。”%s在院里坐了半日，走时留下一份%s。" % [ta(n), gift], "“那条命是你捡回来的。”"]),
				"opts": [_o("take", "收下"), _o("tea", "留%s喝碗茶" % ta(n))]}
		"仇人上门":
			# v0.7.6：她从后窗走过的人再找上门，开场换一套（不再一字不差地重来）
			var t_up: String = pv("仇上门", ["“储物袋的账，今日算。”", "柴门被一脚踹开。“还记得我吗？”", "院里的鸡忽然不叫了。%s站在灵田边上，剑已出鞘。" % nm])
			if int(R(n, P()).get("run", 0)) > 0:
				t_up = pv("仇再上门", ["又是%s。这回没踹门，就坐在檐下，等她出来。" % nm, "柴门上那道剑痕旁边，又多了一道。%s在院里：“后窗我也守着。”" % nm, "“躲得了初一。”%s把剑插在灵田埂上，“今日把话说完。”" % nm, "天还没亮，%s已经站在院里了，衣上带着一夜的露水。" % nm])
			return {"speaker": int(n["id"]), "text": t_up,
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
			# v0.12.1：寻凶分几步走（Gemini v5 P1#8）——头一回是线索，再一回是追近，修为追上后是“时候到了”；每步文字不同，地图上标出仇人所在
			var hs := hunt(int(n["id"]))
			var hk3 := int(hs["k"])
			hs["d"] = int(w["day"])
			hs["k"] = hk3 + 1
			hs["mk"] = int(w["day"]) + int(pace("hunt_mark"))
			var fmt := {"n": nm, "p": n["place"], "lv": realm_name(int(n["lv"]))}
			var tx: String
			if ctx.get("ready", 0) == 1:
				tx = pv("寻凶成", ["如今修为已成。{n}还在{p}，她把剑从墙上取了下来。", "她破境那夜想起了{n}。打听来的消息说，人还在{p}。"]).format(fmt)
			elif hk3 == 0:
				tx = pv("寻凶起", ["打听到{n}在{p}落脚，{lv}。丹炉底下刻着的那个名字，有了下落。", "有人在{p}见过{n}。她把剑擦了一夜。"]).format(fmt)
			elif hk3 == 1:
				tx = pv("寻凶近", ["又有{n}的消息：还在{p}，身边多了两个人。", "{p}来的行脚僧说，{n}近来常在那一带出没，修为又深了些。"]).format(fmt)
			else:
				tx = pv("寻凶终", ["{n}的消息又来了一回，还是{p}。她知道，这件事拖不下去了。", "这是第三回听到{n}在{p}。她把那只小包袱又收拾了一遍。"]).format(fmt)
			return {"speaker": 0, "text": tx,
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
			# v0.8：传闻里有她认识的人，就给一个能伸手的地方（随礼、送药、记下仇人的落脚处、去坟前上香）
			var hk := []
			var kind: String = String(it[3]) if it.size() > 3 else ""
			var tgt := {}
			for i in it[2]:
				var tc := C(i)
				if not tc.is_empty() and known(tc):
					if kind == "伤" and int(i) != int(it[2][-1]):
						continue   # 斗法传闻：ids 是 [胜者, 败者]，伸手的对象是败者
					tgt = tc
					break
			if not tgt.is_empty():
				ctx["nid"] = int(tgt["id"])
				ctx["nk"] = kind
				var tr2 := _rel(P(), tgt)
				match kind:
					"侣":
						if tgt["alive"] and int(tr2["g"]) < 15:
							hk.append(_o("gift", "送两株自家青芝去随礼") if _has("herb_qingzhi", 2) else _o("gift", "托人随一份贺礼（2 灵石）"))
					"伤":
						if tgt["alive"] and int(tr2["g"]) >= 30:
							hk.append(_o("mark", "记下%s养伤的落脚处" % tgt["name"]))
						elif tgt["alive"] and int(_rel(tgt, P())["f"]) >= 0:
							hk.append(_o("med", "托人捎一粒驱瘴丹去") if _has("pill_quzhang") else _o("med", "托人捎些伤药（2 灵石）"))
					"破":
						if tgt["alive"] and int(tr2["g"]) < 15:
							hk.append(_o("congrat", "托人带一句贺喜"))
					"死":
						if not tgt["alive"] and _flag("mourned:%d" % int(tgt["id"])) == 0:
							hk.append(_o("incense", "去%s坟前上一炷香" % tgt["name"]))
			return {"speaker": 0, "text": pv("传闻", ["坊市茶摊上听人说：%s", "说书先生今天讲的是：%s", "药铺伙计压低声音告诉她：%s", "过路的散修提了一句：%s", "家书末尾添了一句：%s", "排队买盐时，前头两个女修在嚼舌根：%s", "渡口的船夫一边撑篙一边说：%s"]) % ctx["news"],
				"opts": (hk + [_o("ok", "听过就算")]) if not hk.is_empty() else ok}
		"赠礼":
			var gs := _sample(LIKES, 3)
			return {"speaker": 0, "text": pv("赠起", ["去坊市换盐时，她想起%s。摊上有几样东西，带一样去？", "听说%s近来闭关，她想托人捎点东西去。", "坊市新到了一批货。%s会喜欢哪一样？", "她在货摊前站了很久，想着%s。"]) % nm,
				"opts": [_o("g:" + gs[0], gs[0]), _o("g:" + gs[1], gs[1]), _o("g:" + gs[2], gs[2])] + ([_o("qz", "自家灵田的青芝（2 株）")] if _has("herb_qingzhi", 2) else [])}
		"朱果之争":
			return {"speaker": int(n["id"]), "text": "%s%s" % [pv("朱果起", ["%s崖上的朱果熟了，正要伸手，%s也到了。", "%s石缝里那株朱果红透了。她刚拨开藤蔓，身后有人落了地——%s。", "%s的朱果香飘了半里。她赶到时，%s已经站在崖边。"]) % [n["place"], nm], pv("朱果话", ["“先到不算先得。”", "“这果子，我盯了三个月。”", "“让给我，我记你一个人情。”"])],
				"opts": [_o("give", "让给%s" % ta(n)), _o("fight", "各凭本事")]}
		"站队":
			var a := C(roles["A"])
			var b := C(roles["B"])
			_flag_add("side:" + _pair(a, b))
			return {"speaker": 0, "text": pv("站队起", ["她撞见%s与%s对峙。", "%s和%s在坊市后巷拔了剑。", "林子里，%s在骂%s，话很难听。", "%s堵住了%s的去路。", "山道上，%s的剑尖抵着%s的喉咙，谁也没先动。", "茶肆里杯子摔了一地，%s揪住了%s的衣领。"]) % [a["name"], b["name"]],
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
			# v0.12.1：只在道侣真受了伤、或真有人冲着他去时才来（Gemini v5 P0#3）
			var dg := in_danger(n)
			ctx["why"] = dg
			ctx["pl"] = String(n["place"])
			var hn := ""
			if dg.begins_with("盯:"):
				hn = String(C(int(dg.trim_prefix("盯:")))["name"])
			var t_dg: String
			if hn != "":
				t_dg = pv("遇险盯", ["%s捎信来，只一行字：%s追到%s了。信纸上有血。" % [nm, hn, n["place"]], "%s的命灯忽明忽暗。坊市里有人说，%s在%s堵住了%s。" % [nm, hn, n["place"], _tb(n)]])
			else:
				t_dg = pv("遇险伤", ["%s在%s受了伤，托人捎信来，字歪歪扭扭：“不要紧。”" % [nm, n["place"]], "%s的命灯暗了一截。听说%s在%s伤得不轻，躲着养伤。" % [nm, _tb(n), n["place"]]])
			return {"speaker": 0, "text": t_dg,
				"opts": [_o("go", "去寻")] + ([_o("pill", "揣上驱瘴丹去")] if _has("pill_quzhang") else []) + [_o("wait", "等消息")]}
		"道侣口角":
			var op := opinion(n, P())
			ctx["good"] = op >= 30
			return {"speaker": int(n["id"]), "text": pv("口角", ["“你又熬夜守炉子。”", "“说好一起去坊市的。”", "“那人送你的东西，你还留着？”", "“出门也不说一声，我找了你半座山。”", "“你的伤还没好，又要去寒潭？”"]),
				"opts": [_o("soft", "先服个软"), _o("hard", "不肯让")]}
		"心魔":
			var bad: Array = P()["mem"].filter(func(m): return int(m[3]) < 0)
			var m: Array = _ch(bad) if not bad.is_empty() else [0, 0, "那盏灯", 0]
			return {"speaker": 0, "text": pv("心魔起", ["闭关时心魔起，幻出的是：%s。", "夜半入定，眼前又是%s。", "灯影里浮出旧事——%s。", "周天走到一半，丹田一冷。耳边有人低声说起%s。", "她睁眼，静室还是静室。可墙上的影子在演%s。"]) % m[2],
				"opts": [_o("face", "直视它"), _o("chant", "闭目诵经")]}
		"魔修袭镇":
			return {"speaker": int(n["id"]), "text": "%s的人从北边下来了，山下小镇起了火。%s" % [n["sect"], pv("袭镇", ["钟声敲到第三下就断了。", "镇东头住着几户她从小认得的人家。", "风里全是焦味。"])],
				"opts": [_o("guard", "护着镇口"), _o("hide", "带镇上的老人孩子进山躲")]}
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
		"家书":
			# v0.13：家在山下桃溪镇；四十年后爹娘不在了，来信的是镇上的后辈
			if int(w["day"]) < 480:
				return {"speaker": 0, "text": pv("家书", ["娘来信，说镇上的桂花开了，问她吃饭没有。", "家里托人捎来一罐腌菜，罐底压着十个铜板。", "爹来信，只写了“冷了加衣”四个字。", "娘说隔壁王婶的孙子会走路了，又问她何时回。", "家书被雨打湿了一半，剩下那半是叮嘱。", "娘信里说梦见她小时候爬树，摔了也不哭。"]), "opts": ok}
			return {"speaker": 0, "text": pv("家书后", ["桃溪镇来了封信，是侄孙写的，字歪歪扭扭，说老宅的桂树还在。", "镇上的后辈来信，问祖上那位修仙的姑奶奶还记不记得家。", "桃溪镇的祠堂翻修，来信请她题一块匾。", "来信的人她不认得，信里说：家里人都记得您。"]), "opts": ok}
		"夜雨":
			var ks := []
			for k in _ids(P()["rel"]):
				if int(P()["rel"][k]["m"]) == 1:
					ks.append(C(k)["name"])
			if ks.is_empty():
				ks = ["桃溪镇的爹娘"]
			return {"speaker": 0, "text": pv("夜雨", ["檐下滴了一夜的水。她数着数着，想到了%s。", "夜雨敲窗。她想起%s。", "灯花爆了一下。她没来由地想起%s。", "山里起雾，像那年和%s走过的那段路。", "听见檐下风铃响，以为是%s来了。", "梦见%s站在桂树下，醒来记不清说了什么。"]) % _ch(ks), "opts": ok}
		"灵田":
			return {"speaker": 0, "text": pv("灵田", ["田垄上落了一只白鹭，站了半个时辰才走。", "灵田里冒了一株不认识的苗。", "鸟啄了半垄青芝。", "今年的青芝结得密。", "夜里下了霜，她给灵田盖了草帘。", "田埂边的野兔又来了，她没赶它。", "引水的竹管裂了，修了一下午。"]), "opts": ok}
		"访客":
			var tails: Dictionary = {"好奇": ["问了很多丹炉的事。", "翻她的药篓，一样一样问名字。"], "淡泊": ["喝完就走了。", "坐在檐下看了半日云，走时道了声叨扰。"], "傲气": ["嫌她的茶淡。", "指点了她两句剑法，也不管她要不要听。"],
				"温柔": ["走前替她把晾的衣裳收了。", "见她袖口磨破了，留下一卷针线。"], "贪财": ["眼睛在灵田上转了好几圈。", "问她丹炉卖不卖。"], "侠义": ["顺手把塌了的篱笆扶正了。", "说山下有户人家病了，问她讨了两包药。"],
				"痴情": ["说起一个人，说了一半又停了。", "看着院里的桂树出神，茶凉了也没喝。"], "多疑": ["坐下前先看了看四下。", "茶端到嘴边，又放下，先看她喝。"], "嗜战": ["非要同她比划两招才肯走。", "说起前日一场斗法，比划得茶碗都翻了。"],
				"阴狠": ["笑着夸她的灵田长得好。", "问起她家里还有什么人。"], "怯懦": ["说话声音很轻，喝完茶就告辞了。", "连声道谢，走到柴门口又回来道了一遍。"], "圆滑": ["把坊市的新鲜事讲了个遍。", "走时留下一张名帖，说有事尽管找。"],
				"记仇": ["说起一个旧仇人，咬着牙笑。", "临走前问她，这些日子可有生人从山道上过。"], "薄情": ["喝了半碗就走了。", "话没说几句，起身就走，也没回头。"]}
			var tail: String = pv("访客尾:" + String(n["traits"][0]), tails[n["traits"][0]]) if tails.has(n["traits"][0]) else pv("访客尾", ["坐了一刻。", "看了一会儿她的灵田。", "临走前替她添了灶里的柴。"])
			var vpre := ""
			if int(R(n, P()).get("n", 0)) >= 2 and rng.randf() < 0.4:
				vpre = pv("访客记号", ["隔着篱笆，她先看见%s。", "还没进门，先认出了%s。", "柴门外是熟悉的%s。"]) % sig(n)[0]
			return {"speaker": int(n["id"]), "text": vpre + pv("访客", ["%s路过青庐，讨了一碗茶，", "%s顺路来看她，带了半袋新茶，", "%s在柴门外喊了她一声，进来坐了坐，", "%s来借丹炉，还的时候擦得锃亮，", "%s冒着雨来了，在灶边烘了半天手，", "%s捎来坊市的一包桂花糖，坐在檐下，"]) % nm + tail, "opts": ok}
		"坊市欺客":
			return {"speaker": 0, "text": pv("欺客", ["%s卖她一株灵草，回来才发现是染了色的。", "在%s的摊上买了张符，一用就碎了。", "%s称灵米的秤，少了三两。", "%s卖的“百年参”，根须是粘上去的。", "%s说那块玉佩是古修遗物，她回去一擦，底下刻着去年的年号。", "在%s那里换的符纸，朱砂一落笔，灵气就散了。", "%s找零塞给她两块碎灵石，回家一看，成色最差。"]) % nm, "opts": ok}
		"师门书信":
			return {"speaker": int(n["id"]), "text": pv("师信", ["师父%s从%s来信，说师门近来不太平。", "师父%s捎信来：%s要开山门大比，问她去不去。", "师父%s的信里只问她修到哪了，末尾提了一句%s的长老病了。"]) % [nm, n["sect"]], "opts": ok}
		"义结金兰":
			return {"speaker": int(n["id"]), "text": pv("金兰", ["%s拉她在桂树下撮土为香：“从今往后，你我姐妹相称。”", "%s拉她在山神庙里磕了三个头，从此以姐妹相称。", "和%s喝光一坛酒，约定此后有难同当。"]) % nm, "opts": ok}
		"飞升异象":
			_flag_add("asc_seen:%d" % int(n["id"]))
			return {"speaker": 0, "text": pv("飞升", ["夜里天边亮了一道光，听说是%s飞升了。她在院里站了很久。", "山那边雷云聚了三日，散时满天霞光。是%s。"]) % nm, "opts": ok}
		"闭关小成":
			return {"speaker": 0, "text": pv("闭关", ["静室里坐了一夜，丹田里那团气凝实了些。", "在寒潭边坐了一夜，周天走得比往常顺。", "读通了功法里卡了半月的一句。", "打坐到天亮，灵气在指尖绕了一圈才散。", "炉火噼啪一声，她忽然想通了一处火候。", "半夜醒来，经脉里像有一条小溪，淌得比白日顺。", "她对着一盆水坐了一夜，水面没起一丝纹，心也是。", "剑招练到第三百遍，手腕忽然松了，剑意自己走了出来。"]) + "（感悟 +6）", "opts": ok}
		"旧物":
			if R(P(), n).has("ks"):
				return {"speaker": 0, "text": pv("旧物信", ["整理行囊时翻出%s。是%s给的，她一直没舍得用。", "%s压在枕下，%s留下它那天说过的话，她还记得。", "灯下，她把%s拿出来看了一会儿，想起%s。"]) % [R(P(), n)["ks"], nm], "opts": ok}
			return {"speaker": 0, "text": pv("旧物", ["整理行囊时翻出一件旧物，是%s当初给的。", "窗台上那只纸鹤，是%s折的。", "那把伞还靠在门后，是%s借的，一直没还。", "灶边那只缺口的碗，%s来时用过。"]) % nm, "opts": ok}
		"宗门大比":
			return {"speaker": 0, "text": pv("大比", ["%s在%s的大比中夺魁，名声传到了坊市。", "听说%s在%s大比上一剑败了三人。", "坊市都在押%s能不能进%s大比前三。"]) % [nm, n["sect"]], "opts": ok}
		"劫修拦路":
			var cost := mini(8, maxi(0, int(lingshi() / 3)))
			ctx["cost"] = cost
			return {"speaker": int(n["id"]), "text": pv("劫修", ["去坊市的路上，%s横剑拦住了她：“留下买路钱。”", "山口，%s从树后转出来，笑：“灵石，还是命？”", "夜路上，%s截住了她。", "%s坐在路中间的石头上磨刀，看见她，咧嘴一笑：“等你呢。”", "岔路口，%s抬手拦住她：“这条路，今天收钱。”"]) % nm,
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
				"opts": [_o("cover", "替%s担下" % ta(n)), _o("drag", "押着%s去赔罪" % ta(n))] + ([_o("qz", "拿三株青芝替%s赔" % ta(n))] if _has("herb_qingzhi", 3) else []) + [_o("let", "让%s自己担" % ta(n))]}
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
				"%s拿着一张发黄的借据找上门：青庐的前任洞主向%s借过三块灵石，“人走了，账还在。连本带利，六块。”" % [nm, ("%s的师父" % ta(n)) if String(n["sect"]) == "散修" else String(n["sect"])],
				"“这洞府的老主人欠我一炉丹。”%s把借据拍在桌上，“十年了。”" % nm,
				"%s在柴门外站着，手里捏着一张旧契：“这青庐的地，原先是租我家的。”" % nm]),
				"opts": [_o("pay", "认了，还钱"), _o("dan", "拿一粒自炼的聚气丹抵债") if _has("pill_juqi") else _o("dan", "提出炼一炉丹抵债"), _o("deny", "不认这笔账")]}
		"节令":
			var real_day := festival_today()
			var fest: String = real_day
			if fest == "":
				fest = "中秋"   # 调试命令硬弹时（不是节令的日子就不报日期）
			if not w.has("fest_done"):
				w["fest_done"] = {}
			w["fest_done"]["%d:%s" % [cal(int(w["day"]))[0], fest]] = true
			ctx["fest"] = fest
			var fx: String = pv("节景:" + fest, {"上元": ["镇上挂满了灯", "山下的灯一盏接一盏亮起来，像一条河", "有人在镇口放了一盏孔明灯，飘过了青庐"], "清明": ["山下飘着纸钱的灰", "细雨落了一整天，山路上都是上坟的人", "坊市的柳枝卖得比灵草还快"], "端午": ["河边在赛龙舟", "家里托人捎来五只粽子，用红线扎着", "镇上家家门口插了艾草"], "七夕": ["镇上的姑娘都在穿针乞巧", "夜里银河很亮，坊市有人卖双生结", "有人在桥头放了一河的莲灯"], "中秋": ["月亮大得像要落进灵田", "家里寄来两块月饼，一块已经压碎了", "镇上有人在月下吹箫，吹了一夜"], "重阳": ["坊市有人卖茱萸和菊花酒", "后山的菊花开了一坡", "镇上的老人结伴上山登高"], "冬至": ["家书里说镇上包了饺子", "院里的水缸结了一层薄冰", "山下的人家早早掩了门，烟囱里冒着白气"]}[fest])
			return {"speaker": 0, "text": "%s%s到了，%s。%s" % [(cal_text(int(w["day"])) + "，") if real_day != "" else "", fest, fx, pv("节尾", ["青庐里只有她一个人。", "她站在院里听了一会儿山下的动静。", "灶上的水开了，她没去管。", "她把那件旧披风翻出来，又放了回去。", "丹炉里的火映着墙，她一个人坐了很久。"])],
				"opts": [_o("town", "下山凑个热闹"), _o("home", "在青庐守着"), _o("aunt", "给家里捎点东西（2 灵石）")]}
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
				"opts": [_o("go", "去喝杯喜酒") if who2 != "" else _o("go", "去送一程"), _o("gift", "托人送一粒自炼的聚气丹") if _has("pill_juqi") else _o("gift", "托人送份礼（3 灵石）"), _o("no", "不去")]}
		"落难":
			return {"speaker": int(n["id"]), "text": pv("落难", [
				"坊市后巷里，%s被人堵在墙角，储物袋已经被翻了出来。%s看见了她，别开了脸。" % [nm, ta(n)],
				"山道边躺着一个人，衣裳被剑气割得一条一条的。是%s——当初在坊市说她闲话的那个。" % nm,
				"%s欠了血煞门的账，被押着往北走。经过青庐时，%s抬头看了她一眼。" % [nm, ta(n)]]),
				"opts": [_o("help", "出手")] + ([_o("pill", "出手，再喂一粒驱瘴丹")] if _has("pill_quzhang") else []) + [_o("pass", "当作没看见")]}
		"坊市认物":
			_flag_add("ks_seen:%d" % int(n["id"]))
			var mk: String = R(n, P())["ks"]
			ctx["ks"] = mk
			ctx["price"] = mini(4, lingshi())
			return {"speaker": 0, "text": pv("认物", ["坊市的地摊上，压在一堆旧货底下的，是%s。她认得——那是她当年给%s的。", "一个货郎的担子里晃着%s。她站住了：那是她亲手交给%s的东西。", "拍卖散场，伙计拎出一篮“无主之物”。最上面是%s——当年她送给%s的。"]) % [mk, nm],
				"opts": [_o("ask", "逼问摊主来历"), _o("buy", "买回来（%d 灵石）" % ctx["price"]) if ctx["price"] > 0 else _o("buy", "拿身上的干粮换回来"), _o("leave", "转身走开")]}
		"两难":
			var a3 := C(roles["A"])
			var b3 := C(roles["B"])
			ctx["cause"] = pv("两难因", ["一株救命的九叶紫参", "一枚能续命的回天丹", "师门里一个空出来的长老位子", "一卷只够一人修的残经"])
			if roles.has("made"):
				R(a3, b3)["g"] = int(R(a3, b3)["g"]) + 40
				R(b3, a3)["g"] = int(R(b3, a3)["g"]) + 30
				remember(a3, b3, "%s夺了我的%s" % [b3["name"], ctx["cause"]], -20)
			b3["inj"] = maxi(int(b3["inj"]), 10)
			return {"speaker": int(a3["id"]), "text": _liangnan_text(a3, b3, ctx["cause"]),
				"opts": [_o("a", "让%s进门" % a3["name"]), _o("b", "护住%s" % b3["name"]), _o("both", "以自身修为强保两边")]}
		"暗涌":
			var like: String = {"桂花糕": "桂花糕", "古琴": "琴谱", "好剑": "新剑穗", "丹方": "手抄的丹方", "灵茶": "新茶", "旧书": "旧书", "梅花": "梅花糕", "烈酒": "松子", "星图": "星图拓片", "木簪": "木簪"}.get(n["likes"][0], "松子")
			var hr := String(w.get("here", "青庐"))
			if hr != "青庐":   # v0.11：在外游历时，暗涌也发生在外头
				return {"speaker": int(n["id"]), "text": pv("暗涌路", [
					"%s下起冷雨，她和%s困在石窟里三日。她入定醒来，身上盖着%s的外袍，人已在洞口擦剑。" % [hr, nm, "对方" if n["sex"] == "女" else "他"],
					"她在%s借宿打坐，夜里窗外有人窥探，被一道剑气斩断了退路。推窗时只剩树梢在晃——那剑意，像是%s的。" % [hr, nm],
					"她在%s落脚的第二天，门口多了一包%s，没留名。她追出去，只看见一个背影：%s。" % [hr, like, sig(n)[1]]]),
					"opts": [_o("keep", "不说破"), _o("ask", "问一句")]}
			return {"speaker": int(n["id"]), "text": pv("暗涌", [
				"去寒潭的路上下起冷雨，她和%s困在石窟里三日。她入定醒来，身上盖着%s的外袍，人已在洞口擦剑。" % [nm, "对方" if n["sex"] == "女" else "他"],
				"她在静室冲一处关窍，窗外有人窥探，被一道剑气斩断了退路。推门时只剩树梢在晃——那剑意，像是%s的。" % nm,
				"%s来还书，书里夹着一片压平的桂叶。%s只说路过，坐到灯芯烧短了一截才走。" % [nm, _tb(n)],
				"门环上挂着一包%s，没留名。她追出去，山道尽头只剩一个背影：%s。" % [like, sig(n)[1]]]),
				"opts": [_o("keep", "不说破"), _o("ask", "问一句")]}
		"道途殊归":
			var bond: String = "道侣" if "道侣" in R(P(), n)["t"] else "金兰"
			ctx["bond"] = bond
			return {"speaker": int(n["id"]), "text": pv("殊归", ["%s提着一壶酒来了。“我要闭死关，修的道容不下尘缘。”%s把酒放下，“这一壶喝完，往后就当……没认识过。”", "月很亮。%s坐在桂树下，半晌才说：“师门要我走另一条路。我答应了。”酒是%s带来的，只有一壶。"]) % [nm, _tb(n)],
				"opts": [_o("drink", "陪%s喝完这壶" % _tb(n)), _o("keep", "留%s" % _tb(n))]}
		"重逢":
			_flag_add("reunion:%d" % int(n["id"]))
			var l0: Array = R(P(), n)["lv0"]
			return {"speaker": int(n["id"]), "text": _reunion_text(n, l0),
				"opts": [_o("warm", "还礼如旧"), _o("cool", "受了这一礼")]}
		"白首":
			n["frail"] = 1   # 出场就是白发模样（pv≥9 看 frail；旧人物看年纪）
			n["age"] = maxf(float(n["age"]), maxf(75.0, float(lifespan(int(n["lv"]))) + 0.5))
			var thing: String = pv("白首物", ["一张没走完的云梦泽地图", "半卷自己批过的剑谱", "一张试了三十年的丹方"])
			ctx["thing"] = thing
			return {"speaker": int(n["id"]), "text": "%s来了。%s%s看着她笑：“你倒一点没变。”临走，从怀里摸出%s：“没走完的路，替我走一走。”" % [nm, pv("白首起", ["上回见时还鬓发乌黑，这回拄着杖，头发白了大半——冲关连败，寿元将尽。", "背驼了，鬓边全白。说是破境三回不成，元气散了。"]), _tb(n), thing],
				"opts": [_o("take", "接下"), _o("stay", "留%s在青庐住几日" % _tb(n))]}
		"借庐":
			var h := C(roles["H"])
			if hurt_p(n, pace("grudge_recent")) or int(_rel(P(), n)["g"]) > 0:
				# v0.12.1：伤过她的人走投无路找上门——得先认这笔账，她也可以趁这时了结（Gemini v5 P0#2）
				ctx["foe"] = true
				return {"speaker": int(n["id"]), "text": pv("借庐仇", ["柴门被叩了三下。门外是%s，浑身是血：“我知道我伤过你……%s在后头，我没处去了。”" % [n["name"], h["name"]],
					"雨里有人翻进篱笆，是%s。%s抬头看见是她，苦笑了一下：“偏偏是你这儿。%s追了我三天。”" % [n["name"], _tb(n), h["name"]]]),
					"opts": [_o("hide", "旧账先不提，藏%s七日" % _tb(n)), _o("seize", "趁%s伤重，了结旧账" % _tb(n)), _o("shut", "不开门")]}
			return {"speaker": int(n["id"]), "text": _jielu_text(n, h),
				"opts": [_o("hide", "开禁制，藏%s七日" % _tb(n)), _o("path", "指%s一条后山小路" % _tb(n)), _o("shut", "不开门")]}
		"点化":
			return {"speaker": 0, "text": "柴门外蹲着个瘦小的少年人，已经蹲了三天——想拜师，又不敢敲门。问起来，说是引气三年，还没入一层，同门都笑%s。" % ("她是个木头" if n["sex"] == "女" else "他是块石头"),
				"opts": [_o("word", "指点孩子一句")] + ([_o("pill", "给孩子一粒聚气丹")] if _has("pill_juqi") else []) + [_o("send", "打发孩子下山")]}
		"点化回响":
			return {"speaker": int(n["id"]), "text": "一个年轻%s领着两个弟子上了山，在柴门外端端正正行了一礼。是当年蹲在门口的那个孩子——如今已是%s。“那年姐姐一句话，我记到今天。”" % ["女修" if n["sex"] == "女" else "修士", realm(n)],
				"opts": [_o("ok2", "受了这一礼"), _o("tea", "请%s进来喝碗茶" % ("对方" if n["sex"] == "女" else "他"))]}
	return {"speaker": 0, "text": "", "opts": ok}

func _liangnan_text(a: Dictionary, b: Dictionary, cause: String) -> String:
	return pv("两难起", ["雪下了一夜。%s按剑站在柴门外：“把%s交出来。”屋里，%s靠在榻上咳血。两人为%s翻了脸，都待她不薄。" % [a["name"], b["name"], b["name"], cause],
		"院里，%s的剑尖垂在雪上：“让开。”身后的门里，%s的药碗还冒着热气。为了%s，两个都对她好过的人，要见生死。" % [a["name"], b["name"], cause]])

func _reunion_text(n: Dictionary, l0: Array) -> String:
	var nm: String = n["name"]
	return pv("重逢", ["坊市口撞见%s。初见时对方已是%s，她才%s，那一眼看得她抬不起头。如今她追了上来。%s怔了怔，拱手道：“道友。”" % [nm, realm_name(int(l0[0])), realm_name(int(l0[1])), nm],
		"山道上，%s让到路边，等她先过。初见时是%s对%s，她得仰着头说话。如今两人的气息，已是平的。" % [nm, realm_name(int(l0[0])), realm_name(int(l0[1]))]])

func _jielu_text(n: Dictionary, h: Dictionary) -> String:
	return pv("借庐", ["夜里柴门被叩了三下。%s浑身是血，靠在门框上：“%s在后头……借你的青庐，躲七日。”" % [n["name"], h["name"]],
		"雨里有人翻进篱笆，倒在灵田边，是%s。%s喘着气：“%s追了我三天。你这儿有禁制吧？”" % [n["name"], _tb(n), h["name"]]])

func _roll(mine: float, theirs: float, a: float = 5.0, b: float = 5.0) -> bool:
	return mine + rng.randf() * a > theirs + rng.randf() * b

func resolve(tid: String, roles: Dictionary, ctx: Dictionary, oid: String) -> String:
	if saga().is_tid(tid):
		return saga().resolve(tid, roles, ctx, oid)
	if tid in TV.TIDS:
		return TV.resolve(self, tid, roles, ctx, oid)
	if tid in MD.TIDS:
		var mr := MD.resolve(self, tid, roles, ctx, oid)
		if tid == "插手":
			TV.on_meddle(self, int(ctx.get("pid", -1)))
		return mr
	if tid in AG.TIDS:
		return AG.resolve(self, tid, roles, ctx, oid)
	var p := P()
	var n: Dictionary = C(roles["B"]) if roles.has("B") else {}
	var nm: String = n.get("name", "")
	var pl := float(plv()) + Gear.edge(self, n)   # v0.14：法宝
	var out := ""
	match tid:
		"偶遇":
			meet(n)
			if oid == "go":
				fav(n, 8, "同行过一段山路", 5)
				out = "%s。%s" % [pv("偶遇同行", ["结伴走了一程", "同行到岔路口才分开", "一起避了场雨，说了些各自的来处", "她分了半块干粮，对方回了一句谢", "一路无话，到岔口时对方先开了口", "对方教她认了两种路边的药草", "过独木桥时，对方回身扶了她一把", "两人在破庙里烤干了衣裳，聊到雨停"]), pv("偶遇自称", ["%s自称%s。", "分手前，%s报了名号：%s。", "临别时%s说，自己叫%s。", "到了岔口，%s才说起自己的名字——%s。", "%s说自己叫%s，往后路上见了，招呼一声便是。"]) % ["对方" if n["sex"] == "女" else ta(n), nm]]   # v0.7.8：认名收尾 5 种
				chron(n, "山道上遇见%s，同行一程。" % pn())
				chron(p, pv("偶遇记", ["与%s同行到岔路口。", "和%s一起避了场雨。", "路上结识%s，同行了一程。", "与%s结伴走过一段山路。"]) % nm)
			else:
				out = "%s。%s" % [pv("偶遇别", ["各自赶路", "她拱了拱手，没多停", "彼此点头，擦肩而过", "她侧身让了路"]), pv("偶遇别名", ["后来才知道，那人叫%s。", "后来在坊市听人提起，才知那是%s。", "那人走远了，她才想起腰牌上的字：%s。", "过后她才想起，那人临别报过名号——%s。", "隔了几日，她才从别人嘴里对上号：那是%s。"]) % nm]
				chron(p, pv("偶遇别记", ["路上与%s擦肩而过。", "在路上见过%s一面，没有搭话。", "与%s点头而过。", "山道上遇见%s，各走各的路。", "同%s打了个照面，没有多留。"]) % nm)
		"求助":
			meet(n)
			if oid == "help":
				_inj(2)
				fav(n, 25, "重伤时%s救了我" % pn(), 30)
				out = pv("求助救", ["她守了一夜，渡了三日修为。%s醒来，只说了一句：“记下了。”", "她把人背回青庐，灵气渡了一遍又一遍。天亮时%s睁开眼，看了她很久。", "她以指尖逼出毒血，又守着药炉熬到三更。%s醒来第一句是：“你不该救我。”"]) % nm + "\n（经脉微损：闭关炼化减半 2 个月）"
				chron(p, "%s救下重伤的%s，耗了三日修为。" % [ctx.get("where", "寒潭边"), nm])
				chron(n, "重伤倒在%s，被%s所救。" % [ctx.get("where", "寒潭边"), pn()])
				schedule(rng.randi_range(8, 25), "报恩", {"B": int(n["id"])}, {"where": ctx.get("where", "寒潭边")})
			elif oid == "pill":
				# v0.8：家里炼的丹派上用场——不伤自己的经脉，人也好得快
				var pid := "pill_quzhang" if _has("pill_quzhang") else "pill_juqi"
				_use(pid)
				fav(n, 28, "重伤时%s喂了我一粒自己炼的丹" % pn(), 30)
				out = _pill_text(pid, nm)
				out += "\n（用去%s ×1）" % g.NAMES.get(pid, "丹")
				chron(p, "%s救下重伤的%s，用了一粒自炼的%s。" % [ctx.get("where", "寒潭边"), nm, g.NAMES.get(pid, "丹")])
				chron(n, "重伤倒在%s，服了%s炼的丹，捡回一条命。" % [ctx.get("where", "寒潭边"), pn()])
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
				out = pv("求助劫", ["储物袋里有%s块灵石。她没回头。", "她解下那只储物袋，掂了掂，%s块灵石。身后的人连骂都骂不出声。"]) % cnum(got)
				chron(p, "搜走了%s的储物袋，得灵石%s块。" % [nm, cnum(got)])
				chron(n, "重伤时被%s劫了储物袋。" % pn())
				schedule(rng.randi_range(15, 40), "仇人上门", {"B": int(n["id"])})
		"报恩":
			var gift: String = ctx.get("gift", "灵茶")
			if oid == "tea":
				fav(n, 14, "%s留我喝了碗茶" % pn(), 6)
				out = pv("报恩茶", ["两人对着灶火坐了半日。%s走时，回头看了一眼青庐。", "茶续了三回。%s说起那日的事，她只笑说记不清了。", "她煮了新茶。%s喝得很慢，像要把这碗茶记住。"]).replace("%s", nm)
			else:
				fav(n, 10)
				out = pv("报恩收", ["她收下了{g}。{n}点点头，走了。", "她没推辞，收下了{g}。{n}像是松了口气。", "{g}用红绳扎着，结打得很仔细。{n}放下就走，没让她送。"]).format({"g": gift, "n": nm})
			_ling(5)
			out += "\n（%s另留下 5 块灵石）" % ta(n)
			chron(p, pv("报恩记", ["%s找到青庐，还了当初的人情。", "当年救下的%s来青庐道谢。", "%s登门，还了那份救命的情。"]) % nm)
			chron(n, "去青庐还了%s的人情。" % pn())
			if oid == "tea":
				out += _swap_ks(n)
			if int(R(n, p)["f"]) > 60 and int(R(n, p).get("n", 0)) >= 3 and n["sex"] != p["sex"] and partner(n) == null and not n.has("dz"):
				schedule(rng.randi_range(10, 20), "表白", {"B": int(n["id"])})
		"仇人上门":
			if oid == "fight":
				if _roll(pl, float(n["lv"]), 5, 4):
					n["inj"] = 10
					R(n, p)["g"] = int(R(n, p)["g"]) + 20
					note_defeat(n, p)
					out = pv("仇退", ["她在院里把%s打退了。灵田踩坏了半垄。", "剑光在院里绕了三圈。%s退出柴门时，衣襟被削去一角。", "她一剑压住%s的剑脊：“到此为止。”对方咬牙退走。"]).replace("%s", nm)
					chron(p, "%s寻上青庐，被她在院里打退。" % nm)
					chron(n, "寻%s报仇，败退。" % pn())
				else:
					_inj(3)
					R(n, p)["g"] = int(R(n, p)["g"]) - 30
					out = pv("仇败", ["她败了。丹炉被砸出一道裂。%s出了这口气，扬长而去。", "三招之后，她的剑落进了灵田。%s一脚踢翻丹炉，头也不回地走了。", "她撑着门框站起来时，%s已经出了柴门。丹炉上多了一道裂。"]).replace("%s", nm) + "\n（受伤：闭关炼化减半 3 个月）"
					chron(p, "%s寻上青庐，她败了，丹炉被砸。" % nm)
					chron(n, "砸了%s的丹炉。" % pn())
			elif oid == "pay" or oid == "beg":
				if oid == "pay":
					_ling(-10)
				R(n, p)["g"] = int(R(n, p)["g"]) - 25
				out = ("她把灵石奉还，又添了一成。" if oid == "pay" else "她低头认了错。") + "%s冷哼一声，收了剑。" % nm
				chron(p, "%s寻上门，她赔了礼。" % nm)
			else:
				# v0.7.6：逃的写法有变化；连躲三回，对方不再找来（以前每 20 日一回，可以躲到天荒地老，一字不差）
				var rr: Dictionary = R(n, p)
				rr["run"] = int(rr.get("run", 0)) + 1
				out = pv("仇逃", ["她从后窗走了。青庐空了三天，回来时柴门上多了一道剑痕。", "她翻过后墙，钻进竹林。回来时院里一片狼藉，鸡倒是都在。", "她从后窗走了，在寒潭边坐了两夜。回来时灵田被踩平了半垄。", "她没去拿剑，抱起丹炉就走。回来时屋里能砸的都砸了，柴门上多了一道剑痕。"])
				if int(rr["run"]) >= 3:
					out += pv("仇罢", ["\n此后%s没有再来。听说有人劝了一句：同一个躲不起的人较劲，不值。", "\n这是%s最后一次找来。往后坊市里提起她，%s只冷笑一声。"]).replace("%s", nm)
					chron(p, "%s又一次寻上门，她又躲了。此后对方没有再来。" % nm)
				else:
					chron(p, pv("仇逃记", ["%s寻上门时，她已从后窗走了。", "%s寻上门，她避开了，柴门上留了一道剑痕。", "%s又来寻仇，她没有接。"]) % nm)
					schedule(20, "仇人上门", {"B": int(n["id"])})
		"表白":
			meet(n)
			if int(w.get("arc", {}).get("fated", 0)) == int(n["id"]):
				w["arc"]["romance_done"] = true
			if oid == "yes":
				R(n, p)["t"].append("道侣")
				R(p, n)["t"].append("道侣")
				out = pv("表白应", ["她说好。%s笑了，像是松了一口气。" % nm, "她没说话，只把那支木簪插进了发髻。", "“好。”她答得很轻。%s却像听见了很响的一声。" % nm]) + _swap_ks(n)
				R(p, n)["bd"] = int(w["day"])
				chron(p, "与%s结为道侣。" % nm)
				chron(n, "与%s结为道侣。" % pn())
				rumor("%s与%s结为道侣。" % [pn(), nm], [n])
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
					hunt(int(n["id"]))["st"] = 2
					die(n, "被%s所斩" % pn())
				else:
					_inj(4)
					R(n, p)["g"] = int(R(n, p)["g"]) + 20
					out = pv("寻凶败", ["与%s一战，败，伤了根基。", "%s比传闻里更狠。她拼着挨了一掌才脱身。", "她的剑断在%s手里，人是被过路的樵夫背回来的。"]) % nm + "\n（重伤：闭关炼化减半 4 个月）"
					chron(p, pv("寻凶败记", ["寻%s报仇，败了，伤了根基。", "与%s一战，重伤而回。"]) % nm)
					var hb := hunt(int(n["id"]))
					hb["st"] = 1
					hb["rd"] = 0
			else:
				out = pv("寻凶缓", ["她把%s的名字刻在丹炉底下。" % nm, "她没有去。只是从那天起，每天多练一个时辰的剑。", "她把打听来的消息写在纸上，压进了经卷。"])
				chron(p, pv("寻凶缓记", ["决定先修到能赢%s再说。", "把%s的名字记下，暂且按住了剑。"]) % nm)
				var hw := hunt(int(n["id"]))
				hw["st"] = 1   # 按住了：修为追上（plv ≥ 对方）时由 _hunt_tick 再提起
				hw["rd"] = 0
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
				out = pv("怨偶由", ["她照旧去坊市买她的盐。闲话传了半个月，自己散了。", "她只当风过耳，照旧采药炼丹。日子久了，说闲话的人自己没了趣。"]) + "\n（心境沉静：感悟 +6）"
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
					out = "她败了。%s翻遍青庐，什么也没找到，临走踢翻了丹炉。\n（受伤：闭关炼化减半 3 个月）" % nm
					chron(p, "%s寻上青庐，她不敌，丹炉被踢翻。" % nm)
			elif oid == "give":
				var lost := _ling(-mini(8, lingshi()))
				out = "%s把青庐翻了个底朝天，什么也没找到，顺手拿走了%s块灵石。" % [nm, cnum(-lost)]
				chron(p, "%s来青庐翻找%s的遗物，一无所获。" % [nm, fr2])
			else:
				out = "她从后窗走了，在山里躲了两夜。回来时，柴门上多了一道剑痕。"
				chron(p, "%s寻上门时，她从后窗走了。" % nm)
				schedule(rng.randi_range(15, 25), "寻凶", {"B": int(n["id"])})
		"坊市传闻":
			chron(p, "听说：%s" % ctx.get("news", ""))
			var tg := C(ctx.get("nid", 0))
			if not tg.is_empty() and oid != "ok":
				var tn: String = tg["name"]
				match oid:
					"gift":
						if _use("herb_qingzhi", 2):
							out = "她托人捎去两株青芝，附了一句贺词。%s回了一包喜糖。\n（用去青芝 ×2）" % tn
						else:
							_ling(-mini(2, lingshi()))
							out = "她托人随了一份薄礼。%s回了一包喜糖，信里说：“改日请你喝酒。”" % tn
						fav(tg, 8, "大喜那天%s随了礼" % pn(), 8)
						chron(p, "听说%s结了道侣，托人随了礼。" % tn)
					"med":
						if _use("pill_quzhang"):
							out = "她托人把一粒自炼的驱瘴丹捎了过去。半月后回信到了，字歪歪扭扭：“好多了。”\n（用去驱瘴丹 ×1）"
						else:
							_ling(-mini(2, lingshi()))
							out = "她托药铺伙计捎了两包伤药过去。回信很短：“记下了。”"
						fav(tg, 10, "我养伤时%s托人送了药" % pn(), 12)
						chron(p, "听说%s负了伤，托人捎去了药。" % tn)
					"mark":
						out = "她把那地方记在了丹炉底下。人伤着，跑不远。"
						chron(p, "记下了%s养伤的落脚处。" % tn)
						schedule(rng.randi_range(2, 4), "寻凶", {"B": int(tg["id"])})
					"congrat":
						fav(tg, 4, "%s托人来贺过" % pn(), 4)
						out = "她托人带了一句贺喜。%s回了两个字：“同喜。”" % tn
						chron(p, "托人去贺%s破境。" % tn)
					"incense":
						_flag_add("mourned:%d" % int(tg["id"]))
						_wu(4)
						out = "她找到那座新坟，插了三炷香，坐到香烧尽。（感悟 +4）"
						chron(p, "去%s坟前上了一炷香。" % tn)
		"赠礼":
			var gift2 := oid.trim_prefix("g:")
			if oid == "qz":
				_use("herb_qingzhi", 2)
				var pick_up: bool = "丹方" in n["likes"] or "灵茶" in n["likes"]
				fav(n, 12 if pick_up else 8, "%s送来亲手种的青芝" % pn(), 8)
				out = pv("赠芝", ["她从灵田里挑了两株最壮的青芝，用油纸包了托人捎去。%s回信说：“自家种的，比坊市的香。”", "两株青芝，根上还带着青庐的土。%s收下了，回了她一句：“替我谢谢那块田。”"]) % nm + "\n（用去青芝 ×2）"
				chron(p, "给%s捎去两株自家种的青芝。" % nm)
				return out
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
					out = pv("朱果败", ["她挨了%s一掌，朱果没了。", "朱果被%s摘走，她肩上青了一块。", "被%s一道剑气削了半截袖子。"]) % nm + "\n（受伤：闭关炼化减半 2 个月）"
			else:
				fav(n, 5)
				out = pv("朱果让", ["她把朱果让给了%s。", "她退了一步，朱果归了%s。", "%s道了声承让，她笑了笑。"]) % nm
			chron(p, "与%s争朱果——%s" % [nm, out.split("\n")[0]])
		"站队":
			var a := C(roles["A"])
			var b := C(roles["B"])
			if oid == "none":
				out = pv("站队避", ["她绕路走了。", "她只当没看见。", "她在远处站了一会儿，走了。"])
				chron(p, pv("站队避记", ["撞见%s与%s相争，没有掺和。", "%s和%s起了争执，她绕开了。", "%s与%s的事，她没有插手。"]) % [a["name"], b["name"]])
			else:
				var x: Dictionary = a if oid == "a" else b
				var y: Dictionary = b if oid == "a" else a
				meet(x)
				meet(y)
				fav(x, 15, "%s帮过我" % pn(), 15)
				R(y, p)["g"] = int(R(y, p)["g"]) + 25
				remember(y, p, "%s帮%s对付我" % [pn(), x["name"]], -20)
				out = pv("站队选", ["她站到了%s身边。", "她替%s挡了一剑。", "她开口替%s说了句话。", "她把剑横在了%s身前。", "她只往%s那边站了一步，局面就变了。"]) % x["name"] + pv("站队记", ["%s记住了她。", "%s没再说什么，只深深看了她一眼。", "%s冷笑一声，拂袖走了。", "%s收了剑，临走回头看了她一眼。"]) % y["name"]
				chron(p, pv("站队选记", ["{a}与{b}相争，她帮了{x}。", "{a}和{b}起了争执，她站在{x}一边。", "替{x}出头，与{y}结下了梁子。"]).format({"a": a["name"], "b": b["name"], "x": x["name"], "y": y["name"]}))
		"拜师":
			meet(n)
			if oid == "yes":
				R(n, p)["t"].append("徒")
				R(p, n)["t"].append("师")
				out = pv("拜师应", ["她跪下，磕了三个头。%s受了。" % nm, "她奉上一盏茶。%s接过去，喝了。" % nm])
				out += _swap_ks(n)
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
			var dpl: String = ctx.get("pl", n["place"])
			var hk2 = null
			if String(ctx.get("why", "")).begins_with("盯:"):
				hk2 = C(int(String(ctx["why"]).trim_prefix("盯:")))
			if oid == "pill" or oid == "go":
				if oid == "pill":
					_use("pill_quzhang")
				_inj(1 if oid == "pill" else 3)
				fav(n, 22 if oid == "pill" else 20, "%s来寻我" % pn(), 25)
				n["inj"] = maxi(0, int(n["inj"]) - 10)
				if hk2 != null and not hk2.is_empty() and hk2["alive"]:
					AG._settle(hk2, int(n["id"]), [])
					remember(hk2, p, "%s护着%s" % [pn(), nm], -8, "辱")
				out = pv("遇险寻", ["她赶到%s，在一处背风的崖下找到了%s。" % [dpl, nm], "她循着命灯的余光一路寻到%s。%s看见她，先笑了一下。" % [dpl, nm], "她背着%s离开%s时，两个人都只剩半条命。" % [nm, dpl]]) + ("\n（用去驱瘴丹 ×1；只是累着了：闭关炼化减半一个月）" if oid == "pill" else "\n（奔波受伤：闭关炼化减半三个月）")
				chron(p, "%s在%s遇险，她赶去，把人找了回来。" % [nm, dpl])
			elif rng.randf() < (0.4 if hk2 != null else 0.15):
				out = pv("遇险失", ["消息再没有来。", "命灯在第九夜熄了。她守着那盏灯，坐到天亮。"])
				if hk2 != null and not hk2.is_empty() and hk2["alive"]:
					die(n, "死于%s之手" % hk2["name"])
				else:
					die(n, "在%s伤重不治" % dpl)
				chron(p, "道侣%s在%s出了事，再没回来。" % [nm, dpl])
			else:
				fav(n, -15, "我出事时%s没来" % pn(), -20)
				out = "半月后%s自己回来了，没提路上的事。" % ta(n)
				chron(p, "%s在%s遇险，半月后自己回来了。" % [nm, dpl])
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
				out = pv("心魔诵", ["经诵到第七遍，灯影平了。", "她闭着眼，把外门早课的那段经一字一字念完。", "木鱼敲了一夜，到鸡鸣才停。"])
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
				out = ("她守在镇口，%s闻讯赶来。" % "、".join(hn) if not hn.is_empty() else pv("袭镇守", ["她一个人守在镇口。", "镇口只剩她一个人和一把剑。"])) + pv("袭镇明", ["天亮时，火灭了。", "鸡叫头遍，北边的人退了。"]) + "\n（受伤：闭关炼化减半 3 个月）"
				chron(p, "%s带人袭镇，她守在镇口。" % nm)
			else:
				remember(p, n, "小镇那夜的火光", -20)
				out = pv("袭镇躲", ["她背着一个走不动的老婆婆进了后山。回头时，半边天是红的。", "她拉着两个孩子钻进后山的石缝，听了一夜的哭喊。"])
				chron(p, "%s血洗小镇那夜，她护着镇上的老人孩子进了后山。" % nm)
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
				var foes := party.filter(func(x): return not _close_p(x))
				if rng.randf() < 0.5 and not foes.is_empty():
					var a2: Dictionary = _ch(foes)
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
			R(p, n)["bd"] = int(w["day"])
			out = _swap_ks(n).strip_edges()
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
				out = pv("劫败", ["她没打过。灵石被搜走了。", "剑被挑飞，储物袋也被扯了去。", "她退到崖边，只好松手交出灵石。"]) + "\n（受伤：闭关炼化减半 2 个月）"
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
					out = ["她走到第九百级时，筐里的石头一块没少。执事在名册上添了她的名字。", "幻阵里她看见了桃溪镇，看见了青庐，最后看见了自己。她走了出来。", "第七招，她的剑停在对方喉前一寸。"][k4] + "
她成了%s的外门弟子。（感悟 +10）" % sect
					chron(p, "过了%s的外门考核，挂名为外门弟子。" % sect)
				else:
					_inj(1)
					_wu(4)
					out = ["第六百级上她腿一软，石头滚了一地。", "幻阵里她在青庐门口站了一夜，没能迈出去。", "她输了半招。对方收剑时说：“明年再来。”"][k4] + "
（落选；吃了些苦头：闭关炼化减半 1 个月，感悟 +4）"
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
（重伤：闭关炼化减半 4 个月）" % -lost2
					chron(p, "被%s伏击，重伤，灵石被劫。" % nm)
			elif oid == "talisman":
				if _roll(pl + 2.0, float(n["lv"]), 5, 4):
					out = pv("伏符", ["符火炸开，林子里一片白。等烟散了，她已经在三里外。", "她撒出去的不是什么好符，但够乱。她钻进了来时的小路。"])
					chron(p, "被%s伏击，撒符脱身。" % nm)
				else:
					_inj(2)
					out = "符烧到一半就灭了。她挨了一刀才脱身。
（受伤：闭关炼化减半 2 个月）"
					chron(p, "被%s伏击，带伤脱身。" % nm)
			else:
				var lost3 := _ling(-mini(6, lingshi()))
				R(p, n)["g"] = int(R(p, n)["g"]) + 10
				out = "她把包袱往地上一扔，转身就走。%s没追。（损失 %d 灵石的货）" % [nm, -lost3]
				chron(p, "被%s伏击，弃货保命。" % nm)
		"师弟惹祸":
			var tb2 := "小师妹" if n["sex"] == "女" else "小师弟"
			if oid == "qz":
				_use("herb_qingzhi", 3)
				fav(n, 15, "%s拿自家的青芝替我赔了" % pn(), 18)
				out = "她回灵田挑了三株青芝，替%s赔给了人家。对方掂了掂成色，没再计较。%s一路跟在她身后，小声说：“我会还的。”\n（用去青芝 ×3）" % [nm, ta(n)]
				chron(p, "拿三株青芝，替%s%s了了一回事。" % [tb2, nm])
			elif oid == "cover":
				var lost4 := _ling(-mini(6, lingshi()))
				fav(n, 15, "%s替我担了事" % pn(), 18)
				out = "她替%s把事了了，花了%s块灵石。%s跟在她后头，一路没说话。" % [nm, cnum(-lost4), ta(n)]
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
（受伤：闭关炼化减半 1 个月）" % nm
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
				var rv = _pick(func(c): return int(c["lv"]) >= plv() - 2 and int(c["lv"]) <= plv() + 5 and not _close_p(c))
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
（受伤：闭关炼化减半 2 个月）" % [nm, it4, ta(n)]
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
				out = pv("破境贺", ["她提了一坛酒去道贺。%s愣了愣，到底让她进了门。", "她备了一份薄礼登门。%s收下了，回赠她一句修行上的话。", "她去道贺，%s正被人围着。看见她，%s挤出人群迎了出来。"]).replace("%s", nm)
				chron(p, "去给%s贺破境。" % nm)
			else:
				_wu(3)
				out = pv("破境笑", ["她笑了笑。道是自己的，快慢也是自己的。", "她照旧去浇她的灵田。青芝不会因为别人破境就长得快些。", "她只说了句“好事”，转身添了炉炭。"]) + "（感悟 +3）"
				chron(p, "听说%s破境，没放在心上。" % nm)
		"旧债上门":
			meet(n)
			if oid == "pay":
				var lost5 := _ling(-mini(6, lingshi()))
				fav(n, 5)
				out = "她把%s块灵石数给%s。借据当着她的面撕了，扔进了灶膛。" % [cnum(-lost5), nm]
				chron(p, "替青庐的前任洞主还了%s一笔旧账。" % nm)
			elif oid == "dan" and _has("pill_juqi"):
				_use("pill_juqi")
				fav(n, 8, "%s拿自炼的丹抵了债" % pn(), 6)
				out = "她从丹房取了一粒聚气丹，放在借据上。%s拈起来闻了闻，脸色缓了：“成色不错。两清。”\n（用去聚气丹 ×1）" % nm
				chron(p, "拿一粒自炼的聚气丹，抵了%s的旧债。" % nm)
			elif oid == "dan":
				if _roll(pl, 4.0):
					fav(n, 8, "%s炼丹抵了债" % pn(), 6)
					_wu(4)
					out = "她守着丹炉熬了一夜。%s捧着那炉丹，脸色缓了下来：“两清。”（感悟 +4）" % nm
					chron(p, "给%s炼了一炉丹，抵了旧债。" % nm)
				else:
					var lost6 := _ling(-mini(3, lingshi()))
					out = "丹炼糊了。%s捏着鼻子，又要走了%s块灵石。" % [nm, cnum(-lost6)]
					chron(p, "想用丹抵%s的债，炼糊了。" % nm)
			else:
				R(n, p)["g"] = int(R(n, p)["g"]) + 15
				rumor("%s说青庐那个女修赖账。" % nm, [n])
				out = pv("赖账", ["她说，租洞府时葛老三没提过这笔账。%s把借据收回去，冷笑一声走了。", "她把借据和《旧主手记》对了对：“这不是他的字。”%s脸色一变，夺过借据就走。"]).replace("%s", nm)
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
					out = pv("节独", ["她在人堆里走了一圈，买了包糖炒栗子，一个人吃完了。", "她在灯下替一个迷路的孩子找到了娘，自己倒走散了。", "她看了一场傀儡戏，散场时才发现袖里多了一枝花，不知是谁塞的。"]) + "（感悟 +2）"
					chron(p, "%s下山逛了一圈。" % fest2)
			elif oid == "home":
				_wu(5)
				out = pv("节守", ["她给灵田浇了水，给丹炉添了炭，早早睡了。（感悟 +5）", "她在院里坐着，听山下的鞭炮响到半夜。（感悟 +5）", "她多摆了一副碗筷，想了想，又收了回去。打坐到天明。（感悟 +5）"])
				chron(p, "%s在青庐过的。" % fest2)
			else:
				_ling(-mini(2, lingshi()))
				out = pv("节寄", ["她托人给家里捎了一包新茶和两块灵石。回信说，钱留着，茶收了。", "她托人给娘捎去两块灵石和一盒胭脂。回信说：老了，涂给谁看。末尾又添一句：颜色很好。", "她给家里捎了东西。回信很长，一半在骂她乱花钱，一半在问她冷不冷。"])
				chron(p, "%s给家里捎了东西。" % fest2)
		"远方来信":
			if oid == "reply":
				fav(n, 5)
				out = "她回了一封信，写灵田、写丹炉、写院里那棵桂树。写完一看，一个字也没提自己。"
				chron(p, "给远方的%s回了一封信。" % nm)
			else:
				_wu(3)
				out = pv("远信收", ["她把信折好，夹进了经卷里。", "她把信读了两遍，压在枕下。有些话，不回也是一种回。"]) + "（感悟 +3）"
				chron(p, "收到%s的信，没有回。" % nm)
		"喜帖":
			var who3: String = ctx.get("spouse", "")
			if oid == "go":
				_wu(4)
				fav(n, 6, "%s来喝了我的喜酒" % pn() if who3 != "" else "%s来送了我一程" % pn(), 6)
				out = ("她去了，喝了一杯，坐了一刻。%s敬酒到她这桌时，两人都笑了。（感悟 +4）" % nm) if who3 != "" else ("她送%s到渡口。船开出去很远，%s还站在船头。（感悟 +4）" % [nm, ta(n)])
				chron(p, "去喝了%s的喜酒。" % nm if who3 != "" else "去渡口送了%s一程。" % nm)
			elif oid == "gift" and _has("pill_juqi"):
				_use("pill_juqi")
				fav(n, 6)
				out = "她托人送去一粒自炼的聚气丹，用红纸包着，没写名字。%s一闻药香就知道是谁送的。\n（用去聚气丹 ×1）" % nm
				chron(p, "托人给%s送了一粒自炼的丹。" % nm)
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
			if oid == "help" or oid == "pill":
				if oid == "pill" and _use("pill_quzhang"):
					fav(n, 6)
				else:
					_inj(1)
				fav(n, 30, "落难时%s救了我" % pn(), 30)
				R(n, p)["g"] = 0
				out = pv("落难救", ["她拔剑上前。人散了之后，%s低着头说了一句：“那些话，是我嘴贱。”" % nm, "她把%s扶回青庐，上了药。%s一夜没睡，天亮时留下一句“对不住”就走了。" % [nm, ta(n)]]) + ("
（用去驱瘴丹 ×1，伤好得快）" if oid == "pill" else "
（受了点伤：闭关炼化减半 1 个月）")
				chron(p, "%s落难，她出了手。旧怨就此了了。" % nm)
				chron(n, "落难时被%s所救。" % pn())
			else:
				_wu(3)
				n["inj"] = 15
				out = "她从旁边走了过去，没回头。夜里想起这事，也说不上痛快。（感悟 +3）"
				chron(p, "见%s落难，没有出手。" % nm)
		"坊市认物":
			var mk: String = ctx.get("ks", "那件旧物")
			if oid == "ask":
				var kl = _killer_of(String(n["log"][-1][1]) if not n["log"].is_empty() else "")
				if kl != null and kl["alive"]:
					R(p, kl)["g"] = int(R(p, kl)["g"]) + 30
					remember(p, kl, "%s身上带着%s的%s" % [kl["name"], nm, mk], -20)
					out = "摊主被她盯得发毛，到底说了：是从%s手里收的，那人急着出手，价都没还。\n她把%s揣进怀里，没付钱，摊主也没敢要。" % [kl["name"], mk]
					chron(p, "在坊市认出%s的遗物%s，问出是从%s手里流出来的。" % [nm, mk, kl["name"]])
					schedule(rng.randi_range(3, 6), "寻凶", {"B": int(kl["id"])})
				else:
					_wu(4)
					out = "摊主说是从%s一处荒坟边捡的，别的什么也不知道。她把%s买了回来，擦了一夜。（感悟 +4）" % [n["place"], mk]
					chron(p, "在坊市认出%s的遗物%s，赎了回来。" % [nm, mk])
			elif oid == "buy":
				var paid := _ling(-int(ctx.get("price", 0)))
				_wu(3)
				out = "她把%s买了回来，%s。放在丹炉旁，夜里炉火一映，像%s还坐在那儿。（感悟 +3）" % [mk, ("花了%s块灵石" % cnum(-paid)) if paid < 0 else "拿两块干饼换的", nm]
				chron(p, "在坊市赎回了当年送给%s的%s。" % [nm, mk])
			else:
				out = "她转身走开了。走出半条街，又回头看了一眼，东西已经被人买走了。"
				remember(p, n, "没赎回%s" % mk, -4)
				chron(p, "在坊市看见%s的旧物%s，没有买。" % [nm, mk])
		"两难":
			var a3 := C(roles["A"])
			var b3 := C(roles["B"])
			var cause: String = ctx.get("cause", "一件东西")
			if oid == "both":
				_inj(5)
				fav(a3, 4, "那夜%s谁也没让" % pn(), 10)
				fav(b3, 10, "那夜%s拼着伤了根基保我" % pn(), 18)
				R(a3, b3)["g"] = maxi(0, int(R(a3, b3)["g"]) - 15)
				out = "她站在门槛上，接了%s三剑，一步没退。天亮时%s收了剑，走了；她吐出一口血。\n（强保两边，伤了经脉：闭关炼化减半 5 个月）" % [a3["name"], a3["name"]]
				chron(p, "%s与%s为%s结仇，%s寻上青庐。她拼着受伤，两边都保了下来。" % [a3["name"], b3["name"], cause, a3["name"]])
			else:
				var x2: Dictionary = a3 if oid == "a" else b3
				var y2: Dictionary = b3 if oid == "a" else a3
				fav(x2, 12, "那夜%s站在我这边" % pn(), 15)
				fav(y2, -30, "那夜%s选了%s" % [pn(), x2["name"]], -25)
				R(y2, p)["g"] = int(R(y2, p)["g"]) + 25
				if oid == "a":
					b3["inj"] = 20
					out = "她让开了门。%s进去时没有看她。屋里没传出什么声音，只是第二日，%s已经不在了——人是被抬走的，活着。临走那一眼，她记了很久。" % [a3["name"], b3["name"]]
				else:
					out = "她把剑横在门口。%s盯了她很久：“好。”雪地上留下一行很深的脚印。" % a3["name"]
				chron(p, "%s与%s为%s结仇。那夜，她站在了%s一边。" % [a3["name"], b3["name"], cause, x2["name"]])
				chron(y2, "那夜%s选了%s。" % [pn(), x2["name"]])
		"暗涌":
			if oid == "keep":
				fav(n, 6, "%s没有说破" % pn(), 6)
				_wu(2)
				out = pv("暗涌藏", ["她什么也没问。只是那天的茶，泡得比往常久。（感悟 +2）", "她没说破，把那件东西收进了柜子最里面。（感悟 +2）"])
				chron(p, pv("暗涌记", ["与%s之间，有些话谁也没说。", "%s来过。她没有说破。"]) % nm)
			else:
				fav(n, 4, "%s问了我一句" % pn(), 4)
				out = pv("暗涌问", ["她问了一句。%s别过头去：“顺路。”耳根却红了。" % nm, "“是你？”%s没答，只说天要黑了，路不好走。" % nm])
				chron(p, "问了%s一句，%s只说顺路。" % [nm, ta(n)])
			if ctx.get("arc", "") == "romance":
				schedule(rng.randi_range(4, 7), "表白", {"B": int(n["id"])}, {"arc": "romance"})
		"道途殊归":
			var bond2: String = ctx.get("bond", "道侣")
			R(p, n)["t"].erase("道侣"); R(n, p)["t"].erase("道侣")
			R(p, n)["t"].erase("结义"); R(n, p)["t"].erase("结义")
			n["dz"] = int(w["day"])
			n["goal"] = "求长生"
			n["place"] = _ch(["云梦泽", "古战场", SECT_HOME[n["sect"]]])
			remember(n, p, "已斩红尘，唯余此念未消", 25)
			var left_ks := ""
			if R(p, n).has("ks"):
				left_ks = "%s留下的%s，她没有还。" % [nm, R(p, n)["ks"]]
			if oid == "drink":
				_wu(12)
				out = "两人对坐，一壶酒喝到月落。%s起身时说了声“保重”，没有回头。%s\n（感悟 +12）" % [nm, left_ks]
			else:
				_wu(6)
				fav(n, 4)
				out = "她说，再坐一会儿。%s坐到天亮，还是走了。走前替她把丹炉的火添旺了。%s\n（感悟 +6）" % [nm, left_ks]
			remember(p, n, "%s走了自己的道" % nm, 10)
			chron(p, "%s来青庐喝了最后一壶酒，斩了尘缘。%s的情分到此为止，念想还在。" % [nm, bond2])
			chron(n, "斩断尘缘，闭了死关。")
			rumor("听说%s斩了尘缘，闭了死关。" % nm, [n])
		"重逢":
			if oid == "warm":
				fav(n, 8, "%s还了礼，和当年一样" % pn(), 8)
				out = "她还了一礼，和当年一样叫了一声“%s道友”。对面愣了愣，笑了。" % nm
			else:
				_wu(5)
				out = "她受了这一礼，点了点头。走出很远，才觉得手心里出了汗。（感悟 +5）"
			chron(p, "又遇见%s。当年要仰头看的人，如今平视了。" % nm)
		"白首":
			var th: String = ctx.get("thing", "一样东西")
			if oid == "take":
				_wu(10)
				remember(n, p, "把%s托付给了%s" % [th, pn()], 10)
				out = "她接下了%s。%s拍了拍她的手，拄着杖慢慢下了山。（感悟 +10）" % [th, nm]
				chron(p, "%s寿元将尽，来青庐看了她一眼，把%s托给了她。" % [nm, th])
			else:
				_wu(4)
				fav(n, 10, "最后几日在青庐住过", 15)
				out = "%s在青庐住了五日，天天坐在桂树下晒太阳。第六日一早，留下%s，自己走了。（感悟 +4）" % [nm, th]
				chron(p, "%s寿元将尽，在青庐住了五日。" % nm)
			chron(n, "寿元将尽，去青庐看了%s一眼。" % pn())
		"借庐":
			var h2 := C(roles["H"])
			meet(n)
			if oid == "hide":
				var healed := _use("pill_quzhang")
				fav(n, 25 if not healed else 30, "青庐那七日", 25)
				R(h2, p)["g"] = int(_rel(h2, p)["g"]) + 15
				n["inj"] = 0 if healed else maxi(int(n["inj"]), 6)
				out = "她开了禁制。第三夜，%s在柴门外站了很久，到底没进来。第七日，%s走时，在门槛上叩了一个头。" % [h2["name"], nm] + ("\n（喂了一粒驱瘴丹，伤好得快）" if healed else "") + _swap_ks(n)
				chron(p, "%s被%s追杀，借青庐躲了七日。" % [nm, h2["name"]])
				chron(n, "被%s追杀，在%s的青庐躲了七日。" % [h2["name"], pn()])
				schedule(rng.randi_range(12, 25), "报恩", {"B": int(n["id"])}, {"where": "青庐的禁制里"})
				if ctx.get("foe", false):
					remember(n, p, "%s不计前嫌，收留了我" % pn(), 20, "庇")
					R(p, n)["g"] = maxi(0, int(_rel(p, n)["g"]) - 20)
					out += "\n旧账她没提。%s也没提，只是走时多看了她一眼。" % nm
					chron(p, "收留了伤过自己的%s，旧账没提。" % nm)
			elif oid == "seize":
				if _roll(float(plv()) + 3.0, float(n["lv"]), 5, 3):
					out = "她没开禁制，开的是剑匣。%s伤得太重，没撑过三招。%s的脚步声在门外停了停，走远了。" % [nm, h2["name"]]
					chron(p, "%s走投无路叩青庐的门，她了结了那笔旧账。" % nm)
					die(n, "被%s所斩" % pn())
				else:
					_inj(2)
					R(n, p)["g"] = int(_rel(n, p)["g"]) + 25
					out = "她拔了剑。%s伤成那样，还是硬接了一招，翻出篱笆不见了。\n（受了点伤：闭关炼化减半两个月）" % nm
					chron(p, "%s来借庐，她想了结旧账，被对方逃了。" % nm)
			elif oid == "path":
				fav(n, 8, "%s指了一条路" % pn(), 8)
				out = "她指了后山那条采药的小路。%s道了声谢，没入雨里。" % nm
				chron(p, "替被追杀的%s指了一条后山小路。" % nm)
			else:
				fav(n, -8, "那夜%s没开门" % pn(), -10)
				_wu(2)
				out = "她没开门。外头的脚步声停了很久，才走远。那一夜她没睡着。（感悟 +2）"
				chron(p, "%s被追杀，叩青庐的门，她没开。" % nm)
		"点化":
			if oid == "send":
				out = "她塞了两个饼，叫孩子下山去。孩子走得很慢，一步一回头。"
				chron(p, "打发走了柴门外的孩子%s。" % nm)
			else:
				meet(n)
				n["dh"] = int(w["day"])
				n["lv"] = int(n["lv"]) + 1
				if oid == "pill" and _use("pill_juqi"):
					out = "她给了孩子一粒聚气丹，只说：“引气不是攥，是放。”第二日一早，孩子在柴门外入了一层，哭着磕了个头。\n（用去聚气丹 ×1）"
				else:
					out = "她只说了一句：“引气不是攥，是放。”孩子在柴门外坐了一夜。天亮时，入了一层。"
				fav(n, 20, "%s那一句话" % pn(), 25)
				chron(p, "点拨了柴门外的孩子%s一句。" % nm)
				schedule(rng.randi_range(25, 40), "点化回响", {"B": int(n["id"])})
		"点化回响":
			n["lv"] = maxi(int(n["lv"]), plv() + 3)
			n["log"].insert(0, [int(n.get("dh", 0)), "微末时于青庐外得%s一语点醒，方有今日。" % pn()])
			if oid == "tea":
				fav(n, 8)
				_wu(6)
				out = "%s喝了茶，说起这些年的事，说到一半，忽然站起来又行了一礼。临走留下一匣灵石。（感悟 +6，灵石 +6）" % nm
			else:
				_wu(4)
				out = "她受了这一礼。%s留下一匣灵石，领着弟子下山了。（感悟 +4，灵石 +6）" % nm
			_ling(6)
			chron(p, "当年柴门外的孩子%s，如今已是%s，上山来谢她。" % [nm, realm(n)])
			rumor("%s逢人便说，自己微末时在青庐外得%s一语点醒。" % [nm, pn()], [n])
		"家书", "夜雨", "灵田", "飞升异象", "旧物", "宗门大比", "师门书信":
			pass
	return out

func _pill_text(pid: String, nm: String) -> String:
	var pn2: String = String(GameState.NAMES.get(pid, "丹")) if g != null else "丹"
	return pv("求助丹", ["她把一粒自炼的%s化在水里喂下去。不到一个时辰，%s脸上就有了血色，睁眼看着她：“这丹……是你炼的？”" % [pn2, nm],
		"丹是青庐的炉子出的，药气里还带着灵田的土味。%s服下，第二日便能坐起来了。" % nm])

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
