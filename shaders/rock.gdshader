shader_type canvas_item;
// Painterly alien rock: lit from above, soft mottling, gentle strata,
// darkening with depth into the ground.
uniform vec4 col_a : source_color;
uniform vec4 col_b : source_color;
uniform vec4 speck : source_color;
uniform float soil = 0.0;
uniform float top_y = 0.0;
uniform float height = 100.0;
varying vec2 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.07; a *= 0.5; } return v; }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	float local = clamp((wpos.y - top_y) / max(height, 1.0), 0.0, 1.0);
	float lit = 1.0 - smoothstep(0.0, soil > 0.5 ? 0.12 : 0.7, local);
	float n = fbm(wpos / 120.0);
	float m = fbm(wpos / 38.0 + 7.0);
	vec3 c = mix(col_b.rgb, col_a.rgb, 0.35 + 0.65 * lit);
	c *= 0.8 + 0.35 * n;
	c = mix(c, c * 1.18, smoothstep(0.55, 0.7, m) * 0.6);
	float strata = smoothstep(0.42, 0.5, abs(fract(wpos.y * 0.025 + n * 1.5) - 0.5));
	c *= 0.92 + 0.08 * strata;
	// sparse soft glowing mineral flecks
	float fl = smoothstep(0.86, 0.9, fbm(wpos / 14.0)) * (1.0 - local * 0.7);
	c += speck.rgb * fl * 0.35;
	COLOR = vec4(c, 1.0);
}
