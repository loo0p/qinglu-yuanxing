extends RefCounted
## 自制水墨小图标（32×32，透明底，显示成 22–24px）。给按钮、页签、底栏用，不拿器物图充动作。
## 笔画加粗、实心。主钮用米白，其余用深墨。许可：本仓库自制。

static var _cache := {}

static func tex(id: String, light: bool = false) -> Texture2D:
	var key := id + ("|l" if light else "")
	if _cache.has(key):
		return _cache[key]
	# 玩家版 Web 模板 deprecated=no，没有 Image.create，用 create_empty。
	var img: Image = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# 主钮上用米白填色，木牌和底栏上用深墨。都是实心，不是细线。
	var ink := Color(0.99, 0.96, 0.90, 1) if light else Color(0.22, 0.16, 0.11, 1)
	var cin := Color(1.0, 0.90, 0.62, 1) if light else Color(0.55, 0.18, 0.12, 1)
	match id:
		"book":
			_line(img, 7, 6, 7, 22, ink, 4)
			_line(img, 7, 6, 21, 8, ink, 4)
			_line(img, 21, 8, 21, 23, ink, 4)
			_line(img, 7, 22, 21, 23, ink, 4)
			_line(img, 14, 7, 14, 22, ink, 3)
		"tea":
			_line(img, 6, 14, 10, 22, ink, 4)
			_line(img, 22, 14, 18, 22, ink, 4)
			_line(img, 10, 22, 18, 22, ink, 4)
			_line(img, 6, 14, 22, 14, ink, 4)
			_line(img, 12, 10, 12, 6, cin, 3)
			_line(img, 16, 11, 16, 7, cin, 3)
		"sword":
			_line(img, 14, 3, 14, 18, ink, 4)
			_line(img, 8, 18, 20, 18, ink, 4)
			_line(img, 14, 18, 14, 25, cin, 4)
		"bottle":
			_line(img, 12, 4, 16, 4, ink, 4)
			_line(img, 13, 4, 13, 8, ink, 3)
			_line(img, 15, 4, 15, 8, ink, 3)
			_line(img, 9, 8, 19, 8, ink, 4)
			_line(img, 9, 8, 8, 24, ink, 4)
			_line(img, 19, 8, 20, 24, ink, 4)
			_line(img, 8, 24, 20, 24, ink, 4)
			_disc(img, 14, 16, 2, cin)
		"pair":
			_disc(img, 9, 8, 3, ink)
			_disc(img, 18, 8, 3, ink)
			_line(img, 9, 12, 9, 22, ink, 4)
			_line(img, 18, 12, 18, 22, ink, 4)
			_line(img, 6, 16, 12, 16, ink, 3)
			_line(img, 15, 16, 21, 16, ink, 3)
		"path":
			_disc(img, 8, 20, 2, ink)
			_disc(img, 14, 13, 2, ink)
			_disc(img, 20, 7, 2, cin)
			_line(img, 8, 20, 14, 13, ink, 3)
			_line(img, 14, 13, 20, 7, ink, 3)
		"gate":
			_line(img, 6, 24, 6, 8, ink, 4)
			_line(img, 22, 24, 22, 8, ink, 4)
			_line(img, 6, 8, 14, 4, ink, 4)
			_line(img, 22, 8, 14, 4, ink, 4)
			_line(img, 14, 6, 14, 24, ink, 3)
		"herb":
			_line(img, 14, 24, 14, 10, ink, 4)
			_line(img, 14, 16, 7, 9, ink, 4)
			_line(img, 14, 14, 21, 8, ink, 4)
			_disc(img, 14, 8, 2, cin)
		"scroll":
			_line(img, 8, 6, 8, 22, ink, 4)
			_line(img, 20, 6, 20, 22, ink, 4)
			_line(img, 8, 6, 20, 6, ink, 4)
			_line(img, 8, 22, 20, 22, ink, 4)
			_line(img, 11, 11, 17, 11, cin, 3)
			_line(img, 11, 15, 17, 15, cin, 3)
		"shop":
			_line(img, 4, 12, 14, 5, ink, 4)
			_line(img, 24, 12, 14, 5, ink, 4)
			_line(img, 7, 12, 7, 23, ink, 4)
			_line(img, 21, 12, 21, 23, ink, 4)
			_line(img, 7, 23, 21, 23, ink, 4)
			_line(img, 12, 23, 12, 15, cin, 4)
			_line(img, 16, 23, 16, 15, cin, 4)
		"mountain":
			_line(img, 3, 22, 11, 8, ink, 4)
			_line(img, 11, 8, 16, 16, ink, 4)
			_line(img, 16, 16, 22, 6, ink, 4)
			_line(img, 22, 6, 26, 22, ink, 4)
			_line(img, 3, 22, 26, 22, ink, 4)
		"home":
			_line(img, 4, 14, 14, 6, ink, 4)
			_line(img, 24, 14, 14, 6, ink, 4)
			_line(img, 7, 14, 7, 23, ink, 4)
			_line(img, 21, 14, 21, 23, ink, 4)
			_line(img, 7, 23, 21, 23, ink, 4)
			_disc(img, 14, 18, 2, cin)
		"bag":
			_line(img, 9, 10, 9, 23, ink, 4)
			_line(img, 19, 10, 19, 23, ink, 4)
			_line(img, 9, 23, 19, 23, ink, 4)
			_line(img, 9, 10, 19, 10, ink, 4)
			_line(img, 11, 10, 11, 7, ink, 4)
			_line(img, 17, 10, 17, 7, ink, 4)
			_line(img, 11, 7, 17, 7, ink, 4)
		"heart":
			_disc(img, 10, 11, 3, cin)
			_disc(img, 17, 11, 3, cin)
			_line(img, 7, 13, 14, 22, cin, 4)
			_line(img, 20, 13, 14, 22, cin, 4)
		"seal":
			_rect(img, 6, 6, 16, 16, cin)
			_disc(img, 14, 14, 3, Color(0.96, 0.93, 0.86, 1))
		"back":
			_line(img, 24, 16, 8, 16, ink, 4)
			_line(img, 8, 16, 16, 8, ink, 4)
			_line(img, 8, 16, 16, 24, ink, 4)
		_:
			_disc(img, 16, 16, 6, ink)
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

static func _plot(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, col)

static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color, w: int) -> void:
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	while true:
		for oy in range(-w + 1, w):
			for ox in range(-w + 1, w):
				if ox * ox + oy * oy <= w * w:
					_plot(img, x0 + ox, y0 + oy, col)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy

static func _disc(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
				_plot(img, x, y, col)

static func _rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	_line(img, x, y, x + w, y, col, 1)
	_line(img, x, y + h, x + w, y + h, col, 1)
	_line(img, x, y, x, y + h, col, 1)
	_line(img, x + w, y, x + w, y + h, col, 1)
