shader_type spatial;

uniform vec3 top_color : source_color = vec3(0.80, 0.56, 0.44);
uniform vec3 side_color : source_color = vec3(0.62, 0.34, 0.26);
uniform vec3 deep_color : source_color = vec3(0.30, 0.14, 0.16);
uniform float darken = 0.0;

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = abs(wnorm.z) > 0.5 ? wpos.xy : (abs(wnorm.x) > 0.5 ? wpos.zy : wpos.xz);
	float n = noise(uv * 1.7) * 0.55 + noise(uv * 4.3 + 7.0) * 0.3 + noise(uv * 11.0) * 0.15;
	float strata = 0.5 + 0.5 * sin(wpos.y * 5.0 + noise(uv * 0.6) * 4.0);
	vec3 c = mix(side_color, deep_color, clamp((1.0 - n) * 0.7 + strata * 0.25, 0.0, 1.0));
	float top = smoothstep(0.55, 0.85, wnorm.y);
	c = mix(c, top_color * (0.82 + 0.35 * n), top);
	float crater = smoothstep(0.78, 0.8, noise(uv * 2.3 + 3.0)) * (1.0 - top);
	c *= 1.0 - crater * 0.25;
	ALBEDO = c * (1.0 - darken);
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
