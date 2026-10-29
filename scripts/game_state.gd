class_name GameState
extends RefCounted
## 《青庐远行》规则层（纯逻辑，无 UI）
## v0.13：一回合 = 一个月（存档里字段仍叫 day，含义是“第几个月”）；境界往后走到化神、寿元按年（docs/design/redesign-v0.13.md）
## 纯规则层：design-v3.1 §2 时间与结算规则、§4 经营、§6 心魔、§8.3 批量操作。
## 不依赖 UI，可被无头测试直接驱动；全部状态在字典 s 里，可整体存读档。

const SAVE_VERSION := 5      # v0.14.2 v5：炼气修为 600 → 1800（v4 及以前读入时炼气修为 ×3，层数不变）；v0.14 v4：行囊装备（s.gear；v3 读入时补一只布囊，原物不动）； v0.6 v2：江湖与立绘；v0.13 v3：回合=月、境界往后、去掉旧开局的亲戚设定（v1/v2 读入时迁移）
const World = preload("res://scripts/world.gd")
const TV = preload("res://scripts/travel.gd")
const Gear = preload("res://scripts/gear.gd")
const Econ = preload("res://scripts/econ.gd")   # v0.15 经济：聚灵阵、服丹闭关、蒙尘、药铺、托售
const Jobs = preload("res://scripts/jobs.gd")   # v0.15.2 坊市差事：代炼、客卿、悬赏
const FIELD_DAYS := 6
const FIELD_YIELD := 2
const RECIPES := {
	"juqi": {"qz": 2, "days": 2, "out": "pill_juqi", "name": "聚气丹"},
	"quzhang": {"qz": 1, "days": 1, "out": "pill_quzhang", "name": "驱瘴丹"},
	"zhuji": {"qz": 3, "days": 6, "out": "pill_zhuji", "name": "筑基丹",
		"main": {"herb_hantanlian": 1, "herb_chiyangguo": 1}},
}
const JUQI_XW := 60          # v0.14.2：炼气 600 → 1800，聚气丹 30 → 60（八颗约占炼气修为的四分之一）
const JUQI_SOFTCAP := 8
const BIGUAN_XW := 12        # v0.14.2：闭关每月 10 → 12
const REFINE_CAP := 20
const XW_GOAL := 1800         # v0.14.2（制作人 2026-10-29 同意）：炼气 600 → 1800，每层 200
const YUYUN_CAP := 120
const WU_SOFTCAP := 140
const RATION_TOPUP := 8
const RATION_CAP := 12
const PACK_SLOTS := 6
const SLOT_STACK := 5
const BASKET_CAP := 30
const SHUI_LIAN_DAYS := 20
const XIANGYANG_DEADLINE := 23
const ZHUJI_RATE := 0.7
const ZHUJI_SECOND_DAYS := 3
const ZHAJI_YUYUN := 20
const AGE0 := 16              # v0.13：十六岁开局
const SHOUYUAN_START := 100 * 12 - AGE0 * 12   # v0.13：炼气寿元 100 年（按月计），开局余 84 年
## v0.13：筑基以后（lv 9–18，与江湖人物同一张境界表）：每月闭关所得、每个小境界所需修为
const XW_BIGUAN_BY_MAJOR := [12, 14, 20, 28, 36]   # 炼气 / 筑基 / 金丹 / 元婴 / 化神
const XW_STAGE_BY_MAJOR := [1800, 2000, 6000, 18000, 30000]
const GATES := {11: 0.55, 14: 0.45, 17: 0.35, 18: 0.40}   # 大关成功率：→金丹 / →元婴 / →化神 / 渡劫
const GATE_FAIL_INJ := 12
const GATE_FAIL_SHOU := 60
const LAOGUI_A_BASE := 0.35
const LAOGUI_A_PER_LAYER := 0.05
const LAOGUI_A_MAX := 0.8
const REBUILD_DAYS := 1
const REBUILD_LINGSHI := 10
const GELAOSAN_FRUIT_PRICE := 20

const NAMES := {
	"res_lingshi": "灵石", "res_xiuwei": "修为", "res_ganwu": "感悟", "res_xinjing": "心境",
	"res_shouyuan": "寿元", "res_ganliang": "辟谷丹", "herb_qingzhi": "青芝", "seed_lianzi": "寒潭莲子",
	"herb_hantanlian": "寒潭莲", "herb_chiyangguo": "赤阳果", "herb_xugucao": "续骨草", "crop_linggu": "灵谷",
	"pill_juqi": "聚气丹", "pill_quzhang": "驱瘴丹", "pill_zhuji": "筑基丹",
	"fu_bishui": "避水符", "fu_jingshui": "净水符", "fu_dingfeng_can": "残符·定风",
}
## 随身行囊装符与丹；采药篓装草药、种子、作物
const PACK_KINDS := ["fu_", "pill_"]

var s: Dictionary = {}
var events: Dictionary = {}
var routes: Dictionary = {}
var xinmo: Dictionary = {}
var rng := RandomNumberGenerator.new()
var on_tick: Callable = Callable()   # 测试钩子：每日结算后回调 snapshot()
var notices: Array = []              # 给 UI 的一次性提示
var world = null                     # 江湖（scripts/world.gd）；没开江湖的档（规则测试）为 null

func _init() -> void:
	events = _load_json("res://data/events.json")
	routes = _load_json("res://data/routes.json")
	xinmo = _load_json("res://data/xinmo.json")

static func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("missing " + path)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

# ---------------------------------------------------------------- 开局 / 存读档
func new_game(name: String, cherish: String, seed: int = -1, with_world: bool = false) -> void:
	if seed < 0:
		seed = int(Time.get_unix_time_from_system()) ^ randi()
	rng.seed = seed
	if cherish == "aunt":
		cherish = "sect"   # v0.13：旧开局的选项，换成“山门”
	s = {
		"v": SAVE_VERSION, "day": 0, "name": name, "cherish": cherish,
		"xiuwei": 0, "yuyun": 0, "ganwu": 0, "wu_lost": 0,
		"src": {"biguan": 0, "ganwu": 0, "dan": 0},
		"shouyuan": SHOUYUAN_START, "hunger_days": 0, "lingshi": 20,
		"fields": [{"prog": 0}, {"prog": 0}], "extra": "",
		"gu_prog": 0, "lian_prog": -1,
		"queue": [], "zhuji_second": false, "debug_zhuji": "",
		"store": {}, "ration": 8, "tu": "month", "plv": 0,
		"pack": [{"id": "fu_bishui", "n": 1, "key": false}], "basket": {},
		"flags": {}, "tags": {"力": 0, "利": 0, "善": 0, "避": 0},
		"memory": [], "log": [], "roadbook": {},
		"injured": 0, "unstable": 0,
		"loc": "home", "trip": {}, "trips_done": 0,
		"juqi_eaten": 0, "juqi_brewed": 0,
		"pending_overflow": [], "xm": {}, "ended": false, "ending": "",
		"stats": {"biguan_days": 0, "trip_days": 0, "heavy": 0, "light": 0, "revisit": 0, "started_ms": Time.get_ticks_msec()},
		"rng": 0,
	}
	Gear.ensure(self)
	_log("%s 十六岁，外门落选，租下后山脚下的旧洞府青庐，做了散修。" % name)
	world = null
	if with_world:
		start_world(seed)

## 开江湖：程序生成 20 个人物；种子与规则 rng 分开，不影响 v3.2 的数值序列
func start_world(seed: int) -> void:
	world = World.new()
	world.create(seed ^ 0x5EED5, String(s.get("name", "")), self)
	s["world"] = world.w

func to_dict() -> Dictionary:
	s["rng"] = rng.state
	s["rng_seed"] = rng.seed
	return s.duplicate(true)

func from_dict(d: Dictionary) -> bool:
	if not d.has("v") or not (int(d["v"]) in [1, 2, 3, 4, SAVE_VERSION]):
		return false
	s = d.duplicate(true)
	var v0 := int(s["v"])
	if v0 < 3:
		_migrate_v3()
	if v0 < 5:
		_migrate_v5()
	Gear.ensure(self)   # v3 → v4：只补字段，原有行囊、仓库、灵石都不动
	s["v"] = SAVE_VERSION   # v1 → v2：字段只增不减；江湖由界面层决定是否补开（migrate_world）
	world = null
	if s.has("world") and s["world"] is Dictionary:
		world = World.new()
		world.attach(self, s["world"])
	# JSON 读回的数字是 float，关键整数字段归一
	for k in ["day", "xiuwei", "yuyun", "ganwu", "lingshi", "ration", "shouyuan", "injured", "unstable"]:
		s[k] = int(s[k])
	rng.seed = int(s.get("rng_seed", 0))
	rng.state = int(s.get("rng", 0))
	return true

## v0.13 迁移（v1/v2 → v3）：旧档的“第 N 日”原样当“第 N 月”（经历一件不丢）；寿元按年龄与境界重算；
## 旧开局“亲戚处寄存”的干粮并进辟谷丹（多的存成灵谷）；筑基结局不再是结局，从筑基初期接着修
func _migrate_v3() -> void:
	s["tu"] = "month"
	if String(s.get("cherish", "")) == "aunt":
		s["cherish"] = "sect"
	var ar := int(s.get("aunt_ration", 0))
	s.erase("aunt_ration")
	if ar > 0:
		var put := mini(ar, RATION_CAP - int(s.get("ration", 0)))
		s["ration"] = int(s.get("ration", 0)) + maxi(put, 0)
		if ar - maxi(put, 0) > 0:
			s["store"]["crop_linggu"] = int(s["store"].get("crop_linggu", 0)) + ar - maxi(put, 0)
	s["flags"].erase("letter_pending")
	s["plv"] = 0
	if bool(s.get("ended", false)) and String(s.get("ending", "")) == "zhuji":
		s["ended"] = false
		s["ending"] = ""
		s["loc"] = "home"
		s["plv"] = 9
		s["xiuwei"] = 0
		s["flags"]["migr_zhuji"] = true
	if not bool(s.get("ended", false)):
		s["shouyuan"] = maxi(12, lifespan_m() - age_m_of(int(s.get("day", 0))))
	s["flags"]["migr_v3"] = true

## v0.14.2 迁移（v4 及以前 → v5）：炼气修为上限 600 → 1800。还在炼气的，修为 ×3（层数、圆满与否都不变，谁也不掉层）；
## 筑基以后（plv ≥ 9）各境界的修为表没动，原样
func _migrate_v5() -> void:
	if int(s.get("plv", 0)) < 9:
		s["xiuwei"] = int(s.get("xiuwei", 0)) * 3
	s["flags"]["migr_v5"] = true

