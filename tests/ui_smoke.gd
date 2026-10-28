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

func _count_faces(n: Node) -> int:
	var k := 0
	if n.get_script() == preload("res://scripts/portrait_box.gd") and n.is_visible_in_tree():
		k += 1
	for ch in n.get_children():
		k += _count_faces(ch)
	return k

func _has_text(n: Node, words: Array) -> bool:
	if n is Label or n is Button:
		for wd in words:
			if String(n.text).replace("\u200b", "").find(wd) >= 0:
				log_lines.append("有男修/女修字样：" + n.text)
				return true
	for ch in n.get_children():
		if _has_text(ch, words):
			return true
	return false

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

## v0.13：去某处游历，逐月点小去处，直到碰上地点奇遇（loc 变成 trip）
func roam_until_vignette(pl: String, max_m: int) -> bool:
	if not seq(["历练", pl, "去%s游历" % pl]):
		return false
	var sps: Array = main.TV.spots(pl)
	for m in max_m:
		drain_story()
		if main.g.s["loc"] == "trip":
			return true
		if main.g.s["loc"] != "roam":
			return false
		main.g.s["ration"] = 12
		main.refresh()
		if not click(String(sps[m % sps.size()][0])):
			return false
	return main.g.s["loc"] == "trip"

## 读完对话，点第一个能选的选项，再“继续”回到游历
func play_vignette() -> bool:
	var ev: Dictionary = main.g.event_view()
	var lab := ""
	for o in ev["options"]:
		if o["enabled"]:
			lab = String(o["label"])
			break
	var ok2 := click(lab)
	drain_story()
	ok2 = ok2 and click("继续")
	drain_story()
	return ok2 and main.g.s["loc"] == "roam"

func seq(list: Array) -> bool:
	for x in list:
		if not click(x):
			return false
	return true

