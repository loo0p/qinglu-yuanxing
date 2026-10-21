## Renders a lib5 spec as layered Sprite2Ds on a 432x576 canvas (origin top-left).
## Blink: open / half / closed feature frames (blink schedule after PuppetStudio runtime/avatar.gd).
## Motion: PuppetStudio pose_solver (MIT, vendored unchanged) drives breathing + spring lag for hair,
## ornaments and shawls; the layer shader adds a tip-weighted sway.
class_name Portrait5View
extends Node2D

const PoseSolver = preload("res://addons/portrait5/pose_solver.gd")
const SH = preload("res://addons/portrait5/portrait5_layer.gdshader")
const CANVAS := Vector2(432, 576)

var spec: Dictionary = {}
var motion := 1.0
var clock := 0.0
var blink_times: Array = []       # fixed blink times within a 4 s loop (movies); empty = random schedule
var eye_state := "open"           # forced state when motion == 0 (stills / parity)
var solver = PoseSolver.new()
var layers: Array = []
var nodes := {}
var eye_frames := {}              # "open"/"half"/"closed" -> Sprite2D or null
var sway_mats: Array = []
var rng := RandomNumberGenerator.new()
var next_blink := 1.2
var blink_left := 0.0
const BLINK_DUR := 0.16

func _layer(id: String, parent: String, extra: Dictionary = {}) -> Node2D:
	var l := {"id": id, "parent": parent, "x": 0.0, "y": 0.0, "rotation": 0.0, "scale": 1.0, "sway": 0.0,
		"bounce": 0.0, "visible": true, "opacity": 1.0, "condition": 0}
	l.merge(extra, true)
	layers.append(l)
	var n := Node2D.new(); n.name = id.replace(":", "_").replace("@", "_")
	if parent == "": add_child(n)
	else: nodes[parent].add_child(n)
	nodes[id] = n
	return n

