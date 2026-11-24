shader_type canvas_item;
// Atmospheric sky: vertical gradient, soft drifting nebula haze, stars.
uniform vec4 top_col : source_color;
uniform vec4 bottom_col : source_color;
uniform vec4 haze_col : source_color;
uniform float stars = 0.5;
varying vec2 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}
void vertex() { wpos = VERTEX; }
void fragment() {
	float y = clamp(wpos.y / 1000.0, 0.0, 1.0);
	vec3 c = mix(top_col.rgb, bottom_col.rgb, smoothstep(0.0, 1.0, y));
	float n = fbm(wpos / 520.0 + vec2(TIME * 0.006, 0.0));
	float n2 = fbm(wpos / 180.0 - vec2(TIME * 0.01, 0.0));
	c = mix(c, haze_col.rgb, smoothstep(0.45, 0.85, n) * 0.35 * (0.4 + y));
	c += haze_col.rgb * smoothstep(0.6, 0.9, n2) * 0.06;
	// stars
	vec2 g = floor(wpos / 3.0);
	float s = step(0.9985, hash(g)) * (1.0 - y) * stars;
	s *= 0.6 + 0.4 * sin(TIME * 2.0 + hash(g + 3.1) * 40.0);
	c += vec3(s) * 1.6;
	COLOR = vec4(c, 1.0);
}
