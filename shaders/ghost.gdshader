shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;

uniform vec4 tint : source_color = vec4(0.35, 0.95, 1.0, 1.0);
uniform float strength = 1.0;
uniform float flicker = 1.0;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float scan = 0.65 + 0.35 * sin(FRAGCOORD.y * 0.9 - TIME * 10.0);
	float fl = mix(1.0, 0.85 + 0.15 * sin(TIME * 37.0 + FRAGCOORD.x * 0.01), flicker);
	ALBEDO = tint.rgb * (0.18 + f * 1.7) * scan * fl * strength;
}
