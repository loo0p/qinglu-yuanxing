extends RefCounted
## v0.15.2（Gemini v7 表 1 筑基 / 金丹进项）：坊市差事——代炼、客卿坐镇、悬赏
## 只在开了江湖的档里生效；随机数用 Gear._rng_for（不动 gs.rng / W.rng）。存档：gs.s["econ"] 里的懒字段
##   comm 代炼单子 [[余月, 酬, 赔]...] · rep 坊市名声（办成的差事数）· kq 客卿（-1 没有）· kq_d 上回坐镇 / 领俸的月
##   bty_d 上回接悬赏的月 · comm_y/comm_n 这一年接了几单
## 每样都有代价：代炼占着丹炉（自家的丹停炉）、搭十株青芝、一成多炸炉要赔料钱；客卿要隔三年内回坊市坐镇一个月、
## 有时有人闹事受伤；悬赏离家两个月、四分之一会带伤回来，偶尔重伤只拿一半
const Gear = preload("res://scripts/gear.gd")
const World = preload("res://scripts/world.gd")

const COMM_PAY := [0, 75, 150, 420, 1200]    # 按大境界（炼气接不到）
const COMM_QZ := 10
const COMM_FUEL := [0, 16, 30, 85, 240]       # 地火钱，接单时先付（坊市租地火炉的钱，她自己出）
const COMM_MONTHS := 4
const COMM_FAIL := 15                         # 炸炉百分比；二阶聚灵阵以上（丹炉成丹率 +10%）减到 5
const COMM_MAX := 3                           # 手上同时最多三单
const COMM_YEAR := 6                          # 一年最多接六单
const KQ_PAY := [0, 70, 140, 380, 1100]       # 客卿年俸
const KQ_REP := 2                             # 名声到 2（办成两件差事）坊市才请她做客卿
const KQ_TERM := 36                           # 隔三年没回来坐镇，客卿之位另请了人；俸最多攒三年
const BTY := [[0, 0], [70, 130], [140, 260], [400, 700], [1200, 2000]]
const BTY_MONTHS := 2
const BTY_KIT := [0, 20, 30, 85, 240]         # 揭榜先备符箓干粮
const BTY_CD := 6
const BTY_HURT := 25
const BTY_BAD := 6

static func on(gs) -> bool:
	return gs != null and gs.world != null

static func E(gs) -> Dictionary:
	if not gs.s.has("econ") or not (gs.s["econ"] is Dictionary):
		gs.s["econ"] = {}
	var e: Dictionary = gs.s["econ"]
	if not e.has("comm") or not (e["comm"] is Array):
		e["comm"] = []
	for k in ["rep", "comm_n", "jobs_ls", "jobs_n", "hurt_n", "jobs_cost"]:
		e[k] = int(e.get(k, 0))
	for k in ["kq", "kq_d", "bty_d", "comm_y"]:
		e[k] = int(e.get(k, -99 if k != "kq" else -1))
	return e

static func _day(gs) -> int:
	return int(gs.s.get("day", 0))

static func _year(gs) -> int:
	return (maxi(_day(gs), 1) - 1) / 12

static func _mj(gs) -> int:
	return int(gs.major())

static func _at_market(gs) -> bool:
	return String(gs.s.get("loc", "")) == "roam" and String(gs.s.get("roam", {}).get("pl", "")) == "坊市"

## 她的履历加一条，带效果标签（{"灵石": +45, "伤|月": 3}）；条目格式和 lv015 的 pchron(t, day, fx) 一样是 [日, 文, 效果]
static func chron(gs, t: String, fx: Dictionary) -> void:
	if not on(gs):
		return
	var lg: Array = gs.world.P()["log"]
	lg.append([int(gs.world.w["day"]), t, fx] if not fx.is_empty() else [int(gs.world.w["day"]), t])
	World.trim_log(lg, World.PLOG_CAP)

