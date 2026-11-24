shader_type canvas_item;
// Pools of living darkness. Lights (lures, glowing plants, sunwells) carve holes.
uniform vec4 darks[4];      // xy center, z radius
uniform int dark_count = 0;
uniform vec4 lights[32];    // xy pos, z radius
uniform int light_count = 0;
uniform vec4 tint : source_color = vec4(0.02, 0.01, 0.05, 1.0);
varying vec2 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	float a = 0.0;
	for (int i = 0; i < 4; i++) {
		if (i >= dark_count) break;
		float d = distance(wpos, darks[i].xy);
		float edge = darks[i].z * (0.92 + 0.08 * noise(wpos / 40.0 + TIME * 0.2));
		a = max(a, 1.0 - smoothstep(edge - 70.0, edge, d));
	}
	float lit = 0.0;
	for (int i = 0; i < 32; i++) {
		if (i >= light_count) break;
		float d = distance(wpos, lights[i].xy);
		lit = max(lit, 1.0 - smoothstep(lights[i].z * 0.45, lights[i].z, d));
	}
	a *= 1.0 - lit * 0.85;
	float wisp = noise(wpos / 70.0 + vec2(TIME * 0.05, -TIME * 0.03));
	vec3 c = tint.rgb + vec3(0.06, 0.03, 0.12) * wisp;
	COLOR = vec4(c, a * 0.96);
}
