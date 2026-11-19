shader_type spatial;

uniform vec3 color : source_color = vec3(0.35, 0.95, 0.3);
uniform vec3 deep : source_color = vec3(0.05, 0.35, 0.12);

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
	VERTEX += NORMAL * sin(TIME * 3.0 + VERTEX.x * 6.0 + VERTEX.z * 4.0) * 0.025;
}

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float spots = smoothstep(0.55, 0.6, fract(sin(dot(floor(lpos.xz * 9.0), vec2(12.9898, 78.233))) * 43758.5453)) * 0.25;
	ALBEDO = mix(deep, color, 0.55 + 0.45 * lpos.y + spots);
	EMISSION = color * (0.35 + f * 1.2);
	ROUGHNESS = 0.15;
	SPECULAR = 0.8;
}
