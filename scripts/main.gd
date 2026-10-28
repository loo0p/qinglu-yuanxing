extends Control
## 《青庐远行》v0.4 试玩版 · 界面层（场景优先）
## 竖屏，360×640 起，适配更高的屏（如 390×844）。规则全部在 GameState，这里只负责显示、动效、音频和调用。
## 结构：stage（整幅插画 + 热点/路标）→ ui（顶栏 HUD、正文、底栏）→ sheet（底部抽屉）→ fx（飞入、冲关特效）

const GS = preload("res://scripts/game_state.gd")
const Store = preload("res://scripts/save_store.gd")
const VERSION = "v0.10.1 试玩版"
const PBox = preload("res://scripts/portrait_box.gd")
const PLib = preload("res://addons/portrait5/portrait5_lib.gd")

const C_TEXT := Color("#2E2A24")
const C_ACCENT := Color("#34586A")
const C_DIM := Color("#7D7466")
const C_WARN := Color("#9A4A2A")
const C_PAPER := Color(0.985, 0.97, 0.935, 0.94)
const C_INK := Color("#4A3F33")
const C_GOLD := Color("#C9973B")
const NAMES_PRESET = ["苏青禾", "林晚照", "沈知微", "温小满"]
const SPEAKER = {"aunt": "姑母", "turtle": "老龟", "gelaosan": "葛老三", "heroine": ""}
const ICON = {"herb_qingzhi": "ico_qingzhi", "herb_hantanlian": "ico_lian", "seed_lianzi": "ico_lian", "herb_chiyangguo": "ico_guo",
	"pill_juqi": "ico_juqi", "pill_zhuji": "ico_zhuji", "pill_quzhang": "ico_juqi", "fu_bishui": "ico_fu", "fu_jingshui": "ico_fu",
	"fu_dingfeng_can": "ico_fu", "herb_xugucao": "ico_qingzhi", "crop_linggu": "ico_ration", "lingshi": "ico_lingshi", "ration": "ico_ration"}
# 路线图上的路标位置（相对插画 0..1）
const MAP_POS = {
	"houshan": {"_start": Vector2(0.47, 0.88), "H1": Vector2(0.42, 0.63), "H2a": Vector2(0.17, 0.52), "H2b": Vector2(0.80, 0.72),
		"Hstar": Vector2(0.70, 0.15), "H3": Vector2(0.47, 0.30), "H4a": Vector2(0.76, 0.47), "H4b": Vector2(0.24, 0.36), "H5": Vector2(0.60, 0.07)},
	"hantan": {"_start": Vector2(0.50, 0.95), "T1": Vector2(0.42, 0.83), "T2": Vector2(0.18, 0.70), "T3a": Vector2(0.40, 0.62), "T3b": Vector2(0.52, 0.45),
		"Tpath": Vector2(0.70, 0.31), "T4": Vector2(0.47, 0.21), "T5": Vector2(0.22, 0.09), "T6": Vector2(0.82, 0.46), "T7": Vector2(0.86, 0.24),
		"T8": Vector2(0.76, 0.68), "T9": Vector2(0.80, 0.90)},
}
# 青庐庭院热点（courtyard.webp）
const HOT = {"field": Vector2(0.27, 0.69), "furnace": Vector2(0.82, 0.69), "room": Vector2(0.62, 0.46), "aunt": Vector2(0.20, 0.47)}

class Ring extends Control:
	var value = 0.0
	var maxv = 1.0
	var col = Color("#34586A")
	var width = 5.0
	func _draw() -> void:
		var c = size / 2
		var r = min(size.x, size.y) / 2 - width
		draw_arc(c, r, 0, TAU, 48, Color(0.29, 0.25, 0.2, 0.18), width, true)
		var f = clamp(value / max(maxv, 0.001), 0.0, 1.0)
		if f > 0:
			draw_arc(c, r, -PI / 2, -PI / 2 + TAU * f, 48, col, width, true)

class MapLines extends Control:
	var segs = []   # [[a, b, done]]
	func _draw() -> void:
		for sg in segs:
			var a: Vector2 = sg[0]
			var b: Vector2 = sg[1]
			var n = int(a.distance_to(b) / 9)
			for i in n:
				if i % 2 == 0:
					draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), Color(0.55, 0.2, 0.12, 0.85) if sg[2] else Color(0.18, 0.15, 0.12, 0.55), 3.0 if sg[2] else 2.0, true)

var g: GS
var store = Store.new()
var legacy = Store.new(Store.LEGACY_SLOT)   # v0.5 的存档：只读，用来迁移，永不改写
var create_portrait = {}
var create_pseed = 0
var person_id = 0       # 江湖：正在看的人物卡
var person_tab = "life" # life | rel | mem
var life_all = false    # 生平：是否展开更早的月份
var screen = "title"     # title | create | game
var tab = "home"         # home | depart | cult | log | jianghu
var modal: Dictionary = {}
var sheet = ""           # 底部抽屉：field | furnace | aunt | pack | stats | ""
var create_name = "苏青禾"
var create_cherish = "aunt"
var selected_route = "houshan"
var preset_save_mode = false
var play_ms_base = 0
var session_start = 0
var beat_i = 0
var beat_key = ""
var last_nums = {}

var stage: Control
var ui: MarginContainer
var hud: VBoxContainer
var body: VBoxContainer
var scroll: ScrollContainer
var footer: VBoxContainer
var toast: Label
var sheet_layer: Control
var fx_layer: Control
var bag_icon: Control
var js_cb = null
var dev_cb = null
var font_body: Font
var font_brush: Font
var tex_cache = {}
var scene_key = ""
var glyphs = ""
# 音频：清单驱动（assets/audio/manifest.json），空槽=静默；第一次点击之后才开始
var manifest = {"bgm": {}, "sfx": {}}
var bgm: AudioStreamPlayer
var sfx_players = []
var audio_unlocked = false
var muted = false
var vol_music := 0.8     # 设置：音乐音量 0–1
var vol_sfx := 0.9       # 设置：音效音量 0–1
var dlg_opts := 0         # 下一个对话框读完后要出几个选项（矮屏时据此缩小立绘）
var text_speed := 1      # 设置：文字速度 0 慢 · 1 中 · 2 快 · 3 立即
const TEXT_CHAR_S = [0.045, 0.025, 0.012, 0.0]
var show_settings := false
var cur_bgm = ""
var bgm_on = false
var bgm_tween: Tween
var snd_cache = {}
var sfx_rr = 0

func _ready() -> void:
	g = GS.new()
	_load_settings()
	var mf = FileAccess.get_file_as_string("res://assets/audio/manifest.json")
	if mf != "":
		var j = JSON.parse_string(mf)
		if j is Dictionary:
			manifest = j
	font_body = _font("res://fonts/WenKai-sub.ttf")
	font_brush = _font("res://fonts/MaShanZheng-sub.ttf")
	theme = _make_theme()
	var paper = ColorRect.new()
	paper.color = Color("#EFE8D8")
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(paper)
	stage = Control.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.clip_contents = true
	add_child(stage)
	ui = MarginContainer.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		ui.add_theme_constant_override("margin_" + side, 8)
	add_child(ui)
	var v = VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	ui.add_child(v)
	hud = VBoxContainer.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hud)
	toast = Label.new()
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.add_theme_color_override("font_color", C_WARN)
	toast.add_theme_font_size_override("font_size", 14)
	var tsb = StyleBoxFlat.new()
	tsb.bg_color = C_PAPER
	tsb.set_corner_radius_all(4)
	tsb.set_content_margin_all(6)
	toast.add_theme_stylebox_override("normal", tsb)
	toast.visible = false
	v.add_child(toast)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	body = VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	footer = VBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_constant_override("separation", 6)
	v.add_child(footer)
	sheet_layer = Control.new()
	sheet_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet_layer)
	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)
	bgm = AudioStreamPlayer.new()
	bgm.volume_db = _bgm_db()
	add_child(bgm)
	for i in 3:
		var sp = AudioStreamPlayer.new()
		add_child(sp)
		sfx_players.append(sp)
	get_viewport().size_changed.connect(func(): _apply_safe_area(); refresh())
	_apply_safe_area()
	_hook_web()
	if OS.has_feature("web"):
		PLib.fetch = _pf_fetch
		# 标题页先出来；2.5 秒后在后台慢慢把立绘部件取完（按需的会插队）
		get_tree().create_timer(2.5).timeout.connect(_pf_prefetch_all)
	session_start = Time.get_ticks_msec()
	refresh()

## 刘海/底部横条：读 CSS env(safe-area-inset-*)（页面已设 viewport-fit=cover），换算成画面像素加到四边留白上
func _apply_safe_area() -> void:
	var ins = [0.0, 0.0, 0.0, 0.0]
	if OS.has_feature("web"):
		var js = JavaScriptBridge.eval("""(function(){var d=document.getElementById('qsafe');if(!d){d=document.createElement('div');d.id='qsafe';d.style.cssText='position:fixed;left:0;top:0;width:0;height:0;visibility:hidden;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';document.body.appendChild(d);}var c=getComputedStyle(d);return JSON.stringify([parseFloat(c.paddingTop)||0,parseFloat(c.paddingRight)||0,parseFloat(c.paddingBottom)||0,parseFloat(c.paddingLeft)||0,window.innerHeight||0]);})()""", true)
		var a = JSON.parse_string(String(js)) if js is String else null
		if a is Array and a.size() == 5 and float(a[4]) > 0:
			var k = get_viewport_rect().size.y / float(a[4])
			ins = [a[0] * k, a[1] * k, a[2] * k, a[3] * k]
	safe_inset = ins
	var sides = ["top", "right", "bottom", "left"]
	for i in 4:
		ui.add_theme_constant_override("margin_" + sides[i], 8 + int(ceil(ins[i])))

var safe_inset = [0.0, 0.0, 0.0, 0.0]

func _font(path: String) -> Font:
	var f = load(path)
	if f == null:
		return null
	var fv = FontVariation.new()
	fv.base_font = f
	return fv

# ------------------------------------------------------------ 资源
## 江湖事件背景（v0.6.5）不进 pck：网页版从 portrait/bg/ 按需下载，下好前先用院子图顶着
const LAZY_BG = ["bg_chasi", "bg_shandao", "bg_fangshi", "bg_yeyu", "bg_dongfu", "bg_leitai"]
var bg_want := {}

func _bg_fetch(name: String) -> void:
	if bg_want.has(name):
		return
	bg_want[name] = true
	if pf_base == "":
		var b = JavaScriptBridge.eval("new URL('portrait/', location.href).href", true)
		pf_base = String(b) if b is String and b != "" else "portrait/"
	var req = HTTPRequest.new()
	req.accept_gzip = false  # 浏览器已解开 Content-Encoding: gzip（GitHub Pages 会压 .bin），别让引擎再解一遍
	add_child(req)
	req.request_completed.connect(func(result, code, _h, body):
		req.queue_free()
		var img = Image.new()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200 and img.load_webp_from_buffer(body) == OK:
			tex_cache[name] = ImageTexture.create_from_image(img)
			refresh()
		else:
			bg_want.erase(name))
	if req.request(pf_base + "bg/%s.webp" % name) != OK:
		req.queue_free()
		bg_want.erase(name)

func tex(name: String) -> Texture2D:
	if tex_cache.has(name):
		return tex_cache[name]
	if name in LAZY_BG:
		if OS.has_feature("web"):
			_bg_fetch(name)
			return tex("courtyard")
		var lb = FileAccess.get_file_as_bytes("res://web_portrait/bg/%s.webp" % name)
		var li = Image.new()
		if lb.size() > 0 and li.load_webp_from_buffer(lb) == OK:
			tex_cache[name] = ImageTexture.create_from_image(li)
			return tex_cache[name]
		return tex("courtyard")
	var t: Texture2D = null
	var bytes = FileAccess.get_file_as_bytes("res://assets/img/%s.webp" % name)
	if bytes.size() > 0:
		var img = Image.new()
		if img.load_webp_from_buffer(bytes) == OK:
			t = ImageTexture.create_from_image(img)
	tex_cache[name] = t
	return t

func snd(kind: String, slot: String) -> AudioStream:
	var key = kind + ":" + slot
	if snd_cache.has(key):
		return snd_cache[key]
	var fn = String(manifest.get(kind, {}).get(slot, ""))
	if fn == "" or not fn.ends_with(".ogg"):
		snd_cache[key] = null
		return null
	if kind == "bgm":
		# 配乐不打进 pck（首包小）：本地/编辑器读 res://web_audio，网页版按需从 audio/ 拉取
		var local = "res://web_audio/" + fn
		if FileAccess.file_exists(local):
			var st = _ogg(FileAccess.get_file_as_bytes(local), slot)
			snd_cache[key] = st
			return st
		_fetch_bgm(slot, fn)
		return null
	var a: AudioStream = null
	var bytes = FileAccess.get_file_as_bytes("res://assets/audio/" + fn)
	if bytes.size() > 0:
		a = AudioStreamOggVorbis.load_from_buffer(bytes)
	snd_cache[key] = a
	return a

func _ogg(bytes: PackedByteArray, slot: String) -> AudioStream:
	if bytes.size() == 0:
		return null
	var a = AudioStreamOggVorbis.load_from_buffer(bytes)
	if a:
		a.loop = bool(manifest.get("bgm_loop", {}).get(slot, true))
		a.loop_offset = 0.0
	return a

var bgm_fetching := {}
func _fetch_bgm(slot: String, fn: String) -> void:
	if bgm_fetching.has(slot) or not OS.has_feature("web"):
		return
	bgm_fetching[slot] = true
	var url = "audio/" + fn
	var base = JavaScriptBridge.eval("new URL('audio/', location.href).href", true)
	if base is String and base != "":
		url = String(base) + fn
	var req = HTTPRequest.new()
	req.accept_gzip = false  # 浏览器已解开 Content-Encoding: gzip（GitHub Pages 会压 .bin），别让引擎再解一遍
	add_child(req)
	req.request_completed.connect(func(result, code, _h, body):
		req.queue_free()
		bgm_fetching.erase(slot)
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			snd_cache["bgm:" + slot] = null
			return
		snd_cache["bgm:" + slot] = _ogg(body, slot)
		if cur_bgm == slot and audio_unlocked and not muted and not bgm_on:
			cur_bgm = ""
			_set_bgm(slot))
	req.request(url)

# ------------------------------------------------------------ 立绘部件按需下载（Web）
const PF_MAX := 6
var pf_queue := []
var pf_want := {}
var pf_active := 0
var pf_base := ""

## 五官贴片按脸型打成了包（tools/bundle_portraits.py）：要其中任何一条，就取整个包（v0.6.8）
var pf_bundles = null
func _pf_unit(rel: String) -> String:
	if pf_bundles == null:
		var t = FileAccess.get_file_as_string("res://data/portrait_bundles.json")
		var d = JSON.parse_string(t) if t != "" else null
		pf_bundles = d if d is Dictionary else {}
	return String(pf_bundles.get(rel, rel))

func _pf_put_bundle(body: PackedByteArray) -> void:
	if body.size() < 4:
		return
	var n = body.decode_u32(0)
	var o = 4
	for i in n:
		if o + 2 > body.size():
			return
		var ln = body.decode_u16(o)
		var name = body.slice(o + 2, o + 2 + ln).get_string_from_utf8()
		o += 2 + ln
		var sz = body.decode_u32(o)
		o += 4
		if not PLib.has(name):
			PLib.put(name, body.slice(o, o + sz))
		o += sz

## 三档排队：主立绘/对话立绘（pf_hi，后要的先取）> 缩略图（pf_lo，按出现顺序）> 后台预取（pf_queue）
var pf_hi := []
var pf_lo := []
func _pf_fetch(rel: String) -> void:
	rel = _pf_unit(rel)
	var queued: bool = pf_queue.has(rel) or pf_hi.has(rel) or pf_lo.has(rel)
	if pf_want.has(rel) and not queued:
		return   # 已在下载
	pf_want[rel] = true
	if PLib.low:
		if pf_hi.has(rel) or pf_lo.has(rel):
			return
		pf_queue.erase(rel)
		pf_lo.push_back(rel)
	else:
		pf_queue.erase(rel)
		pf_lo.erase(rel)
		pf_hi.erase(rel)
		pf_hi.push_front(rel)
	_pf_pump()

func _pf_prefetch_all() -> void:
	for n in LAZY_BG:
		_bg_fetch(n)
	var t = FileAccess.get_file_as_string("res://data/portrait_files.json")
	var lst = JSON.parse_string(t) if t != "" else null
	if not (lst is Array):
		return
	for rel0 in lst:
		var rel = _pf_unit(rel0)
		if not pf_want.has(rel):
			pf_want[rel] = true
			pf_queue.push_back(rel)
	_pf_pump()

