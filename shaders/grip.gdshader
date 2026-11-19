shader_type spatial;
render_mode unshaded;

uniform vec3 color : source_color = vec3(0.35, 1.0, 0.6);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = fract(sin(dot(floor(wpos.yz * vec2(10.0, 6.0)), vec2(12.9898, 78.233))) * 43758.5453);
	float pulse = 0.75 + 0.25 * sin(TIME * 2.0 + wpos.y * 2.0);
	ALBEDO = color * (0.5 + 0.7 * n) * pulse;
}
