extends SceneTree
## 可插拔事件引擎（addons/storylet_engine）本身的测试，用自带的示例包与示例胶水，不碰游戏：
## lint 通过；同种子可复现；中途存读档后结果一致；连锁到期会发；信号里同族只发优先级最高的；
## 生平生成不扰动主随机序列且可复现；玩家选项 present/choose；热插拔新包；语法不重复挑。
const SE = preload("res://addons/storylet_engine/storylet_engine.gd")
const SL = preload("res://addons/storylet_engine/se_lint.gd")
const SIM = preload("res://addons/storylet_engine/se_sim.gd")
const EA = preload("res://addons/storylet_engine/examples/example_adapter.gd")
var fails := 0

## 一刻 = 一月的胶水（测时间单位换算）
class MonthAd extends "res://addons/storylet_engine/examples/example_adapter.gd":
	func se_ticks(n: float, unit: String) -> float:
		return n / 30.0 if unit == "day" else (n * 12.0 if unit == "year" else n)

func ok(c: bool, msg: String) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1

func _pack() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://addons/storylet_engine/examples/example_pack.json"))

func _run(seed_v: int, days: int, split: int = -1) -> Array:
	var a = EA.new()
	var e = SE.new(a, {}, seed_v)
	e.add_pack(_pack())
	for d in days:
		if d == split:
			# 存读档：状态与人物经 JSON 往返，换一个全新的引擎对象
			var blob := JSON.stringify({"se": e.save_state(), "p": a.people, "day": a.day})
			var back = JSON.parse_string(blob)
			var logs = a.logs
			a = EA.new()
			a.people = back["p"]
			a.day = int(back["day"])
			a.logs = logs
			e = SE.new(a, back["se"])
			e.add_pack(_pack())
		a.day += 1
		e.tick_due()
		e.tick_world()
		for p in a.people:
			if e.chance(0.5):
				e.beat(p)
	var out := []
	for k in [1, 2, 3, 4]:
		for l in a.logs[k]:
			out.append("%d:%d:%s" % [k, int(l[0]), l[1]])
	return out

