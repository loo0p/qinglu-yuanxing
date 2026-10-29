extends Control
## 《青庐远行》v0.4 试玩版 · 界面层（场景优先）
## 竖屏，360×640 起，适配更高的屏（如 390×844）。规则全部在 GameState，这里只负责显示、动效、音频和调用。
## 结构：stage（整幅插画 + 热点/路标）→ ui（顶栏 HUD、正文、底栏）→ sheet（底部抽屉）→ fx（飞入、冲关特效）

const GS = preload("res://scripts/game_state.gd")
const TV = preload("res://scripts/travel.gd")
const World = preload("res://scripts/world.gd")
const Gear = preload("res://scripts/gear.gd")
const Econ = preload("res://scripts/econ.gd")
const Jobs = preload("res://scripts/jobs.gd")
const Store = preload("res://scripts/save_store.gd")
const VERSION = "v0.15.5 试玩版"
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
const SPEAKER = {"turtle": "老龟", "gelaosan": "葛老三", "heroine": ""}
const ICON = {"herb_qingzhi": "ico_qingzhi", "herb_hantanlian": "ico_lian", "seed_lianzi": "ico_lian", "herb_chiyangguo": "ico_guo",
	"pill_juqi": "ico_juqi", "pill_zhuji": "ico_zhuji", "pill_quzhang": "ico_g_hulu", "fu_bishui": "ico_fu", "fu_jingshui": "ico_g_fu_jiu",
	"fu_dingfeng_can": "ico_g_fu_can", "herb_xugucao": "ico_qingzhi", "crop_linggu": "ico_ration", "lingshi": "ico_lingshi", "ration": "ico_ration"}
# v0.14.3 器物图标（按原型；没有的按 items.json 里的 icon 键）
const GICON = {"剑": "ico_g_jian", "飞剑": "ico_g_feijian", "伞": "ico_g_san", "铃": "ico_g_ling", "印": "ico_g_yin",
	"道袍": "ico_g_pao", "软甲": "ico_g_jia", "玉佩": "ico_g_pei", "簪": "ico_g_zan", "戒": "ico_g_jie",
	"护身符": "ico_g_fu_huang", "静心符": "ico_g_fu_lan", "布囊": "ico_g_nang", "储物袋": "ico_g_dai", "储物戒": "ico_g_lingjie",
	"芥子镯": "ico_g_zhuo", "天外陨铁": "ico_g_tie", "雷击木": "ico_g_leimu", "妖丹": "ico_g_yaodan"}
const GICON_KEY = {"剑": "ico_g_jian", "伞": "ico_g_san", "铃": "ico_g_ling", "印": "ico_g_yin", "袍": "ico_g_pao", "甲": "ico_g_jia",
	"佩": "ico_g_pei", "簪": "ico_g_zan", "戒": "ico_g_jie", "符": "ico_g_fu_huang", "囊": "ico_g_nang", "袋": "ico_g_dai",
	"镯": "ico_g_zhuo", "材": "ico_g_tie", "丹": "ico_juqi"}
# 路线图上的路标位置（相对插画 0..1）
const MAP_POS = {
	"houshan": {"_start": Vector2(0.47, 0.88), "H1": Vector2(0.42, 0.63), "H2a": Vector2(0.17, 0.52), "H2b": Vector2(0.80, 0.72),
		"Hstar": Vector2(0.70, 0.15), "H3": Vector2(0.47, 0.30), "H4a": Vector2(0.76, 0.47), "H4b": Vector2(0.24, 0.36), "H5": Vector2(0.60, 0.07)},
	"hantan": {"_start": Vector2(0.50, 0.95), "T1": Vector2(0.42, 0.83), "T2": Vector2(0.18, 0.70), "T3a": Vector2(0.40, 0.62), "T3b": Vector2(0.52, 0.45),
		"Tpath": Vector2(0.70, 0.31), "T4": Vector2(0.47, 0.21), "T5": Vector2(0.22, 0.09), "T6": Vector2(0.82, 0.46), "T7": Vector2(0.86, 0.24),
		"T8": Vector2(0.76, 0.68), "T9": Vector2(0.80, 0.90)},
}
# 青庐庭院热点（courtyard.webp）
const HOT = {"field": Vector2(0.27, 0.69), "furnace": Vector2(0.82, 0.69), "room": Vector2(0.62, 0.46), "zao": Vector2(0.20, 0.47)}

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
var new_game_seed := -1   # 新游戏的世界种子；-1 = 按时间随机（玩家）。tests/play_random.gd 设成固定值，让乱点试玩每次跑出同一局
var person_id = 0       # 江湖：正在看的人物卡
var person_tab = "life" # life | rel | mem
var life_all = false    # 生平：是否展开更早的月份
var screen = "title"     # title | create | game
var tab = "home"         # home | depart | cult | log | jianghu
var modal: Dictionary = {}
var sheet = ""           # 底部抽屉：field | furnace | zao | pack | stats | ""
var create_name = "苏青禾"
var create_cherish = "sect"
var selected_route = "houshan"
var sel_place = ""       # v0.11 世界图上点开的地方
var dev_roam_pl := "坊市"  # 调试：roam:<地名> 在哪处游历
var preset_save_mode = false
var item_u := -1          # v0.14：器物抽屉看的是哪一件（她的东西按 u；店里的按 u + shop 标记）
var item_shop := false
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
var btn_cb = null
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
const LAZY_BG = ["bg_chasi", "bg_shandao", "bg_fangshi", "bg_yeyu", "bg_dongfu", "bg_leitai", "map_world",
	"pl_houshan", "pl_fangshi", "pl_hantan", "pl_yaowang", "pl_qingyun", "pl_yunmeng", "pl_xuanshuang", "pl_luoxia", "pl_wanjian", "pl_guzhan", "pl_mijing", "pl_xuesha"]
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

## v0.12.1 避头尾（禁则）：玩家版用的是 fallback 文字服务（无 ICU），中文只能在宽度到了的那个字断行，
## 于是“。”会单独掉到下一行。做法：在汉字之间插零宽空格（U+200B）当断点，但标点前、开括号后不插——
## 句号就和前一个字绑在一起，行尾放不下时连前一个字一起拉到下一行。只用于会自动换行的正文 Label。
const ZW := "\u200b"
const NO_START := "，。、；：？！）」』》〉】”’…—·％,.;:?!)]%~"
const NO_END := "（「『《〈【“‘([(·"   # v0.14：“·”起头的条目，点和第一个字粘在一起（原先改成任意处折行，句号会掉到行首）

static func kt(t: String) -> String:
	if t.length() < 2:
		return t
	var out := ""
	var prev := ""
	for i in t.length():
		var c := t[i]
		if prev != "" and prev != "\n" and c != "\n" and prev != " " and c != " " and c != ZW and prev != ZW:
			var wide := prev.unicode_at(0) >= 0x2E80 or c.unicode_at(0) >= 0x2E80
			if wide and not NO_START.contains(c) and not NO_END.contains(prev):
				out += ZW
		out += c
		prev = c
	return out

func L(text: String, size: int = 16, color: Color = C_TEXT, parent: Node = null) -> Label:
	size = maxi(size, MIN_FONT)
	var l = Label.new()
	var par: Node = parent if parent else body
	l.autowrap_mode = TextServer.AUTOWRAP_OFF if par is HBoxContainer else TextServer.AUTOWRAP_WORD_SMART
	l.text = text if par is HBoxContainer else kt(text)
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

## 器物的图标名（GICON → 消耗品 ICON → items.json 的 icon 键）
func gear_icon(it: Dictionary) -> String:
	var pid := String(it.get("p", ""))
	if GICON.has(pid):
		return GICON[pid]
	if ICON.has(pid):
		return ICON[pid]
	return GICON_KEY.get(String(Gear.prop(pid, "icon", "")), "ico_fu")

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
	if not place_look.is_empty():
		p.add_theme_stylebox_override("panel", _place_card_sb(place_look))
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
	if after[2] == "feisheng" and before[2] == "":
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
	g.notice(line)   # v0.14.2：履历由规则层在当月记（game_state._lq_chron），这里只提示
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
		# v0.13：只读的“屏上按钮表”（文字 + 位置），玩家版也有——发布前/上线后用无头浏览器点一遍玩家版（不改任何状态）
		# Godot 的 JS 回调不能直接返回值：写到 window.qinglu_btns_out 上
		btn_cb = JavaScriptBridge.create_callback(func(_a): w.qinglu_btns_out = _btn_table())
		w.qinglu_btns = btn_cb
		# 调试钩子只在调试导出里有（截图/验收用）；玩家版（release 导出）没有
		if OS.is_debug_build():
			dev_cb = JavaScriptBridge.create_callback(func(a): return _dev(String(a[0]) if a.size() > 0 else ""))
			w.qinglu_dev = dev_cb
		JavaScriptBridge.eval("""
			document.addEventListener('visibilitychange', function(){ if (document.visibilityState==='hidden' && window.qinglu_save) window.qinglu_save(); });
			window.addEventListener('pagehide', function(){ if (window.qinglu_save) window.qinglu_save(); });
		""", true)

func _btn_table() -> String:
	var out := []
	var labs := []
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var st := [self as Node]
	while not st.is_empty():
		var n: Node = st.pop_back()
		for ch in n.get_children():
			st.append(ch)
		if n is BaseButton and (n as BaseButton).is_visible_in_tree() and not (n as BaseButton).disabled:
			var r: Rect2 = (n as Control).get_global_rect()
			var tx := String((n as Button).text) if n is Button else ""
			out.append([tx, r.position.x + r.size.x / 2.0, r.position.y + r.size.y / 2.0])
		elif n is Label and (n as Label).is_visible_in_tree() and labs.size() < 200:
			labs.append(String((n as Label).text).replace(ZW, "").left(24))   # v0.15.2：只读，给 release_check 认小标题（托售、聚灵阵……）
	return JSON.stringify({"w": vs.x, "h": vs.y, "b": out, "l": labs})

func _continue(from_legacy: bool = false) -> void:
	var d = (legacy if from_legacy else store).load_data()
	if d == null or not g.from_dict(d["state"]):
		modal = {"kind": "msg", "text": "这份存档这一版还读不了（可能是更新版本存的）。存档原样留着，没有删，也没有改。"}
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
	g.new_game(create_name if create_name.strip_edges() != "" else "苏青禾", create_cherish, new_game_seed, true)
	g.s["portrait"] = create_portrait.duplicate(true) if not create_portrait.is_empty() else _hero_roll("p%d" % randi())
	play_ms_base = 0
	session_start = Time.get_ticks_msec()
	screen = "game"
	tab = "home"
	g.s["guide"] = {"seen": {}, "off": false}   # 新手提示只给新开的局；旧档/迁移来的档没有这个键，不显示
	modal = {"kind": "msg", "portrait": "gelaosan", "title": "葛老三", "text": "坊市的葛老三把一串铜钥匙和一本发黄的手记交到她手里：“青庐的前任洞主走了好些年，路都记在这本子上。租钱一年一结。”\n“辟谷丹我按月给你补上——别饿死在山里，我收不着钱。”"}



# ------------------------------------------------------------ 刷新
func refresh() -> void:
	_story_check()
	var key = "%s|%s|%s|%s|%s|%s|%s|%s" % [screen, tab, modal.get("kind", ""), g.s.get("loc", ""), g.s.get("trip", {}).get("stage", ""), String(g.s.get("trip", {}).get("node", "")), _story_key(), String(g.s.get("roam", {}).get("pl", "")) if g.s.get("loc", "") == "roam" else ""]
	var changed = key != scene_key
	var prev_key = scene_key
	scene_key = key
	if changed and key != beat_key:
		beat_i = 0
		beat_key = key
	_refresh()
	for n in [hud, body, footer, sheet_layer]:
		_fix_wraps(n)
	_bottom_pad.call_deferred()
	_set_bgm(_bgm_for_scene())
	if changed and not key.contains("|ending|"):
		_clear(fx_layer)   # 离开结局页时把还在飘的灵气粒子收掉
	if changed:
		ui.modulate = Color(1, 1, 1, 0.0)
		create_tween().tween_property(ui, "modulate:a", 1.0, 0.22)
		scroll.scroll_vertical = 0
		if g.s.get("ending", "") == "feisheng" and g.s.get("loc", "") == "ending" and not prev_key.contains("|ending|"):
			_fx_breakthrough()
	if OS.has_feature("web"):
		var w = JavaScriptBridge.get_interface("window")
		if w:
			w.qinglu_state = JSON.stringify({"screen": screen, "tab": tab, "modal": modal.get("kind", ""), "sheet": sheet, "loc": g.s.get("loc", ""), "day": g.s.get("day", -1), "lingshi": g.s.get("lingshi", 0), "stage": g.s.get("trip", {}).get("stage", ""), "node": g.s.get("trip", {}).get("node", ""), "rev": store.rev, "persistent": OS.is_userfs_persistent(), "conflict": store.conflict, "bgm": cur_bgm, "bgm_on": bgm_on, "muted": muted, "unlocked": audio_unlocked})

## v0.15（Gemini v7 P1）：正文滚得动、底下又压着常驻按钮时，正文末尾补 48px 留白，最后一行不被按钮挡住
func _bottom_pad() -> void:
	if body == null or footer == null or footer.get_child_count() == 0 or body.get_child_count() == 0:
		return
	var last := body.get_child(body.get_child_count() - 1)
	if last.has_meta("bottom_pad"):
		return
	if body.get_combined_minimum_size().y <= scroll.size.y + 1.0:
		return
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 48)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.set_meta("bottom_pad", true)
	body.add_child(pad)

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
		"roam":
			return "hantan" if String(g.s["roam"].get("pl", "")) in ["寒潭", "玄霜谷", "秘境", "古战场"] else "travel_houshan"
	return "home"