func _pf_pump() -> void:
	if pf_base == "":
		var b = JavaScriptBridge.eval("new URL('portrait/', location.href).href", true)
		pf_base = String(b) if b is String and b != "" else "portrait/"
	while pf_active < PF_MAX and not (pf_hi.is_empty() and pf_lo.is_empty() and pf_queue.is_empty()):
		var rel: String = pf_hi.pop_front() if not pf_hi.is_empty() else (pf_lo.pop_front() if not pf_lo.is_empty() else pf_queue.pop_front())
		var is_pack = rel.begins_with("pack/")
		if not is_pack and PLib.has(rel):
			continue
		pf_active += 1
		var req = HTTPRequest.new()
		req.accept_gzip = false
		add_child(req)
		req.request_completed.connect(func(result, code, _h, body):
			req.queue_free()
			pf_active -= 1
			if result == HTTPRequest.RESULT_SUCCESS and code == 200:
				if is_pack:
					_pf_put_bundle(body)
				else:
					PLib.put(rel, body)
			else:
				pf_want.erase(rel)   # 下次用到时重试
			_pf_pump())
		if req.request(pf_base + (rel if is_pack else PLib.file_of(rel))) != OK:
			req.queue_free()
			pf_active -= 1
			pf_want.erase(rel)

func sfx(slot: String) -> void:
	if not audio_unlocked or muted or vol_sfx < 0.01:
		return
	var st = snd("sfx", slot)
	if st == null:
		return
	var sp = sfx_players[sfx_rr % sfx_players.size()]
	sfx_rr += 1
	sp.stream = st
	sp.volume_db = _sfx_db()
	sp.play()

func _set_bgm(slot: String) -> void:
	if slot == cur_bgm and (bgm_on or muted or not audio_unlocked):
		return
	cur_bgm = slot
	if not audio_unlocked or muted:
		return
	var st = snd("bgm", slot)
	if bgm_tween and bgm_tween.is_valid():
		bgm_tween.kill()
	var tw = create_tween()
	bgm_tween = tw
	if bgm_on:
		tw.tween_property(bgm, "volume_db", -40.0, 0.6)
	tw.tween_callback(func():
		bgm.stop()
		if muted or st == null:
			return
		bgm.stream = st
		bgm.volume_db = -40.0
		bgm.play())
	tw.tween_property(bgm, "volume_db", _bgm_db(), 1.2)
	bgm_on = st != null

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
		if bgm_tween and bgm_tween.is_valid():
			bgm_tween.kill()
		bgm.stop()
		bgm_on = false
	else:
		var want = cur_bgm
		cur_bgm = ""
		_set_bgm(want)
	_save_settings()

func _load_settings() -> void:
	var cf = ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		muted = bool(cf.get_value("audio", "muted", false))
		vol_music = clampf(float(cf.get_value("audio", "music", 0.8)), 0.0, 1.0)
		vol_sfx = clampf(float(cf.get_value("audio", "sfx", 0.9)), 0.0, 1.0)
		text_speed = clampi(int(cf.get_value("text", "speed", 1)), 0, 3)

func _save_settings() -> void:
	var cf = ConfigFile.new()
	cf.set_value("audio", "muted", muted)
	cf.set_value("audio", "music", vol_music)
	cf.set_value("audio", "sfx", vol_sfx)
	cf.set_value("text", "speed", text_speed)
	cf.save("user://settings.cfg")

## 音乐底子是 -8 dB，再乘设置里的音量
func _bgm_db() -> float:
	return -80.0 if vol_music < 0.01 else -8.0 + linear_to_db(vol_music)

func _sfx_db() -> float:
	return -80.0 if vol_sfx < 0.01 else linear_to_db(vol_sfx)

## 设置页：音乐/音效音量、文字速度；改了立刻生效并存进 user://settings.cfg（与存档分开）
func _settings() -> void:
	_stage_image("bg_home" if screen == "game" else "title", 0.6)
	var c = card()
	H("设置", 24, C_ACCENT, c)
	for it in [["音乐", "music"], ["音效", "sfx"]]:
		var k: String = it[1]
		var r = row(c, 8)
		var nl = L(it[0], 15, C_TEXT, r)
		nl.custom_minimum_size = Vector2(44, 0)
		var sl = HSlider.new()
		sl.min_value = 0
		sl.max_value = 100
		sl.step = 5
		sl.value = (vol_music if k == "music" else vol_sfx) * 100.0
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.custom_minimum_size = Vector2(0, MIN_TAP)
		r.add_child(sl)
		var vl = L("%d" % int(sl.value), 14, C_DIM, r)
		vl.custom_minimum_size = Vector2(32, 0)
		sl.value_changed.connect(func(v):
			vl.text = "%d" % int(v)
			if k == "music":
				vol_music = v / 100.0
				if bgm_tween and bgm_tween.is_valid():
					bgm_tween.kill()
				bgm.volume_db = _bgm_db()
			else:
				vol_sfx = v / 100.0
			_save_settings())
		if k == "sfx":
			sl.drag_ended.connect(func(_c): sfx("tap"))
	L("文字速度", 15, C_TEXT, c)
	var tr = row(c, 4)
	for i in 4:
		var ii = i
		var b = B(("● " if text_speed == i else "") + ["慢", "中", "快", "立即"][i], func(): text_speed = ii; _save_settings(), true, tr, 44)
		b.add_theme_font_size_override("font_size", 14)
	var demo = L("", 15, C_TEXT, c)
	demo.text = "山雨欲来，她把晒着的青芝收进了屋。"
	if TEXT_CHAR_S[text_speed] > 0.0:
		demo.visible_characters = 0
		demo.create_tween().tween_property(demo, "visible_characters", demo.text.length(), demo.text.length() * TEXT_CHAR_S[text_speed])
	if screen == "game" and g.s.get("guide", {}) is Dictionary and g.s.has("guide"):
		var gd: Dictionary = g.s["guide"]
		var off: bool = gd.get("off", false)
		B("新手提示：" + ("已关闭（点此重新打开）" if off else "开着（点此关闭）"), func(): gd["off"] = not off; _save(), true, c, 44)
	L("设置只存在这台设备的浏览器里，与存档分开。", 13, C_DIM, c)
	B("回去", func(): show_settings = false, true, footer, 52)

func _sb(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 6, bw: int = 0, pad: int = 8) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb

func _make_theme() -> Theme:
	var t = Theme.new()
	if font_body:
		t.default_font = font_body
	t.default_font_size = 16
	t.set_color("font_color", "Label", C_TEXT)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb = _sb({"normal": C_PAPER, "hover": C_PAPER, "pressed": Color("#E3D8C2"), "disabled": Color(0.93, 0.915, 0.88, 0.8), "focus": C_PAPER}[st],
			C_INK if st != "disabled" else Color("#CFC6B4"), 4, 1, 10)
		sb.border_width_bottom = 2 if st != "pressed" else 1
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		t.set_stylebox(st, "Button", sb)
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", C_TEXT)
	t.set_color("font_pressed_color", "Button", C_ACCENT)
	t.set_color("font_disabled_color", "Button", Color("#A39B8C"))
	t.set_color("font_focus_color", "Button", C_TEXT)
	var card = _sb(Color(1.0, 0.99, 0.965, 0.93), Color(0.29, 0.25, 0.2, 0.3), 6, 1, 10)
	card.shadow_color = Color(0.1, 0.08, 0.05, 0.18)
	card.shadow_size = 4
	card.shadow_offset = Vector2(0, 2)
	t.set_stylebox("panel", "PanelContainer", card)
	var fill = _sb(C_GOLD, Color(0, 0, 0, 0), 3, 0, 0)
	var bgp = _sb(Color(0.29, 0.25, 0.2, 0.25), Color(0, 0, 0, 0), 3, 0, 0)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_stylebox("background", "ProgressBar", bgp)
	t.set_stylebox("grabber", "VScrollBar", _sb(Color(0.29, 0.25, 0.2, 0.3), Color(0, 0, 0, 0), 2, 0, 0))
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	return t


# ------------------------------------------------------------ 小部件
func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

const MIN_TAP := 44      # 可点控件最小边长（px，≈ CSS px）
const MIN_FONT := 13     # 最小字号：360×640 下 11–12px 太小

func L(text: String, size: int = 16, color: Color = C_TEXT, parent: Node = null) -> Label:
	size = maxi(size, MIN_FONT)
	var l = Label.new()
	l.text = text
	var par: Node = parent if parent else body
	l.autowrap_mode = TextServer.AUTOWRAP_OFF if par is HBoxContainer else TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	par.add_child(l)
	return l

## 图标旁边的换行文字：放在 HBox 里也要占满剩下的宽度，不然会被挤成一字一行
func LW(text: String, size: int = 16, color: Color = C_TEXT, parent: Node = null) -> Label:
	var l = L(text, size, color, parent)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = maxf(l.custom_minimum_size.x, 96)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

## 兜底：任何会换行的 Label，只要它（或它所在的竖排）是某个 HBox 的直接子节点，
## 就让那一格占满剩余宽度，并给 Label 一个最小宽度。换行 Label 的最小宽度是 0，
## HBox 不给它地方时就会一字一行（手机上灵脉第五点就是这样）。
func _fix_wraps(root: Node) -> void:
	if root == null:
		return
	for l in root.find_children("*", "Label", true, false):
		if (l as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
			continue
		var n: Node = l
		var in_row := false
		while n != null and n != root:
			var par = n.get_parent()
			if par is HBoxContainer and n is Control:
				in_row = true
				if not ((n as Control).size_flags_horizontal & Control.SIZE_EXPAND):
					(n as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			n = par
		if in_row:
			var fs := (l as Label).get_theme_font_size("font_size")
			var want := minf(96.0, float(fs * (l as Label).text.length()))
			if (l as Label).custom_minimum_size.x < want:
				(l as Label).custom_minimum_size.x = want

var brush_glyphs = ""
func H(text: String, size: int = 22, color: Color = C_ACCENT, parent: Node = null) -> Label:
	var l = L(text, size, color, parent)
	if brush_glyphs == "":
		brush_glyphs = FileAccess.get_file_as_string("res://fonts/glyphs_brush.txt")
	var ok = font_brush != null
	for i in text.length():
		if text[i] != " " and not brush_glyphs.contains(text[i]):
			ok = false
			break
	if ok:
		l.add_theme_font_override("font", font_brush)
	return l

func IC(name: String, size: int, parent: Node) -> TextureRect:
	var tr = TextureRect.new()
	tr.texture = tex(name)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(size, size)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr

func B(text: String, cb: Callable, enabled: bool = true, parent: Node = null, h: int = 44) -> Button:
	var b = Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(44, maxi(h, MIN_TAP))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(func(): _press(cb))
	b.button_down.connect(func():
		b.pivot_offset = b.size / 2
		var tw = b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.96, 0.96), 0.05)
		tw.tween_property(b, "scale", Vector2.ONE, 0.12))
	(parent if parent else body).add_child(b)
	return b

## 选项依次淡入（每个晚 60ms），读完对话后不至于一下子全砸出来
func _reveal(n: CanvasItem, k: int) -> void:
	if text_speed == 3:
		return
	n.modulate.a = 0.0
	var tw = n.create_tween()
	tw.tween_interval(0.04 + 0.06 * k)
	tw.tween_property(n, "modulate:a", 1.0, 0.16)

## 带图标的按钮（图标在左）
func BI(text: String, icon_name: String, cb: Callable, enabled: bool = true, parent: Node = null, h: int = 44) -> Button:
	var b = B(text, cb, enabled, parent, h)
	var t = tex(icon_name)
	if t:
		b.icon = t
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 28)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b

func row(parent: Node = null, sep: int = 6) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else body).add_child(h)
	return h

func card(parent: Node = null) -> VBoxContainer:
	var p = PanelContainer.new()
	(parent if parent else body).add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	return v

## 小标签（代价、数量）
func chip(text: String, parent: Node, icon_name: String = "", col: Color = C_INK) -> void:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color(col.r, col.g, col.b, 0.12), Color(col.r, col.g, col.b, 0.45), 9, 1, 3))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var h = row(p, 2)
	if icon_name != "":
		IC(icon_name, 16, h)
	L(text, 12, col, h)

func ring(parent: Node, value: float, maxv: float, size: int, col: Color = C_ACCENT, label: String = "", sub: String = "") -> Control:
	var box = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	parent.add_child(box)
	var r = Ring.new()
	r.value = value
	r.maxv = maxv
	r.col = col
	r.custom_minimum_size = Vector2(size, size)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(r)
	if label != "":
		var l = L(label, 13 if size < 70 else 18, C_TEXT, r)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.position = Vector2.ZERO
		l.size = Vector2(size, size)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if sub != "":
		var s2 = L(sub, 12, C_DIM, box)
		s2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return r

var last_press_ms := -1000
func _press(cb: Callable) -> void:
	# 防误触：手机上一次点按可能同时来触摸 + 模拟鼠标，或手抖连点；240ms 内的第二下不算（无头测试不限）
	var now = Time.get_ticks_msec()
	if DisplayServer.get_name() != "headless" and now - last_press_ms < 240:
		return
	last_press_ms = now
	sfx("tap")
	var before = [g.s.get("loc", ""), g.s.get("trip", {}).get("stage", ""), g.s.get("ending", "")]
	var items_before = _inventory()
	var in_game: bool = screen == "game" and g.s.has("xiuwei")
	var lay0: int = g.layer() if in_game else 0
	var full0: bool = in_game and int(g.s["xiuwei"]) >= GS.XW_GOAL
	cb.call()
	var after = [g.s.get("loc", ""), g.s.get("trip", {}).get("stage", ""), g.s.get("ending", "")]
	var grew := false
	if in_game and screen == "game" and g.s.has("xiuwei") and not g.s.get("ended", false):
		grew = _layer_up(lay0, full0)
	if after[2] == "zhuji" and before[2] == "":
		sfx("breakthrough")
	elif grew:
		sfx("success")
	elif after[1] == "event" and before[1] != "event":
		sfx("page")
	elif after[1] == "result" and before[1] != "result":
		var r = String(g.s.get("trip", {}).get("result", {}).get("roll", ""))
		sfx("fail" if r == "败" else ("success" if r != "" else "pickup"))
	_after_action()
	_fly_gains(items_before)

## 修为过了一层（每 1/9 的修为）：提示一句，记进生平；圆满时提醒可以冲关（v0.7.3：以前层数悄悄变，没有一点动静）
func _layer_up(lay0: int, full0: bool) -> bool:
	var lay: int = g.layer()
	var full: bool = int(g.s["xiuwei"]) >= GS.XW_GOAL
	var line := ""
	if full and not full0:
		line = "修为圆满。丹田里的灵气满得发胀——可以冲关筑基了。"
	elif lay > lay0:
		line = pv_layer(lay)
	if line == "":
		return false
	g.notice(line)
	if g.world != null:
		g.world.chron(g.world.P(), "修为精进，入%s。" % g.realm_text())
	return true

func pv_layer(lay: int) -> String:
	var t := ["炼气%s层。经脉里那股气又粗了一圈。", "炼气%s层。闭眼时，能听见灵田里青芝抽芽的声音。", "炼气%s层。剑气走到指尖，不再发涩。", "炼气%s层。这一夜她睡得很沉，醒来手脚都是暖的。"]
	var cn: String = ["一", "二", "三", "四", "五", "六", "七", "八", "九"][clampi(lay - 1, 0, 8)]
	return "修为精进——" + t[lay % t.size()] % cn

func N(id: String) -> String:
	return GS.NAMES.get(id, id)

func _inventory() -> Dictionary:
	if g.s.is_empty():
		return {}
	var d = {"lingshi": int(g.s.get("lingshi", 0)), "ration": int(g.s.get("ration", 0))}
	for id in GS.NAMES:
		if id.begins_with("herb_") or id.begins_with("pill_") or id.begins_with("fu_") or id.begins_with("seed_") or id.begins_with("crop_"):
			d[id] = g.total_n(id)
	return d

