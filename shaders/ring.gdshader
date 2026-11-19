shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 tint : source_color = vec4(1.0, 0.7, 0.3, 1.0);
uniform float power = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ring = smoothstep(0.62, 0.8, r) * (1.0 - smoothstep(0.8, 1.0, r));
	float inner = (1.0 - smoothstep(0.0, 0.8, r)) * 0.25;
	ALBEDO = tint.rgb * (ring * 1.4 + inner) * power;
}
