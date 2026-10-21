## lib5 runtime library: loads lib5.json (baked by portrait/lib5/bake.py) and rolls character specs.
## A spec is a small Dictionary (what saves store); Portrait5View renders it with layered sprites + one shader.
class_name Portrait5Lib
extends RefCounted

static var root := "res://portrait5/"
static var lib: Dictionary = {}
static var _tex := {}

static func ensure() -> void:
	if not lib.is_empty(): return
	var f := FileAccess.open(root + "lib5.json", FileAccess.READ)
	lib = JSON.parse_string(f.get_as_text())

static func tex(rel: String) -> Texture2D:
	if not _tex.has(rel):
		var t: Texture2D = load(root + rel) if ResourceLoader.exists(root + rel) else null
		if t == null:
			var img := Image.load_from_file(ProjectSettings.globalize_path(root + rel))
			t = ImageTexture.create_from_image(img)
		_tex[rel] = t
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
