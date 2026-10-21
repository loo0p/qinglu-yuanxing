extends SceneTree
## UI 冒烟测试——无头实例化主场景，按按钮文字点完整条均衡路线（对话框会自动点 ▼ 读完）。
## 只证明界面流程能走通、没有脚本错误；不代表任何真机/浏览器表现。
var main
var log_lines: PackedStringArray = []
var steps := 0

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://qinglu_slot1.json"))
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
func click(prefix: String) -> bool:
	for attempt in 16:
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
	ok = ok and seq(["新游戏", "出发", "知道了", "历练", "出发：后山"])
	ok = ok and seq(["溪边", "贴上避水符", "继续", "溪畔野地", "采一把续骨草", "继续", "葛老三", "递上续骨草", "继续", "古松残碑", "拓下碑文", "继续", "归途", "回青庐", "回家", "进屋"])
	ok = ok and seq(["开第三块阳田", "修炼", "2 日"]) if false else ok and seq(["开第三块阳田", "修炼"])
	# 闭关 2 日：点 1 日两次
	ok = ok and seq(["1 日", "1 日", "历练", "● 后山"]) if false else ok and seq(["1 日", "1 日", "历练"])
	ok = ok and seq(["寒潭", "+1（1灵石）", "+1（1灵石）", "出发：寒潭"])
	ok = ok and seq(["冷杉道", "向他打听老龟", "继续", "寒潭野地", "拢紧衣襟", "继续", "潭边石屋", "坐下烤火", "继续", "寒潭老龟", "在石头上坐下", "继续",
		"冰瀑", "站定", "继续", "猎屋", "点上蜡烛", "继续", "雾林", "掩住口鼻", "继续", "回程野地", "加快脚步", "继续", "归途", "回青庐", "回家", "进屋"])
	ok = ok and seq(["修炼", "3 日", "历练", "后山", "出发：后山", "溪边", "快走", "继续", "向阳坡", "伏在草里", "继续", "归途", "回青庐", "回家", "进屋"])
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
	log_lines.append("结局：%s 第 %d 日；点击 %d 次" % [g.s["ending"], g.s["day"], steps])
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
	log_lines.append("UI 冒烟：" + ("PASS" if ok else "FAIL"))
	for l in log_lines:
		print(l)
	var f := FileAccess.open("res://tests/ui_smoke_results.txt", FileAccess.WRITE)
	f.store_string("\n".join(log_lines) + "\n")
	quit(0 if ok else 1)