func _refresh() -> void:
	place_look = {}
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
	if g.s["loc"] == "roam":
		_roam()
		if sheet != "":
			_sheet()
		return
	if g.s["extra"] == "" and int(g.s["trips_done"]) >= 1:
		_extra_choice()
		return
	_guide()
	match tab:
		"home": _home()
		"depart": _depart()
		"cult": _cult()
		"log", "life": _log_tab()
		"pack": _pack_tab()
		"jianghu": _jianghu()
	_nav()
	if sheet != "":
		_sheet()

# ------------------------------------------------------------ 新手提示（《旧主手记》夹页）
## 只在新开的局、前 6 个月里出现；每张只出一次；“不必再提”就全关（设置里可再打开）。
const GUIDE = {
	"home": "这院子就是青庐。阳田种青芝，丹炉炼丹，静室闭关——点院里的地方就能打理。山中一月是一回合，修仙的日子要按年算。",
	"home2": "回来了就好。累了就闭关，采回的灵草放进丹炉。寿元按年减，炼气只有百年，别都耗在路上。",
	"depart": "这是山外的图。认得的地方点开就能去，“？”是只听过风声的。每处一月逛一个去处，看看谁在；后山、寒潭走着走着会碰上手记里写过的人和事。",
	"cult": "静室里闭关，一月一月把感悟炼成修为。一闭就是一年、十年也行，江湖照样在走。修为攒满，就能「冲关」：过了心魔那几问，才算筑基。",
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
	IC("ico_fu", 30, hr)
	H("旧主手记", 17, C_ACCENT, hr)
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
	var dl = H(World.cal_short(int(s["day"])), 16, C_ACCENT, r)
	dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var mid = VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 1)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(mid)
	# v0.13 顶栏：境界 · 感悟；进度条；年岁/寿限（Gemini 评审 P1#10.2）
	L("%s · 悟 %d" % [g.realm_text(), int(s["ganwu"])], 12, C_TEXT, mid)
	# 进度条：炼气只看这一层（每层 1/9 修为）；筑基以后看这一小境界
	var pb = ProgressBar.new()
	if int(s.get("plv", 0)) >= 9:
		pb.max_value = g.xw_goal()
		pb.value = mini(int(s["xiuwei"]), g.xw_goal())
	else:
		var per := float(GS.XW_GOAL) / 9.0
		pb.max_value = per
		pb.value = per if int(s["xiuwei"]) >= GS.XW_GOAL else float(int(s["xiuwei"])) - per * (g.layer() - 1)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 7)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(pb)
	var lim: int = g.shou_limit_y()   # v0.15：寿元上限按“出生月 + 寿元月”整除，不再用两次取整相加（99/100 横跳）
	L("%s · %d/%d岁" % [World.season(int(s["day"])), g.age_y(), lim], 11, C_WARN if int(g.shou_years()) * 5 < lim else C_DIM, mid)
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
	# v0.13（Gemini 评审 P1#10.1）：青庐 / 历练 / 行囊 / 江湖 / 生平；修炼并进青庐的静室（点院里的静室），行记改名生平
	var tabs = [["home", "青庐", "ico_qingzhi"], ["depart", "历练", "ico_ration"], ["pack", "行囊", "ico_fu"], ["life", "生平", "ico_zhuji"]]
	if g.world != null:
		tabs.insert(3, ["jianghu", "江湖", "ico_lingshi"])
	var cur: String = "home" if tab == "cult" else ("life" if tab == "log" else tab)
	for t in tabs:
		# 选中的页签：底色 + 主色字；字色在 normal/hover/pressed/focus 都设上——
		# 以前只设了 normal，手机上点完按钮停在 focus/hover，字就变回默认色（“选中页签字不对”的毛病）
		var b = BI(t[1], t[2], func(): tab = t[0]; sheet = "", true, r, 46)
		if cur == t[0]:
			# v0.12.1：选中态每个状态都给定底色与字色——手机上点过之后按钮停在 hover/focus；且底色要不透明（Gemini v5 P1#10.5）
			# 底色不能透：历练页底下是深色地图，原来 16% 的主色底透出地图，主色字就看不见了
			var tsb = _sb(Color("#F6F0E2").lerp(C_ACCENT, 0.14), C_ACCENT, 8, 2, 4)
			for stn in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
				b.add_theme_stylebox_override(stn, tsb)
			for fcn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
				b.add_theme_color_override(fcn, C_ACCENT)
		else:
			# v0.13 修：没选中的页签用默认底框，左右内边距大，五个页签时“青庐”被挤成竖排两行（截图里看到的）；
			# 这里把左右内边距收到 4，跟选中的一致，并且不许折行
			for st in ["normal", "hover", "pressed", "focus", "disabled"]:
				var sb0 = b.get_theme_stylebox(st)
				if sb0 != null:
					var sb1 = sb0.duplicate()
					sb1.content_margin_left = 4
					sb1.content_margin_right = 4
					b.add_theme_stylebox_override(st, sb1)
		b.add_theme_font_size_override("font_size", 13 if tabs.size() > 4 else 14)
		if tabs.size() > 4:
			b.add_theme_constant_override("h_separation", 1)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 20)
		# v0.12.1：页签名只有两个字，不许折行（未选中的页签默认边距大，“青庐”会被挤成上下两行）
		b.autowrap_mode = TextServer.AUTOWRAP_OFF

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
	var tl = {"field": "田", "furnace": "丹炉 · 仓", "zao": "灶间 · 旧主手记", "pack": "行囊", "stats": "近况", "place": sel_place, "goto": "去别处", "item": "器物", "shop": "坊市 · 器物铺", "auc": "坊市 · 拍卖会", "yao": "坊市 · 药铺", "jobs": "坊市 · 差事榜"}.get(sheet, "")
	var ht = H(tl, 24, C_ACCENT, top)
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cb = B("收起", func(): sheet = "", true, top, 34)
	cb.size_flags_horizontal = Control.SIZE_SHRINK_END
	cb.custom_minimum_size = Vector2(64, MIN_TAP)
	cb.add_theme_font_size_override("font_size", 13)
	match sheet:
		"field": _sheet_field(v)
		"furnace": _sheet_furnace(v)
		"zao": _sheet_zao(v)
		"pack": _sheet_pack(v)
		"stats": _sheet_stats(v)
		"place": _sheet_place(v)
		"goto": _sheet_goto(v)
		"item": _sheet_item(v)
		"shop": _sheet_shop(v)
		"auc": _sheet_auc(v)
		"yao": _sheet_yao(v)
		"jobs": _sheet_jobs(v)
	var vs = get_viewport_rect().size
	p.size = Vector2(vs.x, 0)
	p.reset_size()
	var h = max(p.get_combined_minimum_size().y, 120)
	# v0.15：抽屉比屏幕高（器物铺两行货、药铺）就改成能滚，标题和“收起”不滚
	var hmax: float = vs.y * 0.88
	if h > hmax:
		var sc = ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var inner = VBoxContainer.new()
		inner.add_theme_constant_override("separation", 8)
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kids: Array = v.get_children()
		for k in range(1, kids.size()):
			v.remove_child(kids[k])
			inner.add_child(kids[k])
		var pad = Control.new()
		pad.custom_minimum_size = Vector2(0, 24)
		inner.add_child(pad)
		sc.add_child(inner)
		sc.custom_minimum_size = Vector2(0, hmax - top.get_combined_minimum_size().y - 40)
		v.add_child(sc)
		p.size = Vector2(vs.x, 0)
		p.reset_size()
		h = p.get_combined_minimum_size().y
	p.position = Vector2(0, vs.y - h)
	p.size = Vector2(vs.x, h)
	var tw: Tween = null
	if not sheet_layer.has_meta("open") or sheet_layer.get_meta("open") != sheet:
		sheet_layer.set_meta("open", sheet)
		p.position.y = vs.y
		tw = p.create_tween()
		tw.tween_property(p, "position:y", vs.y - h, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# 换行字要排过一帧才知道真实行数：下一帧按真实高度再贴一次底
	var pref = weakref(p)
	get_tree().process_frame.connect(func():
		var p2 = pref.get_ref()
		if p2 == null or not is_instance_valid(p2):
			return
		_refit_sheet(p2, tw, vs)
	, CONNECT_ONE_SHOT)

func _refit_sheet(p: PanelContainer, tw: Tween, vs: Vector2) -> void:
	var h2: float = minf(maxf(p.get_combined_minimum_size().y, 120.0), vs.y * 0.9)
	if absf(h2 - p.size.y) < 1.0:
		return
	p.size = Vector2(vs.x, h2)
	if tw != null and tw.is_valid():
		tw.kill()
		p.create_tween().tween_property(p, "position:y", vs.y - h2, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		p.position.y = vs.y - h2

func _queue_text() -> String:
	if g.s["queue"].is_empty():
		return "空"
	var parts = []
	for q in g.s["queue"]:
		parts.append("%s(%d月)" % [GS.RECIPES[q[0]]["name"], int(q[1])])
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
	L("每块阳田 6 个月一熟，收青芝 2 株，自动入仓。", 13, C_DIM, v)
	if g.can_plant_lianzi():
		BI("水田种下寒潭莲子（20 个月）", "ico_lian", func(): g.plant_lianzi(), true, v)
	if s["extra"] != "":
		var rb: String = g.can_rebuild_extra()
		var bb = B("改建第 5 点 → %s（1 个月 · 10 灵石）%s" % ["水田" if s["extra"] == "field" else "第三块阳田", "" if rb == "" else "（" + rb + "）"], func(): g.rebuild_extra(), rb == "", v, 36)
		bb.add_theme_font_size_override("font_size", 13)

func _sheet_furnace(v: Node) -> void:
	var s = g.s
	if Jobs.furnace_busy(g):
		LW(Jobs.comm_text(g), 12, C_WARN, v)
	var qr = row(v, 6)
	if s["queue"].is_empty():
		L("炉火未起。", 14, C_DIM, qr)
	for i in s["queue"].size():
		var q = s["queue"][i]
		var rc = GS.RECIPES[q[0]]
		var total = rc["days"] if not (q[0] == "zhuji" and s["zhuji_second"]) else GS.ZHUJI_SECOND_DAYS
		ring(qr, total - int(q[1]), total, 50, C_GOLD, "%d月" % int(q[1]), rc["name"].substr(0, 2))
	var r = row(v, 6)
	for k in ["juqi", "quzhang", "zhuji"]:
		var why: String = g.can_enqueue(k)
		var rc = GS.RECIPES[k]
		var b = BI("%s\n%d青芝·%d月" % [rc["name"], rc["qz"], rc["days"] if not (k == "zhuji" and s["zhuji_second"]) else 3], ICON[rc["out"]], func(): g.enqueue(k), why == "", r, 54)
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

func _sheet_zao(v: Node) -> void:
	var r = row(v, 10)
	IC("ico_fu", 72, r)
	var lines = ["手记上写：“丹炉别空着，青芝放久了也是放。”", "手记上写：“出门前，辟谷丹多带两颗。”", "手记上写：“闭关前，把田种上。”", "手记上写：“寒潭的老龟记仇，别招它。”"]
	var t = L(lines[int(g.s["day"]) % lines.size()], 15, C_TEXT, r)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if g.gelaosan_fruit_available():
		BI("托葛老三捎一颗赤阳果（−20 灵石）", "ico_guo", func(): g.buy_gelaosan_fruit(), g.s["lingshi"] >= 20, v)
	var mem = g.s["memory"]
	if not mem.is_empty():
		var m = mem[-1]
		L("%s记得：%s" % [m["npc"], m["text"]], 13, C_DIM, v)

## v0.13 行囊页：随身行囊 + 仓里的东西（v0.14 加储物袋、本命法器/法衣/佩饰/功法四格）
func _pack_tab() -> void:
	_stage_image("bg_home", 0.72)
	H("行囊", 24)
	_equip_panel(card())
	var c = card()
	_sheet_pack(c)
	_gear_lists(c)
	H("青庐仓里", 20)
	var c2 = card()
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	c2.add_child(grid)
	var n := 0
	for id in g.s["store"]:
		if int(g.s["store"][id]) <= 0:
			continue
		n += 1
		var cell = VBoxContainer.new()
		cell.custom_minimum_size = Vector2(80, 0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		grid.add_child(cell)
		var ic = IC(ICON.get(id, "ico_fu"), 30, cell)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		# v0.14 修：名字一行、数量一行，都不折行（原先“避水符×1”会把“1”挤到下一行）
		for t in [N(id), "×%d" % int(g.s["store"][id])]:
			var nl = L(t, 12, C_TEXT if t == N(id) else C_DIM, cell)
			nl.autowrap_mode = TextServer.AUTOWRAP_OFF
			nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if n == 0:
		L("（空）", 13, C_DIM, c2)

const SLOT_LEFT := ["fabao", "yi", "dai"]
const SLOT_RIGHT := ["shi", "shi2", "fu"]
const SLOT_ICON = {"fabao": "ico_g_jian", "yi": "ico_g_pao", "dai": "ico_g_nang", "shi": "ico_g_pei", "shi2": "ico_g_zan", "fu": "ico_g_fu_huang"}
## v0.14 装备：中间她的半身像，左右各三个槽
func _equip_panel(v: Node) -> void:
	var r = row(v, 6)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	var vs = get_viewport_rect().size
	var pw := clampf(vs.x * 0.36, 110, 150)
	for side in [SLOT_LEFT, null, SLOT_RIGHT]:
		if side == null:
			if g.s.get("portrait", {}) is Dictionary and not g.s.get("portrait", {}).is_empty():
				var pf = _portrait_frame(g.s["portrait"], Vector2(pw, pw * 4.0 / 3.0), r)
				pf.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			continue
		var col = VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 6)
		r.add_child(col)
		for sl in side:
			var it = Gear.eq(g, sl)
			var t := "%s\n%s" % [Gear.SLOT_NAME[sl], "—" if it == null else Gear.full_name(it)]
			var uu := -1 if it == null else int(it["u"])
			var b = BI(t, SLOT_ICON[sl] if it == null else gear_icon(it), func(): item_u = uu; item_shop = false; sheet = "item", it != null, col, 56)
			b.add_theme_constant_override("icon_max_width", 30)
			b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.22))
			b.autowrap_mode = TextServer.AUTOWRAP_OFF
			b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			b.add_theme_font_size_override("font_size", 12)
			if it != null:
				b.add_theme_color_override("font_color", Color(Gear.GCOL[int(it["g"])]))
	var st = L(Gear.her_summary(g) + " · 负重 %s/%s 斤" % [str(Gear.load_w(g)), str(Gear.wcap(g))], 12, C_DIM, v)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