func _sprite(parent: Node2D, rel: String, pos: Vector2, scale_f := 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Portrait5Lib.tex(rel)
	s.centered = false
	s.position = pos
	s.scale = Vector2(scale_f, scale_f)
	parent.add_child(s)
	return s

func _mat(s: Sprite2D, origin: Vector2, scale_f: float) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = SH
	m.set_shader_parameter("node_origin", origin)
	m.set_shader_parameter("node_scale", scale_f)
	m.set_shader_parameter("canvas_size", CANVAS)
	m.set_shader_parameter("tex_px", Vector2(s.texture.get_size()) if s.texture != null else Vector2.ONE)   # Web 上贴图可能还没下载到：先占位，到齐后整张重建
	s.material = m
	return m

static func _col(a) -> Vector3:
	return Vector3(float(a[0]) / 255.0, float(a[1]) / 255.0, float(a[2]) / 255.0)

func setup(sp: Dictionary) -> void:
	Portrait5Lib.ensure()
	var L: Dictionary = Portrait5Lib.lib
	spec = sp
	rng.seed = hash(JSON.stringify(sp) + ":blink")
	for c in get_children(): c.queue_free()
	layers.clear(); nodes.clear(); eye_frames.clear(); sway_mats.clear(); solver.clear()
	var base: String = sp.base
	var head: Dictionary = L.heads[base]
	var mask_tex: Texture2D = Portrait5Lib.tex("heads/%s.mask.png" % base)
	# breathing body root (pivot near the collar) -> everything hangs off it
	_layer("root", "", {"y": 0.0, "scale_y": 1.0})
	_sprite(nodes.root, "heads/%s.jpg" % base, Vector2.ZERO)
	# features
	for reg in ["nose", "mouth", "eyes", "brows"]:
		var n := _layer("f_" + reg, "root")
		if reg == "eyes":
			var eid: String = sp.feats.get("eyes", "eyes:" + base)
			for st in ["open", "half", "closed"]:
				var k := "%s|%s|%s" % [eid, base, st]
				if L.feats.has(k):
					var e: Dictionary = L.feats[k]
					var s := _sprite(n, e.tex, Vector2(e.pos[0], e.pos[1]))
					eye_frames[st] = s
				else:
					eye_frames[st] = null
			continue
		var fid = sp.feats.get(reg, null)
		if fid == null: continue
		var k2 := "%s|%s|open" % [fid, base]
		if L.feats.has(k2):
			var e2: Dictionary = L.feats[k2]
			_sprite(n, e2.tex, Vector2(e2.pos[0], e2.pos[1]))
	# marks (translated by anchor delta)
	for mid in sp.get("marks", []):
		var mk: Dictionary = L.marks[mid]
		var sa: Array = L.heads[mk.base].anchors[mk.anchor]; var ta: Array = head.anchors[mk.anchor]
		var off := Vector2(ta[0] - sa[0], ta[1] - sa[1])
		_sprite(nodes.root, mk.tex, Vector2(mk.pos[0], mk.pos[1]) + off)
	# robe
	var rk: String = sp.robe; var re: Dictionary = L.parts[rk]
	var rn := _layer("robe", "root")
	var rs := _sprite(rn, re.tex, Vector2(re.pos[0], re.pos[1]))
	var rm := _mat(rs, rs.position, 1.0)
	if not (rk in L.pools.fixed):
		rm.set_shader_parameter("tint_on", true); rm.set_shader_parameter("tint", _col(sp.robe_tint)); rm.set_shader_parameter("ref", 0.80)
		if re.has("paper"):
			rm.set_shader_parameter("paper_on", true); rm.set_shader_parameter("paper_tex", Portrait5Lib.tex(re.paper))
	rm.set_shader_parameter("cut_on", true); rm.set_shader_parameter("head_mask", mask_tex)
	# outer
	if sp.get("outer") != null:
		var oe: Dictionary = L.parts[sp.outer]
		var on := _layer("outer", "root", {"spring": oe.sway, "spring_frequency": 2.2, "damping": 0.35})
		var os := _sprite(on, oe.tex, Vector2(oe.pos[0], oe.pos[1]))
		var om := _mat(os, os.position, 1.0)
		om.set_shader_parameter("tint_on", true); om.set_shader_parameter("tint", _col(sp.outer_tint)); om.set_shader_parameter("ref", 0.70)
		if oe.sway: _swayify(om, 3.5, 0.45, 1.7)
	# beard
	if sp.get("beard") != null:
		var be: Dictionary = L.parts[sp.beard]; var bb: String = sp.beard.split("@")[1]
		var bx: Array = L.xf.mouth[bb][base]
		var bn := _layer("beard", "root")
		var bpos: Vector2 = Vector2(bx[1], bx[2]) + Vector2(be.pos[0], be.pos[1]) * float(bx[0])
		_sprite(bn, be.tex, bpos, bx[0])
	# hair (+ accessories share its transform)
	var hk: String = sp.hair; var he: Dictionary = L.parts[hk]; var hb: String = hk.split("@")[1]
	var hx: Array = [1.0, 0.0, 0.0] if hb == base else L.xf.skull[hb][base]
	var hn := _layer("hair", "root", {"spring": true, "spring_frequency": 2.6, "damping": 0.45})
	var hpos: Vector2 = Vector2(hx[1], hx[2]) + Vector2(he.pos[0], he.pos[1]) * hx[0]
	var hs := _sprite(hn, he.tex, hpos, hx[0])
	var hm := _mat(hs, hpos, hx[0])
	if hb != base and not (hk in L.pools.native_white) and he.has("aux"):
		hm.set_shader_parameter("protect_on", true); hm.set_shader_parameter("head_mask", mask_tex)
		hm.set_shader_parameter("aux_tex", Portrait5Lib.tex(he.aux))
	if he.sway: _swayify(hm, 2.2, 0.30, 1.9)
	for ak in sp.get("acc", []):
		var ae: Dictionary = L.parts[ak]
		var an := _layer("acc_" + ak, "hair", {"spring": true, "spring_frequency": 3.2, "damping": 0.3})
		var apos: Vector2 = Vector2(hx[1], hx[2]) + Vector2(ae.pos[0], ae.pos[1]) * hx[0]
		var as_ := _sprite(an, ae.tex, apos, hx[0])
		var am := _mat(as_, apos, hx[0])
		if ae.sway: _swayify(am, 1.6, 0.10, 2.8)
	_apply_eyes("open")
	_process(0.0)

func _swayify(m: ShaderMaterial, px: float, top: float, speed: float) -> void:
	m.set_shader_parameter("sway_px", px * motion)
	m.set_shader_parameter("sway_top", top)
	m.set_shader_parameter("sway_speed", speed)
	m.set_shader_parameter("phase", rng.randf() * TAU)
	sway_mats.append(m)

func _apply_eyes(st: String) -> void:
	# native open eyes have no patch (the head already shows them)
	for k in eye_frames:
		if eye_frames[k] != null: eye_frames[k].visible = (k == st)
	if st != "open" and eye_frames.get(st) == null:
		if eye_frames.get("open") != null: eye_frames["open"].visible = true

func _process(delta: float) -> void:
	if layers.is_empty(): return
	clock += delta * (1.0 if motion > 0.0 else 0.0)
	var st := eye_state
	if motion > 0.0:
		if blink_times.is_empty():
			next_blink -= delta
			if next_blink <= 0.0:
				next_blink = rng.randf_range(2.5, 5.2)
				blink_left = BLINK_DUR
				if rng.randf() < 0.15: next_blink = 0.32   # double blink (Anime2.5DRig habit)
		else:
			var t := fmod(clock, 4.0)
			for bt in blink_times:
				if t >= bt and t < bt + BLINK_DUR: blink_left = maxf(blink_left, bt + BLINK_DUR - t)
		blink_left = maxf(0.0, blink_left - delta)
		st = "open"
		if blink_left > 0.0:
			st = "half" if (blink_left > BLINK_DUR * 0.7 or blink_left < BLINK_DUR * 0.25) else "closed"
	_apply_eyes(st)
	if motion <= 0.0: return
	# breathing: tiny vertical scale about the collar, plus a slow body drift that the springs lag behind
	var root_l: Dictionary = layers[0]
	root_l.scale_y = 1.0 + sin(clock * TAU / 4.0) * 0.004 * motion
	root_l.y = sin(clock * TAU / 4.0) * 1.2 * motion
	root_l.x = sin(clock * TAU / 4.0 + 1.0) * 0.8 * motion
	var poses: Dictionary = solver.evaluate(layers, delta, clock, false, st != "open", motion)
	for l in layers:
		var n: Node2D = nodes[l.id]
		var tr: Transform2D = poses.get(l.id, Transform2D.IDENTITY)
		if l.id == "root":
			# pivot the breathing scale at the collar line (y=300 on the 576 canvas)
			tr = Transform2D(0.0, Vector2(1.0, root_l.scale_y), 0.0, Vector2(root_l.x, root_l.y + 300.0 * (1.0 - root_l.scale_y)))
			n.transform = tr
		elif l.parent == "":
			n.transform = tr
		else:
			# solver returns world-space transforms; convert to parent-local
			n.transform = poses.get(l.parent, Transform2D.IDENTITY).affine_inverse() * tr
	for m in sway_mats: m.set_shader_parameter("sway_t", clock)