# ---------------------------------------------------------------- 年月 / 境界 / 寿元（v0.13）
static func age_m_of(day: int) -> int:
	return AGE0 * 12 + day

func age_m() -> int:
	return age_m_of(I("day"))

func age_y() -> int:
	return int(age_m() / 12)

## 当前境界 lv（0–8 炼气按修为算层；9 起按 plv）
func plv_now() -> int:
	return I("plv") if I("plv") >= 9 else layer() - 1

func major() -> int:
	var lv := plv_now()
	return 0 if lv < 9 else mini(4, 1 + int((lv - 9) / 3))

func lifespan_m() -> int:
	return World.lifespan(plv_now() if I("plv") >= 9 else 0) * 12

func xw_goal() -> int:
	return XW_GOAL if I("plv") < 9 else int(XW_STAGE_BY_MAJOR[major()])

func biguan_xw() -> int:
	return BIGUAN_XW if I("plv") < 9 else int(XW_BIGUAN_BY_MAJOR[major()])

## 修为满、要冲大关了（炼气圆满 → 筑基；筑基后期 → 金丹；金丹后期 → 元婴；元婴后期 → 化神；化神圆满 → 渡劫）
func at_gate() -> bool:
	if I("xiuwei") < xw_goal():
		return false
	return I("plv") < 9 or GATES.has(I("plv"))

func gate_name() -> String:
	match I("plv"):
		11: return "结丹"
		14: return "凝婴"
		17: return "化神"
		18: return "渡劫"
	return "筑基"

## 小境界：修为满了自动进（筑基初→中→后 等），多出来的修为带过去
func _stage_up() -> void:
	while I("plv") >= 9 and not GATES.has(I("plv")) and I("xiuwei") >= xw_goal():
		s["xiuwei"] = I("xiuwei") - xw_goal()
		s["plv"] = I("plv") + 1
		_log("修为渐深，入%s。" % realm_text())
		pchron(("闭关中，修为渐深，入%s。" if bool(s.get("seclude", false)) else "修为渐深，入%s。") % realm_text(), I("day"), {"入": realm_text()})
		notice("境界：%s" % realm_text())

func shou_years() -> int:
	return int(ceil(I("shouyuan") / 12.0))

## v0.15：寿元上限（岁）＝（现在的月龄 + 剩余寿元月）整除 12；每月一减一增，不会 99/100 来回跳
func shou_limit_y() -> int:
	return int((age_m() + I("shouyuan")) / 12)

## v0.15：sim / 测试看经济账
func econ_summary() -> Dictionary:
	return Econ.summary(self)

# ---------------------------------------------------------------- 基础量
func I(k: String) -> int:
	return int(s.get(k, 0))

func store_n(id: String) -> int:
	return int(s["store"].get(id, 0))

func pack_n(id: String) -> int:
	var n := 0
	for sl in s["pack"]:
		if sl["id"] == id:
			n += int(sl["n"])
	return n

func basket_n(id: String) -> int:
	return int(s["basket"].get(id, 0))

func basket_total() -> int:
	var n := 0
	for k in s["basket"]:
		n += int(s["basket"][k])
	return n

func total_n(id: String) -> int:
	return store_n(id) + pack_n(id) + basket_n(id)

## 当前可用数量：路上只算随身行囊 + 采药篓；在家算仓 + 行囊
func avail_n(id: String) -> int:
	if away():
		return pack_n(id) + basket_n(id)
	return store_n(id) + pack_n(id)

## v3.2：老龟 A 不再卡境界，成功率随炼气层数上升：35% + 5%×层，封顶 80%
func laogui_a_chance() -> float:
	return minf(LAOGUI_A_MAX, LAOGUI_A_BASE + LAOGUI_A_PER_LAYER * layer())

func layer() -> int:
	if I("plv") >= 9:
		return 9
	return min(9, 1 + int(I("xiuwei") * 9 / XW_GOAL))

func realm_text() -> String:
	if I("plv") >= 9:
		var t := World.realm_name(I("plv"))
		return t + ("圆满" if I("plv") == 18 and I("xiuwei") >= xw_goal() else "")
	if I("xiuwei") >= XW_GOAL:
		return "炼气圆满"
	return "炼气%s层" % ["一", "二", "三", "四", "五", "六", "七", "八", "九"][layer() - 1]

func _log(t: String) -> void:
	# v0.14.1：同一个月解锁好几处新去处，行记里也并成一条（出关通知里早就并了）
	# v0.15.2：同一个月里中间隔了别的行记也并；一次长闭关里陆续认得的路，并进这次闭关的第一条
	if t.begins_with("新去处：") and not s["log"].is_empty():
		var since := int(s.get("sec_m0", I("day"))) if bool(s.get("seclude", false)) else I("day")
		for i in range(s["log"].size() - 1, -1, -1):
			var last: Dictionary = s["log"][i]
			if int(last["day"]) < since:
				break
			var lt := String(last["text"])
			if lt.begins_with("新去处："):
				var prev := lt.substr(4).get_slice("——", 0).get_slice("。", 0)
				var nm := t.substr(4).get_slice("。", 0)
				last["text"] = "新去处：%s、%s——这几处的路，她都认得了。" % [prev, nm]
				return
	s["log"].append({"day": I("day"), "text": t})

## v0.14：她自己的履历（江湖里人物卡上的那份，按年月）。day<0 = 江湖当月；补记旧月份时按日子插进去，不打乱先后
## v0.15：fx = 这条下面的小字效果（修为、寿元、境界……）；当月的写法走 world.chron，别处挂的效果也能挂上
func pchron(t: String, day: int = -1, fx: Dictionary = {}) -> void:
	if world == null:
		return
	var lg: Array = world.P()["log"]
	var d := int(world.w["day"]) if day < 0 else day
	var e := [d, t, fx] if not fx.is_empty() else [d, t]
	if d == int(world.w["day"]):
		world.fx_attach(world.P(), e)
	var at := lg.size()
	while at > 0 and int(lg[at - 1][0]) > d:
		at -= 1
	lg.insert(at, e)
	World.trim_log(lg, World.PLOG_CAP)

## v0.13.1（Gemini v6 P0-6）：一样的话只留一条（长闭关不再五遍“赤阳果要熟了”）；
## 一次解锁好几处新去处，并成一条
func notice(t: String) -> void:
	if t in notices:
		return
	if t.begins_with("新去处："):
		var nm := t.substr(4).get_slice("——", 0)
		for i in notices.size():
			if String(notices[i]).begins_with("新去处："):
				var prev := String(notices[i]).substr(4).get_slice("——", 0)
				notices[i] = "新去处：%s、%s——这几处的路，她都认得了。" % [prev, nm]
				return
	notices.append(t)

# ---------------------------------------------------------------- 物品进出
func _is_pack_kind(id: String) -> bool:
	for p in PACK_KINDS:
		if id.begins_with(p):
			return true
	return false

func _store_add(id: String, n: int) -> void:
	s["store"][id] = store_n(id) + n
	if int(s["store"][id]) <= 0:
		s["store"].erase(id)

func add_item(id: String, n: int) -> void:
	if n <= 0:
		return
	if not away():
		_store_add(id, n)
		return
	if _is_pack_kind(id):
		for i in n:
			if not _pack_add_one(id, false):
				s["pending_overflow"].append(id)
	else:
		var room := BASKET_CAP - basket_total()
		var put := mini(room, n)
		if put > 0:
			s["basket"][id] = basket_n(id) + put
		if n > put:
			notice("采药篓已满（%d 件），%s ×%d 没装下。" % [BASKET_CAP, NAMES.get(id, id), n - put])

func _pack_add_one(id: String, key: bool) -> bool:
	for sl in s["pack"]:
		if sl["id"] == id and int(sl["n"]) < SLOT_STACK and bool(sl["key"]) == key:
			sl["n"] = int(sl["n"]) + 1
			return true
	if s["pack"].size() < Gear.cells(self):   # v0.14：格数看储物袋（布囊 6 格 = 原先的 PACK_SLOTS）
		s["pack"].append({"id": id, "n": 1, "key": key})
		return true
	return false

func _pack_remove(id: String, n: int, allow_key: bool = true) -> int:
	var left := n
	# 先用不带“钥匙”标记的
	for pass_key in [false, true]:
		if pass_key and not allow_key:
			break
		for sl in s["pack"]:
			if left <= 0:
				break
			if sl["id"] == id and bool(sl["key"]) == pass_key:
				var t := mini(left, int(sl["n"]))
				sl["n"] = int(sl["n"]) - t
				left -= t
	s["pack"] = s["pack"].filter(func(x): return int(x["n"]) > 0)
	return n - left

func consume(id: String, n: int) -> bool:
	if avail_n(id) < n:
		return false
	var left := n
	if away():
		var b := mini(left, basket_n(id))
		if b > 0:
			s["basket"][id] = basket_n(id) - b
			if basket_n(id) == 0:
				s["basket"].erase(id)
			left -= b
		left -= _pack_remove(id, left)
	else:
		var t := mini(left, store_n(id))
		_store_add(id, -t)
		left -= t
		left -= _pack_remove(id, left)
	return left == 0

## 行囊溢出：玩家选扔掉哪一格（slot>=0）或不要新物品（-1）
func resolve_overflow(slot: int) -> void:
	if s["pending_overflow"].is_empty():
		return
	var id: String = s["pending_overflow"].pop_front()
	if slot >= 0 and slot < s["pack"].size():
		var old = s["pack"][slot]
		_log("行囊满了，扔下 %s ×%d。" % [NAMES.get(old["id"], old["id"]), int(old["n"])])
		s["pack"].remove_at(slot)
		_pack_add_one(id, false)
	else:
		_log("行囊满了，没带上 %s。" % NAMES.get(id, id))

# ---------------------------------------------------------------- 日结算（§2.3）
func gain(v: int, k: String) -> void:
	var lay0 := layer()
	var full0 := I("xiuwei") >= xw_goal()
	var room := xw_goal() - I("xiuwei")
	var a := mini(v, maxi(room, 0))
	s["xiuwei"] = I("xiuwei") + a
	s["src"][k] = int(s["src"][k]) + a
	s["yuyun"] = mini(YUYUN_CAP, I("yuyun") + (v - a))
	if I("plv") < 9:
		_lq_chron(lay0, full0)
	_stage_up()

