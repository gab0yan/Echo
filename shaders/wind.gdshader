shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 tint : source_color = vec4(0.65, 0.85, 1.0, 1.0);
uniform float height = 6.0;
uniform float power = 1.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	float x = UV.x;
	float y = (1.0 - UV.y) * height;
	float lanes = 9.0;
	float lane = floor(x * lanes);
	float lx = fract(x * lanes) - 0.5;
	float speed = 2.0 + hash(lane) * 2.5;
	float seg = fract((y - TIME * speed) * 0.35 + hash(lane + 7.0));
	float streak = smoothstep(0.0, 0.15, seg) * (1.0 - smoothstep(0.35, 0.55, seg));
	float thin = 1.0 - smoothstep(0.04, 0.14, abs(lx));
	float side = 1.0 - pow(abs(x - 0.5) * 2.0, 4.0);
	float fade = smoothstep(0.0, 0.08, UV.y) * smoothstep(1.0, 0.9, UV.y);
	ALBEDO = tint.rgb * (streak * thin * 0.9 + 0.08 * side) * fade * power;
}