static func _pay(gs, n: int) -> void:
	var e := E(gs)
	gs.s["lingshi"] = int(gs.s["lingshi"]) + n
	e["jobs_ls"] = int(e["jobs_ls"]) + n

static func _hurt(gs, m: int) -> int:
	var d: int = Gear.on_injury(gs, m)
	gs.s["injured"] = maxi(int(gs.s.get("injured", 0)), d)
	E(gs)["hurt_n"] = int(E(gs)["hurt_n"]) + 1
	return d

# ---------------------------------------------------------------- 代炼
static func comm_fail_pct(gs) -> int:
	return COMM_FAIL - (10 if int(gs.s.get("econ", {}).get("arr", 0)) >= 2 else 0)

static func comm_pay(gs) -> int:
	return roundi(COMM_PAY[clampi(_mj(gs), 0, 4)] * Gear.price_idx(_day(gs)))

static func can_comm(gs) -> String:
	if not on(gs):
		return "没开江湖"
	if not _at_market(gs):
		return "要在坊市"
	if _mj(gs) < 1:
		return "筑基以后药铺才肯托你代炼"
	var e := E(gs)
	if e["comm"].size() >= COMM_MAX:
		return "手上已有三单"
	if int(e["comm_y"]) == _year(gs) and int(e["comm_n"]) >= COMM_YEAR:
		return "今年的单子接满了"
	if gs.store_n("herb_qingzhi") < COMM_QZ:
		return "要搭 %d 株青芝" % COMM_QZ
	if int(gs.s.get("lingshi", 0)) < int(COMM_FUEL[clampi(_mj(gs), 0, 4)]):
		return "地火钱 %d 灵石不够" % int(COMM_FUEL[clampi(_mj(gs), 0, 4)])
	return ""

static func take_comm(gs) -> bool:
	if can_comm(gs) != "":
		return false
	var e := E(gs)
	if int(e["comm_y"]) != _year(gs):
		e["comm_y"] = _year(gs)
		e["comm_n"] = 0
	e["comm_n"] = int(e["comm_n"]) + 1
	gs._store_add("herb_qingzhi", -COMM_QZ)
	var fuel := int(COMM_FUEL[clampi(_mj(gs), 0, 4)])
	gs.s["lingshi"] = int(gs.s["lingshi"]) - fuel
	e["jobs_cost"] = int(e["jobs_cost"]) + fuel
	var pay := comm_pay(gs)
	e["comm"].append([COMM_MONTHS, pay, maxi(5, pay / 3)])
	gs.roam_note("药铺托她代炼一炉丹：主家出主料，她搭 %d 株青芝、先付 %d 灵石地火钱；炉子要占 %d 个月，成了 %d 灵石，炸了赔 %d。" % [COMM_QZ, fuel, COMM_MONTHS, pay, maxi(5, pay / 3)])
	return true

## 代炼的单子在炉上：她自家排的丹停炉（tick 里看这个）
static func furnace_busy(gs) -> bool:
	return on(gs) and gs.s.has("econ") and gs.s["econ"] is Dictionary and not gs.s["econ"].get("comm", []).is_empty()

static func comm_text(gs) -> String:
	var c: Array = E(gs)["comm"]
	if c.is_empty():
		return ""
	return "丹炉在替药铺代炼（还有 %d 单，这一炉再 %d 个月），自家的丹先停着。" % [c.size(), int(c[0][0])]

static func _comm_month(gs) -> void:
	var e := E(gs)
	var c: Array = e["comm"]
	if c.is_empty():
		return
	c[0][0] = int(c[0][0]) - 1
	if int(c[0][0]) > 0:
		return
	var job: Array = c.pop_front()
	var r := Gear._rng_for(gs, 9100 + _day(gs) * 3 + c.size())
	if r.randi_range(1, 100) <= comm_fail_pct(gs):
		var loss := mini(int(job[2]), int(gs.s["lingshi"]))
		gs.s["lingshi"] = int(gs.s["lingshi"]) - loss
		e["comm_fail"] = int(e.get("comm_fail", 0)) + 1
		gs.notice("替药铺代炼的一炉炸了，赔了主家 %d 灵石料钱。" % loss)
		chron(gs, "替坊市药铺代炼一炉丹，火候没压住，炸了炉，赔了料钱。", {"灵石": -loss})
	else:
		_pay(gs, int(job[1]))
		e["rep"] = int(e["rep"]) + 1
		e["jobs_n"] = int(e["jobs_n"]) + 1
		gs.notice("代炼的丹成了，药铺来人取走，付了 %d 灵石。" % int(job[1]))
		chron(gs, "替坊市药铺代炼一炉丹，成了。", {"灵石": int(job[1]), "名声": 1})