## v0.14.2：炼气每过一层、修满到关口，当月记进她的履历（以前要等出关后界面补记，长闭关里过的几层会漏掉、顺序也颠倒）
func _lq_chron(lay0: int, full0: bool) -> void:
	var sec := "闭关中，" if bool(s.get("seclude", false)) else ""
	if I("xiuwei") >= xw_goal() and not full0:
		if int(s["flags"].get("gate_noted", -1)) != I("plv"):
			s["flags"]["gate_noted"] = I("plv")
			pchron("%s修为到了筑基的关口。" % sec, I("day"), {"修为": "%d/%d" % [I("xiuwei"), xw_goal()]})
	elif layer() > lay0:
		pchron("%s修为精进，入%s。" % [sec, realm_text()], I("day"), {"层数": layer() - lay0})

func add_wu(v: int) -> void:
	if v <= 0:
		return
	v = Gear.wu_bonus(self, v)
	var room := maxi(0, WU_SOFTCAP - I("ganwu"))
	var full := mini(v, room)
	var half := int((v - full) / 2)
	s["ganwu"] = I("ganwu") + full + half
	s["wu_lost"] = I("wu_lost") + (v - full - half)
	if v - full > 0:
		notice("思绪繁杂：待炼化已过 %d，新得感悟只计一半。" % WU_SOFTCAP)
	if not s["flags"].get("tut_wu", false):
		s["flags"]["tut_wu"] = true
		notice("感悟要回青庐闭关才能炼化成修为。")

## mode: "road" 路上 | "biguan" 闭关 | "home" 冲关等其他耗日
func tick(mode: String) -> void:
	s["day"] = I("day") + 1
	# ① 日初生产 + ② 收获入库（每块田独立判定，与 sim.py 同序）
	for f in s["fields"]:
		f["prog"] = int(f["prog"]) + 1
		if int(f["prog"]) >= FIELD_DAYS:
			f["prog"] = 0
			_store_add("herb_qingzhi", FIELD_YIELD)
	if s["extra"] == "shuitian":
		if int(s["lian_prog"]) < 0:
			s["gu_prog"] = int(s["gu_prog"]) + 1
			if int(s["gu_prog"]) >= FIELD_DAYS:
				s["gu_prog"] = 0
				_store_add("crop_linggu", 2)
				_store_add("herb_qingzhi", 1)
		else:
			s["lian_prog"] = int(s["lian_prog"]) + 1
			if int(s["lian_prog"]) >= SHUI_LIAN_DAYS:
				s["lian_prog"] = -1
				_store_add("herb_hantanlian", 1)
				_log("水田里的寒潭莲开了，一池清冷。")
				notice("水田的寒潭莲开了：寒潭莲 +1")
	if not s["queue"].is_empty() and not Jobs.furnace_busy(self):   # v0.15.2：炉上是替药铺代炼的单子，自家的丹停着
		var q = s["queue"][0]
		q[1] = int(q[1]) - 1
		if int(q[1]) <= 0:
			s["queue"].pop_front()
			_pill_done(String(q[0]))
	# ③ 当日消耗（v0.13 busy：为一件事在外奔波，在外游历时照样吃辟谷丹）
	if mode == "road" or (mode == "busy" and away()):
		s["stats"]["trip_days"] = int(s["stats"]["trip_days"]) + 1
		if I("ration") > 0:
			if not Gear.ration_saved(self):   # v0.14：戴着“辟谷”的戒指，攒够了省一颗
				s["ration"] = I("ration") - 1
		else:
			s["hunger_days"] = I("hunger_days") + 1
			s["shouyuan"] = I("shouyuan") - 1
			s["flags"]["hungry"] = true
	elif mode == "biguan":
		s["stats"]["biguan_days"] = int(s["stats"]["biguan_days"]) + 1
		var cap := REFINE_CAP
		if I("injured") > 0:
			cap = int(cap / 2)
			s["injured"] = I("injured") - 1
		elif I("unstable") > 0:
			cap = int(cap / 2)
			s["unstable"] = I("unstable") - 1
		var r := mini(cap, I("ganwu"))
		s["ganwu"] = I("ganwu") - r
		gain(Econ.biguan_xw(self, Gear.xw_bonus(self, biguan_xw())), "biguan")   # v0.14：玉佩等加成；v0.15：聚灵阵、服丹、蒙尘（没开江湖时原样）
		gain(r, "ganwu")
	if (mode == "road" or mode == "busy") and I("ration") > 0:
		s["flags"].erase("hungry")
	s["shouyuan"] = I("shouyuan") - 1
	Gear.monthly(self)
	Econ.monthly(self, mode)
	# ④ 世事检查
	# v0.13：不再有“第 23 个月前”的倒计时——向阳坡每年五到八月结果；入夏时还没筑基、手里没赤阳果，就捎个话
	var cm := World.cal(I("day"))
	if int(cm[1]) == 5 and I("plv") < 9 and total_n("herb_chiyangguo") == 0 and total_n("pill_zhuji") == 0 and not zhuji_in_progress():
		notice("世事：入夏了，后山向阳坡的赤阳果又要熟了（五到八月，去后山游历时碰得上）。")
	# v0.13.1（Gemini v6 P0-1）：修到炼气七层，旧主手记里那页筑基丹方自己翻出来——三样主药各在哪、缺了去哪补
	if plv_now() >= 6 and I("plv") < 9 and not s["flags"].get("zhuji_hint", false):   # v0.14.2：炼气时 s.plv 一直是 0，要看 plv_now()（以前这条永远不触发）
		s["flags"]["zhuji_hint"] = true
		var have := []
		for it in [["herb_hantanlian", "寒潭莲"], ["herb_chiyangguo", "赤阳果"]]:
			have.append("%s %s" % [it[1], "有了" if total_n(it[0]) > 0 else "还缺"])
		notice("旧主手记翻到筑基丹那页：寒潭莲（灵脉水田里种寒潭莲子，莲子坊市旧货摊偶有）、赤阳果（后山五到八月；坊市药铺一年能收一颗晒干的）、青芝三株。眼下：%s。" % "、".join(have))
		_log("修到炼气七层，翻到旧主手记里的筑基丹方。")
	if I("day") > XIANGYANG_DEADLINE and not s["flags"].get("xiangyang_expired", false):
		s["flags"]["xiangyang_expired"] = true   # 只作“葛老三肯代采”的开关，不再是期限
	if I("shouyuan") <= 0 and not s["ended"]:
		_die_old()
	if world != null:
		# v0.9：路上（历练）也会碰上事；心魔/结局时世界只过日子
		var sec := bool(s.get("seclude", false))
		world.tick(mode != "road" and mode != "busy" and s["loc"] == "home" and not s["ended"] and not sec, mode == "road" and away() and not s["ended"])
	if on_tick.is_valid():
		on_tick.call(snapshot(mode))

func _pill_done(name: String) -> void:
	if name == "zhuji":
		var ok := true
		if not s["zhuji_second"]:
			match String(s.get("debug_zhuji", "")):
				"succeed": ok = true
				"fail": ok = false
				_: ok = rng.randf() < ZHUJI_RATE
		if not ok:
			s["zhuji_second"] = true
			_store_add("herb_hantanlian", 1)
			_store_add("herb_chiyangguo", 1)
			s["yuyun"] = mini(YUYUN_CAP, I("yuyun") + ZHAJI_YUYUN)
			_log("筑基丹成丹失败：主药保留，得筑基药渣（+%d 余韵）；第二炉 %d 个月必成。" % [ZHAJI_YUYUN, ZHUJI_SECOND_DAYS])
			notice("筑基丹没成：主药还在，第二炉 3 个月必成。")
			return
		_log("炉火渐熄，筑基丹成了，丹香满室。")
		notice("筑基丹出炉！")
	_store_add(RECIPES[name]["out"], 1)

func snapshot(mode: String = "") -> Dictionary:
	var q := []
	for x in s["queue"]:
		q.append([String(x[0]), int(x[1])])
	return {"day": I("day"), "mode": mode, "xiuwei": I("xiuwei"), "yuyun": I("yuyun"), "ganwu": I("ganwu"),
		"qingzhi": store_n("herb_qingzhi"), "ganliang": I("ration"), "lingshi": I("lingshi"), "queue": q,
		"ready": {"juqi": total_n("pill_juqi"), "quzhang": total_n("pill_quzhang"), "zhuji": total_n("pill_zhuji")},
		"lian": total_n("herb_hantanlian"), "guo": total_n("herb_chiyangguo")}

# ---------------------------------------------------------------- 在家操作（0 日）
func at_home() -> bool:
	return s["loc"] == "home" and not s["ended"]

## 出门在外（走路书 trip，或在某处游历 roam）：物品进采药篓、只能用随身的
func away() -> bool:
	return s["loc"] in ["trip", "roam"]

func can_enqueue(name: String) -> String:
	if not at_home():
		return "不在家"
	var r = RECIPES[name]
	if store_n("herb_qingzhi") < int(r["qz"]):
		return "青芝不足"
	if r.has("main"):
		for k in r["main"]:
			if store_n(k) < int(r["main"][k]):
				return "缺%s" % NAMES[k]
		if zhuji_in_progress():
			return "筑基丹已在炉中"
	return ""

func zhuji_in_progress() -> bool:
	for q in s["queue"]:
		if q[0] == "zhuji":
			return true
	return false

func enqueue(name: String) -> bool:
	if can_enqueue(name) != "":
		return false
	var r = RECIPES[name]
	_store_add("herb_qingzhi", -int(r["qz"]))
	var days := int(r["days"])
	if r.has("main"):
		for k in r["main"]:
			_store_add(k, -int(r["main"][k]))
		if s["zhuji_second"]:
			days = ZHUJI_SECOND_DAYS
	if name == "juqi":
		s["juqi_brewed"] = I("juqi_brewed") + 1
	s["queue"].append([name, days])   # ⑥ 从下一个日初开始计时
	return true

## 取消队尾未开始的丹，退回材料
func dequeue_last() -> bool:
	if not at_home() or s["queue"].is_empty():
		return false
	var q = s["queue"][-1]
	var r = RECIPES[q[0]]
	if int(q[1]) < (ZHUJI_SECOND_DAYS if (q[0] == "zhuji" and s["zhuji_second"]) else int(r["days"])):
		return false  # 已经开炉
	s["queue"].pop_back()
	_store_add("herb_qingzhi", int(r["qz"]))
	if r.has("main"):
		for k in r["main"]:
			_store_add(k, int(r["main"][k]))
	if q[0] == "juqi":
		s["juqi_brewed"] = I("juqi_brewed") - 1
	return true

## “按目标排程”：建议队列（玩家可改）——先筑基丹（主药齐），再用余下青芝排聚气丹到 8 颗
func auto_schedule() -> Array:
	var added := []
	if can_enqueue("zhuji") == "":
		enqueue("zhuji")
		added.append("zhuji")
	while I("juqi_brewed") < JUQI_SOFTCAP + int(s["flags"].get("juqi_given", 0)) and can_enqueue("juqi") == "":
		enqueue("juqi")
		added.append("juqi")
	return added