## 随身与洞府里的器物（点开看详情、装上 / 带上 / 放回）
func _gear_lists(v: Node) -> void:
	for where in ["bag", "home"]:
		var lst: Array = g.s["gear"][where]
		if lst.is_empty():
			continue
		L("随身器物" if where == "bag" else "洞府里的器物", 13, C_ACCENT, v)
		var grid = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		v.add_child(grid)
		for it in lst:
			var uu := int(it["u"])
			var b = BI("%s · %s" % [Gear.full_name(it), Gear.grade_name(it)], gear_icon(it), func(): item_u = uu; item_shop = false; sheet = "item", true, grid, 40)
			b.autowrap_mode = TextServer.AUTOWRAP_OFF
			b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			b.add_theme_font_size_override("font_size", 13)
			b.add_theme_color_override("font_color", Color(Gear.GCOL[int(it["g"])]))

func _sheet_pack(v: Node) -> void:
	var s = g.s
	var cap: int = Gear.cells(g)
	L("随身 %d/%d 格 · 点格子放回仓" % [s["pack"].size(), cap], 12, C_DIM, v)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for i in maxi(cap, s["pack"].size()):
		if i < s["pack"].size():
			var sl = s["pack"][i]
			var idx = i
			# v0.14 修：名字一行、数量一行，不折行
			var b = BI("%s%s\n×%d" % ["◎" if sl["key"] else "", N(sl["id"]), int(sl["n"])], ICON.get(sl["id"], "ico_fu"), func(): g.pack_take(idx), true, grid, 46)
			b.autowrap_mode = TextServer.AUTOWRAP_OFF
			b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			b.add_theme_font_size_override("font_size", 12)
		else:
			var e = B("空", func(): pass, false, grid, 46)
			e.add_theme_font_size_override("font_size", 12)
	var rr2 = row(v, 4)
	for id in ["pill_juqi", "fu_bishui", "fu_jingshui", "pill_quzhang"]:
		if g.store_n(id) > 0:
			var b2 = BI("带%s" % N(id), ICON[id], func(): g.pack_put(id, id == "pill_juqi"), s["pack"].size() < cap or g.pack_n(id) > 0, rr2, 38)
			b2.autowrap_mode = TextServer.AUTOWRAP_OFF
			b2.add_theme_font_size_override("font_size", 12)
	if s["pack"].size() > 0:
		# v0.14 修：原先一排“◎1 ◎2”没有说明；改成带字的一行
		var rr3 = row(v, 4)
		var kl = L("◎ 留到最后才用：", 12, C_DIM, rr3)
		kl.autowrap_mode = TextServer.AUTOWRAP_OFF
		for i in s["pack"].size():
			var idx = i
			var b3 = B("%s%d" % ["◎" if s["pack"][i]["key"] else "", i + 1], func(): g.toggle_key(idx), true, rr3, 30)
			b3.custom_minimum_size.x = 44
			b3.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			b3.add_theme_font_size_override("font_size", 12)
	L("随身预设（出门前一键换装）", 12, C_DIM, v)
	var pr = row(v, 4)
	var presets: Array = s.get("presets", [{}, {}, {}])
	for k in 3:
		var kk = k
		var has: bool = not presets[k].is_empty()
		# v0.14 修：原先“存入方案1/2/3 + 存…”四个宽按钮挤在一行，最后一个被截成“存…”；改成三四个字
		var lab = ("存到%s" if (preset_save_mode or not has) else "方案%s") % ["一", "二", "三"][k]
		var pb = B(lab, func(): _preset(kk), true, pr, 34)
		pb.autowrap_mode = TextServer.AUTOWRAP_OFF
		pb.add_theme_font_size_override("font_size", 13)
	var sm = B("不存了" if preset_save_mode else "保存当前", func(): preset_save_mode = not preset_save_mode, presets.any(func(x): return not x.is_empty()), pr, 34)
	sm.autowrap_mode = TextServer.AUTOWRAP_OFF
	sm.add_theme_font_size_override("font_size", 13)

## v0.14 器物抽屉：名字（品阶色）、数值、来历；装上 / 卸下 / 带上 / 放回 / 卖 / 修
func _sheet_item(v: Node) -> void:
	var it = null
	var where := ""
	var csg := {}
	if item_shop:
		for x in Gear.shop(g):
			if int(x["u"]) == item_u:
				it = x
		where = "shop"
		csg = Econ.consign_find(g, item_u)
		if it == null and not csg.is_empty():
			it = csg["it"]
			where = "consign"
	else:
		var f: Array = Gear.find(g, item_u)
		if not f.is_empty():
			it = f[2]
			where = String(f[0])
	if it == null:
		L("（这件已经不在了）", 13, C_DIM, v)
		return
	var day := int(g.s["day"])
	var hr = row(v, 10)
	var gc := Color(Gear.GCOL[int(it["g"])])
	var fr = PanelContainer.new()
	fr.add_theme_stylebox_override("panel", _sb(Color(gc, 0.10), Color(gc, 0.75), 8, 2, 4))
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hr.add_child(fr)
	IC(gear_icon(it), 64, fr)
	var hv = VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hr.add_child(hv)
	var hl = L(Gear.full_name(it), 22, gc, hv)
	hl.autowrap_mode = TextServer.AUTOWRAP_OFF
	hl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var meta := "%s · %s %s" % [Gear.grade_name(it), Gear.SLOT_NAME.get(Gear.slot_of(it), "灵材"), Gear.suffix_text(it)]
	LW(meta, 13, C_DIM, hv)
	var stx: String = Gear.stat_text(it)
	if stx != "":
		LW(stx, 14, C_TEXT, v)
	if not Gear.usable(g, it):
		L("（境界不够，祭不动；可以先收着）", 12, C_WARN, v)
	L("%s · 重 %s 斤 · 耐久 %d · 行情价约 %d 灵石" % [String(Gear.prop(String(it["p"]), "desc", "")), str(Gear.weight(it)), int(it.get("dur", 100)), roundi(Gear.value(it, day) * Gear.price_idx(day))], 12, C_DIM, v)
	var hs: Array = it.get("h", [])
	for e in hs.slice(maxi(0, hs.size() - 4)):
		LW("%s · %s" % [World.cal_text(maxi(1, int(e[0]))), String(e[1])], 12, C_TEXT, v)
	var r = row(v, 6)
	var at_fs: bool = String(g.s.get("loc", "")) == "roam" and String(g.s.get("roam", {}).get("pl", "")) == "坊市"
	var uu := int(it["u"])
	var act = func(fn: Callable):
		var msg: String = fn.call()
		if msg != "":
			g.notice(msg)
	if where == "consign":
		var cp := int(csg["price"])
		LW("%s托售，两年内有效（到%s）。" % [String(csg["from"]), World.cal_text(int(csg["until"]))], 12, C_DIM, v)
		B("接下（%d 灵石）" % cp, func(): act.call(func(): return Econ.consign_buy(g, uu)); sheet = "shop", int(g.s["lingshi"]) >= cp, r, 42)
		B("回铺子", func(): sheet = "shop", true, r, 42)
		return
	if where == "shop":
		var pr: int = Gear.buy_price(it, day)
		B("买下（%d 灵石）" % pr, func(): act.call(func(): return Gear.shop_buy(g, uu)); sheet = "shop", int(g.s["lingshi"]) >= pr, r, 42)
		B("回铺子", func(): sheet = "shop", true, r, 42)
		return
	if where == "eq":
		B("卸下", func(): act.call(func(): return Gear.unequip(g, uu)), Gear.slot_of(it) != "dai", r, 42)
	elif Gear.slot_of(it) != "":
		B("装上", func(): act.call(func(): return Gear.equip(g, uu)), Gear.usable(g, it), r, 42)
	if where == "home":
		B("带上", func(): act.call(func(): return Gear.carry(g, uu)), true, r, 42)
	elif where == "bag" and g.at_home():
		B("放回洞府", func(): act.call(func(): return Gear.stash(g, uu)), true, r, 42)
	if at_fs and where != "home":
		var r2 = row(v, 6)
		B("卖（%d 灵石）" % Gear.sell_price(g, it, day), func(): act.call(func(): return Gear.sell(g, uu)); sheet = "shop", not (where == "eq" and Gear.slot_of(it) == "dai"), r2, 42)
		if int(it.get("dur", 100)) < 100:
			B("修（%d 灵石）" % Gear.repair_cost(it), func(): act.call(func(): return Gear.repair(g, uu)), int(g.s["lingshi"]) >= Gear.repair_cost(it), r2, 42)

## v0.14 坊市器物铺：一年换一回货；行情每月不同；卖得多了收价往下走
func _sheet_shop(v: Node) -> void:
	var day := int(g.s["day"])
	L("这个月行情：%s（×%s）· 手里 %d 灵石" % [Gear.idx_text(day), str(Gear.price_idx(day)), int(g.s["lingshi"])], 12, C_DIM, v)
	var st: Array = Gear.shop(g)
	if st.is_empty():
		L("货架空了，开春再来。", 13, C_DIM, v)
	# v0.15（Gemini v7 P1）：两行——名字 · 品阶（部位） · 价；下一行小灰字写数值，买之前看得见
	for it in st:
		var uu := int(it["u"])
		var b = BI("%s · %s（%s） · %d 灵石" % [Gear.full_name(it), Gear.grade_name(it), Gear.SLOT_NAME.get(Gear.slot_of(it), "灵材"), Gear.buy_price(it, day)], gear_icon(it), func(): item_u = uu; item_shop = true; sheet = "item", true, v, 40)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", Color(Gear.GCOL[int(it["g"])]))
		_stat_line(it, v)
	var cs: Array = Econ.consign_list(g)
	L("托售（熟人用不上的，五折）" + ("" if not cs.is_empty() else "（眼下没有）"), 13, C_ACCENT, v)
	if not cs.is_empty():
		for x in cs:
			var it2: Dictionary = x["it"]
			var u2 := int(it2["u"])
			var b3 = BI("%s · %s（%s） · %d 灵石" % [Gear.full_name(it2), Gear.grade_name(it2), String(x["from"]), int(x["price"])], gear_icon(it2), func(): item_u = u2; item_shop = true; sheet = "item", true, v, 40)
			b3.autowrap_mode = TextServer.AUTOWRAP_OFF
			b3.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			b3.add_theme_font_size_override("font_size", 13)
			b3.add_theme_color_override("font_color", Color(Gear.GCOL[int(it2["g"])]))
			_stat_line(it2, v)
	var mine: Array = Gear.equipped(g).filter(func(x): return Gear.slot_of(x) != "dai")
	mine.append_array(g.s["gear"]["bag"])
	if not mine.is_empty():
		L("卖 / 修（随身的）", 13, C_ACCENT, v)
		var grid = GridContainer.new()
		grid.columns = 2
		v.add_child(grid)
		for it in mine:
			var uu := int(it["u"])
			var b2 = BI("%s · 收 %d" % [Gear.full_name(it), Gear.sell_price(g, it, day)], gear_icon(it), func(): item_u = uu; item_shop = false; sheet = "item", true, grid, 38)
			b2.autowrap_mode = TextServer.AUTOWRAP_OFF
			b2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			b2.add_theme_font_size_override("font_size", 12)
	if Gear.auction_month(day):
		B("这个月有拍卖会 →", func(): sheet = "auc", true, v, 40)

func _stat_line(it: Dictionary, v: Node) -> void:
	var stx: String = Gear.stat_text(it)
	if not Gear.usable(g, it):
		stx += ("（" if stx != "" else "") + "境界不够，祭不动" + ("）" if stx != "" else "")
	if stx == "":
		return
	var sl = L("      " + stx, 11, C_DIM, v)
	sl.autowrap_mode = TextServer.AUTOWRAP_OFF
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sl.custom_minimum_size.x = 1

