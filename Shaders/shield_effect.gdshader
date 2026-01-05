shader_type canvas_item;

uniform vec4 shield_color : source_color = vec4(0.3, 0.6, 1.0, 0.5);
uniform float pulse_speed : hint_range(0.5, 10.0) = 3.0;
uniform float outline_width : hint_range(0.0, 5.0) = 2.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float pulse = sin(TIME * pulse_speed) * 0.3 + 0.7;
	
	// Shield tint
	vec4 result = mix(tex, shield_color, 0.35 * pulse);
	result.a = tex.a;
	
	// Edge glow
	float alpha_threshold = 0.1;
	if (tex.a > alpha_threshold) {
		float edge = 0.0;
		for (float x = -1.0; x <= 1.0; x += 1.0) {
			for (float y = -1.0; y <= 1.0; y += 1.0) {
				vec2 offset = vec2(x, y) * TEXTURE_PIXEL_SIZE * outline_width;
				float neighbor = texture(TEXTURE, UV + offset).a;
				if (neighbor < alpha_threshold) {
					edge = 1.0;
				}
			}
		}
		if (edge > 0.0) {
			result.rgb = mix(result.rgb, shield_color.rgb * 2.0, 0.6 * pulse);
		}
	}
	
	COLOR = result;
}
