extends SceneTree
## v0.15.5：金丹 / 元婴专属的履历事件真的会出现（固定种子，直接把她提到金丹 / 元婴，过几十年）
const GS = preload("res://scripts/game_state.gd")
const Gear = preload("res://scripts/gear.gd")
var fails := 0
var lines: PackedStringArray = []

func ok(c: bool, msg: String) -> void:
	lines.append(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1

func fresh(sd: int):
	var g = GS.new()
	g.new_game("苏青禾", "sect", sd, true)
	for i in 40:
		g.tick("biguan")
		g.world.auto_choose()
		g.world.close()
	return g

## 过 years 年：闭关三年、出门走一年，轮着来
func live(g, years: int) -> void:
	var m0 := int(g.world.w["day"])
	while int(g.world.w["day"]) - m0 < years * 12 and not bool(g.s.get("ended", false)):
		g.biguan("years", 3)
		for i in 12:
			g.tick("road" if i % 3 != 2 else "biguan")
			g.world.auto_choose()
			g.world.close()

const WATCH := ["sec_danhuo", "benming", "guanjie", "gongfeng", "echo_gf", "shoutu", "echo_tu", "jiang", "echo_jiang", "sec_shenyou", "yuanying_old", "xuming"]

func count(add: Array, keys: Array) -> int:
	var n := 0
	for e in add:
		for k in keys:
			if String(k) in String(e[1]):
				n += 1
				break
	return n

func _init() -> void:
	var seeds := [3, 5, 8]
	var env := OS.get_environment("REALMSEEDS")
	if env != "":
		seeds = []
		for x in env.split(","):
			seeds.append(int(x))
	var tot := {}
	var all_new := 0
	var all_empty := 0
	for sd in seeds:
		for lv in [12, 15]:
			var g = fresh(int(sd))
			g._raise_to(lv)
			var r := RandomNumberGenerator.new()
			r.seed = int(sd)
			var sw: Dictionary = Gear.make(g, g.world, r, "剑", 1, "测试", int(g.s["day"]))
			Gear.give_her(g, sw, "测试给的")
			Gear.equip(g, int(sw["u"]))
			var n0: int = g.world.P()["log"].size()
			var f0: Dictionary = (g.world.saga().eng.st["fired"] as Dictionary).duplicate()
			live(g, 60)
			var add: Array = g.world.P()["log"].slice(n0)
			var f1: Dictionary = g.world.saga().eng.st["fired"]
			var c := {}
			for k in WATCH:
				c[k] = int(f1.get(k, 0)) - int(f0.get(k, 0))
			for k in c:
				tot["%d:%s" % [lv, k]] = int(tot.get("%d:%s" % [lv, k], 0)) + int(c[k])
			for e in add:
				all_new += 1
				if e.size() < 3 or (e[2] as Dictionary).is_empty():
					all_empty += 1
			print("seed %d lv %d: %d 条 %s" % [sd, lv, add.size(), JSON.stringify(c)])
	print("TOTAL ", JSON.stringify(tot))
	ok(int(tot.get("12:sec_danhuo", 0)) >= 1, "金丹：丹火反噬出现 %d 次" % int(tot.get("12:sec_danhuo", 0)))
	ok(int(tot.get("15:sec_shenyou", 0)) + int(tot.get("15:yuanying_old", 0)) >= 2, "元婴：神游 / 故人凋零出现 %d 次" % (int(tot.get("15:sec_shenyou", 0)) + int(tot.get("15:yuanying_old", 0))))
	ok(int(tot.get("15:sec_danhuo", 0)) == 0 and int(tot.get("12:sec_shenyou", 0)) == 0, "丹火只在金丹、神游只在元婴")
	for k in ["benming", "guanjie", "gongfeng", "echo_gf", "shoutu", "echo_tu", "jiang", "echo_jiang"]:
		var n := int(tot.get("12:" + k, 0)) + int(tot.get("15:" + k, 0))
		ok(n >= 1, "金丹 / 元婴：%s 出现 %d 次" % [k, n])
	print("（续命 xuming：%d 次；要有寿元将尽、好感 ≥10 的熟人，不作断言）" % int(tot.get("15:xuming", 0)))
	ok(all_empty * 10 < all_new, "金丹 / 元婴六十年里没有效果小字的 %d / %d（<10%%）" % [all_empty, all_new])
	for l in lines:
		print(l)
	print("境界事件测试：%d 失败" % fails)
	quit(1 if fails > 0 else 0)
