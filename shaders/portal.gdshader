shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 tint : source_color = vec4(0.75, 0.45, 1.0, 1.0);
uniform float spin = 1.0;
uniform float power = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.x *= 1.6;
	float r = length(p);
	float a = atan(p.y, p.x);
	float arms = 0.5 + 0.5 * sin(a * 3.0 + r * 9.0 * spin - TIME * 4.0 * spin);
	float disc = smoothstep(1.0, 0.75, r);
	float rim = smoothstep(0.7, 0.9, r) * smoothstep(1.05, 0.9, r);
	float core = smoothstep(0.45, 0.0, r);
	ALBEDO = tint.rgb * (arms * disc * 0.7 + rim * 1.6 + core * (spin > 0.0 ? 0.2 : 1.0)) * power;
}
