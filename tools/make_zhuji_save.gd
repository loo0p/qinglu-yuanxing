extends SceneTree
## 生成 release_check 用的筑基档（tests/fixtures/save_zhuji_v016.json）：
## 筑基初期、在青庐；聚灵阵一阶、仓里聚气丹够开服丹闭关；穿一件道袍、立绘带外袍；
## 青庐辟了灵圃、建了客舍；有个低她几个小境界的熟人（能指点 / 收徒）；青芝、灵石够接代炼。
## 用法：godot --headless --path . -s tools/make_zhuji_save.gd
const GS = preload("res://scripts/game_state.gd")
const Gear = preload("res://scripts/gear.gd")
const Econ = preload("res://scripts/econ.gd")
const Estate = preload("res://scripts/estate.gd")
const PLib = preload("res://addons/portrait5/portrait5_lib.gd")
const OUT := "res://tests/fixtures/save_zhuji_v016.json"

func _init() -> void:
	var g = GS.new()
	g.new_game("苏青禾", "sect", 16, true)
	for i in 30:
		g.tick("biguan")
		g.world.auto_choose()
		g.world.close()
	g._raise_to(9)
	g.s["loc"] = "home"
	g.s["roam"] = {}
	g.s["lingshi"] = 900
	g.s["ration"] = 60
	g.s["store"]["herb_qingzhi"] = 90
	g.s["store"]["pill_juqi"] = 30
	# 货郎的六样货单都备一点料（release_check 要真点一回以物易物）
	for o in Estate.BARTER:
		for id in o["give"]:
			g.s["store"][id] = maxi(g.store_n(id), int(o["give"][id]) + 2)
	Econ.build(g)
	Estate.build(g, "pu1")
	Estate.build(g, "ke")
	var W = g.world
	for c in W.npcs():
		if int(c.get("sbg", 0)) <= int(W.w["day"]):
			c["lv"] = 2
			W.R(W.P(), c)["m"] = 1
			break
	var r = RandomNumberGenerator.new()
	r.seed = 16
	var it: Dictionary = Gear.make(g, W, r, "道袍", 2, "fixture", int(g.s["day"]))
	Gear.give_her(g, it, "旧日所得")
	var eq_why: String = Gear.equip(g, int(it["u"]))
	var sp: Dictionary = {}
	for k in 400:
		sp = PLib.roll("zj%d" % k, {"sex": "f", "elder": false, "demonic": false, "robe_v": 10})
		if sp.get("outer") != null:
			break
	g.s["portrait"] = sp
	g.s["guide"] = {}
	var payload := {"rev": 1, "saved_at": "fixture", "state": g.to_dict()}
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(payload))
	f.close()
	print("筑基档：day=%d plv=%d 灵石=%d 外袍=%s 法衣=%s(%s) 青庐=%s" % [int(g.s["day"]), int(g.s["plv"]), int(g.s["lingshi"]), str(sp.get("outer")), Gear.full_name(it), eq_why, Estate.text(g)])
	quit(0)
