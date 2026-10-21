extends Control
## 《青庐远行》v0.3 试玩版 · 界面层
## 竖屏 360×640。所有界面用代码搭建；规则全部在 GameState，这里只负责显示、音画和调用。

const GS = preload("res://scripts/game_state.gd")
const Store = preload("res://scripts/save_store.gd")
const VERSION = "v0.3 试玩版"

const C_BG := Color("#F3EEE2")
const C_TEXT := Color("#2E2A24")
const C_ACCENT := Color("#34586A")
const C_DIM := Color("#7D7466")
const C_WARN := Color("#9A4A2A")
const C_CARD := Color(1.0, 0.99, 0.965, 0.9)
const C_INK := Color("#4A3F33")
const NAMES_PRESET = ["苏青禾", "林晚照", "沈知微", "温小满"]
const PORTRAIT = {"aunt": "por_aunt", "turtle": "por_turtle", "gelaosan": "por_gelaosan", "heroine": "por_heroine"}

var g: GS
var store = Store.new()
var screen = "title"     # title | create | game
var tab = "home"         # home | depart | cult | log
var modal: Dictionary = {}  # 叠在上面的卡片：{"kind":..., ...}
var create_name = "苏青禾"
var create_cherish = "aunt"
var selected_route = "houshan"
var reserve_override = -1
var preset_save_mode = false
var play_ms_base = 0
var session_start = 0

var header: VBoxContainer
var body: VBoxContainer
var scroll: ScrollContainer
var footer: VBoxContainer
var toast: Label
var bg_rect: TextureRect
var veil: TextureRect
var content: Control
var js_cb = null
var dev_cb = null
var font_body: Font
var font_brush: Font
var tex_cache = {}
var cur_bg = ""
var scene_key = ""
# 音频：第一次点击之后才开始（浏览器策略 + 不吓人）
var bgm: AudioStreamPlayer
var sfx_players = []
var audio_unlocked = false
var muted = false
var cur_bgm = ""
var snd_cache = {}

func _ready() -> void:
	g = GS.new()
	_load_settings()
	font_body = _font("res://fonts/WenKai-sub.ttf")
	font_brush = _font("res://fonts/MaShanZheng-sub.ttf")
	theme = _make_theme()
	bg_rect = TextureRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_rect)
	veil = TextureRect.new()   # 纸纹罩层：让文字压得住背景
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.texture = tex("paper")
	veil.stretch_mode = TextureRect.STRETCH_TILE
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var m = MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	add_child(m)
	content = m
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)
	header = VBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	v.add_child(header)
	toast = Label.new()
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.add_theme_color_override("font_color", C_WARN)
	toast.add_theme_font_size_override("font_size", 14)
	toast.visible = false
	v.add_child(toast)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	footer = VBoxContainer.new()
	footer.add_theme_constant_override("separation", 6)
	v.add_child(footer)
	bgm = AudioStreamPlayer.new()
	bgm.volume_db = -8.0
	add_child(bgm)
	for i in 3:
		var sp = AudioStreamPlayer.new()
		sp.volume_db = -4.0
		add_child(sp)
		sfx_players.append(sp)
	_hook_web()
	session_start = Time.get_ticks_msec()
	refresh()

func _font(path: String) -> Font:
	var f = load(path)
	if f == null:
		return null
	var fv = FontVariation.new()
	fv.base_font = f
	return fv

# ------------------------------------------------------------ 资源（webp/ogg 原样打包，运行时解码，省体积）
func tex(name: String) -> Texture2D:
	if tex_cache.has(name):
		return tex_cache[name]
	var t: Texture2D = null
	var bytes = FileAccess.get_file_as_bytes("res://assets/img/%s.webp" % name)
	if bytes.size() > 0:
		var img = Image.new()
		if img.load_webp_from_buffer(bytes) == OK:
			t = ImageTexture.create_from_image(img)
	tex_cache[name] = t
	return t

func snd(name: String) -> AudioStream:
	if snd_cache.has(name):
		return snd_cache[name]
	var a: AudioStream = null
	var bytes = FileAccess.get_file_as_bytes("res://assets/audio/%s.ogg" % name)
	if bytes.size() > 0:
		a = AudioStreamOggVorbis.load_from_buffer(bytes)
		if a and name.begins_with("bgm"):
			a.loop = true
	snd_cache[name] = a
	return a

func sfx(name: String) -> void:
	if not audio_unlocked or muted:
		return
	var st = snd(name)
	if st == null:
		return
	for sp in sfx_players:
		if not sp.playing:
			sp.stream = st
			sp.play()
			return
	sfx_players[0].stream = st
	sfx_players[0].play()

func _set_bgm(name: String) -> void:
	if name == cur_bgm and (bgm.playing or muted or not audio_unlocked):
		return
	cur_bgm = name
	if not audio_unlocked or muted:
		return
	var st = snd(name)
	if st == null:
		return
	var tw = create_tween()
	if bgm.playing:
		tw.tween_property(bgm, "volume_db", -40.0, 0.6)
	tw.tween_callback(func():
		bgm.stream = st
		bgm.volume_db = -40.0
		bgm.play())
	tw.tween_property(bgm, "volume_db", -8.0, 1.2)

func _input(ev: InputEvent) -> void:
	if audio_unlocked:
		return
	if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
		audio_unlocked = true
		var want = cur_bgm
		cur_bgm = ""
		_set_bgm(want if want != "" else _bgm_for_scene())

func _toggle_mute() -> void:
	muted = not muted
	if muted:
		bgm.stop()
	else:
		var want = cur_bgm
		cur_bgm = ""
		_set_bgm(want)
	_save_settings()

func _load_settings() -> void:
	var cf = ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		muted = bool(cf.get_value("audio", "muted", false))

func _save_settings() -> void:
	var cf = ConfigFile.new()
	cf.set_value("audio", "muted", muted)
	cf.save("user://settings.cfg")