# ---------------------------------------------------------------- 客卿坐镇
static func kq_pay(gs) -> int:
	return KQ_PAY[clampi(_mj(gs), 0, 4)]

static func kq_due(gs) -> int:
	## 这回坐镇能领几年的俸（上回坐镇以来满一年算一年，最多三年）
	var e := E(gs)
	if int(e["kq"]) < 0:
		return 0
	return clampi((_day(gs) - int(e["kq_d"])) / 12, 0, KQ_TERM / 12)

static func can_kq(gs) -> String:
	if not on(gs):
		return "没开江湖"
	if not _at_market(gs):
		return "要在坊市"
	if _mj(gs) < 1:
		return "筑基以后坊市才请客卿"
	if int(E(gs)["rep"]) < KQ_REP:
		return "坊市还不认得你（先办成 %d 件差事）" % KQ_REP
	if int(gs.s.get("injured", 0)) > 0:
		return "带着伤"
	return ""

## 应下客卿 / 回来坐镇一个月：领这几年攒下的俸；坐镇这个月有时有人闹事
static func sit_kq(gs) -> bool:
	if can_kq(gs) != "":
		return false
	var e := E(gs)
	var first := int(e["kq"]) < 0
	var due := kq_due(gs)
	var pay := kq_pay(gs)
	e["kq"] = _mj(gs)
	e["kq_d"] = _day(gs) + 1   # 先记上：坐镇这个月里不会被当成过期
	gs.spend_away(1, "坊市")
	if gs.s["ended"]:
		return true
	var fx := {}
	var t := ""
	if first:
		t = "应了坊市的客卿，坐镇一个月。往后三年内回来坐镇一回，每年 %d 灵石的俸。" % pay
		_pay(gs, pay / 2)
		fx["灵石"] = pay / 2
	else:
		t = "回坊市坐镇一个月，领了 %d 年的客卿俸。" % due
		_pay(gs, due * pay)
		fx["灵石"] = due * pay
	var r := Gear._rng_for(gs, 9300 + _day(gs))
	if r.randi_range(1, 100) <= 20:
		if r.randi_range(1, 100) <= 70:
			var bonus := pay / 4
			_pay(gs, bonus)
			e["rep"] = int(e["rep"]) + 1
			fx["灵石"] = int(fx["灵石"]) + bonus
			fx["名声"] = 1
			t += "有散修在坊市闹事，她出手镇住了，商户凑了一份谢礼。"
		else:
			var d := _hurt(gs, 2)
			fx["伤|月"] = d
			t += "有人在坊市闹事，她拦下了，自己也挂了彩。"
	e["kq_n"] = int(e.get("kq_n", 0)) + 1
	gs._log(t)
	chron(gs, t, fx)
	return true

static func kq_text(gs) -> String:
	var e := E(gs)
	if int(e["kq"]) < 0:
		return "客卿：%s" % ("没应过" if int(e["rep"]) >= KQ_REP or _mj(gs) < 1 else "坊市还不认得你（名声 %d/%d）" % [int(e["rep"]), KQ_REP])
	var left := KQ_TERM - (_day(gs) - int(e["kq_d"]))
	return "客卿：每年 %d 灵石，攒了 %d 年；%s" % [kq_pay(gs), kq_due(gs), ("再 %d 个月内要回来坐镇一回" % left) if left > 0 else "过期了"]

