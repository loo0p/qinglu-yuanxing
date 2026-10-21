## lib5 runtime library: loads lib5.json (baked by portrait/lib5/bake.py) and rolls character specs.
## A spec is a small Dictionary (what saves store); Portrait5View renders it with layered sprites + one shader.
class_name Portrait5Lib
extends RefCounted

## 部件贴图不进 pck：放在 res://web_portrait/（.gdignore，不导入、不导出），
## 桌面/无头直接读文件；Web 端从站点 portrait/ 目录按需下载（fetch 回调由宿主提供）。
static var json_path := "res://data/lib5.json"
static var dir := "res://web_portrait/"
static var lib: Dictionary = {}
static var _tex := {}
static var fetch: Callable = Callable()   # Web：fetch.call(file) 发起下载，完成后宿主调用 put(rel, bytes)
static var miss := 0                      # 本次 setup 期间缺了几张（View 用它判断是否完整）
static var gen := 0                       # 每到一张新图 +1，PortraitBox 据此重画

static func ensure() -> void:
	if not lib.is_empty(): return
	var f := FileAccess.open(json_path, FileAccess.READ)
	lib = JSON.parse_string(f.get_as_text())

static func file_of(rel: String) -> String:
	return rel.get_basename() + ".webp"

static func has(rel: String) -> bool:
	return _tex.has(rel) and _tex[rel] != null

static func put(rel: String, bytes: PackedByteArray) -> void:
	var img := Image.new()
	if bytes.size() > 0 and img.load_webp_from_buffer(bytes) == OK:
		_tex[rel] = ImageTexture.create_from_image(img)
		gen += 1

static func tex(rel: String) -> Texture2D:
	if has(rel):
		return _tex[rel]
	if fetch.is_valid():
		miss += 1
		fetch.call(rel)
		return null
	var bytes := FileAccess.get_file_as_bytes(dir + file_of(rel))
	put(rel, bytes)
	if not has(rel):
		miss += 1
		return null
	return _tex[rel]

static func _pick(r: RandomNumberGenerator, a: Array):
	return a[r.randi() % a.size()]

## Roll a random character. opts: sex ("f"/"m"), elder (bool), demonic (bool), seed (String/int)
static func roll(seed_v, opts: Dictionary = {}) -> Dictionary:
	ensure()
	var P: Dictionary = lib.pools
	var r := RandomNumberGenerator.new(); r.seed = hash(str(seed_v))
	var sex: String = opts.get("sex", "f" if r.randf() < 0.5 else "m")
	var elder: bool = opts.get("elder", r.randf() < 0.2)
	var base: String
	if elder: base = "base_fe" if sex == "f" else "base_me"
	else: base = _pick(r, P.F_BASES if sex == "f" else P.M_BASES)
	var sp := {"v": 5, "base": base, "feats": {}, "marks": [], "acc": [], "beard": null, "outer": null}
	if not elder:
		for reg in ["nose", "mouth", "eyes", "brows"]:
			sp.feats[reg] = _pick(r, P.feats[sex][reg])
	else:
		var ev: Dictionary = P.elder_feats.get(base, {})
		for reg in ["brows", "mouth"]:
			if ev.get(reg, []).size() > 0 and r.randf() < 0.5: sp.feats[reg] = _pick(r, ev[reg])
	var marks := []
	for id in lib.marks:
		if lib.marks[id].sex == sex: marks.append(id)
	if r.randf() < 0.35:
		var a: String = _pick(r, marks); sp.marks.append(a)
		if r.randf() < 0.3:
			var other := []
			for id in marks:
				if lib.marks[id].forehead != lib.marks[a].forehead: other.append(id)
			if other.size() > 0: sp.marks.append(_pick(r, other))
	var demon_robe := "robe_f3@base_f" if sex == "f" else "robe_m3@base_m"
	if opts.get("demonic", false) or (not opts.has("demonic") and r.randf() < 0.06):
		sp.robe = demon_robe
	else:
		var pool := []
		for k in (P.elder_robes[sex] if elder else P.robes[sex]):
			if k != demon_robe: pool.append(k)
		sp.robe = _pick(r, pool)
	var pal: Array = P.pal_f if sex == "f" else P.pal_m
	sp.robe_tint = opts.get("robe_tint", _pick(r, pal))
	if r.randf() < 0.35 and not (sp.robe in P.fixed): sp.outer = _pick(r, P.outers[sex])
	sp.outer_tint = _pick(r, pal)
	var hk_pool: Array = P.hair[("fe" if sex == "f" else "me") if elder else sex]
	sp.hair = _pick(r, hk_pool)
	for a in P.acc.get(sp.hair, []):
		if r.randf() < 0.6: sp.acc.append(a)
	if sex == "m":
		if elder and sp.hair != "hair_me1@base_me" and r.randf() < 0.75: sp.beard = _pick(r, P.beards.me)
		elif not elder and r.randf() < 0.3:
			var bp := []
			for k in P.beards.m:
				if k != "beard_m5@base_m5" or base in ["base_m4", "base_m5"]: bp.append(k)
			sp.beard = _pick(r, bp)
	return sp