## v0.15（Gemini v7 专项 1）：坊市药铺——卖青芝、卖丹、卖灵谷；主药保底（晒干赤阳果、冰鉴寒潭莲、旧货摊莲子）
func _sheet_yao(v: Node) -> void:
	var day := int(g.s["day"])
	L("这个月行情：%s · 手里 %d 灵石" % [Gear.idx_text(day), int(g.s["lingshi"])], 12, C_DIM, v)
	L("卖", 13, C_ACCENT, v)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	var sells := []
	sells.append(["青芝 10 株（%d 灵石）· 仓 %d" % [g.qz_sell_price(), g.store_n("herb_qingzhi")], "ico_qingzhi", func(): g.sell_qingzhi(), g.store_n("herb_qingzhi") >= 10])
	for id in ["pill_juqi", "pill_quzhang"]:
		var iid: String = id
		sells.append(["%s 1 颗（%d 灵石）· 仓 %d" % [N(iid), Econ.pill_price(g, iid), g.store_n(iid)], ICON.get(iid, "ico_fu"), func(): Econ.sell_pill(g, iid), g.store_n(iid) > 0])
	sells.append(["灵谷 %d 斗（%d 灵石）· 仓 %d" % [Econ.LINGGU_BATCH, Econ.linggu_price(g), g.store_n("crop_linggu")], ICON.get("crop_linggu", "ico_fu"), func(): Econ.sell_linggu(g), g.store_n("crop_linggu") >= Econ.LINGGU_BATCH])
	for x in sells:
		var b = BI(x[0], x[1], x[2], x[3], grid, 40)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.add_theme_font_size_override("font_size", 12)
	L("丹药一年收四颗按价，再多减半。仓里青芝、灵谷过了两百，多出来的每年陈掉一成。", 11, C_DIM, v)
	var buys := []
	if g.dry_chiyang_available():
		buys.append(["晒干的赤阳果（%d 灵石）" % g.DRY_CHIYANG_PRICE, "ico_guo", func(): g.buy_dry_chiyang(), int(g.s["lingshi"]) >= g.DRY_CHIYANG_PRICE])
	if Econ.ice_lian_available(g):
		buys.append(["冰鉴寒潭莲（%d 灵石）" % Econ.ICE_LIAN_PRICE, "ico_lian", func(): Econ.buy_ice_lian(g), int(g.s["lingshi"]) >= Econ.ICE_LIAN_PRICE])
	if g.junk_lianzi_available():
		buys.append(["旧货摊：寒潭莲子（%d 灵石，要水田）" % g.JUNK_LIANZI_PRICE, "ico_lian", func(): g.buy_junk_lianzi(), int(g.s["lingshi"]) >= g.JUNK_LIANZI_PRICE])
	if not buys.is_empty():
		L("买（筑基主药，一年各一回）", 13, C_ACCENT, v)
		for x in buys:
			var b2 = BI(x[0], x[1], x[2], x[3], v, 40)
			b2.autowrap_mode = TextServer.AUTOWRAP_OFF
			b2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			b2.add_theme_font_size_override("font_size", 13)

## v0.15.2：坊市差事榜——代炼（占丹炉）、客卿（隔三年回来坐镇）、悬赏（离家两个月，有伤）
func _sheet_jobs(v: Node) -> void:
	var e: Dictionary = Jobs.E(g)
	L("坊市名声 %d · 手里 %d 灵石" % [int(e["rep"]), int(g.s["lingshi"])], 12, C_DIM, v)
	var c1 = card(v)
	L("代炼", 14, C_ACCENT, c1)
	LW("药铺出主料，她搭 %d 株青芝、先付 %d 灵石地火钱；丹炉一单占 %d 个月，这期间自家的丹停炉。约 %d%% 炸炉，要赔三成料钱。" % [Jobs.COMM_QZ, int(Jobs.COMM_FUEL[clampi(g.major(), 1, 4)]), Jobs.COMM_MONTHS, Jobs.comm_fail_pct(g)], 11, C_DIM, c1)
	if Jobs.furnace_busy(g):
		LW(Jobs.comm_text(g), 11, C_WARN, c1)
	var w1: String = Jobs.can_comm(g)
	B("接一单代炼（成了 %d 灵石）" % Jobs.comm_pay(g) if w1 == "" else "接一单代炼：%s" % w1, func(): Jobs.take_comm(g), w1 == "", c1, 40)
	var c2 = card(v)
	L("客卿", 14, C_ACCENT, c2)
	LW(Jobs.kq_text(g), 11, C_DIM, c2)
	var w2: String = Jobs.can_kq(g)
	var kq_lb := "应下客卿（坐镇一个月）" if int(e["kq"]) < 0 else "回来坐镇一个月（领 %d 灵石）" % (Jobs.kq_due(g) * Jobs.kq_pay(g))
	B(kq_lb if w2 == "" else "客卿：%s" % w2, func(): sheet = ""; Jobs.sit_kq(g), w2 == "", c2, 40)
	var c3 = card(v)
	L("悬赏", 14, C_ACCENT, c3)
	var rg: Array = Jobs.bty_range(g) if g.major() >= 1 else Jobs.BTY[1]
	LW("离家两个月：除妖、护镖、拿贼，先花 %d 灵石备符箓干粮。赏 %d–%d 灵石（名声越高给得越多）；约四分之一带伤回来，偶尔重伤只拿一半。" % [int(Jobs.BTY_KIT[clampi(g.major(), 1, 4)]), int(rg[0]), int(rg[1])], 11, C_DIM, c3)
	var w3: String = Jobs.can_bty(g)
	B("揭一张悬赏（离开两个月）" if w3 == "" else "悬赏：%s" % w3, func(): sheet = ""; Jobs.take_bty(g), w3 == "", c3, 40)

func _auc_bid() -> void:
	var m: String = Gear.auction_bid(g)
	if m != "":
		g.notice(m)

func _sheet_auc(v: Node) -> void:
	var A: Dictionary = Gear.auction(g)
	if A.is_empty():
		L("拍卖会三月、九月才开。", 13, C_DIM, v)
		return
	var lot: Dictionary = A["lot"]
	if A.has("n"):
		L("%s · 第 %d / %d 件%s" % ["春拍 · 小拍" if Gear.auction_spring(int(g.s["day"])) else "秋拍 · 大拍", int(A["i"]), int(A["n"]), "（压轴）" if not Gear.auction_more(A) else ""], 12, C_DIM, v)
	var hl = L("%s · %s" % [lot["n"], Gear.grade_name(lot)], 20, Color(Gear.GCOL[int(lot["g"])]), v)
	hl.autowrap_mode = TextServer.AUTOWRAP_OFF
	LW(Gear.stat_text(lot) + "（%s）" % String(lot["h"][0][1]), 13, C_TEXT, v)
	for t in A["log"].slice(maxi(0, A["log"].size() - 5)):
		LW(String(t), 13, C_DIM, v)
	var r = row(v, 6)
	if A["done"]:
		if Gear.auction_more(A):
			B("下一件", func(): Gear.auction_next_lot(g), true, r, 42)
		B("散场", func(): sheet = "", true, r, 42)
		L("手里 %d 灵石" % int(g.s["lingshi"]), 12, C_DIM, v)
		return
	var nxt: int = Gear.auction_next(A) if int(A["lead"]) != 0 else int(A["price"])
	var lead_me: bool = int(A["lead"]) == -1
	B("举牌 %d" % nxt, func(): _auc_bid(), not lead_me and int(g.s["lingshi"]) >= nxt, r, 42)
	B("收手", func(): Gear.auction_pass(g), true, r, 42)
	L("手里 %d 灵石" % int(g.s["lingshi"]), 12, C_DIM, v)

func _sheet_stats(v: Node) -> void:
	var s = g.s
	var r = row(v, 10)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	ring(r, int(s["xiuwei"]), g.xw_goal(), 64, C_GOLD, str(int(s["xiuwei"])), "修为/%d" % g.xw_goal())
	ring(r, int(s["ganwu"]), GS.WU_SOFTCAP, 64, C_ACCENT, str(int(s["ganwu"])), "待炼化")
	ring(r, int(s["yuyun"]), GS.YUYUN_CAP, 64, Color("#8A6BA8"), str(int(s["yuyun"])), "余韵")
	ring(r, int(s["shouyuan"]), g.lifespan_m(), 64, C_WARN, str(g.shou_years()), "寿元/年")
	var st = []
	if int(s["injured"]) > 0:
		st.append("受伤 %d 个月" % int(s["injured"]))
	if int(s["unstable"]) > 0:
		st.append("心境不稳 %d 个月" % int(s["unstable"]))
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
			var cb = BI("继续 · %s · %s" % [safe_name(String(st.get("name", ""))), World.cal_short(int(st.get("day", 0)))], "ico_ration", _continue, true, footer, 60)
			cb.alignment = HORIZONTAL_ALIGNMENT_CENTER
			cb.add_theme_font_size_override("font_size", 18)
		else:
			L("存档读不出来（已保留原文件）。", 13, C_WARN, footer)
	elif legacy.exists():
		var ld = legacy.load_data()
		if ld != null:
			var lst = ld["state"]
			var lb = BI("继续 v0.5 旧档 · %s · %s" % [safe_name(String(lst.get("name", ""))), World.cal_short(int(lst.get("day", 0)))], "ico_ration", func(): _continue(true), true, footer, 60)
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
	for ch in [["sect", "山门", "ico_zhuji"], ["town", "小镇", "ico_ration"], ["book", "旧书", "ico_fu"]]:
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
	return g.world.portrait_spec(c)

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
		var total = tl.text.length()
		var last_len = total - kt("".join(shown.slice(maxi(0, shown.size() - 2), shown.size() - 1)) if shown.size() > 1 else "").length()
		tl.visible_characters = total - last_len
		if TEXT_CHAR_S[text_speed] <= 0.0:
			tl.visible_characters = -1
		else:
			var tw = tl.create_tween()
			tw.tween_property(tl, "visible_characters", total, last_len * TEXT_CHAR_S[text_speed])
			type_tw = tw
			type_label = tl
	if not done:
		var adv = B("▼", func(): pass, true, v, 44)
		# v0.13 修：B() 把回调包在 _press（240ms 防连点）里，_advance 翻页时又走一次 _press，第二次被防连点吞掉——
		# 结果点“▼”本身只能把字显完、永远翻不了页（点对话框别处可以）。这里直接接 _advance。
		for cn in adv.pressed.get_connections():
			adv.pressed.disconnect(cn["callable"])
		adv.pressed.connect(func(): _advance())
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
			L(["灶膛是冷的。她生了火，烧上一壶水。", "柴门吱呀一声。院里的青芝又长高了些。", "门槛上压着葛老三留的字条：辟谷丹补上了，租钱别忘。"][int(g.s["day"]) % 3], 15, C_TEXT, c)
			var bk: Dictionary = sm.get("basket", {})
			var ir = HFlowContainer.new()
			ir.add_theme_constant_override("h_separation", 6)
			c.add_child(ir)
			for id in bk:
				chip("%s ×%d" % [N(id), int(bk[id])], ir, ICON.get(id, ""), Color("#3E6B3A"))
			chip("辟谷丹 %d→%d" % [sm["ration_before"], sm["ration_after"]], ir, "ico_ration")
			if sm.get("turned_back", false):
				L("半路折返。", 13, C_DIM, c)
			if sm.has("roam"):
				L(String(sm["roam"]), 13, C_DIM, c)
			if sm.has("news"):
				var nw = card()
				H("山外", 20, C_ACCENT, nw)
				for t in sm["news"]:
					L("·" + String(t), 13, C_TEXT, nw)
			if sm.has("world"):
				var w = card()
				H("世事", 20, C_WARN, w)
				L(sm["world"], 14, C_TEXT, w)
			B("进屋", func(): modal = {}, true, footer, 52)
		"seclude":
			_stage_image("bg_biguan", 0.35)
			_spacer()
			var sq: Dictionary = modal["sum"]
			var c = card()
			H("出关", 26, C_ACCENT, c)
			L("闭关%s。入关时是%s，出关已是%s，%d 岁。" % [GS.span_text(int(sq["months"])), World.cal_text(int(sq["from"])), g.date_text(), g.age_y()], 15, C_TEXT, c)
			if String(sq["r0"]) != String(sq["r1"]):
				L("境界：%s → %s" % [sq["r0"], sq["r1"]], 15, C_ACCENT, c)
			else:
				L("境界：%s" % sq["r1"], 14, C_DIM, c)
			L("寿元余 %d 年" % g.shou_years(), 13, C_WARN, c)
			if not sq.get("lines", []).is_empty():
				var nw = card()
				H("这些年，山外", 18, C_ACCENT, nw)
				if int(sq.get("n_news", 0)) > sq["lines"].size():
					L("共 %d 件，只记了要紧的" % int(sq.get("n_news", 0)), 12, C_DIM, nw)
				for tl in sq["lines"]:
					# v0.13：去掉“· ”后的空格；v0.14：“·”进 NO_END，和第一个字粘住，按词折行（句号不再落到行首）
					LW("·" + String(tl), 13, C_TEXT, nw)
			if not sq.get("people", []).is_empty():
				var pc2 = card()
				H("故人", 18, C_ACCENT, pc2)
				LW("；".join(sq["people"]) + "。", 13, C_TEXT, pc2)
				L("（都记进了她的履历：生平 → 她在江湖里的生平）", 12, C_DIM, pc2)
			B("推开静室的门", func(): modal = {}, true, footer, 52)
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
	LW("水田：出灵谷，能顶辟谷丹，还能种寒潭莲子，是后路。", 14, C_TEXT, r2)
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
	hotspot("灶间", "ico_fu", _at(r, HOT["zao"]) + Vector2(10, -40), func(): sheet = "zao")
	_spacer()
	_light_notes()
	if g.can_breakthrough() == "":
		var bb = B(_gate_label(), func(): g.start_breakthrough(), true, footer, 52)
		bb.add_theme_color_override("font_color", C_WARN)

