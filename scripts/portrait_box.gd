extends Control
## 立绘框：把 Portrait5View（lib5 分层立绘，432×576 画布）按裁切框缩放进一个普通 Control。
## crop 用画布坐标；cover=true 时铺满（裁边），否则完整放下。motion=0 不眨眼不摆动（缩略图用，省电）。
const View = preload("res://addons/portrait5/portrait5_view.gd")
const BUST := Rect2(24, 0, 384, 512)
const FACE := Rect2(104, 40, 224, 250)

var view: Node2D
var crop := BUST
var cover := true

func setup(spec: Dictionary, crop_rect: Rect2 = BUST, motion: float = 1.0) -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	crop = crop_rect
	if view == null:
		view = View.new()
		add_child(view)
	view.motion = motion
	view.setup(spec)
	_fit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit()

func _fit() -> void:
	if view == null or size.x <= 0 or size.y <= 0:
		return
	var s := maxf(size.x / crop.size.x, size.y / crop.size.y) if cover else minf(size.x / crop.size.x, size.y / crop.size.y)
	view.scale = Vector2(s, s)
	view.position = -crop.position * s + (size - crop.size * s) * 0.5
