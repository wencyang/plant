shader_type canvas_item;
// Luminous crystal: angular facets with shifting inner light.
uniform vec4 col : source_color = vec4(0.45, 0.95, 1.0, 1.0);
varying vec2 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 h2(vec2 p) { return vec2(hash(p), hash(p + 17.3)); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	vec2 p = wpos / 26.0;
	vec2 i = floor(p); vec2 f = fract(p);
	float d1 = 9.0; float d2 = 9.0; vec2 cell = vec2(0.0);
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = h2(i + g);
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; cell = i + g; } else if (d < d2) { d2 = d; }
	}
	float edge = smoothstep(0.0, 0.08, d2 - d1);
	float k = hash(cell);
	float shimmer = 0.5 + 0.5 * sin(TIME * 1.6 + k * 30.0);
	vec3 c = col.rgb * (0.35 + 0.55 * k + 0.35 * shimmer);
	c = mix(col.rgb * 2.2, c, edge);
	COLOR = vec4(c, 0.9);
}
