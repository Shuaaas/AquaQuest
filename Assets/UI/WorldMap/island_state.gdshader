shader_type canvas_item;
uniform bool locked = false;
uniform bool unavailable = false;
uniform bool selected = false;
uniform vec4 outline_color : source_color = vec4(0.78, 0.65, 0.42, 1.0);
void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	float alpha = smoothstep(0.25, 0.88, sample_color.a);
	vec3 rgb = sample_color.rgb;
	if (locked || unavailable) {
		float gray = dot(rgb, vec3(0.299, 0.587, 0.114));
		rgb = mix(rgb, vec3(gray * 0.92, gray * 0.90, gray * 0.84), unavailable ? 0.86 : 0.68);
		rgb = mix(rgb, vec3(0.70, 0.72, 0.68), unavailable ? 0.20 : 0.10);
	}
	float edge = 0.0;
	if (selected) {
		vec2 step_uv = TEXTURE_PIXEL_SIZE * 4.0;
		edge = max(max(texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a,
			texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a),
			max(texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a,
			texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a));
		edge = smoothstep(0.65, 0.93, edge) * (1.0 - alpha);
	}
	COLOR = vec4(mix(rgb, outline_color.rgb, edge), max(alpha, edge));
}
