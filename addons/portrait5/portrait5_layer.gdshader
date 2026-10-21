// lib5 runtime layer shader (self-written). Mirrors lib5/compose.py:
//   tint(): v<ref -> tint*v/ref, else mix(tint, white, (v-ref)/(1-ref))   (v = BT.601 luma, like cv2 gray)
//   robe: paper repaint + skin cut from the head mask (R); hair: face protect from head mask (G) and hair aux (R keep, G source face)
//   sway: tip-weighted horizontal UV wobble (driven by the view's clock so movies are deterministic)
shader_type canvas_item;
uniform bool tint_on = false;
uniform vec3 tint = vec3(1.0);
uniform float ref = 0.8;
uniform bool paper_on = false;
uniform sampler2D paper_tex : filter_linear;
uniform vec3 paper_col = vec3(0.941, 0.929, 0.902);
uniform bool cut_on = false;
uniform bool protect_on = false;
uniform sampler2D head_mask : filter_linear;
uniform sampler2D aux_tex : filter_linear;
uniform vec2 canvas_size = vec2(432.0, 576.0);
uniform vec2 node_origin = vec2(0.0);
uniform float node_scale = 1.0;
uniform vec2 tex_px = vec2(1.0);
uniform float sway_px = 0.0;
uniform float sway_t = 0.0;
uniform float sway_speed = 2.0;
uniform float phase = 0.0;
uniform float sway_top = 0.30;
varying vec2 cpos;
void vertex() {
	cpos = node_origin + VERTEX * node_scale;
}
void fragment() {
	vec2 uv = UV;
	if (sway_px > 0.0) {
		float w = smoothstep(sway_top, sway_top + 0.45, cpos.y / canvas_size.y);
		uv.x += sin(sway_t * sway_speed + phase + cpos.y * 0.012) * sway_px * w / tex_px.x;
	}
	vec4 c = texture(TEXTURE, uv);
	if (tint_on) {
		float v = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		vec3 lo = tint * v / ref;
		vec3 hi = tint + (vec3(1.0) - tint) * clamp((v - ref) / (1.0 - ref), 0.0, 1.0);
		c.rgb = v < ref ? lo : hi;
	}
	if (paper_on) {
		float p = texture(paper_tex, uv).r;
		c.rgb = mix(c.rgb, paper_col, p);
	}
	vec2 cuv = cpos / canvas_size;
	if (cut_on) {
		c.a *= 1.0 - texture(head_mask, cuv).r;
	}
	if (protect_on) {
		vec4 ax = texture(aux_tex, uv);
		float prot = max(texture(head_mask, cuv).g, ax.g);
		c.a *= 1.0 - prot * (1.0 - ax.r);
	}
	COLOR = c;
}