## 得到东西：图标从屏幕中间飞进顶栏的行囊
func _fly_gains(before: Dictionary) -> void:
	if before.is_empty() or g.s.is_empty() or bag_icon == null or not is_instance_valid(bag_icon):
		return
	var now = _inventory()
	var k = 0
	for id in now:
		if int(now[id]) > int(before.get(id, 0)) and ICON.has(id) and id != "ration":
			var t = tex(ICON[id])
			if t == null:
				continue
			var tr = TextureRect.new()
			tr.texture = t
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.size = Vector2(44, 44)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var vs = get_viewport_rect().size
			tr.position = Vector2(vs.x / 2 - 22 + k * 30 - 30, vs.y * 0.5)
			fx_layer.add_child(tr)
			var lab = L("+%d" % (int(now[id]) - int(before.get(id, 0))), 16, C_WARN, tr)
			lab.position = Vector2(30, -6)
			var target = bag_icon.get_global_rect().get_center() - Vector2(22, 22)
			var tw = tr.create_tween()
			tw.tween_property(tr, "position:y", tr.position.y - 40, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(k * 0.08)
			tw.tween_property(tr, "position", target, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tw.parallel().tween_property(tr, "scale", Vector2(0.4, 0.4), 0.55)
			tw.tween_callback(tr.queue_free)
			k += 1
	if k > 0 and is_instance_valid(bag_icon):
		var tb = bag_icon.create_tween()
		bag_icon.pivot_offset = bag_icon.size / 2
		tb.tween_interval(0.9 + k * 0.08)
		tb.tween_property(bag_icon, "scale", Vector2(1.3, 1.3), 0.08)
		tb.tween_property(bag_icon, "scale", Vector2.ONE, 0.15)

## 数字跳动：从上次显示的值滚到现在的值
func tick_label(l: Label, key: String, val: int, fmt: String = "%d") -> void:
	var old = int(last_nums.get(key, val))
	last_nums[key] = val
	if old == val:
		l.text = fmt % val
		return
	l.text = fmt % old
	var tw = l.create_tween()
	tw.tween_method(func(x): l.text = fmt % int(round(x)), float(old), float(val), 0.6).set_delay(0.15)

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

func _continue(from_legacy: bool = false) -> void:
	var d = (legacy if from_legacy else store).load_data()
	if d == null or not g.from_dict(d["state"]):
		modal = {"kind": "msg", "text": "存档读不出来（版本不符或已损坏）。旧档没有删除。"}
		return
	play_ms_base = int(g.s.get("play_ms", 0))
	session_start = Time.get_ticks_msec()
	# 旧版允许自由输入名字；字体只含游戏用字，缺字形的名字换成预设名（只改显示名，不动进度）
	var nm = String(g.s.get("name", ""))
	if safe_name(nm) != nm:
		g.s["name"] = safe_name(nm)
		g.notice("旧存档里的名字有字体缺的字，已改称「%s」。进度不受影响。" % g.s["name"])
	_migrate()
	screen = "game"
	tab = "home"
	if from_legacy:
		_save()   # 迁移后的档写进 v0.6 新槽；v0.5 的 qinglu_slot1 不动

## v0.5 → v0.6：补开江湖、补一张立绘（进度、物品、记忆都不动）
func _migrate() -> void:
	if not g.s.has("portrait") or not (g.s["portrait"] is Dictionary) or g.s["portrait"].is_empty():
		g.s["portrait"] = PLib.roll("p%d" % int(g.s.get("rng_seed", 0)), {"sex": "f", "elder": false, "demonic": false})
	if g.world == null:
		g.start_world(int(g.s.get("rng_seed", 0)) + int(g.s.get("day", 0)))
		g.notice("v0.6：山外的江湖开了。认识的人、听来的传闻，都在「江湖」里。")

func safe_name(nm: String) -> String:
	if nm.strip_edges() == "":
		return NAMES_PRESET[0]
	if glyphs == "":
		glyphs = FileAccess.get_file_as_string("res://fonts/glyphs.txt")
		if glyphs == "":
			return nm
	for i in nm.length():
		if not glyphs.contains(nm[i]):
			return NAMES_PRESET[0]
	return nm

func _start_new() -> void:
	if store.exists():
		store.archive()
	g.new_game(create_name if create_name.strip_edges() != "" else "苏青禾", create_cherish, -1, true)
	g.s["portrait"] = create_portrait.duplicate(true) if not create_portrait.is_empty() else _hero_roll("p%d" % randi())
	play_ms_base = 0
	session_start = Time.get_ticks_msec()
	screen = "game"
	tab = "home"
	g.s["guide"] = {"seen": {}, "off": false}   # 新手提示只给新开的局；旧档/迁移来的档没有这个键，不显示
	modal = {"kind": "msg", "portrait": "aunt", "title": "姑母", "text": "姑母把一张避水符塞进她袖里：“后山的溪涨水了，先去那边认认路。”\n“筑基不急。人要先回来。”"}



# ------------------------------------------------------------ 刷新
func refresh() -> void:
	_story_check()
	var key = "%s|%s|%s|%s|%s|%s|%s" % [screen, tab, modal.get("kind", ""), g.s.get("loc", ""), g.s.get("trip", {}).get("stage", ""), String(g.s.get("trip", {}).get("node", "")), _story_key()]
	var changed = key != scene_key
	var prev_key = scene_key
	scene_key = key
	if changed and key != beat_key:
		beat_i = 0
		beat_key = key
	_refresh()
	for n in [hud, body, footer, sheet_layer]:
		_fix_wraps(n)
	_set_bgm(_bgm_for_scene())
	if changed and not key.contains("|ending|"):
		_clear(fx_layer)   # 离开结局页时把还在飘的灵气粒子收掉
	if changed:
		ui.modulate = Color(1, 1, 1, 0.0)
		create_tween().tween_property(ui, "modulate:a", 1.0, 0.22)
		scroll.scroll_vertical = 0
		if g.s.get("ending", "") == "zhuji" and g.s.get("loc", "") == "ending" and not prev_key.contains("|ending|"):
			_fx_breakthrough()
	if OS.has_feature("web"):
		var w = JavaScriptBridge.get_interface("window")
		if w:
			w.qinglu_state = JSON.stringify({"screen": screen, "tab": tab, "modal": modal.get("kind", ""), "sheet": sheet, "loc": g.s.get("loc", ""), "day": g.s.get("day", -1), "stage": g.s.get("trip", {}).get("stage", ""), "node": g.s.get("trip", {}).get("node", ""), "rev": store.rev, "persistent": OS.is_userfs_persistent(), "conflict": store.conflict, "bgm": cur_bgm, "bgm_on": bgm_on, "muted": muted, "unlocked": audio_unlocked})

func _bgm_for_scene() -> String:
	if screen != "game":
		return "title"
	if modal.get("kind", "") == "story" and g.world != null:
		var tid = String(g.world.pending().get("tid", ""))
		if tid in ["心魔", "仇人上门", "魔修袭镇", "寻凶", "道侣遇险", "劫修伏击", "仇家寻上门", "落难", "两难", "寻仇", "截道", "撞见", "求援", "叛门"]:
			return "xinmo"
		if tid in ["秘境", "旧友托梦", "宝地相争", "道途殊归", "坊市认物"]:
			return "hantan"
	match String(g.s.get("loc", "home")):
		"ending":
			return "ending"
		"xinmo":
			return "xinmo"
		"trip":
			return "travel_houshan" if String(g.s["trip"].get("route", "houshan")) == "houshan" else "hantan"
	return "home"

func _refresh() -> void:
	_clear(stage)
	_clear(hud)
	_clear(body)
	_clear(footer)
	_clear(sheet_layer)
	bag_icon = null
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	toast.visible = false
	if not g.notices.is_empty():
		toast.text = "\n".join(g.notices)
		toast.visible = true
		g.notices.clear()
	if store.conflict:
		toast.text = "另一个标签页也打开了这个存档，这里已停止保存。请关闭其中一个后刷新。"
		toast.visible = true
	if not OS.is_userfs_persistent():
		var wl = L("⚠ 这个浏览器不能长期保存（可能是隐私模式），关掉页面进度会丢。", 12, C_WARN, hud)
		wl.add_theme_stylebox_override("normal", _sb(C_PAPER, Color(0, 0, 0, 0), 4, 0, 4))
	if show_settings:
		_settings()
		return
	match screen:
		"title":
			_title()
			return
		"create":
			_create()
			return
	_hud()
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
	_guide()
	match tab:
		"home": _home()
		"depart": _depart()
		"cult": _cult()
		"log": _log_tab()
		"jianghu": _jianghu()
	_nav()
	if sheet != "":
		_sheet()

# ------------------------------------------------------------ 新手提示（姑母留的字条）
## 只在新开的局、前 6 日里出现；每张只出一次；“不必再提”就全关（设置里可再打开）。
const GUIDE = {
	"home": "这院子就是青庐。阳田种青芝，丹炉炼丹，静室闭关——点院里的地方就能打理。日子在这里过，一天是一天。",
	"home2": "回来了就好。累了就闭关，采回的灵草放进丹炉。寿元一日日少，别都耗在路上。",
	"depart": "出门历练：挑一条路，带够干粮。路上每一站都要你拿主意，采回的灵草能入药。别贪远，人要先回来。",
	"cult": "静室里闭关，一日一日把感悟炼成修为。修为攒满，院里会出现「冲关」：过了心魔那几问，才算筑基。",
	"jianghu": "山外的人和事都记在「江湖」里。你怎么待人，人家都记得——好的坏的都记得。",
}
func _guide_key() -> String:
	var gd = g.s.get("guide", null)
	if not (gd is Dictionary) or gd.get("off", false) or int(g.s.get("day", 0)) > 6 or sheet != "":
		return ""
	var k: String = tab
	if tab == "home" and int(g.s.get("trips_done", 0)) >= 1 and gd["seen"].has("home"):
		k = "home2"
	if not GUIDE.has(k) or gd["seen"].has(k):
		return ""
	return k

func _guide() -> void:
	var k := _guide_key()
	if k == "":
		return
	var gd: Dictionary = g.s["guide"]
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color(0.99, 0.97, 0.91, 0.96), Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.8), 8, 1, 10))
	body.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var hr = row(v, 6)
	IC("vn_aunt" if tex("vn_aunt") else "ico_ration", 30, hr)
	H("姑母留的字条", 17, C_ACCENT, hr)
	L(GUIDE[k], 14, C_TEXT, v)
	var br = row(v, 6)
	var b1 = B("记下了", func(): gd["seen"][k] = true; _save(), true, br, 44)
	b1.add_theme_font_size_override("font_size", 14)
	var b2 = B("不必再提", func(): gd["off"] = true; _save(), true, br, 44)
	b2.add_theme_font_size_override("font_size", 14)
	b2.add_theme_color_override("font_color", C_DIM)

# ------------------------------------------------------------ 舞台（整幅插画）
## lift_to：>0 时把画面里墨色最重的那一带（BG_INK_Y，按图高的比例）往上挪到这个 y 附近（最多挪图高的 30%），
## 下面露出的地方铺纸色——选项多时场景不至于全压在对话框和按钮底下（v0.7.5）
const BG_INK_Y = {"bg_chasi": 0.70, "bg_dongfu": 0.69, "bg_fangshi": 0.72, "bg_leitai": 0.71, "bg_shandao": 0.36, "bg_yeyu": 0.45,
	"courtyard": 0.57, "bg_biguan": 0.54, "bg_hantan": 0.61, "bg_houshan": 0.69}
func _stage_image(name: String, dim: float = 0.0, dim_col: Color = Color("#F3EEE2"), lift_to: float = -1.0) -> Rect2:
	var t = tex(name)
	var vs = get_viewport_rect().size
	if t == null:
		return Rect2(Vector2.ZERO, vs)
	var ts = t.get_size()
	var sc = max(vs.x / ts.x, vs.y / ts.y)
	var sz = ts * sc
	var pos = (vs - sz) / 2
	if lift_to > 0 and BG_INK_Y.has(name):
		var lift = clampf(pos.y + float(BG_INK_Y[name]) * sz.y - lift_to, 0.0, sz.y * 0.3)
		if lift > 0:
			pos.y -= lift
			var pad = ColorRect.new()
			pad.color = Color("#F3EEE2")
			pad.position = Vector2(0, pos.y + sz.y - 2)
			pad.size = Vector2(vs.x, vs.y - (pos.y + sz.y) + 4)
			pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stage.add_child(pad)
	var tr = TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.position = pos
	tr.size = sz
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(tr)
	if dim > 0:
		var cr = ColorRect.new()
		cr.color = Color(dim_col.r, dim_col.g, dim_col.b, dim)
		cr.size = vs
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(cr)
	return Rect2(pos, sz)

func _at(r: Rect2, p: Vector2) -> Vector2:
	var vs = get_viewport_rect().size
	var q = r.position + r.size * p
	return Vector2(clamp(q.x, 50, vs.x - 50), clamp(q.y, 92, vs.y - 120))

## 舞台上的可点热点：小纸签 + 图标
func hotspot(text: String, icon_name: String, at: Vector2, cb: Callable, w: int = 86) -> Button:
	var b = Button.new()
	b.text = text
	if icon_name != "" and tex(icon_name):
		b.icon = tex(icon_name)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 24)
	b.add_theme_font_size_override("font_size", 14)
	var sb = _sb(Color(0.985, 0.97, 0.935, 0.9), C_INK, 16, 1, 6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.custom_minimum_size = Vector2(w, MIN_TAP)
	b.size = Vector2(w, MIN_TAP)
	b.position = at - Vector2(w / 2.0, MIN_TAP / 2.0)
	b.pressed.connect(func(): _press(cb))
	stage.add_child(b)
	# 呼吸：轻轻上下浮动，提示可点
	var tw = b.create_tween().set_loops()
	tw.tween_property(b, "position:y", b.position.y - 3, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "position:y", b.position.y, 1.1).set_trans(Tween.TRANS_SINE)
	return b

func _glow(at: Vector2, radius: float, col: Color) -> void:
	var gt = GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gr = Gradient.new()
	gr.set_color(0, col)
	gr.set_color(1, Color(col.r, col.g, col.b, 0.0))
	gt.gradient = gr
	gt.width = 128
	gt.height = 128
	var tr = TextureRect.new()
	tr.texture = gt
	tr.size = Vector2(radius * 2, radius * 2)
	tr.position = at - Vector2(radius, radius)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(tr)
	var tw = tr.create_tween().set_loops()
	tw.tween_property(tr, "modulate:a", 0.45, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(tr, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)

func _spacer(parent: Node = null) -> void:
	var c = Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else body).add_child(c)

# ------------------------------------------------------------ 顶栏 HUD / 底栏
func _hud() -> void:
	var s = g.s
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color(0.985, 0.97, 0.935, 0.9), Color(0.29, 0.25, 0.2, 0.35), 10, 1, 6))
	hud.add_child(p)
	var r = row(p, 8)
	var dl = H("第%d日" % int(s["day"]), 20, C_ACCENT, r)
	dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var mid = VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 1)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(mid)
	L(g.realm_text(), 12, C_TEXT, mid)
	# 进度条只看这一层（每层 1/9 修为），一层满一次，比整条 600 慢慢挪看得见（总数在行囊页的环里）
	var pb = ProgressBar.new()
	var per := float(GS.XW_GOAL) / 9.0
	pb.max_value = per
	pb.value = per if int(s["xiuwei"]) >= GS.XW_GOAL else float(int(s["xiuwei"])) - per * (g.layer() - 1)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 7)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(pb)
	for it in [["ico_ration", "ration", int(s["ration"])], ["ico_lingshi", "lingshi", int(s["lingshi"])]]:
		var h = row(r, 1)
		IC(it[0], 22, h)
		var nl = L("", 14, C_TEXT, h)
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tick_label(nl, it[1], it[2])
	var bb = Button.new()
	bb.icon = tex("ico_juqi")
	bb.expand_icon = true
	bb.custom_minimum_size = Vector2(MIN_TAP, MIN_TAP)
	bb.add_theme_constant_override("icon_max_width", 24)
	bb.pressed.connect(func(): _press(func(): sheet = "" if sheet == "stats" else "stats"))
	r.add_child(bb)
	bag_icon = bb

func _nav() -> void:
	var r = row(footer, 4)
	var tabs = [["home", "青庐", "ico_qingzhi"], ["depart", "历练", "ico_ration"], ["log", "行记", "ico_fu"], ["cult", "修炼", "ico_zhuji"]]
	if g.world != null:
		tabs.insert(3, ["jianghu", "江湖", "ico_lingshi"])
	for t in tabs:
		# 选中的页签不再加“● ”（5 个页签时会把“青庐”挤成两行），改用底色 + 主色字
		var b = BI(t[1], t[2], func(): tab = t[0]; sheet = "", true, r, 46)
		if tab == t[0]:
			b.add_theme_stylebox_override("normal", _sb(Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 0.16), C_ACCENT, 8, 1, 4))
			b.add_theme_color_override("font_color", C_ACCENT)
		b.add_theme_font_size_override("font_size", 13 if tabs.size() > 4 else 14)
		if tabs.size() > 4:
			b.add_theme_constant_override("h_separation", 1)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 20)

