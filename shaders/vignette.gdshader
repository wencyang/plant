shader_type canvas_item;
uniform float strength = 0.55;
void fragment() {
	vec2 uv = SCREEN_UV - 0.5;
	float v = smoothstep(0.35, 0.85, length(uv * vec2(1.25, 1.0)));
	float grain = fract(sin(dot(SCREEN_UV * 1000.0 + TIME, vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(vec3(0.0), v * strength + (grain - 0.5) * 0.025);
}