func _go() -> void:
	var ok := true
	ok = ok and seq(["新游戏", "出发", "知道了"])
	# 新手提示：新局第 1 日在青庐有《旧主手记》里的提示；“记下了”后不再出；去历练页又有一张
	var gd_ok: bool = main.g.s.has("guide") and _find("记下了") != null
	gd_ok = gd_ok and click("记下了") and _find("记下了") == null
	main.tab = "depart"; main.refresh()
	gd_ok = gd_ok and _find("记下了") != null
	main.tab = "home"; main.refresh()
	log_lines.append("新手提示（新局出现、记下后消失）：" + ("PASS" if gd_ok else "FAIL"))
	ok = ok and gd_ok
	# v0.12.1：底栏页签不折行
	var nav_ok := true
	for b in buttons(main.footer, []):
		if b.autowrap_mode != TextServer.AUTOWRAP_OFF:
			nav_ok = false
	log_lines.append("底栏页签不折行：" + ("PASS" if nav_ok else "FAIL"))
	ok = ok and nav_ok
	# v0.13：没有路书了——去后山游历，一月逛一处，碰上手记里写过的事（地点奇遇）就照常选，选完回到游历
	var vg_ok := roam_until_vignette("后山", 30) and play_vignette()
	vg_ok = vg_ok and seq(["回青庐", "进屋"]) and main.g.s["loc"] == "home"
	log_lines.append("后山游历碰上地点奇遇、选完回游历、回家：" + ("PASS" if vg_ok else "FAIL"))
	ok = ok and vg_ok
	ok = ok and seq(["开第三块阳田", "静室", "一月", "一月", "历练"])
	# v0.11：寒潭要修到二层或听够风声才认得路；冒烟测试只测界面，这里直接记作认得
	if main.g.world != null and not main.TV.unlocked(main.g.world, "寒潭"):
		main.TV.unlock(main.g.world, "寒潭", "风声", true)
		main.refresh()
	var ht_ok := roam_until_vignette("寒潭", 30) and play_vignette()
	ht_ok = ht_ok and seq(["回青庐", "进屋"]) and main.g.s["loc"] == "home"
	log_lines.append("寒潭游历碰上地点奇遇：" + ("PASS" if ht_ok else "FAIL"))
	ok = ok and ht_ok
	# 底栏五个页签都能点开（青庐/历练/行囊/江湖/生平）
	var nav_ok := true
	for tb in [["行囊", "pack"], ["生平", "life"], ["江湖", "jianghu"], ["历练", "depart"], ["青庐", "home"]]:
		drain_story()
		nav_ok = nav_ok and click(tb[0]) and main.tab == tb[1]
	log_lines.append("底栏 青庐/历练/行囊/江湖/生平：" + ("PASS" if nav_ok else "FAIL"))
	ok = ok and nav_ok
	# v0.11 游历：世界图 → 点坊市 → 去游历 → 逛一处 → 上前搭话（相逢）→ 回青庐
	var rm_ok := true
	var gw0 = main.g.world
	var meet0 := int(gw0.w["fired"].get("相逢", 0)) if gw0 else 0
	rm_ok = rm_ok and seq(["历练", "坊市", "去坊市游历"]) and main.g.s["loc"] == "roam"
	rm_ok = rm_ok and seq(["茶肆"])
	drain_story()
	if gw0:
		gw0.w["appr"] = -1
		main.refresh()
	# v0.11.1：这一带的人是画像卡（名字 + 画像），不写“男修/女修”
	var ppl_here: int = main.TV.present_at(gw0, "坊市").size() if gw0 else 0
	var faces := _count_faces(main)
	var gender_txt := _has_text(main, ["男修", "女修"])
	var cards_ok := (ppl_here == 0 or faces >= mini(ppl_here, 1)) and not gender_txt
	log_lines.append("游历页画像卡（在场 %d 人，画像 %d 张，无男修/女修字样）：%s" % [ppl_here, faces, "PASS" if cards_ok else "FAIL"])
	rm_ok = rm_ok and cards_ok
	# 点画像卡 = 看看这个人，看完回游历页
	if ppl_here > 0:
		var look_ok := false
		for b in buttons(main.body, []):
			if b.text == "" and _count_faces(b) > 0:
				b.pressed.emit()
				look_ok = main.modal.get("kind", "") == "person" and click("回坊市") and main.g.s["loc"] == "roam" and main.modal.is_empty()
				break
		log_lines.append("点画像卡看人、再回游历页：" + ("PASS" if look_ok else "FAIL"))
		rm_ok = rm_ok and look_ok
	rm_ok = rm_ok and click("上前")
	drain_story()
	rm_ok = rm_ok and gw0 != null and int(gw0.w["fired"].get("相逢", 0)) > meet0
	rm_ok = rm_ok and seq(["去别处"]) and main.sheet == "goto"
	main.sheet = ""
	main.refresh()
	rm_ok = rm_ok and seq(["回青庐", "进屋"]) and main.g.s["loc"] == "home"
	log_lines.append("世界图 → 游历 → 相逢 → 回家：" + ("PASS" if rm_ok else "FAIL"))
	ok = ok and rm_ok
	var jh := true
	var gw = main.g.world
	# 江湖页与人物卡能打开（回家时可能正好弹出一件事，先读完）
	drain_story()
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
	# v0.10 插手：江湖页的“听说某某要……”传闻带“插手”按钮，点开是一件可选的事，选完写进她的生平
	var md_ok := false
	if gw:
		gw.close()
		var ns: Array = gw.npcs()
		for pt in gw.MD.plots(gw):
			pt["p"] = 2
		var pid: int = int(gw.w.get("pln", 0))
		gw.MD.plan(gw, ns[0], "寻仇", ns[1], -1, true)
		var pt0: Dictionary = gw.MD.get_plot(gw, pid)
		if gw.w["news"].filter(func(n): return n.size() > 4 and int(n[4]) == pid).is_empty():
			gw.rumor(gw.MD.leak(gw, pt0), [ns[0]], "谋")
			gw.w["news"][-1].append(pid)
		main.tab = "jianghu"
		main.modal = {}
		main.refresh()
		var mb = _find("插手")
		if mb:
			mb.pressed.emit()
			md_ok = main.modal.get("kind", "") == "story" and String(gw.pending().get("tid", "")) == "插手"
			var n0: int = main.g.world.P()["log"].size()
			drain_story()
			md_ok = md_ok and gw.pending().is_empty() and (int(pt0["p"]) != 0 or int(pt0.get("ig", 0)) == 1)
			md_ok = md_ok and gw.P()["log"].size() > n0
	log_lines.append("江湖页传闻“插手”：" + ("PASS" if md_ok else "FAIL"))
	ok = ok and md_ok
	main.modal = {}
	main.tab = "home"
	main.refresh()
	ok = ok and jh
	var g = main.g
	log_lines.append("第三趟后：D%d 赤阳果 %d 寒潭莲 %d 修为 %d" % [g.s["day"], g.total_n("herb_chiyangguo"), g.total_n("herb_hantanlian"), g.s["xiuwei"]])
	# 收尾：反复“全部服下 / 按目标排程 / 1 日”直到可以冲关
	g.s["debug_zhuji"] = "succeed"
	# v0.13：主药不再靠两条路书必得（游历奇遇/坊市/种莲/野外偶得），冒烟只测界面，这里直接放进仓
	if g.total_n("herb_chiyangguo") == 0:
		g.s["store"]["herb_chiyangguo"] = 1
	if g.total_n("herb_hantanlian") == 0:
		g.s["store"]["herb_hantanlian"] = 1
	g.s["store"]["herb_qingzhi"] = int(g.s["store"].get("herb_qingzhi", 0)) + 6
	for i in 60:
		if g.can_breakthrough() == "":
			break
		click("青庐")
		if click("全部服下"):
			click("服下")
		click("按目标排程")
		if _find("静室") and click("静室") and click("三月") and main.modal.get("kind", "") == "seclude":
			click("推开静室的门")
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
	var ups := []
	if g.world:
		for l in g.world.P()["log"]:
			if String(l[1]).begins_with("修为精进"):
				ups.append("D%d%s" % [int(l[0]), String(l[1]).substr(6, 4)])
	log_lines.append("修为精进提示 %d 次：%s" % [ups.size(), " ".join(ups)])
	ok = ok and ups.size() >= 6
	ok = ok and g.world != null and stories >= 3
	ok = ok and int(g.s["plv"]) >= 9   # v0.13：筑基是里程碑，不再是结局
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
