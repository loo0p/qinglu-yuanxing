extends Control
## 立绘框：把 Portrait5View（lib5 分层立绘，432×576 画布）按裁切框缩放进一个普通 Control。
## crop 用画布坐标；cover=true 时铺满（裁边），否则完整放下。motion=0 不眨眼不摆动（缩略图用，省电）。
const View = preload("res://addons/portrait5/portrait5_view.gd")
const BUST := Rect2(24, 0, 384, 512)
const FACE := Rect2(104, 40, 224, 250)

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

func setup(spec: Dictionary, crop_rect: Rect2 = BUST, motion: float = 1.0) -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	crop = crop_rect
	self.spec = spec
	if motion <= 0.0 and bake_ok and not no_bake:
		_key = "%s|%s" % [JSON.stringify(spec), str(crop)]
		if _cache.has(_key + "|" + _size_key()):
			_use_baked(_cache[_key + "|" + _size_key()])
			return
	if view == null:
		view = View.new()
		add_child(view)
	view.motion = motion
	self.spec = spec
	_build()
	_fit()

func _build() -> void:
	Lib.miss = 0
	Lib.low = view.motion <= 0.0   # 缩略图（不动的）下载排在主立绘后面
	view.setup(spec)
	Lib.low = false
	complete = Lib.miss == 0
	view.visible = complete
	_gen = Lib.gen
	set_process(not complete or _key != "")
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
	var t := ImageTexture.create_from_image(img)
	if _cache.size() > 160:
		_cache.clear()
	_cache[_key + "|" + _size_key()] = t
	_use_baked(t)

func _process(delta: float) -> void:
	if _baked != null:
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
	_pulse += delta
	if not complete:
		queue_redraw()
	if _wait < 0.15 or Lib.gen == _gen:
		return
	_wait = 0.0
	_build()

## 部件没到齐时画一个淡墨剪影（头、颈、肩），轻轻呼吸，免得一片空白
var _pulse := 0.0
func _draw() -> void:
	if _baked != null:
		draw_texture_rect(_baked, Rect2(Vector2.ZERO, size), false)
		return
	if complete or view == null:
		return
	var a := 0.10 + 0.05 * sin(_pulse * 2.4)
	var ink := Color(0.29, 0.25, 0.2, a)
	draw_set_transform(view.position, 0.0, view.scale)
	var body := PackedVector2Array()
	for i in 25:
		var t := PI + PI * float(i) / 24.0
		body.append(Vector2(216 + cos(t) * 190, 600 + sin(t) * 300))
	draw_colored_polygon(body, ink)
	draw_rect(Rect2(188, 256, 56, 45), ink)   # 颈：接在头下、肩上，不与两者重叠（重叠处会显深）
	var head := PackedVector2Array()
	for i in 40:
		var t := TAU * float(i) / 40.0
		head.append(Vector2(216 + cos(t) * 74, 165 + sin(t) * 92))
	draw_colored_polygon(head, Color(ink.r, ink.g, ink.b, a * 1.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit()

func _fit() -> void:
	if _baked != null:
		queue_redraw()
		return
	if view == null or size.x <= 0 or size.y <= 0:
		return
	var s := maxf(size.x / crop.size.x, size.y / crop.size.y) if cover else minf(size.x / crop.size.x, size.y / crop.size.y)
	view.scale = Vector2(s, s)
	view.position = -crop.position * s + (size - crop.size * s) * 0.5
	queue_redraw()
