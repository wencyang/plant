shader_type canvas_item;
// Underground water with drifting caustics.
varying vec2 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	float w = sin(wpos.x * 0.05 + TIME * 1.3) * sin(wpos.x * 0.023 - TIME * 0.7 + wpos.y * 0.1);
	vec3 c = mix(vec3(0.03, 0.12, 0.25), vec3(0.1, 0.4, 0.7), 0.5 + 0.5 * w);
	c += vec3(0.4, 0.8, 1.2) * smoothstep(0.85, 1.0, w) * 0.8;
	COLOR = vec4(c, 0.9);
}