func _make_theme() -> Theme:
	var t = Theme.new()
	if font_body:
		t.default_font = font_body
	t.default_font_size = 16
	t.set_color("font_color", "Label", C_TEXT)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb = StyleBoxFlat.new()
		sb.bg_color = {"normal": Color(0.985, 0.97, 0.935, 0.94), "hover": Color(0.985, 0.97, 0.935, 0.94), "pressed": Color("#E3D8C2"),
			"disabled": Color(0.93, 0.915, 0.88, 0.75), "focus": Color(0.985, 0.97, 0.935, 0.94)}[st]
		sb.border_color = C_INK if st != "disabled" else Color("#CFC6B4")
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.border_width_bottom = 2 if st != "pressed" else 1
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 7
		sb.content_margin_bottom = 7
		if st == "pressed":
			sb.content_margin_top = 8
		t.set_stylebox(st, "Button", sb)
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", C_TEXT)
	t.set_color("font_pressed_color", "Button", C_ACCENT)
	t.set_color("font_disabled_color", "Button", Color("#A39B8C"))
	t.set_color("font_focus_color", "Button", C_TEXT)
	var card = StyleBoxFlat.new()
	card.bg_color = C_CARD
	card.border_color = Color(0.29, 0.25, 0.2, 0.28)
	card.set_border_width_all(1)
	card.set_corner_radius_all(4)
	card.set_content_margin_all(10)
	card.shadow_color = Color(0.2, 0.15, 0.1, 0.12)
	card.shadow_size = 3
	card.shadow_offset = Vector2(0, 1)
	t.set_stylebox("panel", "PanelContainer", card)
	var vs = StyleBoxFlat.new()
	vs.bg_color = Color(0.29, 0.25, 0.2, 0.25)
	vs.set_corner_radius_all(2)
	t.set_stylebox("grabber", "VScrollBar", vs)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	return t

func _bg_for_scene() -> String:
	match screen:
		"title":
			return "title"
		"create":
			return "bg_home"
	match String(g.s.get("loc", "home")):
		"ending":
			return "bg_ending"
		"xinmo":
			return "bg_biguan"
		"trip":
			return "bg_houshan" if String(g.s["trip"].get("route", "houshan")) == "houshan" else "bg_hantan"
	return "bg_biguan" if tab == "cult" else "bg_home"

func _bgm_for_scene() -> String:
	match _bg_for_scene():
		"title", "bg_home":
			return "bgm_home"
		"bg_houshan":
			return "bgm_travel"
		"bg_hantan":
			return "bgm_hantan"
		"bg_biguan":
			return "bgm_xinmo" if String(g.s.get("loc", "")) == "xinmo" else "bgm_home"
		"bg_ending":
			return "bgm_ending"
	return "bgm_home"

func _apply_scene() -> void:
	var b = _bg_for_scene()
	if b != cur_bg:
		cur_bg = b
		bg_rect.texture = tex(b)
		bg_rect.modulate = Color(1, 1, 1, 0.3)
		create_tween().tween_property(bg_rect, "modulate:a", 1.0, 0.5)
	# 标题页让画露出来；其余页面纸色压低背景
	var a = 0.18 if screen == "title" else (0.62 if screen == "create" or g.s.get("loc", "") in ["ending", "trip"] else 0.72)
	veil.modulate = Color(1, 1, 1, a)
	_set_bgm(_bgm_for_scene())
	var key = "%s|%s|%s|%s|%s" % [screen, tab, modal.get("kind", ""), g.s.get("loc", ""), g.s.get("trip", {}).get("stage", "") + String(g.s.get("trip", {}).get("node", ""))]
	if key != scene_key:
		scene_key = key
		content.modulate = Color(1, 1, 1, 0.0)
		create_tween().tween_property(content, "modulate:a", 1.0, 0.22)
		scroll.scroll_vertical = 0

# ------------------------------------------------------------ 小部件
func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

func L(text: String, size: int = 15, color: Color = C_TEXT, parent: Node = null) -> Label:
	var l = Label.new()
	l.text = text
	var par: Node = parent if parent else body
	l.autowrap_mode = TextServer.AUTOWRAP_OFF if par is HBoxContainer else TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	(parent if parent else body).add_child(l)
	return l

func H(text: String, size: int = 22, color: Color = C_ACCENT, parent: Node = null) -> Label:
	var l = L(text, size, color, parent)
	if font_brush:
		l.add_theme_font_override("font", font_brush)
	return l

func portrait(key: String, parent: Node, size: int = 88) -> void:
	var t = tex(PORTRAIT.get(key, key))
	if t == null:
		return
	var tr = TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(size, size)
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(tr)

func B(text: String, cb: Callable, enabled: bool = true, parent: Node = null, h: int = 44) -> Button:
	var b = Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(func(): _press(cb))
	b.button_down.connect(func():
		b.pivot_offset = b.size / 2
		var tw = b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.97, 0.97), 0.05)
		tw.tween_property(b, "scale", Vector2.ONE, 0.12))
	(parent if parent else body).add_child(b)
	return b

func row(parent: Node = null) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	(parent if parent else body).add_child(h)
	return h

func card(parent: Node = null) -> VBoxContainer:
	var p = PanelContainer.new()
	(parent if parent else body).add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	return v

func _press(cb: Callable) -> void:
	sfx("sfx_click")
	var before = [g.s.get("loc", ""), g.s.get("trip", {}).get("stage", ""), g.s.get("ending", "")]
	cb.call()
	var after = [g.s.get("loc", ""), g.s.get("trip", {}).get("stage", ""), g.s.get("ending", "")]
	if after[2] != "" and before[2] == "":
		sfx("sfx_bell")
	elif after[1] == "event" and before[1] != "event":
		sfx("sfx_pluck")
	elif after[1] == "result" and before[1] != "result":
		var r = String(g.s.get("trip", {}).get("result", {}).get("roll", ""))
		sfx("sfx_bad" if r == "败" else ("sfx_good" if r != "" else "sfx_page"))
	_after_action()