# ---------------------------------------------------------------- 悬赏
static func bty_range(gs) -> Array:
	var b: Array = BTY[clampi(_mj(gs), 0, 4)]
	var k := 1.0 + mini(int(E(gs)["rep"]), 10) * 0.03
	return [roundi(int(b[0]) * k), roundi(int(b[1]) * k)]

static func can_bty(gs) -> String:
	if not on(gs):
		return "没开江湖"
	if not _at_market(gs):
		return "要在坊市"
	if _mj(gs) < 1:
		return "筑基以后才揭得悬赏"
	if int(gs.s.get("injured", 0)) > 0:
		return "带着伤"
	if _day(gs) - int(E(gs)["bty_d"]) < BTY_CD:
		return "榜上没有新的（%d 个月后再来）" % (BTY_CD - (_day(gs) - int(E(gs)["bty_d"])))
	if int(gs.s.get("lingshi", 0)) < int(BTY_KIT[clampi(_mj(gs), 0, 4)]):
		return "备符箓干粮要 %d 灵石" % int(BTY_KIT[clampi(_mj(gs), 0, 4)])
	return ""

static func take_bty(gs) -> bool:
	if can_bty(gs) != "":
		return false
	var e := E(gs)
	e["bty_d"] = _day(gs)
	gs.s["lingshi"] = int(gs.s["lingshi"]) - int(BTY_KIT[clampi(_mj(gs), 0, 4)])
	e["jobs_cost"] = int(e["jobs_cost"]) + int(BTY_KIT[clampi(_mj(gs), 0, 4)])
	var rg := bty_range(gs)
	var r := Gear._rng_for(gs, 9500 + _day(gs))
	var pay := r.randi_range(int(rg[0]), int(rg[1]))
	var roll := r.randi_range(1, 100)
	var what: String = ["追一头伤人的妖兽", "护一趟商队过山", "拿一个盗丹的贼修", "清一处闹鬼的旧洞府"][r.randi() % 4]
	gs.spend_away(BTY_MONTHS, "坊市")
	if gs.s["ended"]:
		return true
	var fx := {}
	var t := "揭了坊市的悬赏，去%s。" % what
	if roll <= BTY_BAD:
		pay = pay / 2
		fx["伤|月"] = _hurt(gs, 6)
		t += "差事办成了一半，自己伤得不轻，只领了一半赏钱。"
	elif roll <= BTY_HURT:
		fx["伤|月"] = _hurt(gs, 3)
		t += "办成了，带了伤回来。"
	else:
		t += "办成了。"
	_pay(gs, pay)
	fx["灵石"] = pay
	e["rep"] = int(e["rep"]) + 1
	e["jobs_n"] = int(e["jobs_n"]) + 1
	e["bty_n"] = int(e.get("bty_n", 0)) + 1
	fx["名声"] = 1
	gs._log(t + "（+%d 灵石）" % pay)
	chron(gs, t, fx)
	return true

# ---------------------------------------------------------------- 每月
static func monthly(gs) -> void:
	if not on(gs):
		return
	var e := E(gs)
	_comm_month(gs)
	if int(e["kq"]) >= 0 and _day(gs) - int(e["kq_d"]) > KQ_TERM:
		e["kq"] = -1
		e["rep"] = maxi(0, int(e["rep"]) - 2)
		gs.notice("三年没回坊市坐镇，客卿之位另请了人。")
		chron(gs, "三年没回坊市坐镇，客卿之位另请了人。", {"名声": -2})

static func summary(gs) -> Dictionary:
	var e := E(gs)
	return {"jobs_ls": int(e["jobs_ls"]), "jobs_n": int(e["jobs_n"]), "jobs_cost": int(e["jobs_cost"]), "comm_fail": int(e.get("comm_fail", 0)), "kq_n": int(e.get("kq_n", 0)), "bty_n": int(e.get("bty_n", 0)), "hurt_n": int(e["hurt_n"]), "rep": int(e["rep"])}