# ------------------------------------------------------------ 修炼 / 闭关
func _cult() -> void:
	var s = g.s
	_stage_image("bg_biguan", 0.2)
	H(g.realm_text(), 28, C_ACCENT)
	var rr = row()
	rr.alignment = BoxContainer.ALIGNMENT_CENTER
	var rg = ring(rr, int(s["xiuwei"]), g.xw_goal(), 132, C_GOLD, "", "修为")
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
	chip("%d 岁 · 寿元余 %d 年" % [g.age_y(), g.shou_years()], cr, "", C_WARN)
	chip("聚气丹已服 %d" % int(s["juqi_eaten"]), cr, "ico_juqi")
	if int(s["injured"]) > 0 or int(s["unstable"]) > 0:
		chip("炼化减半", cr, "", C_WARN)
	var hint: String = g.xw_full_hint()
	if hint != "":
		L(hint, 13, C_WARN)
	_spacer()
	var c = card()
	L("闭关：田和丹炉照常走；闭满一年，江湖的事不找上门", 13, C_DIM, c)
	var r = row(c)
	var stalled: bool = g.at_gate()
	for pr in [["一月", "days", 1], ["三月", "days", 3], ["一年", "years", 1], ["十年", "years", 10]]:
		var pp: Array = pr
		B(pp[0], func(): _seclude(pp[1], pp[2]), not (stalled and pp[1] == "years"), r, 46)
	if stalled:
		# v0.14.1：修为满了，长闭关一个月就会出关——不让点，指去冲关 / 备药
		var w2: String = g.can_breakthrough()
		LW("修为已到%s的关口，长闭关坐不出东西了。%s" % [g.gate_name(), ("下面可以冲关。" if w2 == "" else "先把冲关缺的补上；一月、三月仍可坐着等（田和丹炉照走）。")], 12, C_WARN, c)
	var r2 = row(c)
	B("炼完为止（约 %d 个月）" % int(ceil(s["ganwu"] / 20.0)), func(): _seclude("refine", 1), s["ganwu"] > 0, r2, 42)
	B("闭到修为圆满", func(): _seclude("gate", 1), not g.at_gate(), r2, 42)
	var tgt = ""
	for q in s["queue"]:
		if q[0] == "zhuji":
			tgt = "zhuji"
	if tgt == "" and not s["queue"].is_empty():
		tgt = s["queue"][0][0]
	B("到丹成（%s）" % (GS.RECIPES[tgt]["name"] if tgt != "" else "炉空"), func(): _seclude("pill", 1, tgt), tgt != "", c, 42)
	var why: String = g.can_breakthrough()
	if why != "":
		L("冲关：" + why, 12, C_DIM, c)
	if g.world != null:
		_cult_econ()
	var bb = B(_gate_label(), func(): g.start_breakthrough(), why == "", footer, 50)
	if why == "":
		bb.add_theme_color_override("font_color", C_WARN)

## v0.15（Gemini v7 专项 2 / 4c）：静室布置——聚灵阵（布阵 + 每年正月年费）、服丹闭关、蒙尘
func _cult_econ() -> void:
	var c = card()
	L(Econ.arr_text(g), 13, C_INK, c)
	var r = row(c)
	var nx: Dictionary = Econ.arr_next(g)
	if not nx.is_empty():
		var why: String = Econ.can_build(g)
		var bb = B("%s %s（%d 灵石，年费 %d）" % ["升" if int(Econ.E(g)["arr"]) > 0 else "布", nx["n"], int(nx["build"]), int(nx["fee"])], func(): Econ.build(g), why == "", r, 42)
		bb.add_theme_font_size_override("font_size", 13)
	var e: Dictionary = Econ.E(g)
	var fd: bool = bool(e["fudan"])
	var need: int = Econ.fudan_need(g)
	var fb = B("服丹闭关：%s" % ("开着" if fd else "关着"), func(): Econ.set_fudan(g, not fd), fd or g.store_n("pill_juqi") >= need, r, 42)
	fb.add_theme_font_size_override("font_size", 13)
	LW("服丹：每半年服 %d 颗聚气丹，这半年闭关修为 +%d%%（仓里 %d 颗）。连着闭关满三年心境蒙尘、所得减半，满五年坐不住要出关；出门走两个月就好。" % [need, Econ.FUDAN_PCT, g.store_n("pill_juqi")], 11, C_DIM, c)
	if Econ.dusty(g):
		L("心境蒙尘：闭关所得减半，出门走走。", 12, C_WARN, c)

## v0.13：冲关按钮上写清是哪一关、几成把握
func _gate_label() -> String:
	if int(g.s.get("plv", 0)) < 9:
		return "◎ 冲关（筑基，耗 1 个月）"
	return "◎ 冲关（%s，约 %d 成把握）" % [g.gate_name(), int(round(g.gate_chance() * 10))]

## v0.13：闭关；闭满一年的长闭关出关时给“这些年”的摘要
func _seclude(preset: String, n: int, target: String = "") -> void:
	g.s.erase("last_seclude")
	g.biguan(preset, n, target)
	if g.s.has("last_seclude"):
		modal = {"kind": "seclude", "sum": g.s["last_seclude"]}
		g.s.erase("last_seclude")

# ------------------------------------------------------------ 行记
func _log_tab() -> void:
	_stage_image("bg_home", 0.7)
	H("人物记得的事", 24)
	if g.s["memory"].is_empty():
		L("（还没有）", 13, C_DIM)
	var pk = {"老龟": "por_turtle", "葛老三": "por_gelaosan"}
	for m in g.s["memory"]:
		var r = row(card())
		IC(pk.get(m["npc"], "por_heroine"), 40, r)
		LW("%s · %s：%s" % [World.cal_short(int(m["day"])), m["npc"], m["text"]], 14, C_TEXT, r)
	H("青庐行记", 24)
	var lc = card()
	if g.world != null:
		B("她在江湖里的生平（履历）", func(): person_id = 1; person_tab = "life"; modal = {"kind": "person"}, true, lc, 40)
	var lg: Array = g.s["log"]
	for i in range(lg.size() - 1, maxi(-1, lg.size() - 40), -1):
		L("%s  %s" % [World.cal_short(int(lg[i]["day"])), lg[i]["text"]], 13, C_TEXT, lc)


# ------------------------------------------------------------ v0.11.2 地点画风：每处一套底图 / 题头 / 纸色 / 边饰 / 世界图小景
## k 资源名（web_portrait/bg/pl_k.webp 底图，assets/img/vig_k.webp 世界图小景）；paper 卡片纸色；edge 边饰与描边；ink 地名与强调字；
## wash/wa 底图上罩的一层（颜色/浓淡）；hy 题头取底图哪一段（中心，按图高比例）；motto 题头小字（这地方的气味；改了要重跑 tools/make_font.py）
const PLACE_LOOK = {
	"后山": {"k": "houshan", "paper": Color("#EDF3E6"), "edge": Color("#4E7D45"), "ink": Color("#2C5530"), "wash": Color("#E3EDD8"), "wa": 0.26, "hy": 0.17, "motto": "松风 · 山涧 · 青苔"},
	"坊市": {"k": "fangshi", "paper": Color("#FBF0E0"), "edge": Color("#B9582A"), "ink": Color("#86361A"), "wash": Color("#F6E3C6"), "wa": 0.28, "hy": 0.15, "motto": "灯笼 · 檐角 · 人声"},
	"寒潭": {"k": "hantan", "paper": Color("#EAEFF4"), "edge": Color("#56718A"), "ink": Color("#2B4760"), "wash": Color("#DDE6EE"), "wa": 0.24, "hy": 0.17, "motto": "寒雾 · 薄冰 · 瀑声"},
	"药王谷": {"k": "yaowang", "paper": Color("#F5F2DC"), "edge": Color("#7E8A2E"), "ink": Color("#4F5A1A"), "wash": Color("#EEEACB"), "wa": 0.26, "hy": 0.22, "motto": "药圃 · 丹烟 · 日暖"},
	"青云宗": {"k": "qingyun", "paper": Color("#ECF3F9"), "edge": Color("#3A78A8"), "ink": Color("#1D4B74"), "wash": Color("#E4EEF6"), "wa": 0.20, "hy": 0.15, "motto": "云海 · 石阶 · 鹤影"},
	"云梦泽": {"k": "yunmeng", "paper": Color("#F2F0E4"), "edge": Color("#7E907A"), "ink": Color("#3F5A48"), "wash": Color("#ECE8DA"), "wa": 0.20, "hy": 0.20, "motto": "芦花 · 渔火 · 烟水"},
	"玄霜谷": {"k": "xuanshuang", "paper": Color("#F2F0F8"), "edge": Color("#7E77B0"), "ink": Color("#433E78"), "wash": Color("#EAE8F4"), "wa": 0.18, "hy": 0.22, "motto": "落雪 · 冰瀑 · 寂静"},
	"落霞宫": {"k": "luoxia", "paper": Color("#FCEDEA"), "edge": Color("#C2626E"), "ink": Color("#8A3344"), "wash": Color("#F8E0DE"), "wa": 0.22, "hy": 0.20, "motto": "晚霞 · 琴台 · 桃花"},
	"万剑门": {"k": "wanjian", "paper": Color("#EEEFF0"), "edge": Color("#5E6774"), "ink": Color("#2A313C"), "wash": Color("#E4E6E8"), "wa": 0.22, "hy": 0.24, "motto": "剑痕 · 罡风 · 铁色"},
	"古战场": {"k": "guzhan", "paper": Color("#F4EAD6"), "edge": Color("#94622F"), "ink": Color("#663F1C"), "wash": Color("#EADCC0"), "wa": 0.24, "hy": 0.15, "motto": "黄沙 · 断戟 · 残碑"},
	"秘境": {"k": "mijing", "paper": Color("#E8F3F0"), "edge": Color("#2A8178"), "ink": Color("#1B5550"), "wash": Color("#CFE6E1"), "wa": 0.12, "hy": 0.15, "motto": "石门 · 灵光 · 幽深"},
	"血煞门": {"k": "xuesha", "paper": Color("#F6E8E5"), "edge": Color("#8A2626"), "ink": Color("#6A1616"), "wash": Color("#E9C9C3"), "wa": 0.12, "hy": 0.14, "motto": "赤山 · 血池 · 鸦声"},
}
## 当前这一屏用哪处的纸色（_refresh 清空；游历页设上）——card() 照着它换底色和边饰
var place_look: Dictionary = {}

func _place_card_sb(lk: Dictionary) -> StyleBoxFlat:
	var pc: Color = lk["paper"]
	var ec: Color = lk["edge"]
	var sb = _sb(Color(pc.r, pc.g, pc.b, 0.94), Color(ec.r, ec.g, ec.b, 0.55), 8, 1, 10)
	sb.border_width_left = 4          # 左边一道这地方颜色的“墨条”
	sb.shadow_color = Color(ec.r, ec.g, ec.b, 0.16)
	sb.shadow_size = 3
	return sb

## 游历页题头：取这地方底图最有辨识度的一段 + 地名、小景、气味小字
func _place_banner(p: String, lk: Dictionary, sub: String) -> Label:
	# v0.11.2b：图要看得清——题头更高，底下只一层渐隐的本处纸色，地名直接压在画上（纸色晕边 + 柔影）
	var vs: Vector2 = get_viewport_rect().size
	var h := 146.0 if vs.y >= 760 else (112.0 if vs.y >= 700 else 88.0)   # 360×640 这类矮屏：题头比 v0.11.2 还矮 16px，给下面的人和“上前”腾地方
	var pc: Color = lk["paper"]
	var box = PanelContainer.new()
	var fr = _sb(Color(0, 0, 0, 0), lk["edge"], 8, 2, 0)
	fr.draw_center = false
	box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	box.custom_minimum_size = Vector2(0, h)
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(box)
	var t: Texture2D = tex("pl_" + String(lk["k"]))
	if t != null:
		var ts := t.get_size()
		var bw := vs.x - 24.0
		var rh := ts.x * h / bw
		var at = AtlasTexture.new()
		at.atlas = t
		at.region = Rect2(0, clampf(ts.y * float(lk["hy"]) - rh / 2.0, 0.0, ts.y - rh), ts.x, rh)
		var tr = TextureRect.new()
		tr.texture = at
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tr)
	# 下沿渐隐：上面全透明，最底下也只到七成纸色——画一直透到底
	var gv = VBoxContainer.new()
	gv.add_theme_constant_override("separation", 0)
	gv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gv)
	var gsp = Control.new()
	gsp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gsp.size_flags_stretch_ratio = 1.4
	gsp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gv.add_child(gsp)
	var gt = GradientTexture2D.new()
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var gr = Gradient.new()
	gr.set_color(0, Color(pc.r, pc.g, pc.b, 0.0))
	gr.set_color(1, Color(pc.r, pc.g, pc.b, 0.72))
	gt.gradient = gr
	gt.width = 8
	gt.height = 64
	var gtr = TextureRect.new()
	gtr.texture = gt
	gtr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gtr.stretch_mode = TextureRect.STRETCH_SCALE
	gtr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gtr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gv.add_child(gtr)
	var ov = VBoxContainer.new()
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(ov)
	# 右上角一枚小签：这地方的气味（松风 · 山涧 · 青苔 …）
	var tg = HBoxContainer.new()
	tg.alignment = BoxContainer.ALIGNMENT_END
	tg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(tg)
	var ml = L(String(lk["motto"]), 12, lk["ink"], tg)
	ml.add_theme_stylebox_override("normal", _sb(Color(pc.r, pc.g, pc.b, 0.72), Color(0, 0, 0, 0), 0, 0, 3))
	var sp = Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(sp)
	var mg = MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		mg.add_theme_constant_override("margin_" + side, 8)
	mg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(mg)
	var r = row(mg, 8)
	IC("vig_" + String(lk["k"]), 30, r)
	var nm = H(p, 24, lk["ink"], r)
	_halo(nm, pc, 7)
	var sl = L(sub, 13, C_INK, r)
	_halo(sl, pc, 5)
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.clip_text = true
	var frame = Panel.new()
	frame.add_theme_stylebox_override("panel", fr)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(frame)
	return sl