func _init() -> void:
	var r: Dictionary = SL.lint([_pack()])
	ok(r["errors"].is_empty(), "示例包 lint 无错误 %s" % [r["errors"]])
	# 坏包要被 lint 拦下
	var bad := {"id": "bad", "storylets": [{"id": "x", "trigger": "actor", "when": "A.lv >", "outcomes": [{"id": "o", "effects": [{"op": "chron", "text": "#nosuch#"}, {"op": "schedule", "id": "nope"}, {"op": "zap"}]}]}]}
	var rb: Dictionary = SL.lint([bad])
	ok(rb["errors"].size() >= 4, "坏包 lint 报出表达式/符号/连锁目标/未知 op（%d 条）" % rb["errors"].size())
	var l1 := _run(7, 60)
	var l2 := _run(7, 60)
	ok(l1 == l2 and l1.size() > 40, "同种子两次 60 日完全一致（%d 行）" % l1.size())
	var l3 := _run(7, 60, 30)
	ok(l1 == l3, "第 30 日存读档后结果与不存档一致")
	ok(_run(8, 60) != l1, "换种子结果不同")
	ok(l1.any(func(x): return "狼群回来" in x), "连锁（schedule → chain）到期发生")
	# 信号：同一 family 里优先级高的胜出
	var a = EA.new()
	var e = SE.new(a, {}, 3)
	e.add_pack(_pack())
	a.people[0]["friend"]["2"] = 3
	a.people[1]["friend"]["1"] = 3
	e.emit("gone", {"A": a.people[0]})
	ok(a.logs[2].size() == 1 and "眼眶红了" in a.logs[2][0][1] and a.logs[3].is_empty(), "emit：有交情的规则（priority 5）胜出，普通规则不再发")
	# 生平
	var st0 = e.rng.state
	var b1: Array = e.biography(a.people[2], 99)
	var b2: Array = e.biography(a.people[2], 99)
	ok(b1 == b2 and b1.size() >= 1 and e.rng.state == st0, "生平可复现、不扰动主随机序列 %s" % [b1])
	ok(b1.size() < 2 or int(b1[1][0]) >= int(b1[0][0]) + 3, "生平年龄递增")
	# 玩家选项
	var inst: Dictionary = e.make_inst("visitor", {"A": a.people[0]})
	ok(e.cast_roles(e.defs["visitor"], inst), "offer 选角")
	var pr: Dictionary = e.present(inst)
	ok(pr["opts"].size() == 2 and not "{" in pr["text"] and not "#" in pr["text"], "present：%s %s" % [pr["text"], pr["opts"]])
	var res: String = e.choose(JSON.parse_string(JSON.stringify(inst)), "in")
	ok(res.begins_with("两人吃完了") and not "#" in res, "choose（实例经 JSON 往返）：" + res)
	# 热插拔
	var n0: int = e.defs.size()
	e.add_pack({"id": "more", "grammar": {"food": ["一碟花生"]}, "storylets": [{"id": "rain", "trigger": "actor", "weight": 100, "outcomes": [{"id": "o", "effects": [{"op": "chron", "text": "躲雨，吃了#food#。"}]}]}]})
	ok(e.defs.size() == n0 + 1 and e.grammar["food"].size() == 4, "热插拔新包：storylet +1，语法合并")
	e.remove_pack("more")
	ok(e.defs.size() == n0 and e.grammar["food"].size() == 3, "卸下包")
	# 语法不重复挑：8 选 1 连抽 4 次不重样
	e.add_pack({"id": "g8", "grammar": {"g8": ["1", "2", "3", "4", "5", "6", "7", "8"]}})
	var seen := {}
	for i in 4:
		seen[e.say("#g8#", e.make_inst(""))] = true
	ok(seen.size() == 4, "语法：最近用过的一半不再挑（4 抽 4 不同）")
	# 模拟台
	e.trace = []
	for d in 40:
		a.day += 1
		e.tick_due()
		for p in a.people:
			e.beat(p)
	var rep: Dictionary = SIM.report(e)
	ok(rep["lines"] > 50 and rep["outcomes"] > 5, "模拟台：%d 行，%d 种，结果覆盖 %d/%d" % [rep["lines"], rep["distinct"], rep["outcomes_hit"], rep["outcomes"]])
	ok(e.errors.is_empty(), "引擎无运行期错误 %s" % [e.errors.slice(0, 5)])
	# 时间单位：包按“日”写，胶水一刻 = 一月
	var ma = MonthAd.new()
	var me = SE.new(ma, {}, 5)
	me.add_pack({"id": "u", "unit": "day", "storylets": [
		{"id": "u1", "trigger": "manual", "cooldown": 45, "effects": [{"op": "schedule", "id": "u2", "in": 60}]},
		{"id": "u2", "trigger": "chain", "effects": []}]})
	ok(me.dur(45, "day") == 2 and me.dur(3, "day") == 1 and me.dur(2, "year") == 24 and e.dur(45, "day") == 45, "时间单位：45 日=2 月、3 日至少 1 刻、2 年=24 月；无 se_ticks 的胶水原样")
	ok(absf(me.per_tick(0.01, "day") - (1.0 - pow(0.99, 30.0))) < 1e-6 and e.per_tick(0.01, "day") == 0.01, "时间单位：每日 1% → 每月约 26%")
	ma.day = 10
	me.fire("u1", {"A": ma.people[0]}, {})
	ok(me.st["q"].size() == 1 and int(me.st["q"][0][0]) == 12, "时间单位：连锁 in 60 日 → 2 刻后到期")
	ma.day = 11
	ok(not me.gate(me.defs["u1"]), "时间单位：冷却 45 日 → 隔 1 刻仍在冷却")
	ma.day = 12
	ok(me.gate(me.defs["u1"]), "时间单位：隔 2 刻冷却结束")
	print("storylet_engine_test: %s (%d fail)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
