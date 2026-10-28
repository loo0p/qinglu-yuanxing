extends SceneTree
## v0.14：闭关履历 / 行囊装备 / 坊市行情 / 存档 v3→v4 迁移
const GS = preload("res://scripts/game_state.gd")
var fails := 0
var lines: PackedStringArray = []

func ok(c: bool, msg: String) -> void:
	lines.append(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1

func fresh(sd: int = 7):
	var g = GS.new()
	g.new_game("苏青禾", "sect", sd, true)
	for i in 40:
		g.tick("biguan")
		g.world.auto_choose()
		g.world.close()
	return g

func _init() -> void:
	t_seclude()
	for l in lines:
		print(l)
	print("装备/闭关测试：%d 失败" % fails)
	quit(1 if fails > 0 else 0)

func t_seclude() -> void:
	var g = fresh()
	g._raise_to(9)
	g.s["ration"] = 30
	var n0: int = g.world.P()["log"].size()
	g.biguan("years", 20)
	var lg: Array = g.world.P()["log"]
	var add := lg.slice(n0)
	var txt := "\n".join(add.map(func(e): return "%s %s" % [g.world.cal_text(int(e[0])), e[1]]))
	print(txt)
	ok(add.size() >= 15, "二十年闭关写进她的履历 %d 条（≥15）" % add.size())
	var sorted := true
	for i in range(1, lg.size()):
		if int(lg[i][0]) < int(lg[i - 1][0]):
			sorted = false
	ok(sorted, "履历按年月先后")
	ok(txt.contains("入静室闭关") and txt.contains("出关"), "有入关、出关两笔")
	ok(txt.contains("闭关第十年"), "每年一笔心得")
