extends Control
## 立绘框：把 Portrait5View（lib5 分层立绘，432×576 画布）按裁切框缩放进一个普通 Control。
## crop 用画布坐标；cover=true 时铺满（裁边），否则完整放下。motion=0 不眨眼不摆动（缩略图用，省电）。
const View = preload("res://addons/portrait5/portrait5_view.gd")
const BUST := Rect2(24, 0, 384, 512)
## v0.16.4：脸卡从 y=40 起裁，高髻、双髻的上半截在画面外。改从画布顶裁到下巴，发髻留在框里。
const FACE := Rect2(88, 0, 256, 300)

const Lib = preload("res://addons/portrait5/portrait5_lib.gd")
var view: Node2D
var crop := BUST
var cover := true
var spec: Dictionary = {}
var complete := true    # Web 上部件还没下载完时先不显示，到齐了再画
var _gen := -1
var _wait := 0.0
## v0.8 静态缩略图烘焙：motion=0 的小头像（江湖簿、生平、关系卡）画好一次后，用离屏 SubViewport 拍成一张贴图缓存，
## 之后同一个人同一个尺寸只贴一张图，不再挂十几层贴图节点（手机上省 draw call 与透明叠画）。拍不到（无头/不支持）就照旧分层画。
static var _cache := {}
static var bake_ok := true
var _baked: Texture2D = null
var _key := ""
var _sv: SubViewport = null
var _bake_frames := -1
var _k := 2.0
var no_bake := false
## 同一格换人时（创建页）留着上一张，新的好了再淡入。别的立绘不填。
var hold_id := ""
const PAPER := Color(0.96, 0.94, 0.9, 1.0)
const FADE_SEC := 0.15
var _fade := 1.0
var _fading := false
static var _slot := {}
var _gsv: SubViewport = null
var _gframes := -1
var _grab_pending := false

func setup(spec: Dictionary, crop_rect: Rect2 = BUST, motion: float = 1.0) -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # 缩小时不起锯齿（贴图带 mipmap，见 Portrait5Lib.put）
	crop = crop_rect
	self.spec = spec
	var spec_s := JSON.stringify(spec)
	var other := _other_hold(spec_s)
	if motion <= 0.0 and bake_ok and not no_bake:
		_key = "%s|%s" % [spec_s, str(crop)]
		if _cache.has(_key + "|" + _size_key()):
			_use_baked(_cache[_key + "|" + _size_key()])
			_arm_fade(other, true)
			return
	if view == null:
		view = View.new()
		add_child(view)
	view.motion = motion
	self.spec = spec
	_build()
	_fit()
	_arm_fade(other, complete)

func _other_hold(spec_s: String) -> bool:
	if hold_id == "" or not _slot.has(hold_id):
		return false
	return str(_slot[hold_id].get("spec", "")) != "" and str(_slot[hold_id].get("spec", "")) != spec_s

func _arm_fade(other: bool, ready: bool) -> void:
	if not ready:
		_fade = 0.0
		_fading = true
		if view != null:
			view.visible = false
		set_process(true)
		queue_redraw()
		return
	if other:
		_fade = 0.0
		_fading = true
		if view != null:
			view.modulate.a = 0.0
		set_process(true)
		queue_redraw()
		return
	_fade = 1.0
	_fading = false
	if view != null:
		view.modulate.a = 1.0
	_queue_grab()
	queue_redraw()

func _prev_shot() -> Texture2D:
	if hold_id == "" or not _slot.has(hold_id):
		return null
	if str(_slot[hold_id].get("spec", "")) == JSON.stringify(spec):
		return null
	return _slot[hold_id].get("tex")

func _build() -> void:
	Lib.miss = 0
	Lib.low = view.motion <= 0.0   # 缩略图（不动的）下载排在主立绘后面
	view.setup(spec)
	Lib.low = false
	var was := complete
	complete = Lib.miss == 0
	view.visible = complete
	if complete and not was:
		_fade = 0.0
		_fading = true
		view.modulate.a = 0.0
	_gen = Lib.gen
	set_process(not complete or _key != "" or _fading or _gframes > 0)
	queue_redraw()

func _size_key() -> String:
	var sz := size if size.x > 0 else custom_minimum_size
	return "%dx%d" % [int(sz.x), int(sz.y)]

func _use_baked(t: Texture2D) -> void:
	_baked = t
	complete = true
	if view != null:
		view.queue_free()
		view = null
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA   # 离屏透明底拍出来的是预乘色
	material = m
	set_process(false)
	queue_redraw()

func _start_bake() -> void:
	if size.x < 8 or size.y < 8:
		return
	_k = clampf(256.0 / maxf(size.x, size.y), 1.0, 2.0)
	_sv = SubViewport.new()
	_sv.transparent_bg = true
	_sv.disable_3d = true
	_sv.size = Vector2i(ceili(size.x * _k), ceili(size.y * _k))
	_sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	_sv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # 部件缩小拍照时不起锯齿
	# 视口清成透明。底头贴图本身是不透明纸色，裁切缝若露出来，垫一层与人物卡画框相同的纸色，不再落成白底或黑底。
	var paper := ColorRect.new()
	paper.color = Color(0.96, 0.94, 0.9, 1)
	paper.position = Vector2.ZERO
	paper.size = Vector2(_sv.size)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sv.add_child(paper)
	var v2 = View.new()
	v2.motion = 0.0
	_sv.add_child(v2)
	add_child(_sv)
	v2.setup(spec)
	var s := maxf(size.x / crop.size.x, size.y / crop.size.y) if cover else minf(size.x / crop.size.x, size.y / crop.size.y)
	v2.scale = Vector2(s, s) * _k
	v2.position = (-crop.position * s + (size - crop.size * s) * 0.5) * _k
	_bake_frames = 3