## 压在画上的字：一圈纸色晕边 + 一层更宽更淡的柔影，任何底色上都读得出
func _halo(l: Label, pc: Color, w: int) -> void:
	l.add_theme_color_override("font_outline_color", Color(pc.r, pc.g, pc.b, 0.88))
	l.add_theme_constant_override("outline_size", w)
	l.add_theme_color_override("font_shadow_color", Color(pc.r, pc.g, pc.b, 0.55))
	l.add_theme_constant_override("shadow_outline_size", w * 2 + 4)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)

# ------------------------------------------------------------ 出发（路线图预览 + 行囊）
func _trip_bg() -> String:
	if g.s.get("loc", "") == "roam":
		var rp := String(g.s["roam"].get("pl", ""))
		if PLACE_LOOK.has(rp):
			return "pl_" + String(PLACE_LOOK[rp]["k"])
		return String(TV.PL.get(rp, {}).get("bg", "bg_shandao"))
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

func _depart_routes() -> void:
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
		IC({"葛老三": "por_gelaosan"}.get(who, "por_heroine"), 38, rc)
		var tl = L(String(ru["text"]), 13, C_ACCENT if ru.get("key", false) else C_TEXT, rc)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spacer()
	var pc = card()
	var pr = row(pc, 6)
	IC("ico_ration", 30, pr)
	var rl = L("辟谷丹 %d/12" % s["ration"], 15, C_TEXT, pr)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var b1 = B("+1（1灵石）", func(): g.buy_rations(1), s["ration"] < 12 and s["lingshi"] > 0, pr, 36)
	b1.add_theme_font_size_override("font_size", 13)
	if g.store_n("crop_linggu") > 0:
		var b2 = B("装灵谷", func(): g.load_grain(), s["ration"] < 12, pr, 36)
		b2.add_theme_font_size_override("font_size", 13)
	var kr = row(pc, 4)
	for i in mini(Gear.cells(g), 6):
		if i < s["pack"].size():
			var cell = IC(ICON.get(s["pack"][i]["id"], "ico_fu"), 30, kr)
			if s["pack"][i]["key"]:
				cell.modulate = Color(1, 0.85, 0.6)
		else:
			var e = Panel.new()
			e.custom_minimum_size = Vector2(30, 30)
			e.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0.06), Color(0.29, 0.25, 0.2, 0.3), 4, 1, 0))
			kr.add_child(e)
	var pb = BI("行囊 %d/%d" % [s["pack"].size(), Gear.cells(g)], "ico_fu", func(): sheet = "pack", true, kr, 36)
	pb.add_theme_font_size_override("font_size", 13)
	B("出发：%s" % rt["name"], func(): g.start_trip(selected_route), true, footer, 50)

# ------------------------------------------------------------ v0.11 世界图：一处处解锁的地方
func _depart() -> void:
	if g.world == null:
		_depart_routes()
		return
	var W = g.world
	TV.ensure(W)
	var r = _stage_image("map_world", 0.04)
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var home_at = _at(r, Vector2(0.48, 0.87))
	var lines = MapLines.new()
	lines.size = get_viewport_rect().size
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(lines)
	var segs = []
	for p in TV.places(W):
		segs.append([home_at, _at(r, Vector2(TV.PL[p]["xy"][0], TV.PL[p]["xy"][1])), false])
	lines.segs = segs
	var hl = Label.new()
	hl.text = "● 青庐"
	hl.add_theme_font_size_override("font_size", 14)
	hl.add_theme_color_override("font_color", Color("#8A3A22"))
	hl.add_theme_stylebox_override("normal", _sb(Color(0.985, 0.97, 0.935, 0.85), Color(0, 0, 0, 0), 8, 0, 3))
	hl.position = home_at - Vector2(28, 12)
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(hl)
	for p in TV.ORDER:
		var at = _at(r, Vector2(TV.PL[p]["xy"][0], TV.PL[p]["xy"][1]))
		var pn: String = p
		if TV.unlocked(W, p):
			var ka: Array = TV.known_at(W, p)
			var lab = "%s\n%d月%s" % [p, TV.dist(TV.HOME, p), ("·熟人%d" % ka.size()) if not ka.is_empty() else ""]
			var mlk: Dictionary = PLACE_LOOK.get(p, {})
			var vig := ("vig_" + String(mlk["k"])) if not mlk.is_empty() else ""
			var b = hotspot(lab, vig, at, func(): sel_place = pn; sheet = "place", 100)
			b.custom_minimum_size = Vector2(100, 46)
			b.size = Vector2(100, 46)
			b.position.x = at.x - 50.0
			b.add_theme_font_size_override("font_size", 13)
			b.add_theme_constant_override("icon_max_width", 30)
			b.add_theme_constant_override("h_separation", 4)
			if not mlk.is_empty():
				# 地名框染成这地方的颜色：纸色底 + 本地边饰 + 本地墨色字
				var pc: Color = mlk["paper"]
				var ms = _sb(Color(pc.r, pc.g, pc.b, 0.93), mlk["edge"], 16, 2, 4)
				b.add_theme_stylebox_override("normal", ms)
				b.add_theme_stylebox_override("hover", ms)
				b.add_theme_stylebox_override("focus", ms)
				b.add_theme_color_override("font_color", mlk["ink"])
				b.add_theme_color_override("font_hover_color", mlk["ink"])
			if sel_place == p:
				var hs = _sb(Color(1.0, 0.95, 0.85, 0.95), C_WARN, 16, 2, 4)
				b.add_theme_stylebox_override("normal", hs)
				b.add_theme_stylebox_override("hover", hs)
		elif TV.heard_n(W, p) > 0:
			# 听过风声、还去不了：淡淡一个“？”，点开看传闻和还差什么
			var hlk: Dictionary = PLACE_LOOK.get(p, {})
			var b2 = hotspot("%s？" % p, ("vig_" + String(hlk["k"])) if not hlk.is_empty() else "", at, func(): sel_place = pn; sheet = "place", 92)
			b2.add_theme_font_size_override("font_size", 13)
			b2.add_theme_constant_override("icon_max_width", 24)
			b2.add_theme_color_override("icon_normal_color", Color(1, 1, 1, 0.4))   # 只听过：小景淡淡的
			b2.add_theme_color_override("icon_hover_color", Color(1, 1, 1, 0.55))
			b2.add_theme_color_override("font_color", C_DIM)
			var ds = _sb(Color(0.985, 0.97, 0.935, 0.55), Color(0.29, 0.25, 0.2, 0.35), 16, 1, 4)
			b2.add_theme_stylebox_override("normal", ds)
			b2.add_theme_stylebox_override("hover", ds)
	# v0.12.1：打听到的仇人落脚处，在图上标一下（寻凶之后一段时间内，跟着人走）
	var hm: Dictionary = W.hunt_marks()
	for hp in hm:
		if not TV.PL.has(hp) or not (TV.unlocked(W, hp) or TV.heard_n(W, hp) > 0):
			continue
		var hat = _at(r, Vector2(TV.PL[hp]["xy"][0], TV.PL[hp]["xy"][1]))
		var mk = Label.new()
		mk.text = "仇·" + "、".join(hm[hp])
		mk.add_theme_font_size_override("font_size", 12)
		mk.add_theme_color_override("font_color", Color("#8A1F1F"))
		mk.add_theme_stylebox_override("normal", _sb(Color(1.0, 0.94, 0.9, 0.9), Color("#8A1F1F"), 6, 1, 2))
		mk.position = hat + Vector2(-30, 24)
		mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(mk)
	_spacer()
	var n_un = TV.places(W).size()
	var tip = L("认得 %d 处 · 点地名看看，“？”是只听过风声的地方" % n_un, 13, C_INK, footer)
	tip.add_theme_stylebox_override("normal", _sb(Color(0.985, 0.97, 0.935, 0.85), Color(0, 0, 0, 0), 8, 0, 4))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _sheet_place(v: Node) -> void:
	var W = g.world
	var p: String = sel_place
	if W == null or not TV.PL.has(p):
		return
	var pl: Dictionary = TV.PL[p]
	_wl(String(pl["hint"]), 14, C_DIM, v)
	if not TV.unlocked(W, p):
		_wl("还去不了。要么%s。" % TV.need(W, p), 14, C_WARN, v)
		# v0.12.1：风声只是耳闻；坊市里买一张舆图才认得路
		var why_no: String = TV.can_buy_map(W, p)
		var mb2 = B("买一张去%s的舆图（%d 灵石）" % [p, TV.map_cost(p)], func(): TV.buy_map(W, p); refresh(), why_no == "", v, 44)
		if why_no != "":
			mb2.tooltip_text = why_no
			_wl("（%s）" % why_no, 13, C_DIM, v)
		return
	var d := TV.dist(TV.HOME, p)
	var nm := []
	for sp in TV.spots(p):
		nm.append(String(sp[0]))
	_wl("离青庐 %d 个月 · 去处：%s" % [d, "、".join(nm)], 14, C_TEXT, v)
	var ka: Array = TV.known_at(W, p)
	if ka.is_empty():
		_wl("听说那边人来人往，认得的人倒没听说在。", 13, C_DIM, v)
	else:
		_wl("熟人在那边%s" % ("（%d 位）" % ka.size() if ka.size() > 4 else "："), 14, C_ACCENT, v)
		var ar = HBoxContainer.new()
		ar.add_theme_constant_override("separation", 6)
		v.add_child(ar)
		for c in ka.slice(0, 4):
			_mini_face(c, 60.0, ar)
	var pr = row(v, 6)
	IC("ico_ration", 28, pr)
	var rl = L("辟谷丹 %d/12%s" % [int(g.s["ration"]), "（来回就要 %d）" % (d * 2) if int(g.s["ration"]) < d * 2 + 1 else ""], 14, C_WARN if int(g.s["ration"]) < d * 2 + 1 else C_TEXT, pr)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var b1 = B("+1（1灵石）", func(): g.buy_rations(1), int(g.s["ration"]) < 12 and int(g.s["lingshi"]) > 0, pr, 36)
	b1.add_theme_font_size_override("font_size", 13)
	if g.store_n("crop_linggu") > 0:
		var b2 = B("装灵谷", func(): g.load_grain(), int(g.s["ration"]) < 12, pr, 36)
		b2.add_theme_font_size_override("font_size", 13)
	var why: String = g.can_roam(p)
	var gb = B("去%s游历（路上 %d 个月）" % [p, d], func(): _go_roam(p), why == "", v, 50)
	gb.add_theme_color_override("font_color", C_ACCENT)
	if why != "":
		L(why, 13, C_WARN, v)

## 抽屉里的整行换行字（不像 LW 那样给 96 的最小宽度——竖排里那会把抽屉撑得老高）
func _wl(text: String, size: int, color: Color, parent: Node) -> Label:
	var l = L(text, size, color, parent)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = get_viewport_rect().size.x - 56   # 换行字给足宽度，抽屉才算得出真实高度
	l.size = Vector2(l.custom_minimum_size.x, 0)
	return l

func _go_roam(p: String) -> void:
	sheet = ""
	if g.start_roam(p):
		sfx("page")

func _sheet_goto(v: Node) -> void:
	var W = g.world
	var here := String(g.s.get("roam", {}).get("pl", ""))
	if here == "" or not TV.PL.has(here):
		_wl("已经不在外头了。", 14, C_DIM, v)
		return
	for p in TV.places(W):
		if p == here:
			continue
		var pn: String = p
		var ka: Array = TV.known_at(W, p)
		var b = B("%s（%d月）%s" % [p, TV.dist(here, p), ("  熟人%d" % ka.size()) if not ka.is_empty() else ""], func(): sheet = ""; g.roam_move(pn), true, v, 42)
		b.add_theme_font_size_override("font_size", 14)

