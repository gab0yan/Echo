shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 tint : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform float power = 1.0;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float bands = 0.55 + 0.45 * sin(lpos.y * 14.0 - TIME * 6.0);
	float edge = pow(abs(UV.x - 0.5) * 2.0, 6.0);
	float sparkle = step(0.985, fract(sin(dot(floor(lpos.xy * 18.0) + floor(TIME * 12.0), vec2(12.9898, 78.233))) * 43758.5453));
	ALBEDO = tint.rgb * (0.25 + bands * 0.45 + edge * 1.2 + sparkle * 1.5) * power;
}
