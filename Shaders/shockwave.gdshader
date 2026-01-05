shader_type canvas_item;

uniform vec4 ring_color : source_color = vec4(0.7, 0.5, 0.3, 1.0);
uniform vec4 inner_color : source_color = vec4(1.0, 0.7, 0.3, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float ring_width : hint_range(0.02, 0.2) = 0.08;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 uv = UV - center;
	float dist = length(uv) * 2.0;
	
	// Main ring
	float ring_pos = progress;
	float ring_dist = abs(dist - ring_pos);
	float ring = 1.0 - smoothstep(0.0, ring_width, ring_dist);
	
	// Inner ring
	float inner_pos = progress * 0.8;
	float inner_dist = abs(dist - inner_pos);
	float inner_ring = 1.0 - smoothstep(0.0, ring_width * 0.5, inner_dist);
	
	// Combine
	float combined = max(ring, inner_ring * 0.5);
	float alpha = combined * (1.0 - progress);
	
	// Color
	vec4 col = mix(ring_color, inner_color, inner_ring * 0.5);
	col.rgb *= 1.0 + (1.0 - progress) * 0.5;
	col.a = alpha;
	
	if (col.a < 0.01) discard;
	COLOR = col;
}