func eat_juqi_one() -> int:
	s["juqi_eaten"] = I("juqi_eaten") + 1
	var v := JUQI_XW if I("juqi_eaten") <= JUQI_SOFTCAP else int(JUQI_XW / 2)
	gain(v, "dan")
	return v

## 默认留作“钥匙”的数量：老龟还没了结、行囊里又没有聚气丹时，留 1 颗（§8.3）
func default_reserve() -> int:
	if s["flags"].get("laogui_done", false) or s["flags"].get("laogui", "") == "A":
		return 0
	if pack_n("pill_juqi") > 0:
		return 0
	return 1 if store_n("pill_juqi") > 0 else 0

## 服丹预览：[可服数量, 修为变化, 进余韵, 碰到减半线的颗数]
func eat_preview(reserve: int) -> Dictionary:
	var n := maxi(0, store_n("pill_juqi") - reserve)
	var eaten := I("juqi_eaten")
	var total := 0
	var halved := 0
	for i in n:
		eaten += 1
		if eaten > JUQI_SOFTCAP:
			halved += 1
			total += int(JUQI_XW / 2)
		else:
			total += JUQI_XW
	var to_xw := mini(total, maxi(0, xw_goal() - I("xiuwei")))
	return {"n": n, "xw": to_xw, "yuyun": total - to_xw, "halved": halved}

## “全部服下”：只吃仓里的，不动随身行囊（行囊里带“钥匙”标记的更不会动）
func eat_all(reserve: int) -> int:
	if not at_home():
		return 0
	var n := maxi(0, store_n("pill_juqi") - reserve)
	for i in n:
		_store_add("pill_juqi", -1)
		eat_juqi_one()
	return n

func choose_extra(kind: String) -> bool:
	if not at_home() or s["extra"] != "" or not (kind in ["field", "shuitian"]):
		return false
	s["extra"] = kind
	if kind == "field":
		s["fields"].append({"prog": 0})
		_log("灵脉第五点通了：开出第三块阳田。")
	else:
		s["gu_prog"] = 0
		_log("灵脉第五点通了：引潭水，开出一块水田。")
	return true

## v3.2：第 5 点改建：耗 1 日（不算闭关）+ 10 灵石；水田正在长莲时不能改
func can_rebuild_extra() -> String:
	if not at_home() or s["extra"] == "":
		return "还没定第 5 点"
	if int(s["lian_prog"]) >= 0:
		return "水田正在长莲"
	if I("lingshi") < REBUILD_LINGSHI:
		return "灵石不足（需 %d）" % REBUILD_LINGSHI
	return ""

func rebuild_extra() -> bool:
	if can_rebuild_extra() != "":
		return false
	s["lingshi"] = I("lingshi") - REBUILD_LINGSHI
	if s["extra"] == "field":
		s["fields"].pop_back()
		s["extra"] = "shuitian"
		s["gu_prog"] = 0
		_log("把第三块阳田改成了水田（−%d 灵石，1 个月）。" % REBUILD_LINGSHI)
	else:
		s["extra"] = "field"
		s["fields"].append({"prog": 0})
		_log("把水田改成了第三块阳田（−%d 灵石，1 个月）。" % REBUILD_LINGSHI)
	for i in REBUILD_DAYS:
		tick("home")
	return true

## v3.2：丹炉上下调整顺序（剩余日数跟着丹走；只有队首在推进）
func queue_move(i: int, d: int) -> bool:
	var j := i + d
	if not at_home() or i < 0 or j < 0 or i >= s["queue"].size() or j >= s["queue"].size():
		return false
	var t = s["queue"][i]
	s["queue"][i] = s["queue"][j]
	s["queue"][j] = t
	return true

## v3.2：行囊方案（3 个）：记下随身 6 格 + 干粮目标；一键装好（先把行囊全放回仓，再按方案取，缺的跳过）
func preset_save(k: int, label: String = "") -> void:
	if k < 0 or k > 2:
		return
	if not s.has("presets"):
		s["presets"] = [{}, {}, {}]
	s["presets"][k] = {"label": label if label != "" else "方案%d" % (k + 1), "pack": s["pack"].duplicate(true), "ration": I("ration")}

func preset_apply(k: int) -> Array:
	var missing := []
	if not at_home() or not s.has("presets") or s["presets"][k].is_empty():
		return missing
	while s["pack"].size() > 0:
		pack_take(0)
	for sl in s["presets"][k]["pack"]:
		for n in int(sl["n"]):
			if not pack_put(sl["id"], bool(sl["key"])):
				missing.append(sl["id"])
	var want := int(s["presets"][k]["ration"])
	if I("ration") < want:
		load_grain()
		buy_rations(want - I("ration"))
	if I("ration") < want:
		missing.append("res_ganliang")
	return missing

func can_plant_lianzi() -> bool:
	return at_home() and s["extra"] == "shuitian" and int(s["lian_prog"]) < 0 and store_n("seed_lianzi") > 0

func plant_lianzi() -> bool:
	if not can_plant_lianzi():
		return false
	_store_add("seed_lianzi", -1)
	s["lian_prog"] = 0
	s["flags"]["lian_planted_day"] = I("day")
	_log("水田种下寒潭莲子（%d 个月一熟）。" % SHUI_LIAN_DAYS)
	return true

## 播种当日取消退回种子（§2.5）
func cancel_lianzi() -> bool:
	if not at_home() or int(s["lian_prog"]) != 0 or int(s["flags"].get("lian_planted_day", -1)) != I("day"):
		return false
	s["lian_prog"] = -1
	_store_add("seed_lianzi", 1)
	return true

func buy_rations(n: int) -> int:
	if not at_home():
		return 0
	var k := mini(n, RATION_CAP - I("ration"))
	k = mini(k, I("lingshi"))
	k = maxi(k, 0)
	s["lingshi"] = I("lingshi") - k
	s["ration"] = I("ration") + k
	return k

## 仓中灵谷装袋（每 1 灵谷 = 1 日份），超过 12 的留在仓里
func load_grain() -> int:
	var k := mini(store_n("crop_linggu"), RATION_CAP - I("ration"))
	k = maxi(k, 0)
	_store_add("crop_linggu", -k)
	s["ration"] = I("ration") + k
	return k

func pack_put(id: String, key: bool = false) -> bool:
	if not at_home() or store_n(id) <= 0 or not _is_pack_kind(id):
		return false
	if not _pack_add_one(id, key):
		return false
	_store_add(id, -1)
	return true

func pack_take(slot: int) -> bool:
	if not at_home() or slot < 0 or slot >= s["pack"].size():
		return false
	var sl = s["pack"][slot]
	_store_add(sl["id"], int(sl["n"]))
	s["pack"].remove_at(slot)
	return true

func toggle_key(slot: int) -> void:
	if slot >= 0 and slot < s["pack"].size():
		s["pack"][slot]["key"] = not bool(s["pack"][slot]["key"])

func gelaosan_fruit_available() -> bool:
	return at_home() and s["flags"].get("xiangyang_expired", false) and total_n("herb_chiyangguo") == 0 \
		and not zhuji_in_progress() and total_n("pill_zhuji") == 0 and not s["flags"].get("gelaosan_sent", false)

func buy_gelaosan_fruit() -> bool:
	if not gelaosan_fruit_available() or I("lingshi") < GELAOSAN_FRUIT_PRICE:
		return false
	s["lingshi"] = I("lingshi") - GELAOSAN_FRUIT_PRICE
	_store_add("herb_chiyangguo", 1)
	s["flags"]["gelaosan_sent"] = true
	s["tags"]["利"] = int(s["tags"]["利"]) + 1
	_log("葛老三托人送来一颗赤阳果（−%d 灵石）。" % GELAOSAN_FRUIT_PRICE)
	return true

# ---------------------------------------------------------------- 闭关（§8.3 三种预设）
func biguan_day() -> bool:
	if not at_home():
		return false
	tick("biguan")
	return true

## preset: "refine" 炼完为止 | "pill" 到丹成（target=丹名）| "days" N 个月 | "years" N 年 | "gate" 到该冲关
## v0.13：一次闭关满一年（或选“到破境”）算长闭关：江湖照常按月过，但事不找上门；出关时 s.last_seclude 给“这些年”的摘要。
## 提前出关：修为满该冲关了、寿元余不到 5 年、丹成（“到丹成”）
const SECLUDE_MIN := 12
const SECLUDE_MAX := 1200
func biguan(preset: String, n: int = 1, target: String = "") -> int:
	var done := 0
	var start_cnt := total_n(RECIPES[target]["out"]) if target != "" and RECIPES.has(target) else 0
	var months := n * 12 if preset == "years" else n
	var long := (preset in ["years", "gate"]) or (preset == "days" and n >= SECLUDE_MIN)
	# v0.14.1：修为已满（卡在关口）还闭关：仍是一个月就出关，但不再写“入关 / 关口 / 出关”三笔，并成一行、连着的就累计月数
	var stalled := long and preset != "gate" and at_gate()
	if stalled:
		long = false
		var m0 := int(world.w["day"]) if world != null else I("day")
		biguan_day()
		_stalled_chron(m0)
		return 1
	var sum := {"m0": I("day"), "xw0": I("xiuwei"), "r0": realm_text(), "w0": int(world.w["day"]) if world != null else 0, "sy0": I("shouyuan"), "plv0": I("plv")}
	if long:
		s["seclude"] = true
		s["sec_m0"] = I("day")
		sum["kn"] = _known_snapshot()
		# v0.15（Gemini v7 规则 C）：入关这一笔等出关时再写——写成一条“小传”（闭了多久、出关时的境界与年岁、这些年故人的大事），记在入关那个月
		sum["plan"] = {"years": "%s年" % World.cn_num(n), "gate": "闭到修为圆满", "days": "%s个月" % World.cn_num(n)}.get(preset, "")
	for i in SECLUDE_MAX:
		if not at_home():
			break
		match preset:
			"refine":
				if I("ganwu") <= 0:
					break
			"pill":
				if target == "" or total_n(RECIPES[target]["out"]) > start_cnt:
					break
				var inq := false
				for q in s["queue"]:
					if q[0] == target:
						inq = true
				if not inq:
					break
			"days", "years":
				if done >= months:
					break
			"gate":
				if at_gate() and I("injured") <= 0 and I("unstable") <= 0:
					break
		if long and done > 0 and (at_gate() and preset != "gate" or I("shouyuan") < 60):
			break
		if long and done > 0:
			var why := Econ.seclude_break(self)   # v0.15：阵法欠费停了、连着闭关五年蒙尘——出关
			if why != "":
				# 头一回单记一条；以后并进出关那条合并条（不然百年里同一句记二三十回）
				var ek := "told_" + ("dust" if why.contains("蒙") else "arr")
				var ed: Dictionary = Econ.E(self)
				if not bool(ed.get(ek, false)):
					ed[ek] = true
					pchron(why, -1, {"出关": "（%s）" % ("蒙尘" if why.contains("蒙") else "阵停")})
				sum["why"] = "心头蒙尘，坐不下去了" if why.contains("蒙") else "阵法停了"
				notice(why)
				break
		biguan_day()
		done += 1
		# v0.15（Gemini v7 规则 C）：不再每年一笔“闭关第 N 年”的套话；闭关里真出了事（走岔、顿悟、心魔、故人叩门……）
		# 由内容包 qinglu_chron 按月写成带效果的一条（world.tick → _p_month）
	s.erase("seclude")
	s.erase("sec_m0")
	if long and done > 0:
		_seclude_summary(sum, done)
	return done