func N(id: String) -> String:
	return GS.NAMES.get(id, id)

# ------------------------------------------------------------ 存档
func _after_action() -> void:
	if screen == "game":
		_save()
	refresh()

func _save() -> void:
	if g.s.is_empty():
		return
	g.s["play_ms"] = play_ms_base + (Time.get_ticks_msec() - session_start)
	if not store.save(g.to_dict()) and store.conflict:
		modal = {"kind": "conflict"}

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		if screen == "game":
			_save()

func _hook_web() -> void:
	if not OS.has_feature("web"):
		return
	js_cb = JavaScriptBridge.create_callback(func(_a): if screen == "game": _save())
	var w = JavaScriptBridge.get_interface("window")
	if w:
		w.qinglu_save = js_cb
		# 调试钩子只在调试导出里有（截图/验收用）；玩家版（release 导出）没有
		if OS.is_debug_build():
			dev_cb = JavaScriptBridge.create_callback(func(a): return _dev(String(a[0]) if a.size() > 0 else ""))
			w.qinglu_dev = dev_cb
		JavaScriptBridge.eval("""
			document.addEventListener('visibilitychange', function(){ if (document.visibilityState==='hidden' && window.qinglu_save) window.qinglu_save(); });
			window.addEventListener('pagehide', function(){ if (window.qinglu_save) window.qinglu_save(); });
		""", true)

func _continue() -> void:
	var d = store.load_data()
	if d == null or not g.from_dict(d["state"]):
		modal = {"kind": "msg", "text": "存档读不出来（版本不符或已损坏）。旧档没有删除。"}
		return
	play_ms_base = int(g.s.get("play_ms", 0))
	session_start = Time.get_ticks_msec()
	screen = "game"
	tab = "home"

func _start_new() -> void:
	if store.exists():
		store.archive()
	g.new_game(create_name if create_name.strip_edges() != "" else "苏青禾", create_cherish)
	play_ms_base = 0
	session_start = Time.get_ticks_msec()
	screen = "game"
	tab = "home"
	modal = {"kind": "msg", "portrait": "aunt", "title": "离家", "text": "临行前一夜，姑母在灯下把干粮包了又包，又从针线匣底下摸出一张避水符，塞进她袖里。\n“后山的溪涨水了，你先去那边走走，认认路。”她顿了顿，“筑基的事，不急。人要先回来。”\n\n（底部「历练」出发）"}

# ------------------------------------------------------------ 刷新
func refresh() -> void:
	_refresh()
	_apply_scene()
	if OS.has_feature("web"):
		var w = JavaScriptBridge.get_interface("window")
		if w:
			w.qinglu_state = JSON.stringify({"screen": screen, "tab": tab, "modal": modal.get("kind", ""), "loc": g.s.get("loc", ""), "day": g.s.get("day", -1), "stage": g.s.get("trip", {}).get("stage", ""), "node": g.s.get("trip", {}).get("node", ""), "rev": store.rev, "persistent": OS.is_userfs_persistent(), "conflict": store.conflict, "bgm": cur_bgm, "bgm_playing": bgm.playing if bgm else false, "muted": muted, "unlocked": audio_unlocked, "snd_ok": snd_cache.get(cur_bgm) != null})

func _refresh() -> void:
	_clear(header)
	_clear(body)
	_clear(footer)
	toast.visible = false
	if not g.notices.is_empty():
		toast.text = "\n".join(g.notices)
		toast.visible = true
		g.notices.clear()
	if store.conflict:
		toast.text = "另一个标签页也打开了这个存档，这里已停止保存。请关闭其中一个后刷新。"
		toast.visible = true
	if not OS.is_userfs_persistent():
		L("⚠ 这个浏览器不能长期保存（可能是隐私模式），关掉页面进度会丢。", 12, C_WARN, header)
	match screen:
		"title":
			_title()
			return
		"create":
			_create()
			return
	_status()
	if not modal.is_empty():
		_modal()
		return
	if g.s["loc"] == "ending":
		_ending()
		return
	if g.s["loc"] == "xinmo":
		_xinmo()
		return
	if g.s["loc"] == "trip":
		_trip()
		return
	if g.s["extra"] == "" and int(g.s["trips_done"]) >= 1:
		_extra_choice()
		return
	match tab:
		"home": _home()
		"depart": _depart()
		"cult": _cult()
		"log": _log_tab()
	_nav()

func _status() -> void:
	var s = g.s
	var top = row(header)
	var tl = L("第 %d 日 · %s · %s" % [s["day"], s["name"], g.realm_text()], 16, C_TEXT, top)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mute_btn(top)
	var rt = RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.add_theme_font_size_override("normal_font_size", 14)
	rt.add_theme_color_override("default_color", C_TEXT)
	header.add_child(rt)
	rt.append_text("修为 %d/600 · [color=#34586A]待炼化 %d[/color] · 余韵 %d\n" % [s["xiuwei"], s["ganwu"], s["yuyun"]])
	for it in [["ico_ration", "干粮 %d/12" % s["ration"]], ["ico_lingshi", "灵石 %d" % s["lingshi"]], ["ico_qingzhi", "青芝 %d" % g.store_n("herb_qingzhi")], ["ico_juqi", "聚气丹 %d" % g.total_n("pill_juqi")]]:
		var ic = tex(it[0])
		if ic:
			rt.add_image(ic, 18, 18)
		rt.append_text(it[1] + "  ")

func _mute_btn(parent: Node) -> void:
	var mb = Button.new()
	mb.text = "静音" if not muted else "放声"
	mb.add_theme_font_size_override("font_size", 12)
	mb.custom_minimum_size = Vector2(52, 30)
	mb.pressed.connect(func(): _toggle_mute(); mb.text = "静音" if not muted else "放声")
	parent.add_child(mb)

func _nav() -> void:
	var r = row(footer)
	for t in [["home", "青庐"], ["depart", "历练"], ["log", "人物"], ["cult", "修炼"]]:
		var b = B(("● " if tab == t[0] else "") + t[1], func(): tab = t[0], true, r, 44)