# ------------------------------------------------------------ 底部抽屉
func _sheet() -> void:
	var dim = Button.new()
	dim.flat = true
	dim.size = get_viewport_rect().size
	var dsb = StyleBoxFlat.new()
	dsb.bg_color = Color(0.1, 0.08, 0.05, 0.35)
	for st in ["normal", "hover", "pressed", "focus"]:
		dim.add_theme_stylebox_override(st, dsb)
	dim.pressed.connect(func(): sheet = ""; refresh())
	sheet_layer.add_child(dim)
	var p = PanelContainer.new()
	var psb = _sb(Color("#F6F0E2"), Color(0.29, 0.25, 0.2, 0.5), 14, 1, 12)
	psb.corner_radius_bottom_left = 0
	psb.corner_radius_bottom_right = 0
	p.add_theme_stylebox_override("panel", psb)
	sheet_layer.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var top = row(v)
	var tl = {"field": "田", "furnace": "丹炉 · 仓", "aunt": "姑母", "pack": "行囊", "stats": "近况"}.get(sheet, "")
	var ht = H(tl, 24, C_ACCENT, top)
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cb = B("收起", func(): sheet = "", true, top, 34)
	cb.size_flags_horizontal = Control.SIZE_SHRINK_END
	cb.custom_minimum_size = Vector2(64, MIN_TAP)
	cb.add_theme_font_size_override("font_size", 13)
	match sheet:
		"field": _sheet_field(v)
		"furnace": _sheet_furnace(v)
		"aunt": _sheet_aunt(v)
		"pack": _sheet_pack(v)
		"stats": _sheet_stats(v)
	var vs = get_viewport_rect().size
	p.size = Vector2(vs.x, 0)
	p.reset_size()
	var h = max(p.get_combined_minimum_size().y, 120)
	p.position = Vector2(0, vs.y - h)
	p.size = Vector2(vs.x, h)
	if not sheet_layer.has_meta("open") or sheet_layer.get_meta("open") != sheet:
		sheet_layer.set_meta("open", sheet)
		p.position.y = vs.y
		p.create_tween().tween_property(p, "position:y", vs.y - h, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _queue_text() -> String:
	if g.s["queue"].is_empty():
		return "空"
	var parts = []
	for q in g.s["queue"]:
		parts.append("%s(%d日)" % [GS.RECIPES[q[0]]["name"], int(q[1])])
	return " → ".join(parts)

func _sheet_field(v: Node) -> void:
	var s = g.s
	var r = row(v, 14)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in s["fields"].size():
		ring(r, int(s["fields"][i]["prog"]), GS.FIELD_DAYS, 64, Color("#5B8A4A"), "%d/6" % int(s["fields"][i]["prog"]), "阳田%d · 青芝" % (i + 1))
	if s["extra"] == "shuitian":
		if int(s["lian_prog"]) >= 0:
			ring(r, int(s["lian_prog"]), GS.SHUI_LIAN_DAYS, 64, Color("#6B8FA8"), "%d/20" % int(s["lian_prog"]), "水田 · 寒潭莲")
		else:
			ring(r, int(s["gu_prog"]), GS.FIELD_DAYS, 64, Color("#6B8FA8"), "%d/6" % int(s["gu_prog"]), "水田 · 灵谷")
	L("每块阳田 6 日一熟，收青芝 2 株，自动入仓。", 13, C_DIM, v)
	if g.can_plant_lianzi():
		BI("水田种下寒潭莲子（20 日）", "ico_lian", func(): g.plant_lianzi(), true, v)
	if s["extra"] != "":
		var rb: String = g.can_rebuild_extra()
		var bb = B("改建第 5 点 → %s（1 日 · 10 灵石）%s" % ["水田" if s["extra"] == "field" else "第三块阳田", "" if rb == "" else "（" + rb + "）"], func(): g.rebuild_extra(), rb == "", v, 36)
		bb.add_theme_font_size_override("font_size", 13)

func _sheet_furnace(v: Node) -> void:
	var s = g.s
	var qr = row(v, 6)
	if s["queue"].is_empty():
		L("炉火未起。", 14, C_DIM, qr)
	for i in s["queue"].size():
		var q = s["queue"][i]
		var rc = GS.RECIPES[q[0]]
		var total = rc["days"] if not (q[0] == "zhuji" and s["zhuji_second"]) else GS.ZHUJI_SECOND_DAYS
		ring(qr, total - int(q[1]), total, 50, C_GOLD, "%d日" % int(q[1]), rc["name"].substr(0, 2))
	var r = row(v, 6)
	for k in ["juqi", "quzhang", "zhuji"]:
		var why: String = g.can_enqueue(k)
		var rc = GS.RECIPES[k]
		var b = BI("%s\n%d青芝·%d日" % [rc["name"], rc["qz"], rc["days"] if not (k == "zhuji" and s["zhuji_second"]) else 3], ICON[rc["out"]], func(): g.enqueue(k), why == "", r, 54)
		b.add_theme_font_size_override("font_size", 13)
	var r2 = row(v)
	B("按目标排程", _auto_sched, true, r2, 40)
	B("撤回队尾", func(): g.dequeue_last(), not s["queue"].is_empty(), r2, 40)
	if s["queue"].size() > 1:
		var r4 = row(v, 4)
		for i in s["queue"].size():
			var qi = i
			var qb = B("%s%s" % ["↑" if i > 0 else "", GS.RECIPES[s["queue"][i][0]]["name"].substr(0, 2)], func(): g.queue_move(qi, -1), i > 0, r4, 30)
			qb.add_theme_font_size_override("font_size", 13)
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	v.add_child(grid)
	for id in s["store"]:
		if int(s["store"][id]) <= 0:
			continue
		var cell = VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		grid.add_child(cell)
		IC(ICON.get(id, "ico_fu"), 34, cell)
		var nl = L("%s×%d" % [N(id).substr(0, 3), int(s["store"][id])], 11, C_TEXT, cell)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var res = g.default_reserve()
	var pv = g.eat_preview(res)
	var r3 = row(v)
	BI("全部服下（%d 颗）" % pv["n"], "ico_juqi", func(): modal = {"kind": "confirm_eat", "pv": pv, "reserve": res}, pv["n"] > 0, r3)
	if res > 0:
		B("连留的也吃", func(): modal = {"kind": "confirm_eat", "pv": g.eat_preview(0), "reserve": 0}, true, r3)

func _sheet_aunt(v: Node) -> void:
	var r = row(v, 10)
	IC("por_aunt", 72, r)
	var lines = ["“丹炉别空着，青芝放久了也是放。”", "“出门前，干粮多带两日。”", "“累了就回来。”"]
	var t = L(lines[int(g.s["day"]) % lines.size()], 15, C_TEXT, r)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if g.gelaosan_fruit_available():
		BI("托葛老三捎一颗赤阳果（−20 灵石）", "ico_guo", func(): g.buy_gelaosan_fruit(), g.s["lingshi"] >= 20, v)
	var mem = g.s["memory"]
	if not mem.is_empty():
		var m = mem[-1]
		L("%s记得：%s" % [m["npc"], m["text"]], 13, C_DIM, v)

func _sheet_pack(v: Node) -> void:
	var s = g.s
	L("随身 %d/6 格 · 点格子放回仓 · ◎=留作钥匙，不会被吃掉" % s["pack"].size(), 12, C_DIM, v)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for i in 6:
		if i < s["pack"].size():
			var sl = s["pack"][i]
			var idx = i
			var b = BI("%s%s×%d" % ["◎" if sl["key"] else "", N(sl["id"]), int(sl["n"])], ICON.get(sl["id"], "ico_fu"), func(): g.pack_take(idx), true, grid, 42)
			b.add_theme_font_size_override("font_size", 13)
		else:
			var e = B("空", func(): pass, false, grid, 42)
			e.add_theme_font_size_override("font_size", 13)
	var rr2 = row(v, 4)
	for id in ["pill_juqi", "fu_bishui", "fu_jingshui", "pill_quzhang"]:
		if g.store_n(id) > 0:
			var b2 = BI("带%s" % N(id), ICON[id], func(): g.pack_put(id, id == "pill_juqi"), s["pack"].size() < 6 or g.pack_n(id) > 0, rr2, 38)
			b2.add_theme_font_size_override("font_size", 13)
	if s["pack"].size() > 0:
		var rr3 = row(v, 4)
		for i in s["pack"].size():
			var idx = i
			var b3 = B("◎%d" % (i + 1), func(): g.toggle_key(idx), true, rr3, 30)
			b3.add_theme_font_size_override("font_size", 13)
	var pr = row(v, 4)
	var presets: Array = s.get("presets", [{}, {}, {}])
	for k in 3:
		var kk = k
		var has: bool = not presets[k].is_empty()
		var lab = ("存入方案%d" % (k + 1)) if (preset_save_mode or not has) else ("装方案%d" % (k + 1))
		var pb = B(lab, func(): _preset(kk), true, pr, 32)
		pb.add_theme_font_size_override("font_size", 13)
	var sm = B("取消" if preset_save_mode else "存…", func(): preset_save_mode = not preset_save_mode, presets.any(func(x): return not x.is_empty()), pr, 32)
	sm.add_theme_font_size_override("font_size", 13)

func _sheet_stats(v: Node) -> void:
	var s = g.s
	var r = row(v, 10)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	ring(r, int(s["xiuwei"]), GS.XW_GOAL, 64, C_GOLD, str(int(s["xiuwei"])), "修为/600")
	ring(r, int(s["ganwu"]), GS.WU_SOFTCAP, 64, C_ACCENT, str(int(s["ganwu"])), "待炼化")
	ring(r, int(s["yuyun"]), GS.YUYUN_CAP, 64, Color("#8A6BA8"), str(int(s["yuyun"])), "余韵")
	ring(r, int(s["shouyuan"]), GS.SHOUYUAN_START, 64, C_WARN, str(int(s["shouyuan"])), "寿元")
	var st = []
	if int(s["injured"]) > 0:
		st.append("受伤 %d 日" % int(s["injured"]))
	if int(s["unstable"]) > 0:
		st.append("心境不稳 %d 日" % int(s["unstable"]))
	st.append("倾向：力 %d · 利 %d · 善 %d · 避 %d" % [s["tags"]["力"], s["tags"]["利"], s["tags"]["善"], s["tags"]["避"]])
	L(" · ".join(st), 12, C_DIM, v)
	var grid = GridContainer.new()
	grid.columns = 5
	v.add_child(grid)
	var inv = _inventory()
	for id in inv:
		if id in ["lingshi", "ration"] or int(inv[id]) <= 0:
			continue
		var cell = VBoxContainer.new()
		grid.add_child(cell)
		IC(ICON.get(id, "ico_fu"), 32, cell)
		var nl = L("%s×%d" % [N(id).substr(0, 3), int(inv[id])], 11, C_TEXT, cell)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var r2 = row(v)
	B("放声" if muted else "静音", func(): _toggle_mute(), true, r2, 36)
	B("设置", func(): sheet = ""; show_settings = true, true, r2, 36)
	B("回标题", func(): sheet = ""; screen = "title", true, r2, 36)
	L("《青庐远行》%s" % VERSION, 11, C_DIM, v)

func _auto_sched() -> void:
	var a: Array = g.auto_schedule()
	var names = []
	for x in a:
		names.append(GS.RECIPES[x]["name"])
	g.notice("排上：" + ("、".join(names) if names.size() > 0 else "（没有可排的：青芝或主药不够，或聚气丹已排满 8 颗）"))

func _preset(k: int) -> void:
	var presets: Array = g.s.get("presets", [{}, {}, {}])
	if presets[k].is_empty() or preset_save_mode:
		preset_save_mode = false
		g.preset_save(k)
		g.notice("已存为方案%d。" % (k + 1))
	else:
		var miss: Array = g.preset_apply(k)
		g.notice("已装好方案%d。" % (k + 1) + ("缺：" + "、".join(miss.map(func(x): return N(x))) if miss.size() > 0 else ""))


# ------------------------------------------------------------ 标题 / 捏人
func _title() -> void:
	_stage_image("title")
	var top = row()
	var vtag = L(VERSION, 12, Color("#5A5046"), top)
	vtag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb = B("设置", func(): show_settings = true, true, top, 34)
	sb.size_flags_horizontal = Control.SIZE_SHRINK_END
	sb.custom_minimum_size = Vector2(60, MIN_TAP)
	sb.add_theme_font_size_override("font_size", 14)
	var mb = B("♪" if not muted else "♪×", func(): _toggle_mute(), true, top, 34)
	mb.size_flags_horizontal = Control.SIZE_SHRINK_END
	mb.custom_minimum_size = Vector2(MIN_TAP, MIN_TAP)
	var gap = Control.new()
	gap.custom_minimum_size = Vector2(0, get_viewport_rect().size.y * 0.09)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(gap)
	var t = H("青庐远行", 56, Color("#2B2620"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var st0 = L("一盏灯，一条山路", 15, Color("#4A3F33"))
	st0.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spacer()
	if store.exists():
		var d = store.load_data()
		if d != null:
			var st = d["state"]
			var cb = BI("继续 · %s · 第%d日" % [safe_name(String(st.get("name", ""))), int(st.get("day", 0))], "ico_ration", _continue, true, footer, 60)
			cb.alignment = HORIZONTAL_ALIGNMENT_CENTER
			cb.add_theme_font_size_override("font_size", 18)
		else:
			L("存档读不出来（已保留原文件）。", 13, C_WARN, footer)
	elif legacy.exists():
		var ld = legacy.load_data()
		if ld != null:
			var lst = ld["state"]
			var lb = BI("继续 v0.5 旧档 · %s · 第%d日" % [safe_name(String(lst.get("name", ""))), int(lst.get("day", 0))], "ico_ration", func(): _continue(true), true, footer, 60)
			lb.alignment = HORIZONTAL_ALIGNMENT_CENTER
			lb.add_theme_font_size_override("font_size", 16)
			L("旧档会复制一份到新版本继续玩，原档不改。", 12, C_DIM, footer).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nb = B("新游戏", func(): screen = "create", true, footer, 60)
	nb.add_theme_font_size_override("font_size", 20)
	var pad = Control.new()
	pad.custom_minimum_size = Vector2(0, 8)
	footer.add_child(pad)

func _create() -> void:
	_stage_image("bg_home", 0.25)
	if create_portrait.is_empty():
		_reroll_portrait()
	var vs = get_viewport_rect().size
	var ph = clampf(vs.y * 0.36, 180, 330)
	var pr = _portrait_frame(create_portrait, Vector2(ph * 0.75, ph), body)
	pr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var rr = row()
	rr.alignment = BoxContainer.ALIGNMENT_CENTER
	for it in [["换一张脸", "all"], ["发髻", "hair"], ["衣袍", "robe"], ["袍色", "tint"]]:
		var k: String = it[1]
		var rb = B(it[0], func(): _reroll_portrait(k), true, rr, 36)
		rb.add_theme_font_size_override("font_size", 13)
	var c = card()
	H("她叫", 22, C_ACCENT, c)
	var nr = GridContainer.new()
	nr.columns = 2
	nr.add_theme_constant_override("h_separation", 6)
	nr.add_theme_constant_override("v_separation", 6)
	c.add_child(nr)
	for nm in NAMES_PRESET:
		var b = B(nm, func(): create_name = nm, true, nr, 48)
		b.add_theme_font_size_override("font_size", 18)
		if create_name == nm:
			_mark(b)
	H("最舍不得", 22, C_ACCENT, c)
	var cr = row(c)
	for ch in [["aunt", "姑母", "por_aunt"], ["town", "小镇", "ico_ration"], ["book", "旧书", "ico_fu"]]:
		var b2 = BI(ch[1], ch[2], func(): create_cherish = ch[0], true, cr, 56)
		b2.add_theme_constant_override("icon_max_width", 34)
		b2.add_theme_font_size_override("font_size", 16)
		if create_cherish == ch[0]:
			_mark(b2)
	if store.exists():
		L("旧档会另存，不删除。", 12, C_WARN, c)
	var r = row(footer)
	var bk = B("返回", func(): screen = "title", true, r, 56)
	bk.size_flags_stretch_ratio = 0.4
	var go = B("出发", func(): _start_new(), true, r, 56)
	go.add_theme_font_size_override("font_size", 20)

## 主角立绘：整张重摇，或只换一处（发髻 / 衣袍 / 袍色），其余不动
func _reroll_portrait(part: String = "all") -> void:
	create_pseed += 1
	var fresh = PLib.roll("c%d_%d" % [randi(), create_pseed], {"sex": "f", "elder": false, "demonic": false, "robe_v": 10})
	# 主角不带魔纹
	fresh["marks"] = fresh["marks"].filter(func(m): return not String(m).begins_with("demon"))
	if part == "all" or create_portrait.is_empty():
		create_portrait = fresh
		return
	var sp = create_portrait.duplicate(true)
	match part:
		"hair":
			sp["hair"] = fresh["hair"]
			sp["acc"] = fresh["acc"]
		"robe":
			sp["robe"] = fresh["robe"]
			sp["outer"] = fresh["outer"]
			sp["outer_tint"] = fresh["outer_tint"]
		"tint":
			sp["robe_tint"] = fresh["robe_tint"]
	create_portrait = sp

## 带描边的立绘框（纸底画像）
func _portrait_frame(spec: Dictionary, sz: Vector2, parent: Node, crop: Rect2 = PBox.BUST, motion: float = 1.0) -> Control:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color(0.96, 0.94, 0.9, 1), Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.7), 6, 1, 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var pb = PBox.new()
	pb.custom_minimum_size = sz
	p.add_child(pb)
	pb.setup(spec, crop, motion)
	return p

## 主角立绘：女、非老者、无魔纹
func _hero_roll(seed_v) -> Dictionary:
	var sp = PLib.roll(seed_v, {"sex": "f", "elder": false, "demonic": false, "robe_v": 10})
	sp["marks"] = sp["marks"].filter(func(m): return not String(m).begins_with("demon"))
	return sp

func npc_spec(c: Dictionary) -> Dictionary:
	if c.get("player", false):
		return g.s.get("portrait", {})
	return PLib.roll(int(c["pseed"]), g.world.portrait_opts(c))

## 选中态：朱红描边
func _mark(b: Button) -> void:
	var sb = _sb(Color(1.0, 0.95, 0.88, 0.97), Color("#B03A2E"), 4, 2, 8)
	for st in ["normal", "hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color("#B03A2E"))

# ------------------------------------------------------------ 对话框（视觉小说式）
func _beats(text: String) -> Array:
	var out = []
	for para in text.split("\n", false):
		var sents = []
		var cur = ""
		var i = 0
		while i < para.length():
			var ch = para[i]
			cur += ch
			if ch in ["。", "！", "？"]:
				if i + 1 < para.length() and para[i + 1] in ["”", "」"]:
					cur += para[i + 1]
					i += 1
				sents.append(cur)
				cur = ""
			i += 1
		if cur.strip_edges() != "":
			sents.append(cur)
		var buf = ""
		for st in sents:
			if buf != "" and (buf + st).length() > 44:
				out.append(buf)
				buf = ""
			buf += st
		if buf != "":
			out.append(buf)
	return out

## 底部对话框：立绘 + 名字 + 一段一段点出来的台词。返回 true 表示已读完（可以出选项）
func dialog(speaker: String, portrait: String, text: String, dark: bool = true, spec: Dictionary = {}) -> bool:
	var bs = _beats(text)
	var done = beat_i >= bs.size() - 1
	# 矮屏（360×640）上选项多时，读完后把立绘缩小些，免得最后一个选项被挤出屏
	var ps = 0.68 if done and dlg_opts >= 4 and get_viewport_rect().size.y < 700 else 1.0
	dlg_opts = 0
	if spec.is_empty() and portrait.begins_with("vn_heroine") and g.s.get("portrait", {}) is Dictionary and not g.s.get("portrait", {}).is_empty():
		spec = g.s["portrait"]
	if not spec.is_empty():
		var pf = _portrait_frame(spec, Vector2(168, 224) * ps, body)
		pf.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	elif portrait != "" and tex(portrait):
		var pr = TextureRect.new()
		pr.texture = tex(portrait)
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		pr.custom_minimum_size = Vector2(180, 204) * ps
		pr.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(pr)
	var p = PanelContainer.new()
	var col = Color(0.11, 0.09, 0.07, 0.86) if dark else Color(0.985, 0.97, 0.935, 0.95)
	p.add_theme_stylebox_override("panel", _sb(col, Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.6), 8, 1, 12))
	body.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	if speaker != "":
		H(speaker, 20, C_GOLD, v)
	var shown = []
	for k in range(0, min(beat_i + 1, bs.size())):
		shown.append(bs[k])
	var tl = L("".join(shown) if shown.size() <= 2 else "".join(shown.slice(shown.size() - 2)), 16, Color("#F3EEE2") if dark else C_TEXT, v)
	tl.visible_ratio = 1.0
	if bs.size() > 0:
		# 新的一段：逐字显出
		var last_len = String(bs[min(beat_i, bs.size() - 1)]).length()
		var total = tl.text.length()
		tl.visible_characters = total - last_len
		if TEXT_CHAR_S[text_speed] <= 0.0:
			tl.visible_characters = -1
		else:
			var tw = tl.create_tween()
			tw.tween_property(tl, "visible_characters", total, last_len * TEXT_CHAR_S[text_speed])
			type_tw = tw
			type_label = tl
	if not done:
		var adv = B("▼", func(): _advance(), true, v, 44)
		adv.flat = true
		adv.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		adv.add_theme_color_override("font_color", C_GOLD)
		adv.add_theme_color_override("font_hover_color", C_GOLD)
		# 点对话框任意处：字还在走就先一下子显完，再点才翻页（触摸会被模拟成鼠标，只认鼠标左键，免得一下翻两页）
		p.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_advance())
	return done

var type_tw: Tween
var type_label: Label
func _advance() -> void:
	if DisplayServer.get_name() != "headless" and type_tw != null and type_tw.is_valid() and type_tw.is_running():
		type_tw.kill()
		if is_instance_valid(type_label):
			type_label.visible_characters = -1
		return
	_press(func(): beat_i += 1)

# ------------------------------------------------------------ 弹卡
func _modal() -> void:
	var k: String = modal["kind"]
	match k:
		"story":
			_story()
		"person":
			_person()
		"msg":
			_stage_image("bg_home", 0.0)
			_spacer()
			if dialog(modal.get("title", ""), "vn_" + String(modal.get("portrait", "")) if modal.has("portrait") else "", modal["text"]):
				B("知道了", func(): modal = {}, true, footer, 52)
		"conflict":
			_stage_image("bg_home", 0.5)
			var c = card()
			L("另一个标签页也在玩这个存档。为免互相覆盖，这一页已停止保存。\n请关掉其中一个页面，再刷新。", 15, C_WARN, c)
			B("知道了", func(): modal = {}, true, footer, 52)
		"home":
			_stage_image("courtyard", 0.35)
			_spacer()
			var sm: Dictionary = modal["sum"]
			var c = card()
			H("回到青庐", 26, C_ACCENT, c)
			L("姑母从灶间探出头：“回来了？先吃饭。”", 15, C_TEXT, c)
			var bk: Dictionary = sm.get("basket", {})
			var ir = HFlowContainer.new()
			ir.add_theme_constant_override("h_separation", 6)
			c.add_child(ir)
			for id in bk:
				chip("%s ×%d" % [N(id), int(bk[id])], ir, ICON.get(id, ""), Color("#3E6B3A"))
			chip("干粮 %d→%d" % [sm["ration_before"], sm["ration_after"]], ir, "ico_ration")
			if int(sm["aunt_ration"]) > 0:
				chip("姑母处寄存 %d" % int(sm["aunt_ration"]), ir, "ico_ration")
			if sm.get("turned_back", false):
				L("半路折返。", 13, C_DIM, c)
			if sm.has("news"):
				var nw = card()
				H("山外", 20, C_ACCENT, nw)
				for t in sm["news"]:
					L("· " + String(t), 13, C_TEXT, nw)
			if sm.has("world"):
				var w = card()
				H("世事", 20, C_WARN, w)
				L(sm["world"], 14, C_TEXT, w)
			B("进屋", func(): modal = {}, true, footer, 52)
		"thought":
			_stage_image(_trip_bg(), 0.3)
			_spacer()
			var c = card()
			L("◎ 关键选择，会被记住。", 13, C_ACCENT, c)
			L("她心里想：" + modal["text"], 17, C_TEXT, c)
			B("好", func(): modal = {}, true, footer, 48)
		"confirm_eat":
			_stage_image("courtyard", 0.45)
			_spacer()
			var pv: Dictionary = modal["pv"]
			var c = card()
			var r = row(c)
			IC("ico_juqi", 56, r)
			var vv = VBoxContainer.new()
			vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(vv)
			H("服下 %d 颗聚气丹" % pv["n"], 22, C_ACCENT, vv)
			L("修为 +%d%s" % [pv["xw"], ("，余韵 +%d" % pv["yuyun"]) if pv["yuyun"] > 0 else ""], 15, C_TEXT, vv)
			if pv["halved"] > 0:
				L("其中 %d 颗过了 8 颗的减半线（每颗只 +15）" % pv["halved"], 13, C_DIM, c)
			if int(modal["reserve"]) > 0:
				L("留 %d 颗不吃（老龟那边也许用得上）。" % modal["reserve"], 13, C_DIM, c)
			B("服下", func(): g.eat_all(int(modal["reserve"])); modal = {}, true, footer, 52)
			B("算了", func(): modal = {}, true, footer, 40)

# ------------------------------------------------------------ 第五点灵脉
func _extra_choice() -> void:
	_stage_image("courtyard", 0.3)
	_spacer()
	var c = card()
	H("灵脉第五点", 26, C_ACCENT, c)
	L("青庐的灵脉多通了一处，只够开一块地。", 15, C_TEXT, c)
	var r1 = row(c)
	IC("ico_qingzhi", 44, r1)
	LW("第三块阳田：青芝多一半，快。", 14, C_TEXT, r1)
	var r2 = row(c)
	IC("ico_lian", 44, r2)
	LW("水田：出灵谷当干粮，还能种寒潭莲子，是后路。", 14, C_TEXT, r2)
	BI("开第三块阳田", "ico_qingzhi", func(): g.choose_extra("field"), true, footer, 50)
	BI("开水田", "ico_lian", func(): g.choose_extra("shuitian"), true, footer, 50)

# ------------------------------------------------------------ 青庐（庭院）
func _home() -> void:
	var s = g.s
	var r = _stage_image("courtyard")
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 田里的青芝：长到哪，画到哪
	var plots = [Vector2(0.17, 0.64), Vector2(0.33, 0.72), Vector2(0.10, 0.78)]
	for i in s["fields"].size():
		var f = float(int(s["fields"][i]["prog"])) / GS.FIELD_DAYS
		for k in 3:
			var sp = TextureRect.new()
			sp.texture = tex("ico_qingzhi")
			sp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			var sz = 14 + 22 * f
			sp.size = Vector2(sz, sz)
			sp.position = r.position + r.size * plots[min(i, 2)] + Vector2((k - 1) * 26, -sz + 8 * (k % 2))
			sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stage.add_child(sp)
	if s["extra"] == "shuitian":
		var lp = r.position + r.size * Vector2(0.12, 0.84)
		var lt = TextureRect.new()
		lt.texture = tex("ico_lian" if int(s["lian_prog"]) >= 0 else "ico_ration")
		lt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lt.size = Vector2(34, 34)
		lt.position = lp - Vector2(17, 17)
		lt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(lt)
	var fp = r.position + r.size * Vector2(0.82, 0.66)
	if not s["queue"].is_empty():
		_glow(fp, 70, Color(1.0, 0.62, 0.2, 0.55))
	hotspot("阳田", "ico_qingzhi", _at(r, HOT["field"]) + Vector2(0, -60), func(): sheet = "field")
	hotspot("丹炉" + ("·%s" % GS.RECIPES[s["queue"][0][0]]["name"].substr(0, 2) if not s["queue"].is_empty() else ""), "ico_juqi", _at(r, HOT["furnace"]) + Vector2(-10, -78), func(): sheet = "furnace", 100)
	hotspot("静室", "ico_zhuji", _at(r, HOT["room"]) + Vector2(0, -30), func(): tab = "cult")
	hotspot("姑母", "ico_ration", _at(r, HOT["aunt"]) + Vector2(10, -40), func(): sheet = "aunt")
	_spacer()
	_light_notes()
	if g.can_breakthrough() == "":
		var bb = B("◎ 冲关（筑基，耗 1 日）", func(): g.start_breakthrough(), true, footer, 52)
		bb.add_theme_color_override("font_color", C_WARN)

# ------------------------------------------------------------ 修炼 / 闭关
func _cult() -> void:
	var s = g.s
	_stage_image("bg_biguan", 0.2)
	H(g.realm_text(), 28, C_ACCENT)
	var rr = row()
	rr.alignment = BoxContainer.ALIGNMENT_CENTER
	var rg = ring(rr, int(s["xiuwei"]), GS.XW_GOAL, 132, C_GOLD, "", "修为")
	var nl = L("", 26, C_TEXT, rg)
	nl.autowrap_mode = TextServer.AUTOWRAP_OFF
	nl.position = Vector2.ZERO
	nl.size = Vector2(132, 132)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tick_label(nl, "xw", int(s["xiuwei"]), "%d")
	var cr = HFlowContainer.new()
	cr.add_theme_constant_override("h_separation", 6)
	cr.alignment = FlowContainer.ALIGNMENT_CENTER
	body.add_child(cr)
	chip("待炼化 %d" % int(s["ganwu"]), cr, "", C_ACCENT)
	chip("余韵 %d/120" % int(s["yuyun"]), cr, "", Color("#6B4F8A"))
	chip("寿元 %d" % int(s["shouyuan"]), cr, "", C_WARN)
	chip("聚气丹已服 %d" % int(s["juqi_eaten"]), cr, "ico_juqi")
	if int(s["injured"]) > 0 or int(s["unstable"]) > 0:
		chip("炼化减半", cr, "", C_WARN)
	var hint: String = g.xw_full_hint()
	if hint != "":
		L(hint, 13, C_WARN)
	_spacer()
	var c = card()
	L("闭关：田和丹炉照常走", 13, C_DIM, c)
	var r = row(c)
	for n in [1, 3, 5]:
		B("%d 日" % n, func(): g.biguan("days", n), true, r, 46)
	B("炼完为止（约 %d 日）" % int(ceil(s["ganwu"] / 20.0)), func(): g.biguan("refine"), s["ganwu"] > 0, c, 42)
	var tgt = ""
	for q in s["queue"]:
		if q[0] == "zhuji":
			tgt = "zhuji"
	if tgt == "" and not s["queue"].is_empty():
		tgt = s["queue"][0][0]
	B("到丹成（%s）" % (GS.RECIPES[tgt]["name"] if tgt != "" else "炉空"), func(): g.biguan("pill", 1, tgt), tgt != "", c, 42)
	var why: String = g.can_breakthrough()
	if why != "":
		L("冲关：" + why, 12, C_DIM, c)
	var bb = B("◎ 冲关（筑基，耗 1 日）", func(): g.start_breakthrough(), why == "", footer, 50)
	if why == "":
		bb.add_theme_color_override("font_color", C_WARN)

# ------------------------------------------------------------ 行记
func _log_tab() -> void:
	_stage_image("bg_home", 0.7)
	H("人物记得的事", 24)
	if g.s["memory"].is_empty():
		L("（还没有）", 13, C_DIM)
	var pk = {"老龟": "por_turtle", "姑母": "por_aunt", "葛老三": "por_gelaosan"}
	for m in g.s["memory"]:
		var r = row(card())
		IC(pk.get(m["npc"], "por_heroine"), 40, r)
		LW("第%d日 · %s：%s" % [int(m["day"]), m["npc"], m["text"]], 14, C_TEXT, r)
	H("青庐行记", 24)
	var lc = card()
	var lg: Array = g.s["log"]
	for i in range(lg.size() - 1, maxi(-1, lg.size() - 40), -1):
		L("第%d日  %s" % [int(lg[i]["day"]), lg[i]["text"]], 13, C_TEXT, lc)


# ------------------------------------------------------------ 出发（路线图预览 + 行囊）
func _trip_bg() -> String:
	var rid = String(g.s.get("trip", {}).get("route", selected_route)) if g.s.get("loc", "") == "trip" else selected_route
	return "bg_houshan" if rid == "houshan" else "bg_hantan"

func _map_markers(rid: String, r: Rect2, interactive: Array, done_path: Array, cur: String) -> void:
	var nodes = g.routes[rid]["nodes"]
	var pos = MAP_POS[rid]
	var lines = MapLines.new()
	lines.size = get_viewport_rect().size
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(lines)
	var segs = []
	var prev = "_start"
	for nid in done_path:
		segs.append([_at(r, pos[prev]), _at(r, pos.get(nid, pos["_start"])), true])
		prev = nid
	for nid in interactive:
		segs.append([_at(r, pos[cur]), _at(r, pos.get(nid, pos["_start"])), false])
	lines.segs = segs
	# 不可点的路标：小墨点 + 名字
	for nid in nodes:
		if nid in interactive:
			continue
		var nd = nodes[nid]
		if nd.has("visible_if") and not g.check(nd["visible_if"]):
			continue
		var at = _at(r, pos.get(nid, pos["_start"]))
		var dot = Label.new()
		dot.text = ("● " if nid in done_path else "○ ") + g.events[nd["event"]]["title"]
		dot.add_theme_font_size_override("font_size", 13)
		dot.add_theme_color_override("font_color", Color("#8A3A22") if nid in done_path else Color("#3A332B"))
		dot.add_theme_stylebox_override("normal", _sb(Color(0.985, 0.97, 0.935, 0.75), Color(0, 0, 0, 0), 8, 0, 3))
		dot.position = at - Vector2(30, 10)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(dot)

func _token(at: Vector2, from: Vector2) -> void:
	var t = TextureRect.new()
	t.texture = tex("token")
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.size = Vector2(30, 56)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(t)
	t.position = from - Vector2(15, 52)
	var tw = t.create_tween()
	tw.tween_property(t, "position", at - Vector2(15, 52), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var bob = t.create_tween().set_loops()
	bob.tween_property(t, "rotation", 0.06, 0.25)
	bob.tween_property(t, "rotation", -0.06, 0.25)

func _depart() -> void:
	var s = g.s
	var r = _stage_image("map_" + selected_route, 0.15)
	_map_markers(selected_route, r, [], [], "_start")
	var rr = row()
	for rid in ["houshan", "hantan"]:
		var b = B(("● " if selected_route == rid else "") + g.routes[rid]["name"], func(): selected_route = rid, true, rr, 38)
		if selected_route == rid:
			b.add_theme_color_override("font_color", C_WARN)
	var rt = g.routes[selected_route]
	for ru in rt["rumors"]:
		var rc = row(card(), 8)
		var who = String(ru["text"]).split("：")[0] if String(ru["text"]).contains("：") else ""
		IC({"姑母": "por_aunt", "葛老三": "por_gelaosan"}.get(who, "por_heroine"), 38, rc)
		var tl = L(String(ru["text"]), 13, C_ACCENT if ru.get("key", false) else C_TEXT, rc)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spacer()
	var pc = card()
	var pr = row(pc, 6)
	IC("ico_ration", 30, pr)
	var rl = L("干粮 %d/12" % s["ration"], 15, C_TEXT, pr)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var b1 = B("+1（1灵石）", func(): g.buy_rations(1), s["ration"] < 12 and s["lingshi"] > 0, pr, 36)
	b1.add_theme_font_size_override("font_size", 13)
	if g.store_n("crop_linggu") > 0:
		var b2 = B("装灵谷", func(): g.load_grain(), s["ration"] < 12, pr, 36)
		b2.add_theme_font_size_override("font_size", 13)
	var kr = row(pc, 4)
	for i in 6:
		if i < s["pack"].size():
			var cell = IC(ICON.get(s["pack"][i]["id"], "ico_fu"), 30, kr)
			if s["pack"][i]["key"]:
				cell.modulate = Color(1, 0.85, 0.6)
		else:
			var e = Panel.new()
			e.custom_minimum_size = Vector2(30, 30)
			e.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0.06), Color(0.29, 0.25, 0.2, 0.3), 4, 1, 0))
			kr.add_child(e)
	var pb = BI("行囊 %d/6" % s["pack"].size(), "ico_fu", func(): sheet = "pack", true, kr, 36)
	pb.add_theme_font_size_override("font_size", 13)
	B("出发：%s" % rt["name"], func(): g.start_trip(selected_route), true, footer, 50)

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
	var rid = String(t["route"])
	var rt = g.route()
	var r = _stage_image("map_" + rid)
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path: Array = t["path"]
	var cur = path[-1] if path.size() > 0 else "_start"
	var choices = g.visible_choices()
	_map_markers(rid, r, choices, path, cur)
	var pos = MAP_POS[rid]
	var prevp = pos[path[-2]] if path.size() > 1 else pos["_start"]
	_token(_at(r, pos.get(cur, pos["_start"])), _at(r, prevp))
	for nid in choices:
		var nd = rt["nodes"][nid]
		var ev = g.events[nd["event"]]
		var days = int(ev.get("days", 1))
		if days > 0:
			days += g.day_mod()
		var rv: bool = g.is_revisit(nid)
		var lab = "%s\n%s%s" % [ev["title"], ("%d日" % days) if days > 0 else "到家", "·熟路" if rv else ("·要事" if ev.get("heavy", false) else "")]
		var b = hotspot(lab, "", _at(r, pos.get(nid, pos["_start"])), func(): g.enter_node(nid), 92)
		b.custom_minimum_size = Vector2(92, 46)
		b.size = Vector2(92, 46)
		b.add_theme_font_size_override("font_size", 13)
		if ev.get("heavy", false):
			var hs = _sb(Color(1.0, 0.95, 0.85, 0.95), C_WARN, 16, 2, 4)
			b.add_theme_stylebox_override("normal", hs)
			b.add_theme_stylebox_override("hover", hs)
	var hc = PanelContainer.new()
	hc.add_theme_stylebox_override("panel", _sb(Color(0.985, 0.97, 0.935, 0.85), Color(0, 0, 0, 0), 8, 0, 6))
	body.add_child(hc)
	var hr = row(hc)
	H(rt["name"], 22, C_ACCENT, hr)
	L("已走 %d 日 · 点路标前行" % int(t["walked"]), 13, C_DIM, hr).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if g.day_mod() > 0:
		L("老龟记仇：寒潭每段路 +%d 日" % g.day_mod(), 12, C_WARN)
	_spacer()
	if int(t["walked"]) > 0:
		B("半路折返（%d 日，每日扣干粮）" % g.turn_back_days(), func(): _turn_back(), true, footer, 42)
	else:
		B("不去了，回家（0 日）", func(): _turn_back(), true, footer, 42)

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
	_stage_image(_trip_bg())
	var pv = g.events[g.route()["nodes"][g.s["trip"]["node"]]["event"]].get("portrait", "")
	var pk = pv if pv is String else ""
	var tag = PanelContainer.new()
	tag.add_theme_stylebox_override("panel", _sb(Color(0.985, 0.97, 0.935, 0.85), Color(0, 0, 0, 0), 8, 0, 6))
	body.add_child(tag)
	var tr = row(tag)
	H(ev["title"], 24, C_ACCENT, tr)
	if ev.get("heavy", false):
		chip("要事", tr, "", C_WARN)
	_spacer()
	dlg_opts = ev["options"].size()
	var done = dialog(SPEAKER.get(pk, ""), ("vn_" + pk) if pk != "" else "", ev["text"])
	if not done:
		return
	for o in ev["options"]:
		var r = row(null, 4)
		var txt = String(o["label"])
		var ct = _cost_text(o)
		if ct != "":
			txt += "\n" + ct
		if not o["enabled"]:
			txt += "（" + String(o["reason"]) + "）"
		var oid: String = o["id"]
		var ic = ""
		for id in o.get("cost", {}).get("items", {}):
			ic = ICON.get(id, "")
		if o.get("cost", {}).has("chance_by_layer") or o.has("roll"):
			ic = "ico_lingshi" if ic == "" else ic
		var b = BI(txt, ic, func(): _choose(oid), o["enabled"], r, 50) if ic != "" else B(txt, func(): _choose(oid), o["enabled"], r, 50)
		b.add_theme_font_size_override("font_size", 14)
		_reveal(r, ev["options"].find(o))
		if o.get("key", false):
			var th = String(o.get("thought", ""))
			var kb = B("◎", func(): modal = {"kind": "thought", "text": th}, true, r, 50)
			kb.size_flags_horizontal = Control.SIZE_SHRINK_END
			kb.custom_minimum_size = Vector2(44, 50)