func _stalled_chron(m0: int) -> void:
	if world == null:
		return
	if int(s["flags"].get("gate_noted", -1)) != I("plv"):
		s["flags"]["gate_noted"] = I("plv")
		pchron("修为到了%s的关口。" % gate_name(), m0, {"修为": "圆满"})
	var head := "修为停在%s的关口，" % gate_name()
	var lg: Array = world.P()["log"]
	var st: Array = s["flags"].get("stall", [-1, 0, 0])
	var n := 1
	if int(st[0]) == I("plv"):
		# 往回找几条：中间夹了一两件江湖事也接着并
		for k in range(lg.size() - 1, maxi(-1, lg.size() - 7), -1):
			if String(lg[k][1]).begins_with(head):
				n = int(st[1]) + 1
				m0 = int(st[2])
				lg.remove_at(k)
				break
	s["flags"]["stall"] = [I("plv"), n, m0]
	pchron(head + ("在静室里又坐了一个月，只攒了些余韵。" if n == 1 else "在静室里前后又坐了%s个月，只攒了些余韵。" % ("两" if n == 2 else World.cn_num(n))), m0)

func _seclude_summary(sum: Dictionary, done: int) -> void:
	var out := {"months": done, "from": int(sum["m0"]), "r0": sum["r0"], "r1": realm_text(), "lines": []}
	if world != null:
		var mine := []
		var rest := []
		for x in world.w["news"]:
			if int(x[0]) <= int(sum["w0"]):
				continue
			var k := false
			for i in x[2]:
				if world.known(world.C(i)):
					k = true
			(mine if k else rest).append("%s，%s" % [World.cal_short(int(x[0])), String(x[1])])
		out["lines"] = (mine.slice(maxi(0, mine.size() - 6)) + rest.slice(maxi(0, rest.size() - maxi(0, 6 - mine.size()))))
		out["n_news"] = mine.size() + rest.size()
	s["last_seclude"] = out
	_log("闭关%s，出关时已是%s。" % [span_text(done), date_text()])
	_seclude_chron(sum, done, out)

## v0.15：长闭关在履历里只写一条合并的（入关几年、出关时的境界、这些年听来的事和故人近况，见 _seclude_chron）；
## 关中的事（顿悟、走岔、心魔、灵脉涨潮…）由 qinglu_chron 包的 pmonth 事件写，每条都有效果
func _known_snapshot() -> Dictionary:
	var out := {}
	if world == null:
		return out
	for c in world.w["C"].values():
		if not c.get("player", false) and world.known(c):
			out[str(int(c["id"]))] = [int(c["lv"]), bool(c["alive"]), float(c["age"])]
	return out

func _seclude_chron(sum: Dictionary, done: int, out: Dictionary) -> void:
	if world == null:
		return
	# v0.14.1：“修为到了关口”每个关口只记一次（修为满了还闭关，不再一回回重记）
	if at_gate() and I("xiuwei") >= xw_goal() and int(s["flags"].get("gate_noted", -1)) != I("plv"):
		s["flags"]["gate_noted"] = I("plv")
		pchron("修为到了%s的关口。" % gate_name(), -1, {"修为": "圆满"})
	var efx := {}
	if I("plv") == int(sum.get("plv0", I("plv"))) and I("xiuwei") != int(sum["xw0"]):
		efx["修为"] = I("xiuwei") - int(sum["xw0"])
	if realm_text() != String(sum["r0"]):
		efx["入"] = realm_text()
	var sy := int((int(sum.get("sy0", I("shouyuan"))) - I("shouyuan")) / 12)
	if sy > 0:
		efx["寿元|年"] = -sy
	# 山外的事（v0.15，Gemini v7 P1）：只收与她相干的——相熟 / 结怨 / 师徒 / 道侣的人的大事，认识的人的生死与结侣；
	# 切磋胜负这类水词不进她的履历
	var heard := []
	for x in world.w["news"]:
		if int(x[0]) <= int(sum["w0"]):
			continue
		var t := String(x[1])
		var kd := String(x[3]) if x.size() > 3 else ""
		if t.contains("切磋") or t.contains("半招"):
			continue
		var close := false
		var kn0 := false
		for i in x[2]:
			var o: Dictionary = world.C(i)
			if o.is_empty() or not world.known(o):
				continue
			kn0 = true
			var r: Dictionary = world._rel(world.P(), o)
			if absi(int(r.get("f", 0))) >= 25 or int(r.get("g", 0)) >= 20 or not (r.get("t", []) as Array).is_empty():
				close = true
		if (close and kd in ["死", "侣", "破", "宝", "子", "徒"]) or (kn0 and kd in ["死", "侣"]):
			heard.append(t.trim_prefix("听说").trim_suffix("。"))
	# 认识的人：这些年坐化 / 破境（相熟的排前面）
	var kn: Dictionary = sum.get("kn", {})
	var lines := []
	var near := []
	for id in kn:
		var c: Dictionary = world.C(id)
		if c.is_empty():
			continue
		var was: Array = kn[id]
		var ln := ""
		if bool(was[1]) and not bool(c["alive"]):
			ln = "%s已经%s了" % [c["name"], "飞升" if c.get("asc", false) else "不在"]
		elif bool(c["alive"]) and World.major(int(c["lv"])) > World.major(int(was[0])):
			ln = "%s入了%s" % [c["name"], World.realm_name(int(c["lv"]))]
		elif bool(c["alive"]) and int(c["lv"]) > int(was[0]):
			ln = "%s入了%s" % [c["name"], World.realm_name(int(c["lv"]))]
		if ln == "":
			continue
		var rr: Dictionary = world._rel(world.P(), c)
		(near if absi(int(rr.get("f", 0))) >= 20 or not (rr.get("t", []) as Array).is_empty() else lines).append(ln)
	lines = near + lines
	var plan := String(sum.get("plan", ""))
	var txt := "入静室闭关%s。" % (plan if plan != "" and not plan.begins_with("闭") else span_text(done))
	if plan.begins_with("闭"):
		txt = "入静室闭关，说要%s；坐了%s。" % [plan, span_text(done)]
	elif span_text(done) != plan:
		txt = "入静室闭关，原说%s，坐了%s。" % [plan, span_text(done)]
	if sum.has("why"):
		txt += "%s。" % String(sum["why"])
	txt += "出关时%s岁，%s%s。" % [World.cn_num(age_y()), realm_text(), "，仍在原地" if realm_text() == String(sum["r0"]) and not efx.has("修为") else ""]
	var news := heard.slice(maxi(0, heard.size() - 3)) + lines.slice(0, maxi(0, 5 - mini(3, heard.size())))
	if not news.is_empty():
		txt += "这些年：%s。" % "；".join(news)
	pchron(txt, int(sum["w0"]), efx)
	out["people"] = lines.slice(0, 6)

## “三年零五个月”“十一个月”
static func span_text(m: int) -> String:
	var y := int(m / 12)
	var r := m % 12
	if y == 0:
		return "%s个月" % World.cn_num(r)
	return "%s年" % World.cn_num(y) + ("" if r == 0 else "零%s个月" % World.cn_num(r))

func xw_full_hint() -> String:
	if I("xiuwei") >= xw_goal() and at_gate():
		return "修为已满，继续闭关只会攒余韵（剩 %d 点到上限）" % (YUYUN_CAP - I("yuyun"))
	return ""

# ---------------------------------------------------------------- 条件
func check(c) -> bool:
	if c == null or not (c is Dictionary):
		return true
	for k in c:
		var v = c[k]
		match k:
			"flag":
				for f in v:
					if s["flags"].get(f, null) != v[f]:
						return false
			"not_flag":
				for f in v:
					if s["flags"].get(f, null) == v[f]:
						return false
			"has_item":
				for id in v:
					if avail_n(id) < int(v[id]):
						return false
			"min_layer":
				if layer() < int(v):
					return false
			"day_le":
				if I("day") > int(v):
					return false
			"flag_gt":
				for f in v:
					if int(s["flags"].get(f, 0)) <= int(v[f]):
						return false
			"tag_ge":
				for t in v:
					if int(s["tags"].get(t, 0)) < int(v[t]):
						return false
			"tag_le":
				for t in v:
					if int(s["tags"].get(t, 0)) > int(v[t]):
						return false
			"stat_ge":
				for t in v:
					if int(s["stats"].get(t, 0)) < int(v[t]):
						return false
			"stat_le":
				for t in v:
					if int(s["stats"].get(t, 0)) > int(v[t]):
						return false
			"else":
				pass
	return true

func cond_reason(c) -> String:
	if c is Dictionary:
		if c.has("has_item"):
			for id in c["has_item"]:
				if avail_n(id) < int(c["has_item"][id]):
					return "需%s ×%d（%s）" % [NAMES.get(id, id), int(c["has_item"][id]), "行囊里" if away() else "仓里"]
		if c.has("min_layer") and layer() < int(c["min_layer"]):
			return "需炼气%d层" % int(c["min_layer"])
	return "条件不足"

# ---------------------------------------------------------------- 历练：路线 / 节点状态机
## trip.stage: "choose" 选下一节点 | "event" 事件卡 | "quick" 快走 | "result" 结果卡
func start_trip(route_id: String) -> bool:
	if not at_home() or not routes.has(route_id) or not s["pending_overflow"].is_empty():
		return false
	s["loc"] = "trip"
	s["trip"] = {"route": route_id, "node": "", "walked": 0, "path": [], "stage": "choose",
		"choices": routes[route_id]["start"].duplicate(), "result": {}, "start_day": I("day"),
		"w0": int(world.w["day"]) if world != null else 0}
	_log("出发：%s。" % routes[route_id]["name"])
	return true

func route() -> Dictionary:
	return routes.get(s["trip"].get("route", ""), {})

