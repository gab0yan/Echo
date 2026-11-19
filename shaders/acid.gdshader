shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 color : source_color = vec3(0.4, 1.0, 0.25);
uniform vec3 deep : source_color = vec3(0.03, 0.25, 0.08);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 g = wpos.xz * 4.0 + vec2(0.0, TIME * 0.3);
	vec2 id = floor(g);
	vec2 fr = fract(g) - 0.5;
	float ph = fract(TIME * 0.6 + hash(id));
	float bub = smoothstep(0.32 * ph, 0.32 * ph - 0.05, length(fr)) * (1.0 - ph) * step(0.6, hash(id + 3.0));
	float wave = 0.5 + 0.5 * sin(wpos.x * 5.0 + TIME * 2.0) * sin(wpos.z * 4.0 - TIME * 1.3);
	float topf = smoothstep(0.5, 0.9, NORMAL.y);
	vec3 c = mix(deep, color, 0.35 + 0.4 * wave * topf + bub);
	ALBEDO = c * (0.8 + 0.6 * topf);
}