# ------------------------------------------------------------ 标题 / 捏人
func _title() -> void:
	var top = row()
	var vtag = L(VERSION, 13, Color("#5A5046"), top)
	vtag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vtag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mute_btn(top)
	var gap = Control.new()
	gap.custom_minimum_size = Vector2(0, 70)
	body.add_child(gap)
	var t = H("青庐远行", 52, Color("#2B2620"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var st0 = L("一盏灯，一条山路，一个想筑基的姑娘", 15, Color("#4A3F33"))
	st0.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gap2 = Control.new()
	gap2.custom_minimum_size = Vector2(0, 150)
	body.add_child(gap2)
	if store.exists():
		var d = store.load_data()
		if d != null:
			var st = d["state"]
			var info = "%s · 第 %d 日 · %s" % [st.get("name", "?"), int(st.get("day", 0)), "已完结" if st.get("ended", false) else "进行中"]
			B("继续：" + info, _continue, true, null, 56)
		else:
			L("存档读不出来（已保留原文件）。", 13, C_WARN)
	B("新游戏", func(): screen = "create", true, null, 56)


func _create() -> void:
	H("离家之前", 28)
	var c0 = card()
	var hr = row(c0)
	portrait("heroine", hr, 96)
	var intro = L("青庐在山脚下，她跟着姑母长大。今年她十七岁，吐纳已到炼气圆满的门口，只差筑基这一步。", 15, C_TEXT, hr)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	L("她叫：", 15)
	var nr = GridContainer.new()
	nr.columns = 2
	nr.add_theme_constant_override("h_separation", 6)
	nr.add_theme_constant_override("v_separation", 6)
	body.add_child(nr)
	for nm in NAMES_PRESET:
		B(("◉ " if create_name == nm else "○ ") + nm, func(): create_name = nm, true, nr, 42)
	L("离家时，她最舍不得：", 15)
	for c in [["aunt", "姑母"], ["town", "小镇"], ["book", "一本书"]]:
		B(("◉ " if create_cherish == c[0] else "○ ") + c[1], func(): create_cherish = c[0], true, null, 42)
	var nc = card()
	L("这份牵挂，会在心魔劫里被问起。", 13, C_DIM, nc)
	if store.exists():
		L("已有存档：开始新游戏会把它另存为 qinglu_prev，不会删除。", 12, C_WARN, nc)
	L("进度只存在这台设备的浏览器里；换手机、清缓存都会丢。", 12, C_DIM, nc)
	B("出发", func(): _start_new(), true, footer, 52)
	B("返回", func(): screen = "title", true, footer, 40)

# ------------------------------------------------------------ 弹卡
func _modal() -> void:
	var k: String = modal["kind"]
	var c = card()
	match k:
		"msg":
			if modal.has("title"):
				H(modal["title"], 24, C_ACCENT, c)
			if modal.has("portrait"):
				portrait(modal["portrait"], c, 112)
			L(modal["text"], 16, C_TEXT, c)
			B("知道了", func(): modal = {}, true, footer, 52)
		"conflict":
			L("另一个标签页也在玩这个存档。为免互相覆盖，这一页已停止保存。\n请关掉其中一个页面，再刷新。", 15, C_WARN, c)
			B("知道了", func(): modal = {}, true, footer, 52)
		"home":
			var sm: Dictionary = modal["sum"]
			H("回到青庐", 24, C_ACCENT, c)
			L("柴门吱呀一声。姑母从灶间探出头来：“回来了？先吃饭。”", 15, C_TEXT, c)
			var lines = []
			if sm.get("turned_back", false):
				lines.append("半路折返。")
			var bk: Dictionary = sm.get("basket", {})
			if not bk.is_empty():
				var parts = []
				for id in bk:
					parts.append("%s ×%d" % [N(id), int(bk[id])])
				lines.append("采药篓入仓：" + "、".join(parts))
			lines.append("干粮 %d → %d（姑母补到 8%s）" % [sm["ration_before"], sm["ration_after"], "；寄存 %d 日份在姑母处" % sm["aunt_ration"] if int(sm["aunt_ration"]) > 0 else ""])
			lines.append("仓中青芝 %d · 丹炉 %s" % [g.store_n("herb_qingzhi"), _queue_text()])
			L("\n".join(lines), 14, C_TEXT, c)
			if sm.has("world"):
				var w = card()
				L("世事", 16, C_WARN, w)
				L(sm["world"], 14, C_TEXT, w)
			B("进屋", func(): modal = {}, true, footer, 52)
		"thought":
			L("◎ 这是关键选择，会被记住。", 14, C_ACCENT, c)
			L("她心里想：" + modal["text"], 16, C_TEXT, c)
			B("好", func(): modal = {}, true, footer, 48)
		"confirm_eat":
			var pv: Dictionary = modal["pv"]
			L("全部服下：聚气丹 ×%d" % pv["n"], 16, C_ACCENT, c)
			L("修为 +%d%s%s" % [pv["xw"], ("，进余韵 %d" % pv["yuyun"]) if pv["yuyun"] > 0 else "", ("\n其中 %d 颗过了 8 颗的减半线（每颗只 +15）" % pv["halved"]) if pv["halved"] > 0 else ""], 14, C_TEXT, c)
			if int(modal["reserve"]) > 0:
				L("留 %d 颗不吃（老龟那边也许用得上）。" % modal["reserve"], 13, C_DIM, c)
			B("服下", func(): g.eat_all(int(modal["reserve"])); modal = {}, true, footer, 52)
			B("算了", func(): modal = {}, true, footer, 40)
	if k in ["home"] and not g.s["pending_overflow"].is_empty():
		pass

# ------------------------------------------------------------ 第五点灵脉
func _extra_choice() -> void:
	var c = card()
	H("灵脉第五点", 24, C_ACCENT, c)
	L("青庐的灵脉多出一点，只够开一处：", 14, C_TEXT, c)
	L("· 第三块阳田：青芝多 50%，效率高。\n· 水田：每 6 日灵谷 +2（当干粮）、青芝 +1；能种寒潭莲子（20 日得一朵寒潭莲），是保险。", 13, C_TEXT, c)
	B("开第三块阳田", func(): g.choose_extra("field"), true, null, 52)
	B("开水田", func(): g.choose_extra("shuitian"), true, null, 52)

# ------------------------------------------------------------ 青庐
func _queue_text() -> String:
	if g.s["queue"].is_empty():
		return "空"
	var parts = []
	for q in g.s["queue"]:
		parts.append("%s(%d日)" % [GS.RECIPES[q[0]]["name"], int(q[1])])
	return " → ".join(parts)

func _home() -> void:
	var s = g.s
	var c = card()
	L("田", 15, C_ACCENT, c)
	var ft = []
	for i in s["fields"].size():
		ft.append("阳田%d：青芝 %d/6 日" % [i + 1, int(s["fields"][i]["prog"])])
	if s["extra"] == "shuitian":
		if int(s["lian_prog"]) >= 0:
			ft.append("水田：寒潭莲 %d/20 日" % int(s["lian_prog"]))
		else:
			ft.append("水田：灵谷 %d/6 日" % int(s["gu_prog"]))
	L("\n".join(ft), 13, C_TEXT, c)
	if g.can_plant_lianzi():
		B("水田种下寒潭莲子（20 日）", func(): g.plant_lianzi(), true, c)
	if s["extra"] != "":
		var rb: String = g.can_rebuild_extra()
		var bb = B("改建第 5 点 → %s（1 日 · 10 灵石）%s" % ["水田" if s["extra"] == "field" else "第三块阳田", "" if rb == "" else "（" + rb + "）"], func(): g.rebuild_extra(), rb == "", c, 34)
		bb.add_theme_font_size_override("font_size", 12)
	var f = card()
	L("丹炉（单队列）：" + _queue_text(), 14, C_ACCENT, f)
	var r = row(f)
	for k in ["juqi", "quzhang", "zhuji"]:
		var why: String = g.can_enqueue(k)
		var rc = GS.RECIPES[k]
		B("%s\n%d青芝·%d日" % [rc["name"], rc["qz"], rc["days"] if not (k == "zhuji" and s["zhuji_second"]) else 3], func(): g.enqueue(k), why == "", r, 52)
	var r2 = row(f)
	B("按目标排程", _auto_sched, true, r2)
	B("撤回队尾", func(): g.dequeue_last(), not s["queue"].is_empty(), r2)
	if s["queue"].size() > 1:
		var r4 = row(f)
		for i in s["queue"].size():
			var qi = i
			var qb = B("%s%s" % ["↑" if i > 0 else "", GS.RECIPES[s["queue"][i][0]]["name"].substr(0, 2)], func(): g.queue_move(qi, -1), i > 0, r4, 32)
			qb.add_theme_font_size_override("font_size", 11)
	var st = card()
	var items = []
	for id in s["store"]:
		items.append("%s ×%d" % [N(id), int(s["store"][id])])
	L("仓：" + ("、".join(items) if items.size() > 0 else "空"), 13, C_TEXT, st)
	var res = default_reserve()
	var pv = g.eat_preview(res)
	var r3 = row(st)
	B("全部服下（%d 颗）" % pv["n"], func(): modal = {"kind": "confirm_eat", "pv": pv, "reserve": res}, pv["n"] > 0, r3)
	if res > 0:
		B("连留的也吃", func(): modal = {"kind": "confirm_eat", "pv": g.eat_preview(0), "reserve": 0}, true, r3)
		L("没去过寒潭、手上有聚气丹：默认留 1 颗。", 12, C_DIM, st)
	if g.gelaosan_fruit_available():
		B("托葛老三捎一颗赤阳果（−20 灵石）", func(): g.buy_gelaosan_fruit(), s["lingshi"] >= 20, st)
	var why: String = g.can_breakthrough()
	if why == "":
		B("◎ 冲关（筑基，耗 1 日）", func(): g.start_breakthrough(), true, footer, 52)

func _auto_sched() -> void:
	var a: Array = g.auto_schedule()
	var names = []
	for x in a:
		names.append(GS.RECIPES[x]["name"])
	g.notice("排上：" + ("、".join(names) if names.size() > 0 else "（没有可排的：青芝或主药不够，或聚气丹已排满 8 颗）"))

func default_reserve() -> int:
	return g.default_reserve()

# ------------------------------------------------------------ 修炼 / 闭关
func _cult() -> void:
	var s = g.s
	var c = card()
	L("%s · 修为 %d/600" % [g.realm_text(), s["xiuwei"]], 16, C_ACCENT, c)
	L("待炼化感悟 %d（每日最多炼化 20%s）· 圆满余韵 %d/120" % [s["ganwu"], "，受伤减半" if s["injured"] > 0 else ("，心境不稳减半" if s["unstable"] > 0 else ""), s["yuyun"]], 13, C_TEXT, c)
	L("聚气丹已服 %d 颗（第 9 颗起减半）" % s["juqi_eaten"], 12, C_DIM, c)
	var hint: String = g.xw_full_hint()
	if hint != "":
		L(hint, 13, C_WARN, c)
	H("闭关", 24)
	L("关门打坐，田和丹炉照常推进。", 13, C_DIM)
	B("炼完为止（待炼化归零就停，约 %d 日）" % int(ceil(s["ganwu"] / 20.0)), func(): g.biguan("refine"), s["ganwu"] > 0)
	var tgt = ""
	for q in s["queue"]:
		if q[0] == "zhuji":
			tgt = "zhuji"
	if tgt == "" and not s["queue"].is_empty():
		tgt = s["queue"][0][0]
	B("到丹成（%s）" % (GS.RECIPES[tgt]["name"] if tgt != "" else "炉空"), func(): g.biguan("pill", 1, tgt), tgt != "")
	var r = row()
	for n in [1, 3, 5]:
		B("%d 日" % n, func(): g.biguan("days", n), true, r)
	var why: String = g.can_breakthrough()
	L("冲关：" + ("条件已齐" if why == "" else why), 13, C_TEXT if why == "" else C_DIM)
	B("◎ 冲关（筑基，耗 1 日）", func(): g.start_breakthrough(), why == "", footer, 52)

# ------------------------------------------------------------ 人物 / 行记
func _log_tab() -> void:
	H("人物记得的事", 24)
	if g.s["memory"].is_empty():
		L("（还没有）", 13, C_DIM)
	for m in g.s["memory"]:
		L("第%d日 · %s：%s" % [int(m["day"]), m["npc"], m["text"]], 14)
	H("青庐行记", 24)
	var lg: Array = g.s["log"]
	for i in range(lg.size() - 1, maxi(-1, lg.size() - 40), -1):
		L("第%d日  %s" % [int(lg[i]["day"]), lg[i]["text"]], 14)
	L("倾向：力 %d · 利 %d · 善 %d · 避 %d" % [g.s["tags"]["力"], g.s["tags"]["利"], g.s["tags"]["善"], g.s["tags"]["避"]], 12, C_DIM)

# ------------------------------------------------------------ 出发页（一屏：路线 + 风闻 + 三段式行囊）
func _depart() -> void:
	var s = g.s
	var r = row()
	for rid in ["houshan", "hantan"]:
		B(("● " if selected_route == rid else "") + g.routes[rid]["name"], func(): selected_route = rid, true, r, 36)
	var rt = g.routes[selected_route]
	var rc = card()
	for ru in rt["rumors"]:
		L("风闻 · " + ru["text"], 14, C_ACCENT if ru.get("key", false) else C_TEXT, rc)
	L("路线：" + _route_outline(selected_route), 13, C_DIM, rc)
	var pc = card()
	var rr = row(pc)
	L("干粮袋 %d/12" % s["ration"], 14, C_TEXT, rr)
	B("+1（1灵石）", func(): g.buy_rations(1), s["ration"] < 12 and s["lingshi"] > 0, rr, 36)
	B("装灵谷", func(): g.load_grain(), g.store_n("crop_linggu") > 0 and s["ration"] < 12, rr, 36)
	L("随身 %d/6 格（点格放回仓；◎=留作钥匙）· 采药篓 0/30" % s["pack"].size(), 12, C_TEXT, pc)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	pc.add_child(grid)
	for i in 6:
		if i < s["pack"].size():
			var sl = s["pack"][i]
			var idx = i
			var b = B("%s%s×%d" % ["◎" if sl["key"] else "", N(sl["id"]), int(sl["n"])], func(): g.pack_take(idx), true, grid, 36)
			b.add_theme_font_size_override("font_size", 12)
		else:
			var e = B("空", func(): pass, false, grid, 36)
			e.add_theme_font_size_override("font_size", 12)
	var rr2 = row(pc)
	for id in ["pill_juqi", "fu_bishui", "fu_jingshui", "pill_quzhang"]:
		if g.store_n(id) > 0:
			var b2 = B("带%s" % N(id), func(): g.pack_put(id, id == "pill_juqi"), s["pack"].size() < 6 or g.pack_n(id) > 0, rr2, 36)
			b2.add_theme_font_size_override("font_size", 12)
	if s["pack"].size() > 0:
		var rr3 = row(pc)
		for i in s["pack"].size():
			var idx = i
			var b3 = B("◎%d" % (i + 1), func(): g.toggle_key(idx), true, rr3, 30)
			b3.add_theme_font_size_override("font_size", 11)
	var pr = row(pc)
	var presets: Array = s.get("presets", [{}, {}, {}])
	for k in 3:
		var kk = k
		var has: bool = not presets[k].is_empty()
		var lab = ("存入方案%d" % (k + 1)) if (preset_save_mode or not has) else ("装方案%d" % (k + 1))
		var pb = B(lab, func(): _preset(kk), true, pr, 32)
		pb.add_theme_font_size_override("font_size", 11)
	var sm = B("取消" if preset_save_mode else "存…", func(): preset_save_mode = not preset_save_mode, presets.any(func(x): return not x.is_empty()), pr, 32)
	sm.add_theme_font_size_override("font_size", 11)
	B("出发：%s" % rt["name"], func(): g.start_trip(selected_route), true, footer, 48)

func _preset(k: int) -> void:
	var presets: Array = g.s.get("presets", [{}, {}, {}])
	if presets[k].is_empty() or preset_save_mode:
		preset_save_mode = false
		g.preset_save(k)
		g.notice("已存为方案%d。" % (k + 1))
	else:
		var miss: Array = g.preset_apply(k)
		g.notice("已装好方案%d。" % (k + 1) + ("缺：" + "、".join(miss.map(func(x): return N(x))) if miss.size() > 0 else ""))

func _route_outline(rid: String) -> String:
	var parts = []
	for nid in g.routes[rid]["nodes"]:
		var nd = g.routes[rid]["nodes"][nid]
		if nd.has("visible_if") and not g.check(nd["visible_if"]):
			continue
		var t: String = g.events[nd["event"]]["title"]
		parts.append(("✓" if g.s["roadbook"].has(rid + ":" + nid) else "") + t)
	return " · ".join(parts)

# ------------------------------------------------------------ 历练
func _trip() -> void:
	var t = g.s["trip"]
	if not g.s["pending_overflow"].is_empty():
		_overflow()
		return
	match t["stage"]:
		"choose": _trip_choose()
		"event": _trip_event()
		"quick": _trip_quick()
		"result": _trip_result()

func _trip_choose() -> void:
	var t = g.s["trip"]
	var rt = g.route()
	H(rt["name"], 28)
	L("已走 %d 日" % int(t["walked"]), 14, C_DIM)
	var path = []
	for nid in t["path"]:
		path.append(g.events[rt["nodes"][nid]["event"]]["title"])
	L("走过：" + (" → ".join(path) if path.size() > 0 else "（刚出门）"), 12, C_DIM)
	if g.day_mod() > 0:
		L("老龟记仇：寒潭每个节点 +%d 日" % g.day_mod(), 12, C_WARN)
	L("前面的路：", 15)
	for nid in g.visible_choices():
		var nd = rt["nodes"][nid]
		var ev = g.events[nd["event"]]
		var days = int(ev.get("days", 1))
		if days > 0:
			days += g.day_mod()
		var rv: bool = g.is_revisit(nid)
		var label = "%s · %s%s · %s" % [ev["title"], ev["type"], "·重" if ev.get("heavy", false) else "", ("%d 日" % days) if days > 0 else "到家"]
		if rv:
			label += " · 路书已记（快走）"
		B(label, func(): g.enter_node(nid), true, null, 52)
	if int(t["walked"]) > 0:
		B("半路折返（%d 日，每日扣干粮）" % g.turn_back_days(), func(): _turn_back(), true, footer, 44)
	else:
		B("不去了，回家（0 日）", func(): _turn_back(), true, footer, 44)

func _turn_back() -> void:
	g.turn_back()
	if g.s.has("last_home"):
		modal = {"kind": "home", "sum": g.s["last_home"]}

func _cost_text(o: Dictionary) -> String:
	var parts = []
	var d = int(o["days"])
	if d > 0:
		parts.append(o.get("cost", {}).get("note", "%d 日" % d))
	var c: Dictionary = o.get("cost", {})
	for id in c.get("items", {}):
		parts.append("%s×%d" % [N(id), int(c["items"][id])])
	if c.has("chance") or c.has("chance_by_layer"):
		var p = g.laogui_a_chance() if c.has("chance_by_layer") else float(c["chance"])
		if g.s["flags"].get("hungry", false):
			p -= 0.2
		parts.append("成 %d%%" % roundi(p * 100))
	return " · ".join(parts)

func _trip_event() -> void:
	var ev: Dictionary = g.event_view()
	var c = card()
	H(ev["title"], 26, C_ACCENT, c)
	L("%s%s" % [ev["type"], " · 要事" if ev.get("heavy", false) else ""], 12, C_DIM, c)
	var pv = g.events[g.route()["nodes"][g.s["trip"]["node"]]["event"]].get("portrait", "")
	var pk = pv if pv is String else ""
	if pk != "":
		portrait(pk, c, 120)
	L(ev["text"], 16, C_TEXT, c)
	for o in ev["options"]:
		var r = row()
		var txt = String(o["label"])
		var ct = _cost_text(o)
		if ct != "":
			txt += "\n" + ct
		if not o["enabled"]:
			txt += "（" + String(o["reason"]) + "）"
		var oid: String = o["id"]
		B(txt, func(): _choose(oid), o["enabled"], r, 52)
		if o.get("key", false):
			var th = String(o.get("thought", ""))
			var kb = B("◎", func(): modal = {"kind": "thought", "text": th}, true, r, 52)
			kb.size_flags_horizontal = Control.SIZE_SHRINK_END
			kb.custom_minimum_size = Vector2(44, 52)

func _choose(oid: String) -> void:
	g.resolve(oid)

func _trip_quick() -> void:
	var nid: String = g.s["trip"]["node"]
	var ev = g.events[g.route()["nodes"][nid]["event"]]
	H(ev["title"], 26)
	L("这段路走过，路书上记着。脚下熟了，一晃就过去。", 15, C_DIM)
	B("快走（%d 日）" % (1 + g.day_mod()), func(): g.quick_walk(), true, footer, 52)

func _trip_result() -> void:
	var res: Dictionary = g.s["trip"]["result"]
	var c = card()
	H(res.get("title", ""), 24, C_ACCENT, c)
	L(String(res.get("option", "")), 14, C_DIM, c)
	var lines = []
	if int(res.get("days", 0)) > 0:
		lines.append("耗 %d 日（干粮余 %d）" % [res["days"], g.s["ration"]])
	if res.has("roll"):
		lines.append("判定：" + res["roll"])
	if int(res.get("ganwu", 0)) > 0:
		lines.append("感悟 +%d（待炼化 %d）" % [res["ganwu"], g.s["ganwu"]])
	for id in res.get("items", {}):
		var n = int(res["items"][id])
		lines.append("%s %s%d" % [N(id), "+" if n > 0 else "", n])
	if int(res.get("lingshi", 0)) != 0:
		lines.append("灵石 %+d" % int(res["lingshi"]))
	for l in res.get("lines", []):
		lines.append(l)
	L("\n".join(lines), 15, C_TEXT, c)
	if res.get("memory", []).size() > 0:
		L("记入：%s / 《青庐行记》" % "、".join(res["memory"]), 12, C_DIM, c)
	B("回家" if res.get("end_trip", false) else "继续", func(): _continue_trip(), true, footer, 52)

func _continue_trip() -> void:
	var was_end: bool = g.s["trip"]["result"].get("end_trip", false)
	g.continue_trip()
	if was_end and g.s.has("last_home"):
		modal = {"kind": "home", "sum": g.s["last_home"]}

func _overflow() -> void:
	var id: String = g.s["pending_overflow"][0]
	var c = card()
	L("行囊满了（6 格）", 16, C_WARN, c)
	L("要带上 %s，就得扔掉一格：" % N(id), 14, C_TEXT, c)
	for i in g.s["pack"].size():
		var sl = g.s["pack"][i]
		var idx = i
		B("扔掉 %s ×%d" % [N(sl["id"]), int(sl["n"])], func(): g.resolve_overflow(idx), true)
	B("不要 %s" % N(id), func(): g.resolve_overflow(-1), true, footer, 48)

# ------------------------------------------------------------ 心魔 / 结局
func _xinmo() -> void:
	var q: Dictionary = g.current_xinmo()
	var xm = g.s["xm"]
	H("心魔劫", 34, Color("#3B3340"))
	L("第 %d 幕 / 共 %d 幕" % [int(xm["idx"]) + 1, xm["ids"].size()], 13, C_DIM)
	var c = card()
	L(q["text"], 17, C_TEXT, c)
	L("答案不分对错，只看与她做过的事是否相合。", 13, C_DIM)
	for i in q["answers"].size():
		var idx = i
		B(q["answers"][i]["label"], func(): _answer(idx), true, null, 52)

func _answer(i: int) -> void:
	var r: Dictionary = g.answer_xinmo(i)
	if r.get("done", false) and not r.get("passed", true):
		modal = {"kind": "msg", "title": "心魔未平", "text": "雾里那个声音笑了一声，散了。她睁开眼，静室里灯还亮着，额上一层冷汗。\n有一句回答，和她做过的事对不上。\n筑基丹还在。先闭关 3 日（炼化减半），再冲关。"}

func _ending() -> void:
	var s = g.s
	if s["ending"] == "zhuji":
		var t = H("筑基", 56, C_ACCENT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var ec = card()
		portrait("heroine", ec, 104)
		L("第 %d 日，%s在青庐静室筑基。\n\n那一夜，后山的溪水退了，寒潭上的雾散了一半。姑母在门外坐到天亮，听见屋里的灯芯轻轻爆了一声。\n推门出来的时候，%s看见院子里的阳田都绿了。她想，该去给葛老三送点什么，也该再去潭边，跟那只老龟说一声。" % [s["day"], s["name"], s["name"]], 16, C_TEXT, ec)
	else:
		var t2 = H("坐化于青庐", 40, C_ACCENT)
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var ec2 = card()
		L("寿元耗尽。她回到青庐静室，在灯下合上了眼。\n姑母替她把那本旧书收好，压在枕边。窗外，后山的溪水还是那样流着。", 16, C_TEXT, ec2)
	var c = card()
	var src = s["src"]
	L("修为来源：闭关 %d · 炼化感悟 %d · 丹药 %d · 余韵 %d" % [src["biguan"], src["ganwu"], src["dan"], s["yuyun"]], 13, C_TEXT, c)
	var st = s["stats"]
	L("历练 %d 日 · 闭关 %d 日 · 重事件 %d · 轻节点 %d · 快走 %d" % [st["trip_days"], st["biguan_days"], st["heavy"], st["light"], st["revisit"]], 13, C_TEXT, c)
	L("实际游玩时长：%.1f 分钟（含读档前累计）" % (float(s.get("play_ms", 0)) / 60000.0), 13, C_ACCENT, c)
	H("青庐行记", 24)
	var lc = card()
	for e in s["log"]:
		L("第%d日  %s" % [int(e["day"]), e["text"]], 14, C_TEXT, lc)
	L("《青庐远行》%s · 谢谢你陪她走完这一程" % VERSION, 12, C_DIM)
	B("回标题", func(): screen = "title", true, footer, 48)

# ------------------------------------------------------------ 调试场景（只在调试导出里可用，给验收截图）
func _dev(cmd: String) -> String:
	match cmd:
		"state":
			return JSON.stringify({"screen": screen, "loc": g.s.get("loc", ""), "day": g.s.get("day", -1), "stage": g.s.get("trip", {}).get("stage", ""), "node": g.s.get("trip", {}).get("node", ""), "rev": store.rev})
		"title":
			screen = "title"
			modal = {}
			refresh()
		"event":
			g.new_game("苏青禾", "aunt", 3)
			screen = "game"
			modal = {}
			g.start_trip("houshan")
			for pk in [["H1", "A"], ["H2a", "A"]]:
				g.enter_node(pk[0]); g.resolve(pk[1]); g.continue_trip()
			g.enter_node("H3")
			_save()
			refresh()
		"xinmo", "ending":
			_dev("home")
			g.s["flags"]["laogui"] = "C"
			g.s["loc"] = "xinmo"
			var ids = []
			for q in g.pick_xinmo():
				ids.append(q["id"])
			g.s["xm"] = {"ids": ids, "idx": 0, "ok": true, "answers": []}
			if cmd == "ending":
				g.s["day"] = 41
				g.s["loc"] = "ending"
				g.s["ending"] = "zhuji"
				g.s["ended"] = true
				g.s["log"].append({"day": 41, "text": "第 41 日，筑基功成。"})
			_save()
			refresh()
		"laogui", "depart", "home", "cult":
			g.new_game("苏青禾", "aunt", 3)
			screen = "game"
			modal = {}
			g.start_trip("houshan")
			for pk in [["H1", "A"], ["H2a", "A"], ["H3", "A"], ["H4a", "A"], ["H5", "A"]]:
				g.enter_node(pk[0]); g.resolve(pk[1]); g.continue_trip()
			g.choose_extra("shuitian")
			g.s["store"]["pill_juqi"] = 3
			g.s["store"]["fu_bishui"] = 2
			g.s["store"]["herb_qingzhi"] = 6
			g.s["xiuwei"] = 300
			if cmd == "depart" or cmd == "laogui":
				g.pack_put("pill_juqi", true)
				g.pack_put("fu_bishui")
				g.pack_put("pill_juqi")
				g.s["pack"].append({"id": "pill_quzhang", "n": 1, "key": false})
				g.s["pack"].append({"id": "fu_dingfeng_can", "n": 1, "key": false})
				tab = "depart"
				selected_route = "hantan"
			if cmd == "laogui":
				g.start_trip("hantan")
				for pk in [["T1", "A"], ["T2", "A"], ["T3a", "A"]]:
					g.enter_node(pk[0]); g.resolve(pk[1]); g.continue_trip()
				g.enter_node("T4")
			if cmd == "cult":
				tab = "cult"
				g.enqueue("juqi")
			if cmd == "home":
				tab = "home"
				g.enqueue("juqi")
			_save()
			refresh()
	return cmd