func _finish_bake() -> void:
	var img: Image = _sv.get_texture().get_image() if _sv != null else null
	if _sv != null:
		_sv.queue_free()
		_sv = null
	if img == null or img.is_empty() or img.is_invisible():
		bake_ok = false   # 这台设备拍不到：以后都照旧分层画
		set_process(false)
		return
	img.generate_mipmaps()   # 烘的是 1–2 倍大小，贴回去时再缩小
	var t := ImageTexture.create_from_image(img)
	if _cache.size() > 160:
		_cache.clear()
	_cache[_key + "|" + _size_key()] = t
	_use_baked(t)

func _process(delta: float) -> void:
	if _grab_pending and _gsv == null and not _fading and size.x >= 8.0:
		_queue_grab()
	if _fading and (complete or _baked != null):
		_fade = minf(1.0, _fade + delta / FADE_SEC)
		if view != null:
			view.modulate.a = _fade
		queue_redraw()
		if _fade >= 1.0:
			_fading = false
			_queue_grab()
	if _gframes > 0:
		_gframes -= 1
		if _gframes == 0:
			_finish_grab()
	if _baked != null and not _fading and _gframes < 0:
		set_process(false)
		return
	if _bake_frames > 0:
		_bake_frames -= 1
		if _bake_frames == 0:
			_finish_bake()
		return
	if complete and _key != "" and bake_ok and _sv == null and is_visible_in_tree():
		if _cache.has(_key + "|" + _size_key()):
			_use_baked(_cache[_key + "|" + _size_key()])
		else:
			_start_bake()
		return
	_wait += delta
	if _wait < 0.15 or Lib.gen == _gen:
		return
	_wait = 0.0
	_build()

## 部件没到齐、或新立绘还在淡入时：只垫纸色，或留着上一张。不画剪影。
func _draw() -> void:
	var under := (not complete) or _fade < 0.999
	if under and size.x > 1.0 and size.y > 1.0:
		var shot := _prev_shot()
		if shot != null:
			var ss := shot.get_size()
			if ss.x > 1.0 and ss.y > 1.0:
				var sc := maxf(size.x / ss.x, size.y / ss.y)
				var dst := ss * sc
				draw_texture_rect(shot, Rect2((size - dst) * 0.5, dst), false)
			else:
				draw_rect(Rect2(Vector2.ZERO, size), PAPER)
		else:
			draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	if _baked != null:
		var ts := _baked.get_size()
		if ts.x > 1.0 and ts.y > 1.0 and size.x > 1.0 and size.y > 1.0:
			# 铺满并裁边，不把脸拉扁。控件比例和烘焙时一致时，正好贴满。
			var sc2 := maxf(size.x / ts.x, size.y / ts.y)
			var dst2 := ts * sc2
			draw_texture_rect(_baked, Rect2((size - dst2) * 0.5, dst2), false, Color(1, 1, 1, _fade))
		return

func _queue_grab() -> void:
	if hold_id == "" or not complete or _gsv != null:
		return
	if _slot.has(hold_id) and str(_slot[hold_id].get("spec", "")) == JSON.stringify(spec):
		return
	if size.x < 8.0 or size.y < 8.0:
		_grab_pending = true
		set_process(true)
		return
	_grab_pending = false
	_gsv = SubViewport.new()
	_gsv.transparent_bg = false
	_gsv.disable_3d = true
	_gsv.size = Vector2i(maxi(8, int(size.x)), maxi(8, int(size.y)))
	_gsv.render_target_update_mode = SubViewport.UPDATE_ONCE
	var paper := ColorRect.new()
	paper.color = PAPER
	paper.position = Vector2.ZERO
	paper.size = Vector2(_gsv.size)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gsv.add_child(paper)
	var v2 = View.new()
	v2.motion = 0.0
	_gsv.add_child(v2)
	add_child(_gsv)
	v2.setup(spec)
	var s := maxf(size.x / crop.size.x, size.y / crop.size.y) if cover else minf(size.x / crop.size.x, size.y / crop.size.y)
	v2.scale = Vector2(s, s)
	v2.position = -crop.position * s + (size - crop.size * s) * 0.5
	_gframes = 3
	set_process(true)

func _finish_grab() -> void:
	var img: Image = _gsv.get_texture().get_image() if _gsv != null else null
	if _gsv != null:
		_gsv.queue_free()
		_gsv = null
	_gframes = -1
	if img == null or img.is_empty():
		return
	_slot[hold_id] = {"tex": ImageTexture.create_from_image(img), "spec": JSON.stringify(spec)}

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit()

func _fit() -> void:
	if _baked != null:
		var ts := _baked.get_size()
		if _key != "" and ts.y > 1.0 and size.y > 1.0:
			var ba := ts.x / ts.y
			var ca := size.x / size.y
			if absf(ba - ca) > 0.05:
				# 行高变了之后不要拿旧图硬拉。丢掉这张，按新尺寸重拍。
				_baked = null
				material = null
				set_process(true)
		queue_redraw()
		return
	if view == null or size.x <= 0 or size.y <= 0:
		return
	var s := maxf(size.x / crop.size.x, size.y / crop.size.y) if cover else minf(size.x / crop.size.x, size.y / crop.size.y)
	view.scale = Vector2(s, s)
	view.position = -crop.position * s + (size - crop.size * s) * 0.5
	queue_redraw()
