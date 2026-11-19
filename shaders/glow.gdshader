shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 tint : source_color = vec4(0.4, 1.0, 0.8, 1.0);
uniform float power = 1.0;

void fragment() {
	float v = pow(1.0 - abs(UV.x - 0.5) * 2.0, 2.0);
	float pulse = 0.8 + 0.2 * sin(TIME * 3.0 + UV.y * 10.0);
	ALBEDO = tint.rgb * v * (1.0 - UV.y) * pulse * power;
}
