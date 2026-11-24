shader_type canvas_item;
// Glassy, slippery cliff: cool translucent body with moving highlights.
uniform vec4 tint : source_color = vec4(0.55, 0.8, 0.95, 1.0);
varying vec2 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	float band = sin((wpos.x * 0.6 + wpos.y) * 0.02 + TIME * 0.4);
	float streak = smoothstep(0.985, 1.0, band);
	float facet = floor((wpos.x + wpos.y * 0.3) / 38.0);
	float shade = 0.55 + 0.25 * hash(vec2(facet, 1.0));
	vec3 c = tint.rgb * shade * 0.55;
	c += tint.rgb * streak * 0.45;
	c += vec3(0.8, 0.95, 1.0) * step(0.997, hash(floor(wpos / 3.0))) * 1.5;
	COLOR = vec4(c, 0.92);
}