func visible_choices() -> Array:
	var out := []
	var r := route()
	for nid in s["trip"].get("choices", []):
		var nd = r["nodes"].get(nid, {})
		if check(nd.get("visible_if", null)):
			out.append(nid)
	return out

func day_mod() -> int:
	var add := 0
	for m in route().get("day_mods", []):
		if check(m["if"]):
			add += int(m["add"])
	return add

func is_revisit(nid: String) -> bool:
	var ev = events[route()["nodes"][nid]["event"]]
	return bool(ev.get("once", false)) and s["roadbook"].has(s["trip"]["route"] + ":" + nid)

func enter_node(nid: String) -> bool:
	if s["loc"] != "trip" or s["trip"]["stage"] != "choose" or not (nid in visible_choices()):
		return false
	s["trip"]["node"] = nid
	s["trip"]["stage"] = "quick" if is_revisit(nid) else "event"
	return true

## 当前事件（已套用变体），选项带 enabled / reason
func event_view() -> Dictionary:
	var nid: String = s["trip"]["node"]
	var ev: Dictionary = events[route()["nodes"][nid]["event"]].duplicate(true)
	for vr in ev.get("variants", []):
		if check(vr["if"]):
			for k in vr:
				if k != "if":
					ev[k] = vr[k]
			break
	ev.erase("variants")
	var base_days := int(ev.get("days", 1))
	if base_days > 0:
		base_days += day_mod()
	if s["trip"].has("roam"):
		base_days = day_mod()   # 游历时碰上的：这个月已经过了；只有选项写明的耗时（和老龟记仇的雾）另算
	ev["base_days"] = base_days
	var opts := []
	for o in ev.get("options", []):
		if not check(o.get("visible_if", null)):
			continue
		var oo: Dictionary = o.duplicate(true)
		oo["enabled"] = check(o.get("requires", null))
		oo["reason"] = "" if oo["enabled"] else cond_reason(o.get("requires", null))
		oo["days"] = base_days + int(o.get("cost", {}).get("days", 0))
		opts.append(oo)
	ev["options"] = opts
	return ev

func _apply(e: Dictionary, res: Dictionary) -> void:
	if e.is_empty():
		return
	if e.has("ganwu"):
		add_wu(int(e["ganwu"]))
		res["ganwu"] = int(res.get("ganwu", 0)) + int(e["ganwu"])
	if e.has("items"):
		for id in e["items"]:
			add_item(id, int(e["items"][id]))
			res["items"][id] = int(res["items"].get(id, 0)) + int(e["items"][id])
	if e.has("lingshi"):
		s["lingshi"] = I("lingshi") + int(e["lingshi"])
		res["lingshi"] = int(res.get("lingshi", 0)) + int(e["lingshi"])
		if int(e["lingshi"]) > 0:
			s["tags"]["利"] = int(s["tags"]["利"]) + 1
	if e.has("flags"):
		for f in e["flags"]:
			s["flags"][f] = e["flags"][f]
	if e.has("tags"):
		for t in e["tags"]:
			s["tags"][t] = int(s["tags"].get(t, 0)) + 1
	if e.has("memory"):
		var m = e["memory"]
		s["memory"].append({"npc": m["npc"], "text": m["text"], "day": I("day")})
		res["memory"].append(m["npc"])
	if e.has("injure"):
		s["injured"] = maxi(I("injured"), int(e["injure"]))
		res["lines"].append("受伤：%d 个月内闭关炼化减半" % int(e["injure"]))
	if e.has("log"):
		_log(e["log"])
		res["lines"].append(e["log"])
	if e.has("goto"):
		res["goto"] = e["goto"]
	if e.has("end_trip"):
		res["end_trip"] = true

func resolve(opt_id: String) -> Dictionary:
	if s["loc"] != "trip" or s["trip"]["stage"] != "event":
		return {}
	var ev := event_view()
	var opt: Dictionary = {}
	for o in ev["options"]:
		if o["id"] == opt_id:
			opt = o
	if opt.is_empty() or not opt["enabled"]:
		return {}
	var res := {"title": ev["title"], "option": opt["label"], "days": int(opt["days"]), "items": {}, "lines": [], "memory": [], "ganwu": 0, "fog_used": day_mod() > 0 and int(ev["base_days"]) > 0}
	var cost: Dictionary = opt.get("cost", {})
	for id in cost.get("items", {}):
		consume(id, int(cost["items"][id]))
		res["items"][id] = -int(cost["items"][id])
		if id == "pill_juqi":
			s["flags"]["juqi_given"] = int(s["flags"].get("juqi_given", 0)) + int(cost["items"][id])
	for i in int(opt["days"]):
		tick("road")
		if s["ended"]:
			break
	s["trip"]["walked"] = int(s["trip"]["walked"]) + int(opt["days"])
	# sim.py 顺序：过日 → 节点感悟 → 选项效果
	var nid: String = s["trip"]["node"]
	add_wu(int(ev.get("ganwu", 0)))
	res["ganwu"] = int(ev.get("ganwu", 0))
	_apply(opt.get("effects", {}), res)
	if opt.has("roll"):
		var p := laogui_a_chance() if opt["roll"].get("chance_by_layer", false) else float(opt["roll"]["chance"])
		if s["flags"].get("hungry", false):
			p -= 0.2
		var ok := rng.randf() < p
		res["roll"] = "成" if ok else "败"
		_apply(opt["roll"]["success" if ok else "fail"], res)
	if opt.has("branch"):
		for b in opt["branch"]:
			if b.has("else") or check(b["if"]):
				_apply(b["effects"], res)
				break
	if opt.get("key", false):
		_log("◎ %s：%s" % [ev["title"], opt["label"]])
	var st := "heavy" if ev.get("heavy", false) else "light"
	s["stats"][st] = int(s["stats"][st]) + 1
	s["roadbook"][s["trip"]["route"] + ":" + nid] = true
	s["trip"]["path"].append(nid)
	_laogui_seed(ev, opt_id, res)
	_after_node(nid, res)
	return res

## v0.15（Gemini v7 P0·开局）：江湖里碰上的老龟，抢来的、陪坐换来的那朵莲离了潭水就谢，只剩一粒莲子——
## 得有水田种二十个月才开；拿聚气丹换、赔罪换的照旧是整朵（丹是自己炼的）。没开江湖的老路书（规则测试）原样
func _laogui_seed(ev: Dictionary, opt_id: String, res: Dictionary) -> void:
	if world == null or not in_vignette() or String(ev.get("key", "")) != "laogui" or not (opt_id in ["A", "C"]):
		return
	if int(res["items"].get("herb_hantanlian", 0)) <= 0 or total_n("herb_hantanlian") <= 0:
		return
	consume("herb_hantanlian", 1)
	add_item("seed_lianzi", 1)
	res["items"]["herb_hantanlian"] = int(res["items"]["herb_hantanlian"]) - 1
	if int(res["items"]["herb_hantanlian"]) == 0:
		res["items"].erase("herb_hantanlian")
	res["items"]["seed_lianzi"] = int(res["items"].get("seed_lianzi", 0)) + 1
	res["lines"].append("回到岸上，那朵莲离了潭水，转眼就谢了，只剩一粒莲子。得有水田才种得活。")
	_log("寒潭莲离水就谢，只落下一粒莲子。")

func quick_walk() -> Dictionary:
	if s["loc"] != "trip" or s["trip"]["stage"] != "quick":
		return {}
	var nid: String = s["trip"]["node"]
	var ev = events[route()["nodes"][nid]["event"]]
	var days := 1 + day_mod()
	for i in days:
		tick("road")
	s["trip"]["walked"] = int(s["trip"]["walked"]) + days
	s["stats"]["revisit"] = int(s["stats"]["revisit"]) + 1
	s["trip"]["path"].append(nid)
	var res := {"title": ev["title"], "option": "快走（路书已记）", "days": days, "items": {}, "lines": [], "memory": [], "ganwu": 0, "fog_used": day_mod() > 0}
	_after_node(nid, res)
	return res

func _after_node(nid: String, res: Dictionary) -> void:
	var nd = route()["nodes"][nid]
	if res.get("fog_used", false):
		s["flags"]["fog_left"] = maxi(0, int(s["flags"].get("fog_left", 0)) - 1)
	if res.get("goto", "") != "":
		s["trip"]["choices"] = [res["goto"]]
	else:
		s["trip"]["choices"] = nd.get("next", []).duplicate()
	s["trip"]["result"] = res
	s["trip"]["stage"] = "result"
	if s["trip"].has("roam"):
		res["end_trip"] = false
		if res.get("goto", "") != "":
			s["trip"]["roam"]["force"] = res["goto"]
		return
	if res.get("end_trip", false) or nd.get("end", false):
		res["end_trip"] = true

## 结果卡点“继续”
func continue_trip() -> void:
	if s["loc"] != "trip" or s["trip"]["stage"] != "result":
		return
	if s["trip"].has("roam"):
		var rm: Dictionary = s["trip"]["roam"]
		var res: Dictionary = s["trip"]["result"]
		s["loc"] = "roam"
		s["roam"] = rm
		roam_note("%s：%s" % [res.get("title", ""), res.get("option", "")])
		s["trip"] = {}
		return
	if s["trip"]["result"].get("end_trip", false):
		come_home(false)
	else:
		s["trip"]["stage"] = "choose"

## 半路折返：⌈已走日数 ÷ 2⌉ 日，每日照扣干粮，不触发事件
func turn_back_days() -> int:
	return int(ceil(int(s["trip"].get("walked", 0)) / 2.0))

func turn_back() -> int:
	if s["loc"] != "trip" or not (s["trip"]["stage"] in ["choose", "result"]):
		return -1
	var d := turn_back_days()
	for i in d:
		tick("road")
	_log("半路折返，走了 %d 个月回家。" % d)
	come_home(true)
	return d

