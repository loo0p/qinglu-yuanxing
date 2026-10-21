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

func setup(spec: Dictionary, crop_rect: Rect2 = BUST, motion: float = 1.0) -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	crop = crop_rect
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
	set_process(not complete)
	queue_redraw()

func _process(delta: float) -> void:
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
	draw_rect(Rect2(186, 230, 60, 90), ink)
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
	if view == null or size.x <= 0 or size.y <= 0:
		return
	var s := maxf(size.x / crop.size.x, size.y / crop.size.y) if cover else minf(size.x / crop.size.x, size.y / crop.size.y)
	view.scale = Vector2(s, s)
	view.position = -crop.position * s + (size - crop.size * s) * 0.5
	queue_redraw()
