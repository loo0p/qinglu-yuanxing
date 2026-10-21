extends SceneTree
## UI 冒烟测试——无头实例化主场景，按按钮文字点完整条均衡路线（对话框会自动点 ▼ 读完）。
## 只证明界面流程能走通、没有脚本错误；不代表任何真机/浏览器表现。
var main
var log_lines: PackedStringArray = []
var steps := 0

func _init() -> void:
	for f in ["qinglu_v6_slot1.json", "qinglu_v6_slot1.bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + f))
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	process_frame.connect(_go, CONNECT_ONE_SHOT)

func buttons(n: Node, out: Array) -> Array:
	for c in n.get_children():
		if c is Button and c.is_inside_tree():
			out.append(c)
		buttons(c, out)
	return out

func _find(prefix: String):
	for b in buttons(main, []):
		if not b.disabled and b.text.replace("● ", "").begins_with(prefix):
			return b
	return null

## 找不到时：先把对话一段段点完（▼），丹炉里的按钮要先点开“丹炉”抽屉
var stories := 0
## 江湖事件随时可能弹出（v0.6）：读完对话，点第一个选项，再点“知道了”
func drain_story() -> void:
	var guard := 0
	while main.modal.get("kind", "") == "story" and guard < 40:
		guard += 1
		var adv = _find("▼")
		if adv:
			adv.pressed.emit()
			continue
		var fb := []
		for b in buttons(main.footer, []):
			if not b.disabled:
				fb.append(b)
		if fb.is_empty():
			break
		if main.g.world.pending().get("stage", "") == "ask":
			stories += 1
		fb[0].pressed.emit()

func click(prefix: String) -> bool:
	for attempt in 16:
		drain_story()
		var b = _find(prefix)
		if b:
			b.pressed.emit()
			steps += 1
			return true
		var adv = _find("▼")
		if adv:
			adv.pressed.emit()
			continue
		if prefix in ["全部服下", "按目标排程", "撤回队尾"] and main.sheet != "furnace" and _find("丹炉"):
			_find("丹炉").pressed.emit()
			continue
		break
	var all := []
	for b in buttons(main, []):
		all.append(("[x]" if b.disabled else "") + b.text.replace("\n", "/"))
	log_lines.append("找不到按钮「%s」；当前：%s" % [prefix, all])
	return false

func seq(list: Array) -> bool:
	for x in list:
		if not click(x):
			return false
	return true

func _go() -> void:
	var ok := true
	ok = ok and seq(["新游戏", "出发", "知道了"])
	# 新手提示：新局第 1 日在青庐有姑母的字条；“记下了”后不再出；去历练页又有一张
	var gd_ok: bool = main.g.s.has("guide") and _find("记下了") != null
	gd_ok = gd_ok and click("记下了") and _find("记下了") == null
	main.tab = "depart"; main.refresh()
	gd_ok = gd_ok and _find("记下了") != null
	main.tab = "home"; main.refresh()
	log_lines.append("新手提示（新局出现、记下后消失）：" + ("PASS" if gd_ok else "FAIL"))
	ok = ok and gd_ok
	ok = ok and seq(["历练", "出发：后山"])
	ok = ok and seq(["溪边", "贴上避水符", "继续", "溪畔野地", "采一把续骨草", "继续", "葛老三", "递上续骨草", "继续", "古松残碑", "拓下碑文", "继续", "归途", "回青庐", "回家", "进屋"])
	ok = ok and seq(["开第三块阳田", "修炼", "2 日"]) if false else ok and seq(["开第三块阳田", "修炼"])
	# 闭关 2 日：点 1 日两次
	ok = ok and seq(["1 日", "1 日", "历练", "● 后山"]) if false else ok and seq(["1 日", "1 日", "历练"])
	ok = ok and seq(["寒潭", "+1（1灵石）", "+1（1灵石）", "出发：寒潭"])
	ok = ok and seq(["冷杉道", "向他打听老龟", "继续", "寒潭野地", "拢紧衣襟", "继续", "潭边石屋", "坐下烤火", "继续", "寒潭老龟", "在石头上坐下", "继续",
		"冰瀑", "站定", "继续", "猎屋", "点上蜡烛", "继续", "雾林", "掩住口鼻", "继续", "回程野地", "加快脚步", "继续", "归途", "回青庐", "回家", "进屋"])
	ok = ok and seq(["修炼", "3 日", "历练", "后山", "出发：后山", "溪边", "快走", "继续", "向阳坡", "伏在草里", "继续", "归途", "回青庐", "回家", "进屋"])
	var jh := true
	var gw = main.g.world
	# 江湖页与人物卡能打开
	main.tab = "jianghu"
	main.modal = {}
	main.refresh()
	jh = jh and _find("她的生平") != null
	if gw and not gw.acquaintances().is_empty():
		main.person_id = int(gw.acquaintances()[0]["id"])
		main.modal = {"kind": "person"}
		main.refresh()
		jh = jh and _find("回江湖") != null and _find("生平") != null
		click("关系")
		click("记得她")
		var back := click("回江湖")
		jh = jh and back
	log_lines.append("江湖页 / 人物卡：" + ("PASS" if jh else "FAIL"))
	main.tab = "home"
	main.refresh()
	ok = ok and jh
	var g = main.g
	log_lines.append("第三趟后：D%d 赤阳果 %d 寒潭莲 %d 修为 %d" % [g.s["day"], g.total_n("herb_chiyangguo"), g.total_n("herb_hantanlian"), g.s["xiuwei"]])
	# 收尾：反复“全部服下 / 按目标排程 / 1 日”直到可以冲关
	g.s["debug_zhuji"] = "succeed"
	for i in 60:
		if g.can_breakthrough() == "":
			break
		click("青庐")
		if click("全部服下"):
			click("服下")
		click("按目标排程")
		click("修炼")
		click("1 日")
	ok = ok and click("◎ 冲关")
	for i in 3:
		var q = g.current_xinmo()
		if q.is_empty():
			break
		for a in q["answers"]:
			if g.check(a["consistent_if"]):
				click(a["label"])
				break
	log_lines.append("结局：%s 第 %d 日；点击 %d 次；江湖事件 %d 件；认识 %d 人" % [g.s["ending"], g.s["day"], steps, stories, g.world.acquaintances().size() if g.world else -1])
	ok = ok and g.world != null and stories >= 3
	ok = ok and g.s["ending"] == "zhuji"
	# 存档存在且能读回
	var st = load("res://scripts/save_store.gd").new()
	var d = st.load_data()
	ok = ok and d != null and int(d["state"]["day"]) == g.s["day"]
	log_lines.append("存档 rev=%s day=%s" % [d["rev"] if d else "?", d["state"]["day"] if d else "?"])
	# 旧档自由输入的名字若含字体缺的字 → 换成预设名
	var nm_ok = main.safe_name("鑫𠀀") == "苏青禾" and main.safe_name("林晚照") == "林晚照"
	log_lines.append("旧档名字兜底：" + ("PASS" if nm_ok else "FAIL"))
	ok = ok and nm_ok
	# 旧档（没有 guide 键）读进来：不出新手提示
	var od: Dictionary = g.to_dict()
	od.erase("guide")
	od["day"] = 2
	od["ending"] = ""
	od["ended"] = false
	od["loc"] = "home"
	g.from_dict(od)
	main.modal = {}; main.tab = "home"; main.screen = "game"; main.refresh()
	var mig_ok: bool = _find("记下了") == null
	log_lines.append("旧档不出新手提示：" + ("PASS" if mig_ok else "FAIL"))
	ok = ok and mig_ok
	# 设置：文字速度、音量改了能存能读
	if g.world and not g.world.pending().is_empty():
		g.world.auto_choose()
		g.world.close()
	main.modal = {}
	var sp0: int = main.text_speed
	var vm0: float = main.vol_music
	main.show_settings = true; main.refresh()
	var st_ok: bool = click("立即")
	st_ok = st_ok and main.text_speed == 3
	main.vol_music = 0.35
	main._save_settings()
	main.text_speed = 1; main.vol_music = 0.8
	main._load_settings()
	st_ok = st_ok and main.text_speed == 3 and absf(main.vol_music - 0.35) < 0.01
	main.text_speed = sp0; main.vol_music = vm0; main._save_settings()
	st_ok = st_ok and click("回去") and not main.show_settings
	log_lines.append("设置（文字速度/音量存读）：" + ("PASS" if st_ok else "FAIL"))
	ok = ok and st_ok
	log_lines.append("UI 冒烟：" + ("PASS" if ok else "FAIL"))
	for l in log_lines:
		print(l)
	var f := FileAccess.open("res://tests/ui_smoke_results.txt", FileAccess.WRITE)
	f.store_string("\n".join(log_lines) + "\n")
	quit(0 if ok else 1)