# ------------------------------------------------------------ v0.11 游历：在一处地方，一天去一个小去处，看看今天谁在
func _roam() -> void:
	if not g.s["pending_overflow"].is_empty():
		_overflow()
		return
	var W = g.world
	var rm: Dictionary = g.s["roam"]
	var p := String(rm["pl"])
	var pl: Dictionary = TV.PL[p]
	# v0.11.2：每处一套画风——底图、题头、纸色、边饰（PLACE_LOOK）
	var lk: Dictionary = PLACE_LOOK.get(p, {})
	if lk.is_empty():
		_stage_image(String(pl["bg"]), 0.42)
		var tag = PanelContainer.new()
		tag.add_theme_stylebox_override("panel", _sb(Color(0.985, 0.97, 0.935, 0.88), Color(0, 0, 0, 0), 8, 0, 6))
		body.add_child(tag)
		var tr = row(tag)
		H(p, 24, C_ACCENT, tr)
		var sl0 = L("游历 %d 个月 · 回青庐 %d 个月" % [int(rm.get("days", 0)), g.roam_home_days()], 13, C_DIM, tr)
		sl0.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		_stage_image("pl_" + String(lk["k"]), float(lk["wa"]), lk["wash"])
		_place_banner(p, lk, "游历 %d 个月 · 回青庐 %d 个月" % [int(rm.get("days", 0)), g.roam_home_days()])
		place_look = lk
	# 今天去哪：每个小去处 1 日、1 份干粮
	# v0.11.4：矮屏（高 <700，如 360×640）小去处并成一排、只写地名，整页不用滚动
	var short_scr: bool = get_viewport_rect().size.y < 700
	var sc = card()
	L("这个月去哪儿走走（各 1 个月）", 14, C_INK, sc)
	var spots: Array = TV.spots(p)
	var spr = row(sc, 6) if short_scr else null
	for i in spots.size():
		var sp: Array = spots[i]
		var idx = i
		var b = B(String(sp[0]) if short_scr else "%s · %s" % [sp[0], sp[1]], func(): _roam_spot(idx), true, spr if short_scr else sc, 44)
		b.add_theme_font_size_override("font_size", 14)
		if not short_scr:
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		if int(rm.get("si", -1)) == i:
			b.add_theme_color_override("font_color", C_ACCENT)
	# 今天在这一带的人：熟人在前，再添一两个生面孔
	var pc = card()
	var can: bool = TV.can_approach(W)
	L("这一带的人" + ("" if can else "（这个月已上前搭过话）"), 14, C_INK, pc)
	var here: Array = TV.present_at(W, p)
	var show := []
	for c in here:
		if W.known(c) and show.size() < 3:
			show.append(c)
	for c in here:
		if not W.known(c) and show.size() < 5:
			show.append(c)
	if show.is_empty():
		L("这个月没碰见什么人。", 13, C_DIM, pc)
	var spn := String(spots[clampi(int(rm.get("si", 0)), 0, spots.size() - 1)][0])
	# v0.11.1：画像卡（点卡 = 看看；下面“上前”）。生面孔也是 TA 自己的画像和名字，日后认得了还是这张脸
	if not show.is_empty():
		var vw: float = get_viewport_rect().size.x
		var cw: float = floorf(clampf((vw - 44.0) / 3.4, 92.0, 116.0))
		if get_viewport_rect().size.y < 700:
			cw = 80.0   # 矮屏：卡小一点，上前按钮不被底栏压住
		var sc2 = ScrollContainer.new()
		sc2.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if show.size() * (cw + 6) > vw - 40 else ScrollContainer.SCROLL_MODE_DISABLED
		sc2.custom_minimum_size = Vector2(0, cw * 1.08 + 36 + 44 + 6)
		pc.add_child(sc2)
		var hb2 = HBoxContainer.new()
		hb2.add_theme_constant_override("separation", 6)
		sc2.add_child(hb2)
		for c in show:
			_roam_card(W, c, cw, can, p, spn, hb2)
	var lg: Array = rm.get("log", [])
	if not lg.is_empty():
		var lc = card()
		for it in lg.slice(-1 if short_scr else -2):
			if short_scr:
				# 矮屏只留最近一行，放不下用省略号（点小去处时整段在提示里看过了）
				var ll = L("%s·%s" % [World.cal_short(int(it[0])), String(it[1])], 13, C_DIM, lc)
				ll.autowrap_mode = TextServer.AUTOWRAP_OFF
				ll.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				ll.custom_minimum_size.x = 1
			else:
				_wl("%s·%s" % [World.cal_short(int(it[0])), String(it[1])], 13, C_DIM, lc)
	_spacer()
	var fr = row(footer, 6)
	var hb = B("回青庐（%d月）" % g.roam_home_days(), func(): _roam_home(), true, fr, 46)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mb = B("去别处", func(): sheet = "goto", TV.places(W).size() > 1, fr, 46)
	mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var xr = row(footer, 6)
	if p == "坊市":
		var bb = B("买辟谷丹（1灵石）", func(): g.roam_buy_ration(), int(g.s["lingshi"]) > 0 and int(g.s["ration"]) < 12, xr, 40)
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bb.add_theme_font_size_override("font_size", 13)
	if p == "坊市":
		var gr = row(footer, 6)
		var sb = B("器物铺 · 卖修", func(): sheet = "shop", true, gr, 40)
		sb.add_theme_font_size_override("font_size", 13)
		# v0.15：卖青芝 / 卖丹 / 主药保底都收进“药铺”抽屉，底栏不再挤三排
		var yb = B("药铺 · 卖药收药" + (" ●" if g.dry_chiyang_available() or Econ.ice_lian_available(g) or g.junk_lianzi_available() else ""), func(): sheet = "yao", true, gr, 40)
		yb.add_theme_font_size_override("font_size", 13)
		var gr2 = row(footer, 6)
		var jb = B("差事榜 · 代炼 客卿 悬赏", func(): sheet = "jobs", true, gr2, 40)
		jb.add_theme_font_size_override("font_size", 13)
		if Gear.auction_month(int(g.s["day"])):
			var ab = B("拍卖会（%s）" % ("春拍" if (int(g.s["day"]) - 1) % 12 + 1 == 3 else "秋拍"), func(): sheet = "auc", true, gr2, 40)
			ab.add_theme_font_size_override("font_size", 13)

## 小头像（点开看这个人）：地点抽屉里“熟人在那边”
func _mini_face(c: Dictionary, cw: float, parent: Node) -> void:
	var cid := int(c["id"])
	var cell = Button.new()
	cell.custom_minimum_size = Vector2(cw, cw * 1.08 + 20)
	cell.pressed.connect(func(): _press(func(): sheet = ""; person_id = cid; person_tab = "life"; modal = {"kind": "person"}))
	parent.add_child(cell)
	var v = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 2; v.offset_top = 2; v.offset_right = -2; v.offset_bottom = -1
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(v)
	var pb = PBox.new()
	pb.custom_minimum_size = Vector2(cw - 4, cw * 1.08 - 4)
	v.add_child(pb)
	pb.setup(npc_spec(c), PBox.FACE, 0.0)
	var nl = L(String(c["name"]), 11, C_TEXT, v)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.autowrap_mode = TextServer.AUTOWRAP_OFF
	nl.clip_text = true

const DOING := {"求财": "买卖", "交游": "说笑", "探秘": "寻宝", "扬名": "比试", "压人": "比试", "破境": "闭关", "复仇": "寻人", "寻仇": "寻人", "疗伤": "养伤", "求偶": "出神", "护人": "等人", "报恩": "寻人", "赎过": "赶路", "叛门": "匆匆"}

func _roam_card(W, c: Dictionary, cw: float, can: bool, p: String, spn: String, parent: Node) -> void:
	var cid := int(c["id"])
	var known: bool = W.known(c)
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	parent.add_child(col)
	var cell = Button.new()
	cell.custom_minimum_size = Vector2(cw, cw * 1.08 + 36)
	cell.pressed.connect(func(): _press(func(): person_id = cid; person_tab = "life"; modal = {"kind": "person"}))
	col.add_child(cell)
	var v = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 3; v.offset_top = 3; v.offset_right = -3; v.offset_bottom = -2
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(v)
	var pb = PBox.new()
	pb.custom_minimum_size = Vector2(cw - 6, cw * 1.08 - 6)
	v.add_child(pb)
	pb.setup(npc_spec(c), PBox.FACE, 0.0)
	var nl = L(String(c["name"]), 14, C_TEXT if known else C_INK, v)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.autowrap_mode = TextServer.AUTOWRAP_OFF
	nl.clip_text = true
	var k := String(c.get("dr", {}).get("k", "交游"))
	var rw: String = W.rel_word(c) if known else String(c["sect"])
	var hc = C_WARN if rw in ["仇", "有隙"] else C_DIM
	var hl = L("%s·%s" % [rw, DOING.get(k, "闲逛")], 11, hc, v)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl.autowrap_mode = TextServer.AUTOWRAP_OFF
	hl.clip_text = true
	var ab = B("上前", func(): _approach(cid, p, spn), can, col, 44)
	ab.add_theme_font_size_override("font_size", 14)

func _roam_spot(i: int) -> void:
	var r: Dictionary = g.roam_spot(i)
	if r.is_empty():
		return
	if String(r.get("text", "")) != "":
		g.notice(String(r["text"]))
	sfx("success" if not r["items"].is_empty() or int(r["ls"]) > 0 else "page")

func _approach(id: int, p: String, sp: String) -> void:
	if TV.approach(g.world, id, p, sp):
		g.world._save_rng()

func _roam_home() -> void:
	g.roam_home()
	if g.s.get("loc", "") == "home" and g.s.has("last_home"):
		modal = {"kind": "home", "sum": g.s["last_home"]}
		tab = "home"

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
		var lab = "%s\n%s%s" % [ev["title"], ("%d月" % days) if days > 0 else "到家", "·熟路" if rv else ("·要事" if ev.get("heavy", false) else "")]
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
	L("已走 %d 个月 · 点路标前行" % int(t["walked"]), 13, C_DIM, hr).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if g.day_mod() > 0:
		L("老龟记仇：寒潭每段路 +%d 个月" % g.day_mod(), 12, C_WARN)
	_spacer()
	if int(t["walked"]) > 0:
		B("半路折返（%d 个月，每月一颗辟谷丹）" % g.turn_back_days(), func(): _turn_back(), true, footer, 42)
	else:
		B("不去了，回家", func(): _turn_back(), true, footer, 42)

func _turn_back() -> void:
	g.turn_back()
	if g.s.has("last_home"):
		modal = {"kind": "home", "sum": g.s["last_home"]}

func _cost_text(o: Dictionary) -> String:
	var parts = []
	var d = int(o["days"])
	if d > 0:
		parts.append(o.get("cost", {}).get("note", "%d 个月" % d))
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
	B("快走（%d 个月）" % (1 + g.day_mod()), func(): g.quick_walk(), true, footer, 52)

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
		chip("%d 个月 · 辟谷丹余 %d" % [res["days"], g.s["ration"]], fr, "ico_ration")
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
		modal = {"kind": "msg", "title": "心魔未平", "text": "雾里那个声音笑了一声，散了。她睁开眼，额上一层冷汗。\n有一句回答，和她做过的事对不上。%s先闭关 3 个月（炼化减半），再冲关。" % ("筑基丹还在，" if int(g.s.get("plv", 0)) < 9 else "")}
	elif r.get("done", false) and r.has("gate") and not r.get("ended", false):
		if r.get("ok", false):
			_fx_breakthrough()
			sfx("breakthrough")
			var tx := {"筑基": "灵气在丹田里沉下去，凝成一汪。推门出来时，院里的阳田都绿了。\n寿元延至两百年。往后的路，要按十年、百年算了。",
				"结丹": "丹田里那汪灵液越转越紧，凝成了一粒金丹。\n寿元延至五百年。", "凝婴": "金丹碎了，又长出一个小小的人来，眉眼和她一样。\n寿元延至千年。",
				"化神": "元婴睁开了眼。她看青庐的院子，像看掌心的纹路。\n寿元延至两千年。"}
			modal = {"kind": "msg", "title": "%s功成" % r["gate"], "text": "%s，%s\n如今是%s。" % [g.date_text(), tx.get(String(r["gate"]), ""), g.realm_text()]}
		else:
			modal = {"kind": "msg", "title": "%s未成" % r["gate"], "text": "关口没冲过去。经脉受损，要养一年；修为退了两成半，折寿五年。\n%s。" % g.date_text()}