func _choose(oid: String) -> void:
	g.resolve(oid)

func _trip_quick() -> void:
	var nid: String = g.s["trip"]["node"]
	var rid = String(g.s["trip"]["route"])
	var r = _stage_image("map_" + rid, 0.1)
	var pos = MAP_POS[rid]
	var path: Array = g.s["trip"]["path"]
	_map_markers(rid, r, [], path, nid)
	_token(_at(r, pos.get(nid, pos["_start"])), _at(r, pos[path[-1]] if path.size() > 0 else pos["_start"]))
	var ev = g.events[g.route()["nodes"][nid]["event"]]
	_spacer()
	var c = card()
	H(ev["title"], 24, C_ACCENT, c)
	L("走过的路，脚下熟了，一晃就过去。", 14, C_DIM, c)
	B("快走（%d 日）" % (1 + g.day_mod()), func(): g.quick_walk(), true, footer, 52)

func _trip_result() -> void:
	var res: Dictionary = g.s["trip"]["result"]
	_stage_image(_trip_bg(), 0.15)
	_spacer()
	var c = card()
	var hr = row(c)
	var ht = H(res.get("title", ""), 24, C_ACCENT, hr)
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if res.has("roll"):
		var stamp = H("成" if res["roll"] == "成" else "败", 34, Color("#B03A2E") if res["roll"] == "成" else Color("#555555"), hr)
		stamp.pivot_offset = Vector2(17, 20)
		stamp.scale = Vector2(2, 2)
		stamp.create_tween().tween_property(stamp, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	L(String(res.get("option", "")), 13, C_DIM, c)
	var lines = []
	for l in res.get("lines", []):
		lines.append(l)
	if lines.size() > 0:
		L("\n".join(lines), 15, C_TEXT, c)
	var fr = HFlowContainer.new()
	fr.add_theme_constant_override("h_separation", 6)
	fr.add_theme_constant_override("v_separation", 4)
	c.add_child(fr)
	if int(res.get("days", 0)) > 0:
		chip("%d 日 · 粮余 %d" % [res["days"], g.s["ration"]], fr, "ico_ration")
	if int(res.get("ganwu", 0)) > 0:
		chip("感悟 +%d" % res["ganwu"], fr, "", C_ACCENT)
	for id in res.get("items", {}):
		var n = int(res["items"][id])
		chip("%s %s%d" % [N(id), "+" if n > 0 else "", n], fr, ICON.get(id, ""), Color("#3E6B3A") if n > 0 else C_WARN)
	if int(res.get("lingshi", 0)) != 0:
		chip("灵石 %+d" % int(res["lingshi"]), fr, "ico_lingshi")
	if res.get("memory", []).size() > 0:
		L("记住了：%s" % "、".join(res["memory"]), 12, C_DIM, c)
	B("回家" if res.get("end_trip", false) else "继续", func(): _continue_trip(), true, footer, 52)

func _continue_trip() -> void:
	var was_end: bool = g.s["trip"]["result"].get("end_trip", false)
	g.continue_trip()
	if was_end and g.s.has("last_home"):
		modal = {"kind": "home", "sum": g.s["last_home"]}

func _overflow() -> void:
	_stage_image(_trip_bg(), 0.4)
	var id: String = g.s["pending_overflow"][0]
	var c = card()
	H("行囊满了", 24, C_WARN, c)
	var r = row(c)
	IC(ICON.get(id, "ico_fu"), 40, r)
	L("要带上 %s，就得扔掉一格：" % N(id), 15, C_TEXT, r)
	for i in g.s["pack"].size():
		var sl = g.s["pack"][i]
		var idx = i
		BI("扔掉 %s ×%d" % [N(sl["id"]), int(sl["n"])], ICON.get(sl["id"], "ico_fu"), func(): g.resolve_overflow(idx), true)
	B("不要 %s" % N(id), func(): g.resolve_overflow(-1), true, footer, 48)

# ------------------------------------------------------------ 心魔 / 结局
func _xinmo() -> void:
	var q: Dictionary = g.current_xinmo()
	var xm = g.s["xm"]
	_stage_image("bg_biguan", 0.55, Color(0.05, 0.04, 0.08))
	var t = H("心魔劫", 40, Color("#E8DCC8"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sl = L("第 %d 幕 / 共 %d 幕" % [int(xm["idx"]) + 1, xm["ids"].size()], 13, Color("#C8BBA8"))
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spacer()
	if not dialog("", "", q["text"]):
		return
	L("不分对错，只看与她做过的事是否相合。", 12, Color("#C8BBA8"))
	for i in q["answers"].size():
		var idx = i
		B(q["answers"][i]["label"], func(): _answer(idx), true, null, 48)

func _answer(i: int) -> void:
	var r: Dictionary = g.answer_xinmo(i)
	if r.get("done", false) and not r.get("passed", true):
		modal = {"kind": "msg", "title": "心魔未平", "text": "雾里那个声音笑了一声，散了。她睁开眼，额上一层冷汗。\n有一句回答，和她做过的事对不上。筑基丹还在，先闭关 3 日（炼化减半），再冲关。"}

var show_log = false
func _ending() -> void:
	var s = g.s
	_stage_image("bg_ending", 0.1)
	if s["ending"] == "zhuji":
		var t = H("筑基", 64, C_ACCENT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_spacer()
		beat_i = 99
		dialog(String(s["name"]), "vn_heroine_smile", "第 %d 日，她在青庐静室筑基。那一夜，后山的溪水退了，寒潭上的雾散了一半。姑母在门外坐到天亮。推门出来时，院里的阳田都绿了。" % s["day"], false)
	else:
		var t2 = H("坐化于青庐", 44, C_ACCENT)
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_spacer()
		var ec2 = card()
		L("寿元耗尽。她回到青庐静室，在灯下合上了眼。窗外，后山的溪水还是那样流着。", 16, C_TEXT, ec2)
	var c = card()
	var fr = HFlowContainer.new()
	fr.add_theme_constant_override("h_separation", 6)
	c.add_child(fr)
	var st = s["stats"]
	chip("历练 %d 日" % st["trip_days"], fr, "ico_ration")
	chip("闭关 %d 日" % st["biguan_days"], fr, "ico_zhuji")
	chip("要事 %d" % st["heavy"], fr, "", C_WARN)
	chip("用时 %.0f 分钟" % (float(s.get("play_ms", 0)) / 60000.0), fr, "", C_ACCENT)
	if show_log:
		for e in s["log"]:
			L("第%d日  %s" % [int(e["day"]), e["text"]], 13, C_TEXT, c)
	B("收起行记" if show_log else "翻开青庐行记", func(): show_log = not show_log, true, footer, 40)
	B("回标题", func(): screen = "title", true, footer, 46)

var _dot_tex: Texture2D
func _soft_dot() -> Texture2D:
	if _dot_tex == null:
		var img = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				var d = Vector2(x + 0.5 - 8.0, y + 0.5 - 8.0).length() / 8.0
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
		_dot_tex = ImageTexture.create_from_image(img)
	return _dot_tex

## 冲关特效：金光一闪 + 灵气上浮
func _fx_breakthrough() -> void:
	var vs = get_viewport_rect().size
	var fl = ColorRect.new()
	fl.color = Color(1.0, 0.93, 0.7, 0.0)
	fl.size = vs
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(fl)
	var tw = fl.create_tween()
	tw.tween_property(fl, "color:a", 0.85, 0.25)
	tw.tween_property(fl, "color:a", 0.0, 1.2)
	tw.tween_callback(fl.queue_free)
	# 灵气上浮：用几十个小光点 + 补间，不用 CPUParticles2D——
	# 网页版（Compatibility / 部分 GPU，如 swiftshader）上 CPUParticles2D 的多实例绘制会混进一批黑点，换混合模式也去不掉
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in 70:
		var d = TextureRect.new()
		d.texture = _soft_dot()
		d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var sz = rng.randf_range(7.0, 19.0)
		d.size = Vector2(sz, sz)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.position = Vector2(rng.randf_range(0, vs.x), vs.y * 0.75 + rng.randf_range(-30, 30))
		d.modulate = Color(1.0, 0.86, 0.5, 0.0)
		fx_layer.add_child(d)
		var life = rng.randf_range(1.6, 2.6)
		var delay = rng.randf_range(0.0, 0.9) if i > 40 else rng.randf_range(0.0, 0.25)
		var t = d.create_tween()
		t.tween_interval(delay)
		t.tween_property(d, "modulate:a", 0.9, 0.2)
		t.parallel().tween_property(d, "position", d.position + Vector2(rng.randf_range(-40, 40), -rng.randf_range(180, 430)), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(d, "modulate:a", 0.0, life * 0.6).set_delay(life * 0.4)
		t.tween_callback(d.queue_free)


# ------------------------------------------------------------ 江湖（v0.6）：说书人事件 / 人物 / 传闻
## 有待处理的江湖事件、人在青庐、没有别的弹卡时，打开事件对话框
func _story_check() -> void:
	if screen != "game" or g.world == null or not modal.is_empty():
		return
	var on_trip: bool = g.s.get("loc", "") == "trip" and String(g.s.get("trip", {}).get("stage", "")) in ["result", "choose"]
	if (g.s.get("loc", "") != "home" and not on_trip) or g.s.get("ended", false):
		return
	if not on_trip and g.s["extra"] == "" and int(g.s["trips_done"]) >= 1:
		return
	var pe: Dictionary = g.world.pending()
	if not pe.is_empty():
		# v0.8：低频的日常小事（灵田、家书、夜雨……只有“知道了”）不再弹整屏对话，收进院里的一行小字，点开才看
		if pe.get("stage", "") == "ask" and String(pe.get("tid", "")) in LIGHT_TIDS and pe["opts"].size() == 1:
			g.world.choose(String(pe["opts"][0][0]))
			g.world.close()
			var lt: Array = g.world.w.get("light", [])
			lt.append([int(g.world.w["day"]), String(pe["tid"]), String(pe["text"])])
			g.world.w["light"] = lt.slice(-3)
			return
		modal = {"kind": "story"}
		sheet = ""
		sfx("page")

const LIGHT_TIDS = ["灵田", "闭关小成", "姑母来信", "夜雨", "旧物", "宗门大比", "飞升异象", "师门书信", "坊市传闻"]

## 院里的小字：最近收进来的日常小事（最多 3 条），点一下展开看全文
func _light_notes() -> void:
	if g.world == null:
		return
	var lt: Array = g.world.w.get("light", [])
	if lt.is_empty():
		return
	var it: Array = lt[-1]
	var txt := String(it[2])
	var short := txt.substr(0, 16) + ("…" if txt.length() > 16 else "")
	var lb = B("【%s】%s%s" % [String(it[1]), short, ("  +%d" % (lt.size() - 1)) if lt.size() > 1 else ""], _open_light, true, footer, 44)
	lb.add_theme_font_size_override("font_size", 14)
	lb.add_theme_color_override("font_color", C_INK)
	lb.add_theme_stylebox_override("normal", _sb(Color(0.985, 0.97, 0.935, 0.80), Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.5), 18, 1, 6))
	lb.alignment = HORIZONTAL_ALIGNMENT_LEFT
	lb.autowrap_mode = TextServer.AUTOWRAP_OFF
	lb.clip_text = true

func _open_light() -> void:
	var lt: Array = g.world.w.get("light", [])
	if lt.is_empty():
		return
	var it: Array = lt.pop_back()
	g.world.w["light"] = lt
	g.notice("【%s】%s" % [String(it[1]), String(it[2])])

func _story_key() -> String:
	if g.world == null or modal.get("kind", "") != "story":
		return ""
	var ev = g.world.pending()
	return "%s:%s:%s" % [ev.get("tid", ""), ev.get("day", 0), ev.get("stage", "")]

func _story() -> void:
	var ev: Dictionary = g.world.pending()
	if ev.is_empty():
		modal = {}
		_refresh()
		return
	var tier = int(g.world.T.get(String(ev["tid"]), [0])[0])
	var bgs = {"秘境": "bg_dongfu", "朱果之争": "bg_houshan", "偶遇": "bg_shandao", "求助": "bg_hantan", "寻凶": "bg_shandao", "道侣遇险": "bg_hantan",
		"心魔": "bg_biguan", "闭关小成": "bg_biguan", "魔修袭镇": "bg_fangshi", "仇人上门": "courtyard", "劫修拦路": "bg_shandao", "师父考验": "bg_dongfu",
		"夜雨": "bg_yeyu", "旧友死讯": "bg_yeyu", "表白": "bg_chasi", "访客": "bg_chasi", "论道": "bg_chasi", "义结金兰": "bg_chasi",
		"坊市传闻": "bg_fangshi", "坊市欺客": "bg_fangshi", "赠礼": "bg_fangshi", "宗门大比": "bg_leitai", "站队": "bg_leitai", "拜师": "bg_dongfu",
		"旧物": "bg_yeyu", "报恩": "bg_chasi", "飞升异象": "bg_houshan",
		"暗恋不舍": "bg_chasi", "再问": "bg_chasi", "怨偶": "bg_fangshi", "旧友托梦": "bg_yeyu", "仇家寻上门": "courtyard",
		"宗门招徒": "bg_leitai", "入门试炼": "bg_leitai", "秘境请柬": "bg_chasi", "拍卖会": "bg_fangshi", "劫修伏击": "bg_shandao",
		"师弟惹祸": "bg_fangshi", "天材地宝": "bg_houshan", "宝地相争": "bg_houshan", "对手突破": "bg_biguan", "旧债上门": "courtyard",
		"节令": "bg_fangshi", "远方来信": "bg_yeyu", "喜帖": "bg_chasi", "落难": "bg_shandao",
		"坊市认物": "bg_fangshi", "两难": "courtyard", "暗涌": "bg_yeyu", "道途殊归": "bg_yeyu", "重逢": "bg_shandao", "白首": "courtyard",
		"借庐": "courtyard", "点化": "courtyard", "点化回响": "courtyard",
		"寻仇": "bg_shandao", "截道": "bg_shandao", "失窃": "courtyard", "示好": "bg_chasi", "馈赠": "bg_chasi", "结伴": "bg_shandao",
		"交易": "bg_fangshi", "讨债": "bg_fangshi", "求援": "bg_yeyu", "示警": "bg_yeyu", "求教": "bg_chasi", "还情": "bg_chasi",
		"挑战": "bg_leitai", "流言": "bg_fangshi", "叛门": "bg_yeyu", "劝和": "bg_chasi", "夺宝": "bg_houshan", "邀游": "bg_dongfu", "撞见": "bg_shandao",
		"求药": "courtyard", "赔罪": "bg_chasi", "托付": "bg_yeyu", "问道": "bg_chasi", "风声": "bg_fangshi", "插手": "bg_yeyu"}
	# 选项多（节令、拍卖会……）时按钮紧凑些，并把场景往上挪，让画面露在对话框上方
	var n_opt = ev["opts"].size() if ev["stage"] == "ask" else 1
	var opt_h = 46 if n_opt >= 3 else 50
	var vsz = get_viewport_rect().size
	var free_bot = vsz.y - (n_opt * (opt_h + 6) + 150)
	_stage_image(bgs.get(String(ev["tid"]), "courtyard"), 0.3 if tier < 2 else 0.2, Color("#F3EEE2"), maxf(vsz.y * 0.32, (170.0 + free_bot) / 2.0 + 40.0))
	var tag = PanelContainer.new()
	tag.add_theme_stylebox_override("panel", _sb(Color(0.985, 0.97, 0.935, 0.85), Color(0, 0, 0, 0), 8, 0, 6))
	body.add_child(tag)
	var tr = row(tag)
	H("江湖 · " + String(ev["tid"]), 22, C_ACCENT, tr)
	if tier >= 2:
		chip("要事", tr, "", C_WARN)
	_spacer()
	var sid = int(ev.get("speaker", 0))
	var spk = ""
	var spec = {}
	if sid > 0:
		var c = g.world.C(sid)
		spec = npc_spec(c)
		spk = "陌生人" if (ev.get("anon", false) and ev["stage"] == "ask") else String(c["name"])
	var text = String(ev["text"]) if ev["stage"] == "ask" else String(ev.get("result", ""))
	if not dialog(spk, "", text, true, spec):
		return
	if ev["stage"] == "ask":
		var k = 0
		for o in ev["opts"]:
			var oid = String(o[0])
			var b = B(String(o[1]), func(): _story_pick(oid), true, footer, opt_h)
			b.add_theme_font_size_override("font_size", 15)
			_reveal(b, k)
			k += 1
	else:
		B("知道了", func(): g.world.close(); modal = {}, true, footer, 50)

func _story_pick(oid: String) -> void:
	var before = int(g.s.get("injured", 0))
	var res = g.world.choose(oid)
	if res == "":
		modal = {}
	elif int(g.s.get("injured", 0)) > before:
		sfx("fail")
	elif res.contains("感悟 +") or res.contains("灵石"):
		sfx("success")

## 插手（v0.10）：从传闻或心事页打开那件事
func _meddle(pid: int) -> void:
	if not g.world.pending().is_empty():
		g.notice("眼下还有一件事没了结。")
		return
	if g.world.MD.open(g.world, pid):
		modal = {"kind": "story"}
		sheet = ""
		sfx("page")

func _jianghu() -> void:
	_stage_image("bg_home", 0.72)
	var w = g.world
	var top = row()
	H("江湖", 26, C_ACCENT, top).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var me = B("她的生平", func(): person_id = 1; person_tab = "life"; modal = {"kind": "person"}, true, top, 36)
	me.size_flags_horizontal = Control.SIZE_SHRINK_END
	me.custom_minimum_size = Vector2(96, MIN_TAP)
	var ppl: Array = w.acquaintances()
	L("认识的人（%d）" % ppl.size(), 15, C_INK)
	if ppl.is_empty():
		L("还没有认识谁。日子长了，山外的人自会找上门来。", 13, C_DIM)
	var gw = get_viewport_rect().size.x - 16
	var cols = 3 if gw < 380 else 4
	var grid = GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	var cw = floor((gw - 6 * (cols - 1)) / cols)
	for c in ppl.slice(0, 24):
		var id = int(c["id"])
		var cell = Button.new()
		cell.custom_minimum_size = Vector2(cw, cw * 1.12 + 40)
		cell.pressed.connect(func(): _press(func(): person_id = id; person_tab = "life"; modal = {"kind": "person"}))
		grid.add_child(cell)
		var v = VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 3; v.offset_top = 3; v.offset_right = -3; v.offset_bottom = -2
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(v)
		var pb = PBox.new()
		pb.custom_minimum_size = Vector2(cw - 6, cw * 1.12 - 6)
		v.add_child(pb)
		pb.setup(npc_spec(c), PBox.FACE, 0.0)
		if not c["alive"]:
			pb.modulate = Color(0.75, 0.75, 0.75, 0.85)
		var nl = L(String(c["name"]), 14, C_TEXT, v)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF
		nl.clip_text = true
		var rw = w.rel_word(c)
		var col = C_WARN if rw in ["仇", "有隙"] else (Color("#B03A2E") if rw in ["道侣", "金兰", "师父"] else C_DIM)
		var sl = L(rw + ("" if c["alive"] else " · " + w.status(c)), 11, col, v)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.autowrap_mode = TextServer.AUTOWRAP_OFF
	H("传闻", 22, C_ACCENT)
	var nc = card()
	var news: Array = w.recent_news(40)
	if news.is_empty():
		L("山里很静，没听见什么。", 13, C_DIM, nc)
	for i in range(news.size() - 1, maxi(-1, news.size() - 13), -1):
		# v0.10：“听说某某要……”的传闻，日子没到之前可以插手
		var pid: int = w.MD.news_pid(w, news[i])
		if pid >= 0:
			var nr = row(nc, 6)
			LW("第%d日  %s" % [int(news[i][0]), news[i][1]], 13, C_TEXT, nr)
			var mb = B("插手", func(): _meddle(pid), true, nr, 40)
			mb.size_flags_horizontal = Control.SIZE_SHRINK_END
			mb.custom_minimum_size.x = 64
			mb.add_theme_font_size_override("font_size", 14)
		else:
			L("第%d日  %s" % [int(news[i][0]), news[i][1]], 13, C_TEXT, nc)

func _person() -> void:
	var w = g.world
	var c: Dictionary = w.C(person_id)
	if c.is_empty():
		modal = {}
		_refresh()
		return
	_stage_image("bg_home", 0.75)
	var is_p = c.get("player", false)
	var hr = row()
	var vs = get_viewport_rect().size
	var pw = clampf(vs.x * 0.4, 130, 190)
	_portrait_frame(npc_spec(c), Vector2(pw, pw * 4.0 / 3.0), hr)
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	hr.add_child(info)
	H(String(c["name"]), 26, C_ACCENT, info)
	var realm = g.realm_text() if is_p else w.status(c)
	L("%s · %s" % [String(c["sect"]), realm], 14, C_TEXT, info)
	if not is_p:
		L("关系：%s" % w.rel_word(c), 14, C_WARN if w.rel_word(c) in ["仇", "有隙"] else C_TEXT, info)
	var tf = HFlowContainer.new()
	tf.add_theme_constant_override("h_separation", 4)
	info.add_child(tf)
	if not is_p:
		for t in c["traits"]:
			chip(String(t), tf)
		var r = w.R(c, w.P())
		var close = int(r["f"]) >= 20 or c.get("known_like", false) or not w.R(w.P(), c)["t"].is_empty()
		L("喜：%s" % ("、".join(c["likes"]) if close else "（还不熟）"), 13, C_DIM, info)
		L("志：%s" % (String(c["goal"]) if close else "（还不熟）"), 13, C_DIM, info)
		if w.known(c):
			L("记得：%s" % String(w.sig(c)[1]), 13, C_DIM, info).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if w.R(w.P(), c).has("ks"):
			L("信物：%s" % String(w.R(w.P(), c)["ks"]), 13, C_GOLD, info).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var bar = ProgressBar.new()
		bar.min_value = -60
		bar.max_value = 80
		bar.value = clampf(float(r["f"]) - float(r["g"]), -60, 80)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		info.add_child(bar)
		L("好感", 11, C_DIM, info)
	var tr = row()
	for t in ([["life", "生平"], ["rel", "关系"]] + ([] if is_p else [["why", "心事"], ["mem", "记得她"]])):
		var k = String(t[0])
		var b = B(("● " if person_tab == k else "") + String(t[1]), func(): person_tab = k, true, tr, 38)
		b.add_theme_font_size_override("font_size", 14)
	var cc = card()
	match person_tab:
		"life":
			_life_timeline(c, cc)
		"why":
			# v0.9：这个人眼下想做什么、为什么（动机 + 最放不下的几件事 + 性子）
			var wl: Array = w.AG.why_lines(w, c)
			var deep: bool = int(w.R(c, w.P())["f"]) >= 20 or not w.R(w.P(), c)["t"].is_empty() or int(w.R(c, w.P())["g"]) >= 20
			if wl.is_empty():
				L("（无从知晓）", 13, C_DIM, cc)
			for i in wl.size():
				var ln := String(wl[i])
				if not deep and i > 0:
					L("（再熟些，才看得出%s心里放不下什么。）" % w.ta(c), 13, C_DIM, cc)
					break
				L(ln, 14 if i == 0 else 13, C_TEXT if i == 0 else C_DIM, cc)
			# v0.10：她已经听说了这个人在谋的事（传闻、风声），日子没到就还能管
			var mpid: int = w.MD.plot_of(w, c)
			if mpid >= 0:
				var pt: Dictionary = w.MD.get_plot(w, mpid)
				L("听说：%s" % w.MD.leak(w, pt), 13, C_WARN, cc)
				B("插手这件事", func(): _meddle(mpid), true, cc, 44)
		"rel":
			var ks = c["rel"].keys()
			ks.sort_custom(func(a, b): return _rel_depth(c["rel"][a]) > _rel_depth(c["rel"][b]))
			var n = 0
			for k in ks:
				var o = w.C(k)
				var r2 = c["rel"][k]
				if o.is_empty() or int(r2["m"]) == 0 or _rel_depth(r2) < 8:
					continue
				var word = "/".join(r2["t"]) if not r2["t"].is_empty() else ("仇" if int(r2["g"]) >= 30 else ("好友" if int(r2["f"]) >= 30 else "相识"))
				# v0.8：竖向卡片（小头像 + 关系 + 最近一件共同的事），手机窄屏不挤
				var oid2 := int(o["id"])
				var rr = row(cc, 8)
				var tb2 = Button.new()
				tb2.custom_minimum_size = Vector2(44, 50)
				tb2.flat = true
				tb2.pressed.connect(func(): _press(func(): person_id = oid2; person_tab = "life"; life_all = false))
				rr.add_child(tb2)
				var pb2 = PBox.new()
				pb2.set_anchors_preset(Control.PRESET_FULL_RECT)
				pb2.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tb2.add_child(pb2)
				pb2.setup(npc_spec(o), PBox.FACE, 0.0)
				if not o["alive"]:
					pb2.modulate = Color(0.75, 0.75, 0.75, 0.85)
				var rv = VBoxContainer.new()
				rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				rv.add_theme_constant_override("separation", 0)
				rr.add_child(rv)
				var wcol = C_WARN if int(r2["g"]) >= 30 else (Color("#B03A2E") if not r2["t"].is_empty() else C_TEXT)
				L("%s · %s%s" % [String(o["name"]), word, "" if o["alive"] else " · 已故"], 14, wcol, rv)
				var lastm = ""
				for m in c["mem"]:
					if int(m[1]) == oid2:
						lastm = String(m[2])
				var ml = L(("“%s”" % lastm) if lastm != "" else String(o["sect"]), 13, C_DIM, rv)
				ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				n += 1
				if n >= 10:
					break
			if n == 0:
				L("（还没有深交的人）", 13, C_DIM, cc)
		"mem":
			var ms: Array = w.memories_of_p(c)
			if ms.is_empty():
				L("%s对她还没什么印象。" % ("她" if c["sex"] == "女" else "他"), 13, C_DIM, cc)
			for m in ms:
				L("第%d日  %s" % [int(m[0]), m[2]], 14, C_WARN if int(m[3]) < 0 else C_TEXT, cc)
	B("回江湖", func(): modal = {}; tab = "jianghu"; life_all = false, true, footer, 46)

## 生平时间线：按历法分月（第 1 日是正月初一，30 日一月；节令也按这个历），近的月份在上、月内按日先后；每条右侧是提到的人的小头像（点开看此人）
func _life_timeline(c: Dictionary, cc: VBoxContainer) -> void:
	var w = g.world
	var lg: Array = c["log"]
	if lg.is_empty():
		L("（没听说过什么）", 13, C_DIM, cc)
		return
	var ppl := []
	for o in w.w["C"].values():
		if int(o["id"]) != int(c["id"]) and not o.get("player", false) and String(o["name"]).length() >= 2:
			ppl.append(o)
	var months := []
	for e in lg:
		var m := (maxi(int(e[0]), 1) - 1) / 30
		if months.is_empty() or int(months[-1][0]) != m:
			months.append([m, []])
		months[-1][1].append(e)
	var first := 0 if life_all else maxi(0, months.size() - 3)
	var pname := String(w.P()["name"])
	for mi in range(months.size() - 1, first - 1, -1):
		var m: int = months[mi][0]
		var hr = row(cc, 8)
		var mt: String = w.cal_text(m * 30 + 1)
		H(mt.substr(0, mt.length() - 2), 20, C_ACCENT, hr)
		var sub = L("第 %d–%d 日 · %d 件" % [m * 30 + 1, m * 30 + 30, months[mi][1].size()], 13, C_DIM, hr)
		sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for e in months[mi][1]:
			var er = row(cc, 6)
			var dl = L(w.cn_day(int(w.cal(int(e[0]))[2])), 13, C_GOLD, er)
			dl.custom_minimum_size = Vector2(40, 0)
			dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			dl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			var tp = PanelContainer.new()
			var tsb = StyleBoxFlat.new()
			tsb.bg_color = Color(0, 0, 0, 0)
			tsb.border_color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.45)
			tsb.border_width_left = 2
			tsb.content_margin_left = 8
			tsb.content_margin_bottom = 4
			tp.add_theme_stylebox_override("panel", tsb)
			tp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			er.add_child(tp)
			var tl = L(String(e[1]).replace(pname, "她") if c.get("player", false) else String(e[1]), 14, C_TEXT, tp)
			tl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			var who := []
			for o in ppl:
				if String(e[1]).contains(String(o["name"])):
					who.append(o)
					if who.size() >= 2:
						break
			for o in who:
				var oid := int(o["id"])
				var tb = Button.new()
				tb.custom_minimum_size = Vector2(44, 50)
				tb.flat = true
				tb.tooltip_text = String(o["name"])
				tb.pressed.connect(func(): _press(func(): person_id = oid; person_tab = "life"; life_all = false))
				er.add_child(tb)
				var pb = PBox.new()
				pb.set_anchors_preset(Control.PRESET_FULL_RECT)
				pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tb.add_child(pb)
				pb.setup(npc_spec(o), PBox.FACE, 0.0)
				if not o["alive"]:
					pb.modulate = Color(0.75, 0.75, 0.75, 0.85)
	if first > 0:
		var hidden := 0
		for i in first:
			hidden += months[i][1].size()
		var mb = B("再往前：%d 个月 · %d 件" % [first, hidden], func(): life_all = true, true, cc, 44)
		mb.add_theme_font_size_override("font_size", 14)

func _rel_depth(r: Dictionary) -> float:
	return absf(float(r["f"])) + float(r["g"]) + r["t"].size() * 50

# ------------------------------------------------------------ 调试场景（只在调试导出里可用，给验收截图）
func _dev(cmd: String) -> String:
	if cmd != "settings" and cmd != "state":
		show_settings = false
	match cmd:
		"state":
			return JSON.stringify({"screen": screen, "loc": g.s.get("loc", ""), "day": g.s.get("day", -1), "stage": g.s.get("trip", {}).get("stage", ""), "node": g.s.get("trip", {}).get("node", ""), "rev": store.rev})
		"choose", "result":
			_dev("depart")
			g.start_trip("hantan")
			for pk in [["T1", "A"], ["T2", "A"], ["T3a", "A"]]:
				g.enter_node(pk[0]); g.resolve(pk[1]); g.continue_trip()
			if cmd == "result":
				g.enter_node("T4"); g.resolve("C")
			sheet = ""
			g.notices.clear()
			_save()
			refresh()
		"settings":
			show_settings = true
			refresh()
		"extra":
			# 调试：灵脉第五点的二选一（第一次历练回来后）
			g.new_game("苏青禾", "aunt", 5, true)
			g.s["portrait"] = _hero_roll("p5")
			g.s["trips_done"] = 1
			g.s["extra"] = ""
			screen = "game"
			modal = {}
			sheet = ""
			tab = "home"
			g.notices.clear()
			refresh()
		"story", "jianghu", "person", "create_rnd", "life", "guide", "guide_depart":
			if cmd == "create_rnd":
				screen = "create"
				_reroll_portrait()
				refresh()
				return cmd
			g.new_game("苏青禾", "aunt", 5, true)
			g.s["portrait"] = _hero_roll("p5")
			g.s["trips_done"] = 1
			g.s["extra"] = "field"
			screen = "game"
			modal = {}
			for i in (110 if cmd == "life" else 40):
				g.tick("biguan")
				g.world.auto_choose()
			g.world.close()
			if cmd == "story":
				var c = g.world.acquaintances()[0] if not g.world.acquaintances().is_empty() else g.world.npcs()[0]
				g.world.fire("表白" if c["sex"] == "男" else "访客", {"B": int(c["id"])}, {})
			if cmd == "jianghu":
				tab = "jianghu"
			if cmd in ["guide", "guide_depart"]:
				g.s["day"] = 1
				g.s["trips_done"] = 0
				g.s["guide"] = {"seen": {}, "off": false}
				tab = "home" if cmd == "guide" else "depart"
			if cmd == "life":
				tab = "jianghu"
				person_id = 1
				person_tab = "life"
				life_all = false
				modal = {"kind": "person"}
			if cmd == "person":
				tab = "jianghu"
				person_id = int(g.world.acquaintances()[0]["id"])
				person_tab = "life"
				modal = {"kind": "person"}
			g.notices.clear()
			_save()
			refresh()
		_ when cmd.begins_with("npcsheet"):
			# 调试：12 个随机新人物（种子 npcsheet:<n>）一屏排开，看彼此是否够不同、有没有贴歪的部件
			var base := int(cmd.substr(9)) if cmd.length() > 9 else 1
			var specs2 := []
			for k in 12:
				var sect: String = g.world.SECT_LIST[(base + k) % g.world.SECT_LIST.size()] if g.world != null else "散修"
				var o := {"sex": "m" if k % 3 == 2 else "f", "elder": k == 11, "demonic": sect in ["血煞门", "阴骨教"], "demon_mix": true, "robe_v": 10, "sect": sect}
				if g.world != null and g.world.SECT_TINT.has(sect):
					o["robe_tint"] = g.world.SECT_TINT[sect]
				specs2.append(PLib.roll((base * 7919 + k * 104729) % 1000000000, o))
			return _dev("psheet:" + JSON.stringify(specs2))
		_ when cmd.begins_with("psheet:"):
			# 调试：一屏摆一组立绘（静止，可指定 eye_state），验部件和闭眼帧
			var specs = JSON.parse_string(cmd.substr(7))
			var old_sheet = get_node_or_null("DevSheet")
			if old_sheet != null:
				old_sheet.free()
			var bg := ColorRect.new()
			bg.name = "DevSheet"
			bg.color = Color(0.96, 0.94, 0.9)
			bg.set_anchors_preset(Control.PRESET_FULL_RECT)
			add_child(bg)
			var grid := GridContainer.new()
			grid.columns = 3
			grid.set_anchors_preset(Control.PRESET_FULL_RECT)
			bg.add_child(grid)
			for sp in specs:
				var pb = PBox.new()
				pb.custom_minimum_size = Vector2(118, 158)
				grid.add_child(pb)
				pb.no_bake = true   # 对照图要看闭眼帧，不烘焙
				pb.setup(sp, PBox.BUST, 0.0)
				pb.view.eye_state = String(sp.get("eye_state", "open"))
				pb.view._apply_eyes(pb.view.eye_state)
			return "ok"
		_ when cmd.begins_with("xinshi"):
			# 调试：打开一个熟人的“心事”页（先跑几十日让人物有动机和记忆，并把关系拉近到能看全）
			_dev("jianghu")
			for i in 40:
				g.world.tick(i % 3 != 0)
				g.world.auto_choose()
			var cx: Dictionary = {}
			for c in g.world.npcs():
				if c.has("dr") and String(c["dr"]["k"]) != "交游" and not c["mem"].is_empty():
					cx = c
					break
			if cx.is_empty():
				cx = g.world.npcs()[0]
			g.world.R(cx, g.world.P())["f"] = 25
			g.world.R(g.world.P(), cx)["m"] = 1
			tab = "jianghu"
			person_id = int(cx["id"])
			person_tab = "why"
			modal = {"kind": "person"}
			_save()
			refresh()
		"mdpick":
			# 调试：插手事件点第一个选项，看结果页
			var ev3: Dictionary = g.world.pending()
			if not ev3.is_empty() and ev3["stage"] == "ask":
				g.world.choose(String(ev3["opts"][0][0]))
			modal = {"kind": "story"}
			_save()
			refresh()
		_ when cmd.begins_with("md:") or cmd == "mdnews":
			# 调试（v0.10 插手）：md:风声 / md:风声@路 / md:插手:夺宝 / mdnews（江湖页带“插手”的传闻）
			_dev("jianghu")
			tab = "home"
			var wd = g.world
			for i in 12:
				wd.tick(true)
				wd.auto_choose()
			var spec3 := cmd.substr(3).split("@") if cmd != "mdnews" else PackedStringArray(["插手"])
			var head := String(spec3[0]).split(":")
			var v3 := String(head[1]) if head.size() > 1 else "寻仇"
			var ns3: Array = wd.acquaintances().filter(func(x): return x["alive"])
			for c in wd.npcs():
				if not c in ns3:
					ns3.append(c)
			var a3: Dictionary = ns3[0]
			var b3: Dictionary = {}
			for c in ns3:
				if c != a3 and (v3 != "示好" or c["sex"] != a3["sex"]):
					b3 = c
					break
			for pt in wd.MD.plots(wd):
				if int(pt["a"]) == int(a3["id"]):
					pt["p"] = 2
			var pid3 := int(wd.w.get("pln", 0))
			wd.MD.plan(wd, a3, v3, {} if v3 == "叛门" else b3, -1, true)
			var pt3: Dictionary = wd.MD.get_plot(wd, pid3)
			pt3["k"] = 1
			if wd.w["news"].filter(func(n): return n.size() > 4 and int(n[4]) == pid3).is_empty():
				wd.rumor(wd.MD.leak(wd, pt3), [a3], "谋")
				wd.w["news"][-1].append(pid3)
			wd.w["agq"] = wd.w["agq"].filter(func(it): return String(it[1]) != "风声")
			wd.close()
			if spec3.size() > 1:
				wd.w["here"] = "后山"
			if cmd == "mdnews":
				tab = "jianghu"
				modal = {}
				get_tree().create_timer(0.4).timeout.connect(func(): scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value))
			elif String(head[0]) == "插手":
				wd.MD.open(wd, pid3)
				modal = {"kind": "story"}
			else:
				var inf3: Dictionary = ns3[2] if ns3[2] != b3 else ns3[3]
				wd.fire("风声", {"B": int(inf3["id"]), "X": int(a3["id"]), "V": int(pt3["b"])}, {"pid": pid3, "aid": -1, "ov": 1 if spec3.size() > 1 else 0})
			_save()
			refresh()
		_ when cmd.begins_with("ag:"):
			# 调试：人物自主事件（ag:截道 在家；ag:截道@路 在路上）
			_dev("jianghu")
			tab = "home"
			var spec := cmd.substr(3).split("@")
			var tid2 := String(spec[0])
			var ns: Array = g.world.acquaintances().filter(func(x): return x["alive"])
			for c in g.world.npcs():
				if not c in ns:
					ns.append(c)
			var a: Dictionary = ns[0]
			g.world.AG.pers(a)
			a["dr"] = {"k": "复仇" if tid2 in ["寻仇", "截道", "流言", "撞见"] else "求财", "t": 1, "u": 0.8, "d": int(g.world.w["day"]), "why": "%s抢了我在后山看中的灵物" % g.world.pn(), "src": -1}
			var r2 := {"B": int(a["id"])}
			match tid2:
				"求援":
					r2["V"] = int(ns[1]["id"]); r2["H"] = int(ns[2]["id"])
				"示警", "劝和":
					r2["H"] = int(ns[2]["id"])
				"撞见":
					r2["V"] = int(ns[1]["id"])
			g.world.R(a, g.world.P())["owe"] = 6
			if tid2 == "赔罪":
				a["dr"]["why"] = "当年在后山抢了你看中的灵物，是我对不住你"
			elif tid2 == "托付":
				a["dr"]["why"] = "自知时日无多，你待我好"
			elif tid2 == "求药":
				a["inj"] = 14
			if spec.size() > 1:
				g.world.w["here"] = "后山"
			g.world.fire(tid2, r2, {"aid": -1, "why": String(a["dr"]["why"]), "v": "截杀"})
			_save()
			refresh()
		_ when cmd.begins_with("story:"):
			# 调试：直接弹某个江湖事件（截背景用）；绑不上角色就退回表白/访客
			_dev("jianghu")
			tab = "home"
			var tid = cmd.substr(6)
			var r = g.world.bind(tid)
			if r == null:
				var acq: Array = g.world.acquaintances().filter(func(x): return x["alive"])
				var c = acq[0] if not acq.is_empty() else g.world.npcs()[0]
				var c2 = acq[1] if acq.size() > 1 else g.world.npcs()[1]
				r = {"B": int(c["id"])}
				match tid:
					"两难":
						r = {"A": int(c["id"]), "B": int(c2["id"]), "made": 1}
					"借庐":
						r["H"] = int(g.world.npcs()[-1]["id"])
					"重逢":
						g.world.R(g.world.P(), c)["lv0"] = [int(c["lv"]) + 3, 0]
					"坊市认物":
						g.world._swap_ks(c)
						g.world.die(c, "死于无名劫修之手")
			g.world.fire(tid, r, {})
			_save()
			refresh()
		"bakestat":
			# 调试：缩略图烘焙缓存了几张、这台设备能不能烘焙
			var bs := "%d %s" % [PBox._cache.size(), str(PBox.bake_ok)]
			if OS.has_feature("web"):
				JavaScriptBridge.get_interface("window").qinglu_bake = bs
			return bs
		"beat":
			if OS.has_feature("web"):
				JavaScriptBridge.get_interface("window").qinglu_beat = beat_i
			return str(beat_i)
		"audit":
			# 调试：列出当前画面里小于 44px 的可点控件、小于 13px 的字
			var small := []
			var tiny := []
			var st := [self]
			while not st.is_empty():
				var n: Node = st.pop_back()
				for c in n.get_children():
					st.append(c)
				if n is Control and n.is_visible_in_tree():
					var r: Rect2 = n.get_global_rect()
					if n is BaseButton and (r.size.y < 44 or r.size.x < 44):
						small.append("%s %dx%d" % [String(n.text) if n is Button else n.get_class(), int(r.size.x), int(r.size.y)])
					if n is Label and n.text.strip_edges() != "" and n.get_theme_font_size("font_size") < 13:
						tiny.append("%s %d" % [n.text.substr(0, 10), n.get_theme_font_size("font_size")])
			var js = JSON.stringify({"small": small, "tiny": tiny})
			if OS.has_feature("web"):
				JavaScriptBridge.get_interface("window").qinglu_audit = js
			return js
		"reveal":
			beat_i = 99
			refresh()
		"sheet_furnace", "sheet_field", "sheet_stats", "sheet_pack":
			sheet = cmd.substr(6)
			refresh()
		"create":
			screen = "create"
			modal = {}
			sheet = ""
			refresh()
		"title":
			screen = "title"
			modal = {}
			refresh()
		"event":
			g.new_game("苏青禾", "aunt", 3, true)
			g.s["portrait"] = _hero_roll("p3")
			screen = "game"
			modal = {}
			g.start_trip("houshan")
			for pk in [["H1", "A"], ["H2a", "A"]]:
				g.enter_node(pk[0]); g.resolve(pk[1]); g.continue_trip()
			g.enter_node("H3")
			g.notices.clear()
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
			g.notices.clear()
			_save()
			refresh()
		"laogui", "depart", "home", "cult":
			g.new_game("苏青禾", "aunt", 3, true)
			g.s["portrait"] = _hero_roll("p3")
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
			g.notices.clear()
			_save()
			refresh()
	return cmd
