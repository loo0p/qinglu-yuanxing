extends SceneTree
## 乱点试玩：像不看攻略的玩家那样，在主场景里随机点当前可点的按钮（不总点第一个）。
## 3 个种子 × 最多 1500 次点击。查：有没有“一个能点的都没有”的死局、长时间日子不动的卡住、脚本错误（看输出）。
## 除了标题页（点“返回”回到标题时要能再进来）不点“新游戏/重新开始/删档”，免得把局面清空；只证明流程不卡，不代表真机表现。
var main
var lines: PackedStringArray = []
var rng := RandomNumberGenerator.new()

func _init() -> void:
	process_frame.connect(_go, CONNECT_ONE_SHOT)

func buttons(n: Node, out: Array) -> Array:
	for c in n.get_children():
		if c is Button and c.is_inside_tree() and c.is_visible_in_tree() and not c.disabled:
			out.append(c)
		buttons(c, out)
	return out

func _clear() -> void:
	for f in ["qinglu_v6_slot1.json", "qinglu_v6_slot1.bak", "qinglu_v6_slot1.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + f))

## 测试目录里可能留着别的测试写的 v0.5 旧档：先挪开、跑完挪回（不删）
func _stash(back: bool) -> void:
	for f in ["qinglu_slot1.json", "qinglu_slot1.bak"]:
		var a := ProjectSettings.globalize_path("user://" + f)
		var b := a + ".play_random"
		if back and FileAccess.file_exists(b):
			DirAccess.rename_absolute(b, a)
		elif not back and FileAccess.file_exists(a):
			DirAccess.rename_absolute(a, b)

func _go() -> void:
	var fails := 0
	_stash(false)
	for sd in [11, 22, 33]:
		_clear()
		rng.seed = sd
		main = load("res://scenes/Main.tscn").instantiate()
		root.add_child(main)
		await process_frame
		var started := false
		var dead := 0
		var last_day := -1
		var still := 0
		var worst_still := 0
		var screens := {}
		var clicks := 0
		var stuck_at := ""
		var in_person := 0
		for i in 1500:
			var bs: Array = buttons(main, [])
			if not started:
				for b in bs:
					if b.text.begins_with("新游戏"):
						b.pressed.emit(); started = true
						break
				await process_frame
				continue
			bs = bs.filter(func(b): return not ((b.text.contains("新游戏") and main.screen != "title") or b.text.contains("重新") or b.text.contains("删") or b.text.contains("再来一局")))
			var g = main.g
			if g.s.get("ending", "") != "":
				break
			if bs.is_empty():
				dead += 1
				stuck_at = "%s/%s/%s" % [main.screen, main.modal.get("kind", ""), main.sheet]
				if dead > 3:
					break
				await process_frame
				continue
			dead = 0
			# 对话框的 ▼ 是“读下去”，玩家总会点；其余随机
			var adv = bs.filter(func(b): return b.text == "▼")
			# 换页签/返回这类按钮权重 1，能推进事情的按钮权重 3（真人不会一直来回切页签）
			var NAV := ["", "♪", "♪×", "青庐", "历练", "行记", "江湖", "修炼", "返回", "收起", "回江湖", "关系", "生平", "● 生平", "记得她", "她的生平", "心事", "● 心事", "● 关系", "● 记得她"]
			var pool := []
			for x in bs:
				for k in (1 if x.text in NAV else 3):
					pool.append(x)
			var b = adv[0] if not adv.is_empty() and rng.randf() < 0.9 else pool[rng.randi() % pool.size()]
			# 人物卡里能一张张点进别人的卡，真人翻二三十下总会关掉
			if String(main.modal.get("kind", "")) == "person":
				in_person += 1
				if in_person > 25:
					var cl = bs.filter(func(x): return x.text in ["回江湖", "返回", "收起"])
					if not cl.is_empty():
						b = cl[0]
						in_person = 0
			else:
				in_person = 0
			screens["%s|%s|%s" % [main.screen, main.modal.get("kind", ""), main.sheet]] = 1
			var here := "%s/%s/%s 按钮：%s" % [main.screen, main.modal.get("kind", ""), main.sheet, ", ".join(bs.slice(0, 10).map(func(x): return x.text.replace("\n", "/")))]
			b.pressed.emit()
			clicks += 1
			await process_frame
			var d := int(g.s.get("day", 0))
			if d == last_day:
				still += 1
				if still > worst_still:
					worst_still = still
					stuck_at = here
			else:
				still = 0
				last_day = d
		var g = main.g
		var w = g.world
		var info := "种子 %d：点击 %d，第 %d 日，历练 %d 趟，结局「%s」，江湖事件 %d，界面 %d 种，最久 %d 次点击日子没动（%s）" % [
			sd, clicks, int(g.s.get("day", 0)), int(g.s.get("trips_done", 0)), String(g.s.get("ending", "")),
			w.w["events"].size() if w else 0, screens.size(), worst_still, stuck_at]
		var bad: bool = dead > 3 or worst_still > 300
		lines.append(("FAIL " if bad else "PASS ") + info)
		if bad:
			fails += 1
		main.queue_free()
		await process_frame
	_clear()
	_stash(true)
	for l in lines:
		print(l)
	print("乱点试玩：%d 失败" % fails)
	quit(1 if fails > 0 else 0)