var show_log = false
func _ending() -> void:
	var s = g.s
	_stage_image("bg_ending", 0.1)
	if s["ending"] == "feisheng":
		var t = H("飞升", 64, C_ACCENT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_spacer()
		beat_i = 99
		dialog(String(s["name"]), "vn_heroine_smile", "%s，九道雷劫落在青庐后山。最后一道散了，天上开了一道门。她回头看了一眼院子，%d 岁，白日飞升。" % [g.date_text(), g.age_y()], false)
	elif s["ending"] == "jiewu":
		var t3 = H("劫灰", 52, C_ACCENT)
		t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_spacer()
		var ec3 = card()
		L("%s，第九道雷劫落下，她没有接住。青庐后山烧焦了一片，第二年春天，那里长出了一丛青芝。" % g.date_text(), 16, C_TEXT, ec3)
	else:
		var t2 = H("坐化于青庐", 44, C_ACCENT)
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_spacer()
		var ec2 = card()
		L("%s，寿元耗尽。她回到青庐静室，在灯下合上了眼，享年 %d 岁。窗外，后山的溪水还是那样流着。" % [g.date_text(), g.age_y()], 16, C_TEXT, ec2)
	var c = card()
	var fr = HFlowContainer.new()
	fr.add_theme_constant_override("h_separation", 6)
	c.add_child(fr)
	var st = s["stats"]
	chip("历练 %s" % GS.span_text(int(st["trip_days"])), fr, "ico_ration")
	chip("闭关 %s" % GS.span_text(int(st["biguan_days"])), fr, "ico_zhuji")
	chip("要事 %d" % st["heavy"], fr, "", C_WARN)
	chip("用时 %.0f 分钟" % (float(s.get("play_ms", 0)) / 60000.0), fr, "", C_ACCENT)
	if show_log:
		for e in s["log"]:
			L("%s  %s" % [World.cal_short(int(e["day"])), e["text"]], 13, C_TEXT, c)
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
	var on_trip: bool = (g.s.get("loc", "") == "trip" and String(g.s.get("trip", {}).get("stage", "")) in ["result", "choose"]) or (g.s.get("loc", "") == "roam" and g.s["pending_overflow"].is_empty())
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

const LIGHT_TIDS = ["灵田", "闭关小成", "家书", "夜雨", "旧物", "宗门大比", "飞升异象", "师门书信", "坊市传闻"]

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
	var bgn: String = bgs.get(String(ev["tid"]), "courtyard")
	if String(ev["tid"]) == "相逢" or (g.s.get("loc", "") == "roam" and not bgs.has(String(ev["tid"]))):
		bgn = _trip_bg()
	elif String(ev["tid"]) == "引路":
		bgn = "bg_chasi" if g.s.get("loc", "") == "home" else _trip_bg()
	_stage_image(bgn, 0.3 if tier < 2 else 0.2, Color("#F3EEE2"), maxf(vsz.y * 0.32, (170.0 + free_bot) / 2.0 + 40.0))
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
		spk = g.world.speaker_title(ev)
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
			LW("%s  %s" % [World.cal_short(int(news[i][0])), news[i][1]], 13, C_TEXT, nr)
			var mb = B("插手", func(): _meddle(pid), true, nr, 40)
			mb.size_flags_horizontal = Control.SIZE_SHRINK_END
			mb.custom_minimum_size.x = 64
			mb.add_theme_font_size_override("font_size", 14)
		else:
			L("%s  %s" % [World.cal_short(int(news[i][0])), news[i][1]], 13, C_TEXT, nc)

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
	var agey := g.age_y() if is_p else int(float(c.get("age", 0)))
	L("%s · %s%s" % [String(c["sect"]), realm, (" · %d 岁" % agey) if agey > 0 else ""], 14, C_TEXT, info)
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
				L("%s  %s" % [World.cal_short(int(m[0])), m[2]], 14, C_WARN if int(m[3]) < 0 else C_TEXT, cc)
	if String(g.s.get("loc", "")) == "roam" and tab != "jianghu":
		# v0.11.1：从游历页的画像卡点开的，看完回游历页
		B("回%s" % String(g.s["roam"].get("pl", "")), func(): modal = {}; life_all = false, true, footer, 46)
	else:
		B("回江湖", func(): modal = {}; tab = "jianghu"; life_all = false, true, footer, 46)

## 生平时间线：按历法分月（第 1 日是正月初一，30 日一月；节令也按这个历），近的月份在上、月内按日先后；每条右侧是提到的人的小头像（点开看此人）
func _life_timeline(c: Dictionary, cc: VBoxContainer) -> void:
	var w = g.world
	var lg: Array = c["log"]
	var pre: Array = [] if c.get("player", false) else w.pre_of(c)
	if lg.is_empty():
		if pre.is_empty():
			L("（没听说过什么）", 13, C_DIM, cc)
		else:
			_life_pre(pre, cc)
		return
	var ppl := []
	for o in w.w["C"].values():
		if int(o["id"]) != int(c["id"]) and not o.get("player", false) and String(o["name"]).length() >= 2:
			ppl.append(o)
	var months := []   # v0.13：按年分组（变量名沿用）
	for e in lg:
		var m := int(w.cal(int(e[0]))[0])
		if months.is_empty() or int(months[-1][0]) != m:
			months.append([m, []])
		months[-1][1].append(e)
	var first := 0 if life_all else maxi(0, months.size() - 3)
	var pname := String(w.P()["name"])
	for mi in range(months.size() - 1, first - 1, -1):
		var m: int = months[mi][0]
		var hr = row(cc, 8)
		H("青庐" + w.year_name(m), 20, C_ACCENT, hr)
		var age_txt := ""
		if c.get("player", false):
			age_txt = "%d 岁 · " % int((GS.AGE0 * 12 + m * 12 + 1) / 12)
		elif c.has("age"):
			var ay := int(float(c["age"]) - float(int(w.w["day"]) - (m * 12 + 1)) / 12.0)
			if ay > 0:
				age_txt = "%d 岁 · " % ay
		var sub = L("%s%d 件" % [age_txt, months[mi][1].size()], 13, C_DIM, hr)
		sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for e in months[mi][1]:
			var er = row(cc, 6)
			var dl = L(w.MONTH_NAMES[int(w.cal(int(e[0]))[1]) - 1], 13, C_GOLD, er)
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
			var tv = VBoxContainer.new()
			tv.add_theme_constant_override("separation", 1)
			tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tp.add_child(tv)
			var tl = L(String(e[1]).replace(pname, "她") if c.get("player", false) else String(e[1]), 14, C_TEXT, tv)
			tl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			# v0.15：这件事改动了什么（悟性+1　得「青玉符」　与某某好感+8），小字一行
			var fxs: String = w.fx_text(e[2]) if e.size() > 2 else ""
			if fxs != "":
				L(fxs.replace(pname, "她"), 12, Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.8), tv)
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
	elif not pre.is_empty():
		_life_pre(pre, cc)

## 句首“十三岁，”“六岁那年”“十二岁时”去掉（Web 模板没有 RegEx，手写）
static func _strip_age(t: String) -> String:
	var i := 0
	while i < t.length() and "零一二三四五六七八九十百".contains(t[i]):
		i += 1
	if i == 0 or i >= t.length() or t[i] != "岁":
		return t
	i += 1
	for suf in ["那年", "时"]:
		if t.substr(i, suf.length()) == suf:
			i += suf.length()
			break
	if i < t.length() and t[i] == "，":
		i += 1
	return t.substr(i) if i < t.length() else t

## v0.12 前尘：入青庐之前的经历，按年岁排（旧档第一次看时按种子补写）
func _life_pre(pre: Array, cc: VBoxContainer) -> void:
	var hr = row(cc, 8)
	H("前尘", 20, C_ACCENT, hr)
	var sub = L("入局之前 · %d 件" % pre.size(), 13, C_DIM, hr)

	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in range(pre.size() - 1, -1, -1):
		var e: Array = pre[i]
		var er = row(cc, 6)
		var dl = L("%s岁" % g.world.saga().cn(int(e[0])), 13, C_GOLD, er)
		dl.custom_minimum_size = Vector2(52, 0)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var tl = L(_strip_age(String(e[1])), 14, C_TEXT, er)   # 左边已标了年岁，句首的“十三岁，”不再重复
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

func _rel_depth(r: Dictionary) -> float:
	return absf(float(r["f"])) + float(r["g"]) + r["t"].size() * 50

# ------------------------------------------------------------ 调试场景（只在调试导出里可用，给验收截图）
func _dev_put_home(r: RandomNumberGenerator, d: int) -> void:
	var it := Gear.make(g, g.world, r, "储物袋", 1, "调试：放进来的。", d)
	g.s["gear"]["home"].append(it)

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
		"saga":
			# 调试（v0.12）：跑 200 日，打开江湖里履历最长的人的生平（含前尘），全部月份展开
			_dev("jianghu")
			for i in 160:
				g.tick("biguan")
				g.world.auto_choose()
			g.world.close()
			var best = null
			for c in g.world.npcs():
				if best == null or c["log"].size() > best["log"].size():
					best = c
			tab = "jianghu"
			person_id = int(best["id"])
			person_tab = "life"
			life_all = true
			modal = {"kind": "person"}
			g.notices.clear()
			_save()
			refresh()
		"extra":
			# 调试：灵脉第五点的二选一（第一次历练回来后）
			g.new_game("苏青禾", "sect", 5, true)
			g.s["portrait"] = _hero_roll("p5")
			g.s["trips_done"] = 1
			g.s["extra"] = ""
			screen = "game"
			modal = {}
			sheet = ""
			tab = "home"
			g.notices.clear()
			refresh()
		"pack", "chron", "seclude":
			# 调试（v0.13）：行囊页 / 她的生平（按年）/ 筑基后闭关二十年出关
			g.new_game("苏青禾", "sect", 5, true)
			g.s["portrait"] = _hero_roll("p5")
			g.s["trips_done"] = 1
			g.s["extra"] = "field"
			screen = "game"
			modal = {}
			sheet = ""
			for i in 40:
				g.tick("biguan")
				g.world.auto_choose()
				g.world.close()
			if cmd == "seclude":
				g._raise_to(9)
				g.s["ration"] = 30
				_seclude("years", 20)
				tab = "home"
			elif cmd == "pack":
				tab = "pack"
			else:
				tab = "life"
			g.notices.clear()
			_save()
			refresh()
		"story", "jianghu", "person", "create_rnd", "life", "guide", "guide_depart":
			if cmd == "create_rnd":
				screen = "create"
				_reroll_portrait()
				refresh()
				return cmd
			g.new_game("苏青禾", "sect", 5, true)
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
		"map", "map_place", "roam", "meet":
			# 调试（v0.11）：世界图 / 点开一处 / 在坊市游历 / 上前搭话
			_dev("jianghu")
			var W = g.world
			g.s["xiuwei"] = 450   # 炼气三层（v0.14.2：炼气 1800）
			TV.ensure(W)
			W.w["unl"] = {}
			W.w["heard"] = {"云梦泽": 1, "玄霜谷": 2, "古战场": 1}
			for q in ["后山", "坊市", "寒潭", "药王谷", "青云宗"]:
				W.w["unl"][q] = 1
				W.w["uwhy"][q] = "调试"
			var ac: Array = W.acquaintances()
			for k in mini(3, ac.size()):
				ac[k]["place"] = ["坊市", "药王谷", "坊市"][k]
			tab = "depart"
			if cmd == "map_place":
				sel_place = "坊市"
				sheet = "place"
			if cmd in ["roam", "meet"]:
				sheet = ""
				W.w["unl"][dev_roam_pl] = 1
				g.start_roam(dev_roam_pl)
				W.close()
				g.roam_spot(0)
				W.close()
				g.s["roam"]["log"] = g.s["roam"]["log"].slice(-2)
			if cmd == "meet":
				var who: Array = TV.present_at(W, "坊市")
				W.w["appr"] = -1
				TV.approach(W, int(who[0]["id"]), "坊市", "茶肆")
			g.notices.clear()
			_save()
			refresh()
		"item":
			_dev("equip")
			var fb = Gear.eq(g, "fabao")
			if fb != null:
				item_u = int(fb["u"])
				item_shop = false
				sheet = "item"
				refresh()
		"equip", "shop", "auc":
			# 调试（v0.14）：行囊页带几件器物 / 坊市器物铺 / 拍卖会（标明是调试场景）
			if cmd == "equip":
				_dev("pack")
			else:
				_dev("roam")
				if cmd == "auc":
					while (int(g.s["day"]) - 1) % 12 + 1 != 3:
						g.s["day"] = int(g.s["day"]) + 1
					g.world.w["day"] = int(g.s["day"])
				g.s["lingshi"] = 600 if cmd == "auc" else 160
			var r := RandomNumberGenerator.new()
			r.seed = 1414
			var d := int(g.s["day"])
			var put := [["剑", 1, true], ["道袍", 1, true], ["玉佩", 2, true], ["护身符", 0, true], ["铃", 0, false]]
			if cmd == "equip":
				put.append(["软甲", 2, false])
			for x in put:
				var it := Gear.make(g, g.world, r, String(x[0]), int(x[1]), "调试：放进来的。", d)
				Gear.give_her(g, it, "调试")
				if x[2] and not it.has("c"):
					Gear.equip(g, int(it["u"]))
			if cmd == "equip":
				_dev_put_home(r, d)
				tab = "pack"
			else:
				sheet = cmd
			g.notices.clear()
			_save()
			refresh()
		_ when cmd.begins_with("roam:"):
			# 调试（v0.11.2）：在指定一处游历，看各地画风
			dev_roam_pl = cmd.substr(5)
			var rr := _dev("roam")
			dev_roam_pl = "坊市"
			return rr
		"map_all":
			# 调试（v0.11.2）：12 处全认得，看世界图小景
			_dev("map")
			for q in TV.ORDER:
				g.world.w["unl"][q] = 1
			g.world.w["heard"] = {}
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
		_ when cmd.begins_with("artsheet"):
			# 调试（v0.14.3）：16 个随机人物大图（纸底画框，同生平页），半数强制带外披，看衣袍/头发抠边
			var omode := cmd == "artsheet:o"   # 每种外披都上一遍：粉披配紫袍（玩家截图那套）
			var b0 := 1 if omode else (int(cmd.substr(9)) if cmd.length() > 9 else 1)
			var old_a = get_node_or_null("DevSheet")
			if old_a != null:
				old_a.free()
			var bga := ColorRect.new()
			bga.name = "DevSheet"
			bga.color = Color(0.93, 0.91, 0.86)
			bga.set_anchors_preset(Control.PRESET_FULL_RECT)
			add_child(bga)
			var ga := GridContainer.new()
			ga.columns = 4
			ga.set_anchors_preset(Control.PRESET_FULL_RECT)
			bga.add_child(ga)
			for k in 16:
				var sexa := "m" if k % 4 == 3 else "f"
				var spa: Dictionary = PLib.roll((b0 * 7919 + k * 104729) % 1000000000, {"sex": sexa, "elder": false, "demonic": false, "robe_v": 10})
				if omode:
					sexa = "f" if k < 10 else "m"
					spa = PLib.roll(k * 104729 + 17, {"sex": sexa, "elder": false, "demonic": false, "robe_v": 10})
					if spa.robe in PLib.lib.pools.fixed:
						spa.robe = PLib.lib.pools.robes[sexa][0]
					var pz: Array = PLib.lib.pools.outers[sexa]
					spa.outer = pz[k % pz.size()]
					spa.robe_tint = [118, 84, 150]
					spa.outer_tint = [206, 158, 176] if k % 2 == 0 else [196, 150, 168]
				elif k % 2 == 0 and spa.get("outer") == null and not (spa.robe in PLib.lib.pools.fixed):
					var po: Array = PLib.lib.pools.outers[sexa]
					spa.outer = po[(b0 + k) % po.size()]
				var pfa = PanelContainer.new()
				pfa.add_theme_stylebox_override("panel", _sb(Color(0.96, 0.94, 0.9, 1), Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.7), 6, 1, 2))
				ga.add_child(pfa)
				var pba = PBox.new()
				pba.custom_minimum_size = Vector2(84, 112)
				pba.no_bake = true   # 和生平页大立绘一样逐层画，不烘焙
				pfa.add_child(pba)
				pba.setup(spa, PBox.BUST, 0.0)
			return "ok"
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
			g.new_game("苏青禾", "sect", 3, true)
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
				g.s["ending"] = "feisheng"
				g.s["ended"] = true
				g.s["plv"] = 18
				g.s["log"].append({"day": 41, "text": "九道雷劫过尽，她白日飞升。"})
			g.notices.clear()
			_save()
			refresh()
		"laogui", "depart", "home", "cult":
			g.new_game("苏青禾", "sect", 3, true)
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
			g.s["xiuwei"] = 900   # 炼气五层（v0.14.2：炼气 1800）
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