func come_home(turned_back: bool) -> Dictionary:
	if s["ended"]:
		return {}
	var route_id: String = s["trip"].get("route", "")
	s["loc"] = "home"
	s["trips_done"] = I("trips_done") + 1
	var sum := {"basket": s["basket"].duplicate(), "ration_before": I("ration")}
	for id in s["basket"]:
		_store_add(id, int(s["basket"][id]))
	s["basket"] = {}
	# 辟谷丹（§2.4，v0.13 改）：仓中灵谷先装袋 → 葛老三按租约补到 8（旧开局的亲戚补给 / 家书加粮 / 寄存取消）
	load_grain()
	if I("ration") < RATION_TOPUP:
		s["ration"] = RATION_TOPUP
	s["flags"].erase("letter_pending")
	sum["ration_after"] = I("ration")
	sum["turned_back"] = turned_back
	if route_id == "hantan":
		s["flags"]["hantan_visited"] = true
	s["flags"]["fog_left"] = 0   # 潭雾只拖本趟
	# 世事：第一次从寒潭回来、结算完之后出现
	if route_id == "hantan" and not turned_back and not s["flags"].get("world_xiangyang", false):
		s["flags"]["world_xiangyang"] = true
		sum["world"] = "葛老三捎来口信：后山向阳坡的赤阳果每年五到八月结果，山下的人也盯着。"
		_log("世事：听说后山向阳坡的赤阳果每年五到八月结果。")
	# 江湖：出门这几天山外发生的事（优先认识的人），回家时一并听说
	if world != null:
		var w0 := int(s["trip"].get("w0", s.get("roam", {}).get("w0", 0)))
		var fresh := []
		for x in world.w["news"]:
			if int(x[0]) > w0:
				var mine := false
				for i in x[2]:
					if world.known(world.C(i)):
						mine = true
				fresh.append([0 if mine else 1, x[1]])
		fresh.sort_custom(func(a, b): return a[0] < b[0])
		var lines := []
		for f in fresh.slice(0, 3):
			lines.append(f[1])
		if not lines.is_empty():
			sum["news"] = lines
	s["trip"] = {}
	s["roam"] = {}
	s["last_home"] = sum
	_log("推开柴门，回到青庐（辟谷丹 %d → %d）。" % [sum["ration_before"], sum["ration_after"]])
	return sum

# ---------------------------------------------------------------- v0.11 游历：去一处地方，每天挑个小去处走走
## s["roam"] = {pl 所在, w0 出门时江湖日, d0 出门日, si 今天去的小去处, days 游历了几日, log 最近几行}
func roam() -> Dictionary:
	return s.get("roam", {}) if s["loc"] == "roam" else {}

func can_roam(pl: String) -> String:
	if world == null:
		return "江湖未开"
	if not TV.PL.has(pl):
		return "没有这个地方"
	if not TV.unlocked(world, pl):
		return "还不认得路"
	if not s["pending_overflow"].is_empty():
		return "行囊满了，先腾一格"
	return ""

func start_roam(pl: String) -> bool:
	if not at_home() or can_roam(pl) != "":
		return false
	s["loc"] = "roam"
	s["roam"] = {"pl": pl, "w0": int(world.w["day"]), "d0": I("day"), "si": -1, "days": 0, "log": []}
	_log("出发去%s。" % pl)
	_walk(TV.dist(TV.HOME, pl), pl)
	return true

func roam_note(t: String) -> void:
	if s["loc"] != "roam":
		return
	var lg: Array = s["roam"].get("log", [])
	lg.append([I("day"), t])
	s["roam"]["log"] = lg.slice(-5)

func _walk(d: int, pl: String) -> void:
	for i in d:
		if s["loc"] != "roam":
			return
		tick("road")
	roam_note("走了%d个月，到了%s。" % [d, pl])

## 游历一日：去第 i 个小去处（耗 1 日、1 份干粮）
func roam_spot(i: int) -> Dictionary:
	if s["loc"] != "roam" or s["ended"] or not world.pending().is_empty() or not s["pending_overflow"].is_empty():
		return {}
	tick("road")
	if s["loc"] != "roam":
		return {}
	var pl := String(s["roam"]["pl"])
	# v0.13：后山、寒潭的老路（葛老三、老龟、向阳坡……）不再是一条路书，成了在那里游历时会碰上的事
	var vg := _pick_vignette(pl)
	if vg != "":
		s["roam"]["si"] = i
		s["roam"]["days"] = int(s["roam"]["days"]) + 1
		_start_vignette(pl, vg)
		return {"text": "", "items": {}, "ls": 0, "wu": 0, "vignette": vg}
	var r: Dictionary = TV.roam_day(world, pl, i)
	for id in r["items"]:
		add_item(String(id), int(r["items"][id]))
	if int(r["ls"]) > 0:
		s["lingshi"] = I("lingshi") + int(r["ls"])
	if int(r["wu"]) > 0:
		add_wu(int(r["wu"]))
	s["roam"]["si"] = i
	s["roam"]["days"] = int(s["roam"]["days"]) + 1
	roam_note(String(r["text"]))
	return r

## ---- v0.13 地点奇遇：原路书节点按地点加权抽出来，选项照旧结算；结算完回到游历
const VIGNETTE_P := 0.4
const VIG_SKIP := ["H5", "T9", "T8", "Tpath"]
func _pick_vignette(pl: String) -> String:
	var rid := String(TV.PL.get(pl, {}).get("route", ""))
	if rid == "" or not routes.has(rid) or not world.pending().is_empty():
		return ""
	var force := String(s["roam"].get("force", ""))
	if force != "" and routes[rid]["nodes"].has(force):
		s["roam"].erase("force")
		return force
	if world.rng.randf() >= VIGNETTE_P:
		return ""
	var c := World.cal(I("day"))
	var seen_any := false
	for k in s["roadbook"]:
		if String(k).begins_with(rid + ":"):
			seen_any = true
	var last := String(s["flags"].get("vig_last", ""))
	var cands := []
	var ws := []
	for nid in routes[rid]["nodes"]:
		if nid in VIG_SKIP or nid == last:
			continue
		var nd: Dictionary = routes[rid]["nodes"][nid]
		var ev: Dictionary = events[nd["event"]]
		var wt := 1.0
		if nid == "Hstar":
			# 向阳坡的赤阳果：每年五到八月熟一回
			if int(c[1]) < 5 or int(c[1]) > 8 or int(s["flags"].get("xy_year", -1)) == int(c[0]):
				continue
			wt = 3.0
		elif nid == "T4":
			# 老龟：先在寒潭走过一回才碰得上；见过以后偶尔再见（赔罪、还愿）
			if not seen_any:
				continue
			if String(s["flags"].get("laogui", "")) != "" and I("day") - int(s["flags"].get("vig_cd", {}).get(nid, -999)) < 24:
				continue
			wt = 3.0 if String(s["flags"].get("laogui", "")) == "" else 0.3
		else:
			if bool(ev.get("once", false)) and s["roadbook"].has(rid + ":" + nid):
				continue
			if not check(nd.get("visible_if", null)):
				continue
			# 能重来的（寒潭野地、猎屋）隔一年才再碰上
			if I("day") - int(s["flags"].get("vig_cd", {}).get(nid, -999)) < 12:
				continue
		cands.append(nid)
		ws.append(wt)
	if cands.is_empty():
		return ""
	var tot := 0.0
	for x in ws:
		tot += x
	var r: float = world.rng.randf() * tot
	for k in cands.size():
		r -= ws[k]
		if r <= 0:
			return cands[k]
	return cands[-1]

func _start_vignette(pl: String, nid: String) -> void:
	var rid := String(TV.PL[pl]["route"])
	s["flags"]["vig_last"] = nid
	var cd: Dictionary = s["flags"].get("vig_cd", {})
	cd[nid] = I("day")
	s["flags"]["vig_cd"] = cd
	if nid == "Hstar":
		s["flags"]["world_xiangyang"] = true
		s["flags"].erase("xiangyang_done")
		s["flags"]["xy_year"] = int(World.cal(I("day"))[0])
	if rid == "hantan":
		s["flags"]["hantan_visited"] = true
	s["trip"] = {"route": rid, "node": nid, "walked": 0, "path": [], "stage": "event", "choices": [], "result": {},
		"start_day": I("day"), "w0": int(world.w["day"]), "roam": s["roam"].duplicate(true)}
	s["loc"] = "trip"

func in_vignette() -> bool:
	return s["loc"] == "trip" and s["trip"].has("roam")

## v0.13（P0#5）：事件里“赶去、躲进山、结伴走”的真实耗时——由江湖在事件关掉时调用
func spend_away(m: int, pl: String) -> void:
	if m <= 0 or s["ended"] or s["loc"] in ["xinmo", "ending"]:
		return
	var where := pl if pl != "" else "外头"
	_log("为这件事在%s耽了 %d 个月。" % [where, m])
	s["stats"]["away_months"] = int(s["stats"].get("away_months", 0)) + m
	for i in m:
		tick("busy")
		if s["ended"]:
			return
	if s["loc"] == "roam" and pl != "" and TV.PL.has(pl) and TV.unlocked(world, pl) and pl != String(s["roam"]["pl"]):
		s["roam"]["pl"] = pl
		s["roam"]["si"] = -1
		roam_note("跟着这件事到了%s。" % pl)

## 从这里去另一处已认得的地方
func roam_move(pl: String) -> bool:
	if s["loc"] != "roam" or not world.pending().is_empty() or can_roam(pl) != "" or pl == String(s["roam"]["pl"]):
		return false
	var d := TV.dist(String(s["roam"]["pl"]), pl)
	s["roam"]["pl"] = pl
	s["roam"]["si"] = -1
	_log("动身去%s。" % pl)
	_walk(d, pl)
	return true

func roam_home_days() -> int:
	return TV.dist(String(s["roam"].get("pl", TV.HOME)), TV.HOME) if s["loc"] == "roam" else 0

func roam_home() -> Dictionary:
	if s["loc"] != "roam" or not world.pending().is_empty():
		return {}
	var d := roam_home_days()
	for i in d:
		tick("road")
		if s["loc"] != "roam":
			return {}
	var info := "在%s一带游历了 %d 个月。" % [s["roam"]["pl"], int(s["roam"].get("days", 0))]
	_log("从%s回来，路上走了 %d 个月。" % [s["roam"]["pl"], d])
	var sum := come_home(false)
	if not sum.is_empty():
		sum["roam"] = info
		s["last_home"] = sum
	return sum

## v0.13：坊市旧货摊偶尔收到寒潭莲子（筑基主药的另一条路：买种子回水田种，二十个月开花），一年一回
const JUNK_LIANZI_PRICE := 35   # v0.15（Gemini v7 专项 1）：40 → 35
func junk_lianzi_available() -> bool:
	return s["loc"] == "roam" and String(s["roam"].get("pl", "")) == "坊市" and I("plv") < 9 \
		and total_n("seed_lianzi") == 0 and total_n("herb_hantanlian") == 0 and total_n("pill_zhuji") == 0 \
		and int(s["flags"].get("junk_lz_year", -1)) != int(World.cal(I("day"))[0])

## v0.13.1（Gemini v6 P0-1）：炼气七层以后还缺赤阳果，坊市药铺一年能收到一颗晒干的——比后山贵，但不必干等五到八月
const DRY_CHIYANG_PRICE := 45   # v0.15：60 → 45
func dry_chiyang_available() -> bool:
	return s["loc"] == "roam" and String(s["roam"].get("pl", "")) == "坊市" and plv_now() >= 6 and I("plv") < 9 \
		and total_n("herb_chiyangguo") == 0 and total_n("pill_zhuji") == 0 and not zhuji_in_progress() \
		and int(s["flags"].get("dry_cy_year", -1)) != int(World.cal(I("day"))[0])

