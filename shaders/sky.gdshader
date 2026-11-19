shader_type sky;

uniform vec3 top_color : source_color = vec3(0.015, 0.015, 0.05);
uniform vec3 horizon_color : source_color = vec3(0.24, 0.10, 0.22);
uniform vec3 glow_color : source_color = vec3(0.95, 0.45, 0.35);
uniform vec3 planet_dir = vec3(0.3, 0.17, -1.0);
uniform float planet_size = 0.11;
uniform vec3 band_a : source_color = vec3(0.92, 0.6, 0.45);
uniform vec3 band_b : source_color = vec3(0.5, 0.26, 0.36);
uniform vec3 moon_dir = vec3(-0.25, 0.45, -1.0);
uniform float moon_size = 0.045;
uniform float dim = 1.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

vec4 body(vec3 d, vec3 dir, float size, vec3 ca, vec3 cb, float bands) {
	vec3 pd = normalize(dir);
	if (dot(d, pd) <= 0.0) {
		return vec4(0.0);
	}
	vec3 right = normalize(cross(pd, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(right, pd);
	vec2 p = vec2(dot(d, right), dot(d, up)) / size;
	float r = length(p);
	vec3 col = vec3(0.0);
	float a = 0.0;
	if (r < 1.0) {
		float z = sqrt(1.0 - r * r);
		vec3 n = normalize(p.x * right + p.y * up - z * pd);
		float lat = p.y * bands + sin(p.x * 3.0 + p.y * 2.0) * 0.4 + noise(vec3(p * 6.0, 1.0)) * 0.6;
		vec3 base = mix(ca, cb, 0.5 + 0.5 * sin(lat));
		float lit = clamp(dot(n, normalize(vec3(-0.45, 0.05, 0.9))) * 1.1 + 0.08, 0.0, 1.0);
		col = base * (0.05 + lit * 0.8);
		col += glow_color * pow(1.0 - z, 3.0) * 0.8 * (0.2 + lit);
		a = smoothstep(1.0, 0.985, r);
	} else {
		col = glow_color * exp(-(r - 1.0) * 9.0) * 0.35;
	}
	return vec4(col, a);
}

void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y, -1.0, 1.0);
	vec3 c = mix(horizon_color, top_color, smoothstep(-0.05, 0.55, h));
	c += glow_color * pow(max(0.0, 1.0 - abs(h + 0.02) * 3.0), 3.0) * 0.3;
	float neb = noise(d * 3.0) * 0.6 + noise(d * 7.0) * 0.3 + noise(d * 15.0) * 0.1;
	c += vec3(0.28, 0.08, 0.38) * smoothstep(0.45, 0.85, neb) * 0.45 * smoothstep(-0.1, 0.4, h);
	c += vec3(0.05, 0.15, 0.32) * smoothstep(0.55, 0.9, noise(d * 4.0 + 11.0)) * 0.35;
	vec3 cell = floor(d * 230.0);
	float s = hash(cell);
	float tw = 0.55 + 0.45 * sin(TIME * (0.6 + s * 2.5) + s * 60.0);
	c += vec3(1.0, 0.95, 0.9) * step(0.9965, s) * tw * smoothstep(-0.05, 0.15, h) * (0.5 + 0.5 * hash(cell + 3.0));
	vec3 cell2 = floor(d * 90.0);
	c += vec3(0.8, 0.9, 1.0) * step(0.9985, hash(cell2 + 7.0)) * 1.3 * smoothstep(0.0, 0.2, h);
	vec4 pl = body(d, planet_dir, planet_size, band_a, band_b, 7.0);
	c = mix(c, pl.rgb, pl.a) + pl.rgb * (1.0 - pl.a);
	vec4 mo = body(d, moon_dir, moon_size, vec3(0.75, 0.78, 0.85), vec3(0.5, 0.52, 0.6), 2.0);
	c = mix(c, mo.rgb, mo.a) + mo.rgb * (1.0 - mo.a) * 0.4;
	COLOR = c * dim;
}
