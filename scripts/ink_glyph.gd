extends RefCounted
## 自制水墨小图标（28×28，透明底）。给按钮、页签、底栏用，不拿器物图充动作。
## 笔画是墨线，不是色块。许可：本仓库自制。

static var _cache := {}

static func tex(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	# 玩家版 Web 模板 deprecated=no，没有 Image.create，用 create_empty。
	var img: Image = Image.create_empty(28, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := Color(0.29, 0.24, 0.18, 1)
	var cin := Color(0.62, 0.22, 0.14, 1)
	match id:
		"book":
			_line(img, 7, 6, 7, 22, ink, 2)
			_line(img, 7, 6, 21, 8, ink, 2)
			_line(img, 21, 8, 21, 23, ink, 2)
			_line(img, 7, 22, 21, 23, ink, 2)
			_line(img, 14, 7, 14, 22, ink, 1)
		"tea":
			_line(img, 6, 14, 10, 22, ink, 2)
			_line(img, 22, 14, 18, 22, ink, 2)
			_line(img, 10, 22, 18, 22, ink, 2)
			_line(img, 6, 14, 22, 14, ink, 2)
			_line(img, 12, 10, 12, 6, cin, 1)
			_line(img, 16, 11, 16, 7, cin, 1)
		"sword":
			_line(img, 14, 3, 14, 18, ink, 2)
			_line(img, 8, 18, 20, 18, ink, 2)
			_line(img, 14, 18, 14, 25, cin, 2)
		"bottle":
			_line(img, 12, 4, 16, 4, ink, 2)
			_line(img, 13, 4, 13, 8, ink, 1)
			_line(img, 15, 4, 15, 8, ink, 1)
			_line(img, 9, 8, 19, 8, ink, 2)
			_line(img, 9, 8, 8, 24, ink, 2)
			_line(img, 19, 8, 20, 24, ink, 2)
			_line(img, 8, 24, 20, 24, ink, 2)
			_disc(img, 14, 16, 2, cin)
		"pair":
			_disc(img, 9, 8, 3, ink)
			_disc(img, 18, 8, 3, ink)
			_line(img, 9, 12, 9, 22, ink, 2)
			_line(img, 18, 12, 18, 22, ink, 2)
			_line(img, 6, 16, 12, 16, ink, 1)
			_line(img, 15, 16, 21, 16, ink, 1)
		"path":
			_disc(img, 8, 20, 2, ink)
			_disc(img, 14, 13, 2, ink)
			_disc(img, 20, 7, 2, cin)
			_line(img, 8, 20, 14, 13, ink, 1)
			_line(img, 14, 13, 20, 7, ink, 1)
		"gate":
			_line(img, 6, 24, 6, 8, ink, 2)
			_line(img, 22, 24, 22, 8, ink, 2)
			_line(img, 6, 8, 14, 4, ink, 2)
			_line(img, 22, 8, 14, 4, ink, 2)
			_line(img, 14, 6, 14, 24, ink, 1)
		"herb":
			_line(img, 14, 24, 14, 10, ink, 2)
			_line(img, 14, 16, 7, 9, ink, 2)
			_line(img, 14, 14, 21, 8, ink, 2)
			_disc(img, 14, 8, 2, cin)
		"scroll":
			_line(img, 8, 6, 8, 22, ink, 2)
			_line(img, 20, 6, 20, 22, ink, 2)
			_line(img, 8, 6, 20, 6, ink, 2)
			_line(img, 8, 22, 20, 22, ink, 2)
			_line(img, 11, 11, 17, 11, cin, 1)
			_line(img, 11, 15, 17, 15, cin, 1)
		"shop":
			_line(img, 4, 12, 14, 5, ink, 2)
			_line(img, 24, 12, 14, 5, ink, 2)
			_line(img, 7, 12, 7, 23, ink, 2)
			_line(img, 21, 12, 21, 23, ink, 2)
			_line(img, 7, 23, 21, 23, ink, 2)
			_line(img, 12, 23, 12, 15, cin, 2)
			_line(img, 16, 23, 16, 15, cin, 2)
		"mountain":
			_line(img, 3, 22, 11, 8, ink, 2)
			_line(img, 11, 8, 16, 16, ink, 2)
			_line(img, 16, 16, 22, 6, ink, 2)
			_line(img, 22, 6, 26, 22, ink, 2)
			_line(img, 3, 22, 26, 22, ink, 2)
		"home":
			_line(img, 4, 14, 14, 6, ink, 2)
			_line(img, 24, 14, 14, 6, ink, 2)
			_line(img, 7, 14, 7, 23, ink, 2)
			_line(img, 21, 14, 21, 23, ink, 2)
			_line(img, 7, 23, 21, 23, ink, 2)
			_disc(img, 14, 18, 2, cin)
		"bag":
			_line(img, 9, 10, 9, 23, ink, 2)
			_line(img, 19, 10, 19, 23, ink, 2)
			_line(img, 9, 23, 19, 23, ink, 2)
			_line(img, 9, 10, 19, 10, ink, 2)
			_line(img, 11, 10, 11, 7, ink, 2)
			_line(img, 17, 10, 17, 7, ink, 2)
			_line(img, 11, 7, 17, 7, ink, 2)
		"heart":
			_disc(img, 10, 11, 3, cin)
			_disc(img, 17, 11, 3, cin)
			_line(img, 7, 13, 14, 22, cin, 2)
			_line(img, 20, 13, 14, 22, cin, 2)
		"seal":
			_rect(img, 6, 6, 16, 16, cin)
			_disc(img, 14, 14, 2, Color(0.96, 0.93, 0.86, 1))
		_:
			_disc(img, 14, 14, 4, ink)
	var t := ImageTexture.create_from_image(img)
	_cache[id] = t
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