func buy_dry_chiyang() -> bool:
	if not dry_chiyang_available() or I("lingshi") < DRY_CHIYANG_PRICE or not s["pending_overflow"].is_empty():
		return false
	s["lingshi"] = I("lingshi") - DRY_CHIYANG_PRICE
	s["flags"]["dry_cy_year"] = int(World.cal(I("day"))[0])
	add_item("herb_chiyangguo", 1)
	roam_note("在药铺买下一颗晒干的赤阳果（−%d 灵石）。" % DRY_CHIYANG_PRICE)
	_log("在坊市药铺买下一颗晒干的赤阳果。")
	return true

## v0.13.1（Gemini v6 P0-5）：吃不完的青芝拿到坊市药铺批售：十株一批，按当月行情（约五株一块灵石）
func qz_sell_price() -> int:
	return maxi(1, roundi(3.0 * Gear.price_idx(I("day"))))   # v0.15：十株约三块灵石（原两块）

func sell_qingzhi() -> bool:
	if s["loc"] != "roam" or String(s["roam"].get("pl", "")) != "坊市" or store_n("herb_qingzhi") < 10:
		return false
	var got := qz_sell_price()
	_store_add("herb_qingzhi", -10)
	s["lingshi"] = I("lingshi") + got
	roam_note("十株青芝批给了药铺（+%d 灵石）。" % got)
	return true

func buy_junk_lianzi() -> bool:
	if not junk_lianzi_available() or I("lingshi") < JUNK_LIANZI_PRICE or not s["pending_overflow"].is_empty():
		return false
	s["lingshi"] = I("lingshi") - JUNK_LIANZI_PRICE
	s["flags"]["junk_lz_year"] = int(World.cal(I("day"))[0])
	add_item("seed_lianzi", 1)
	roam_note("在旧货摊淘到一颗寒潭莲子（−%d 灵石）。" % JUNK_LIANZI_PRICE)
	_log("在坊市旧货摊淘到一颗寒潭莲子。")
	return true

## 坊市里能补干粮
func roam_buy_ration() -> bool:
	if s["loc"] != "roam" or String(s["roam"]["pl"]) != "坊市" or I("lingshi") < 1 or I("ration") >= RATION_CAP:
		return false
	s["lingshi"] = I("lingshi") - 1
	s["ration"] = I("ration") + 1
	return true

## 后山、寒潭：沿《旧主手记》里的老路走一趟（原来的路线，成了这两处的支线）
func roam_route() -> bool:
	if s["loc"] != "roam" or not world.pending().is_empty():
		return false
	var rid := String(TV.PL[String(s["roam"]["pl"])].get("route", ""))
	if rid == "" or not routes.has(rid):
		return false
	var w0 := int(s["roam"]["w0"])
	s["loc"] = "home"
	if not start_trip(rid):
		s["loc"] = "roam"
		return false
	s["trip"]["w0"] = w0
	s["roam"] = {}
	return true

# ---------------------------------------------------------------- 冲关与心魔（§2.6 / §6）
func can_breakthrough() -> String:
	if not at_home():
		return "要在青庐静室"
	if I("xiuwei") < xw_goal() or not at_gate():
		return "修为未满（%d/%d）" % [I("xiuwei"), xw_goal()]
	if I("plv") < 9 and store_n("pill_zhuji") < 1:
		return "手上没有筑基丹"
	if I("unstable") > 0:
		return "心境不稳：先闭关 %d 个月" % I("unstable")
	if I("injured") > 0 and I("plv") >= 9:
		return "伤还没好（%d 个月）" % I("injured")
	return ""

## v0.13：大关成功率（筑基仍是 v3.2 的筑基丹 + 心魔；之后的大关过了心魔还要看这一下）
func gate_chance() -> float:
	return float(GATES.get(I("plv"), 1.0))

## 选题：第一幕=最舍不得；第二幕=老龟（没遇到就用倾向标签题补）
func pick_xinmo() -> Array:
	var qs := []
	if I("plv") >= 9:
		# 筑基以后：从倾向题库里按种子挑两问（每次冲关不一样）
		var pool := []
		for q in xinmo["tag_pool"]:
			if check(q["requires"]):
				pool.append(q)
		while qs.size() < 2 and not pool.is_empty():
			qs.append(pool.pop_at(rng.randi() % pool.size()))
		return qs
	var a1 = xinmo["act1"].get(s["cherish"], null)
	if a1 != null and check(a1["requires"]):
		qs.append(a1)
	var lg = s["flags"].get("laogui", "")
	if lg != "" and xinmo["act2"].has("laogui_" + lg) and check(xinmo["act2"]["laogui_" + lg]["requires"]):
		qs.append(xinmo["act2"]["laogui_" + lg])
	var used := {}
	for q in qs:
		used[q["id"]] = true
	for q in xinmo["tag_pool"]:
		if qs.size() >= 2:
			break
		if not used.has(q["id"]) and check(q["requires"]):
			qs.append(q)
	return qs

func start_breakthrough() -> bool:
	if can_breakthrough() != "":
		return false
	tick("home")   # 冲关耗 1 个月
	var ids := []
	for q in pick_xinmo():
		ids.append(q["id"])
	s["xm"] = {"ids": ids, "idx": 0, "ok": true, "answers": []}
	s["loc"] = "xinmo"
	return true

func xinmo_question(id: String) -> Dictionary:
	for k in xinmo["act1"]:
		if xinmo["act1"][k]["id"] == id:
			return xinmo["act1"][k]
	for k in xinmo["act2"]:
		if xinmo["act2"][k]["id"] == id:
			return xinmo["act2"][k]
	for q in xinmo["tag_pool"]:
		if q["id"] == id:
			return q
	return {}

func current_xinmo() -> Dictionary:
	if s["loc"] != "xinmo":
		return {}
	return xinmo_question(s["xm"]["ids"][int(s["xm"]["idx"])])

## 返回 {done, passed}
func answer_xinmo(i: int) -> Dictionary:
	var q := current_xinmo()
	if q.is_empty() or i < 0 or i >= q["answers"].size():
		return {}
	var ok := check(q["answers"][i]["consistent_if"])
	s["xm"]["answers"].append({"id": q["id"], "a": i, "ok": ok})
	if not ok:
		s["xm"]["ok"] = false
	s["xm"]["idx"] = int(s["xm"]["idx"]) + 1
	if int(s["xm"]["idx"]) < s["xm"]["ids"].size():
		return {"done": false}
	if s["xm"]["ok"]:
		return _gate_pass()
	s["loc"] = "home"
	s["unstable"] = 3
	if Gear.on_xinmo_fail(self):
		s["unstable"] = 1
		_log("静心符烧成了灰，道心稳住了些。")
	pchron("冲关，心魔一问没有过去。")
	if I("plv") < 9:
		_log("心魔劫未过：她答的，与她做过的对不上。筑基丹还在，先闭关 3 个月（炼化减半）。")
	else:
		_log("心魔劫未过：她答的，与她做过的对不上。先闭关 3 个月（炼化减半）再冲。")
	return {"done": true, "passed": false}

## 心魔过了：筑基必成（v3.2）；之后的大关再看成功率；渡劫成 = 飞升
func _gate_pass() -> Dictionary:
	s["loc"] = "home"
	var lv := I("plv")
	var _ls0 := lifespan_m()
	if lv < 9:
		_store_add("pill_zhuji", -1)
		_raise_to(9)
		_log("%s，筑基功成。" % date_text())
		pchron("冲关，筑基功成。", -1, {"入": realm_text(), "寿元|年": int((lifespan_m() - _ls0) / 12)} if lifespan_m() > _ls0 else {"入": realm_text()})
		return {"done": true, "passed": true, "gate": "筑基", "ok": true}
	var ok := rng.randf() < gate_chance()
	match String(s.get("debug_gate", "")):
		"succeed": ok = true
		"fail": ok = false
	var gn := gate_name()
	if not ok:
		s["injured"] = maxi(I("injured"), GATE_FAIL_INJ)
		s["xiuwei"] = int(I("xiuwei") * 0.75)
		s["shouyuan"] = I("shouyuan") - GATE_FAIL_SHOU
		s["flags"]["gate_fail"] = int(s["flags"].get("gate_fail", 0)) + 1
		if lv == 18:
			s["ended"] = true
			s["ending"] = "jiewu"
			s["loc"] = "ending"
			_log("%s，雷劫第九道落下，她没有接住。" % date_text())
			return {"done": true, "passed": true, "gate": gn, "ok": false, "ended": true}
		_log("%s，冲击%s未成，经脉受损（伤 %d 个月，修为退了两成半，折寿 5 年）。" % [date_text(), gn, GATE_FAIL_INJ])
		pchron("冲击%s未成，经脉受损，折寿五年。" % gn, -1, {"伤|月": GATE_FAIL_INJ, "修为": "退两成半", "寿元|年": -int(GATE_FAIL_SHOU / 12)})
		if I("shouyuan") <= 0:
			_die_old()
		return {"done": true, "passed": true, "gate": gn, "ok": false}
	if lv == 18:
		s["ended"] = true
		s["ending"] = "feisheng"
		s["loc"] = "ending"
		_log("%s，九道雷劫过尽，她白日飞升。" % date_text())
		return {"done": true, "passed": true, "gate": gn, "ok": true, "ended": true}
	_raise_to(lv + 1)
	_log("%s，%s功成，入%s。" % [date_text(), gn, realm_text()])
	pchron("冲击%s，功成，入%s。" % [gn, realm_text()], -1, {"入": realm_text(), "寿元|年": int((lifespan_m() - _ls0) / 12)} if lifespan_m() > _ls0 else {"入": realm_text()})
	return {"done": true, "passed": true, "gate": gn, "ok": true}

func _raise_to(lv: int) -> void:
	var before := lifespan_m()
	s["plv"] = lv
	s["xiuwei"] = 0
	s["shouyuan"] = I("shouyuan") + maxi(0, lifespan_m() - before)

func _die_old() -> void:
	if s["ended"]:
		return
	s["ended"] = true
	s["ending"] = "zuohua"
	s["loc"] = "ending"
	_log("寿元耗尽。她回到青庐静室，在灯下坐化，享年 %d 岁。" % age_y())

## “青庐 N 年 · 某月”（第 0 月 = 青庐元年正月）
func date_text(day: int = -1) -> String:
	return World.cal_text(I("day") if day < 0 else day)
