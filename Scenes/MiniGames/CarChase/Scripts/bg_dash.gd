extends ColorRect

@export var player: CharacterBody2D

var shader_code = """
shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.3);
uniform float speed : hint_range(0.0, 10.0) = 1.0;
uniform float line_count : hint_range(5.0, 70.0) = 50.0;
uniform float min_length : hint_range(0.05, 0.3) = 0.1;
uniform float max_length : hint_range(0.2, 0.8) = 0.4;
uniform float line_width : hint_range(0.01, 0.3) = 0.05;

// Simple random function
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    
    // Divide screen into columns
    float column = floor(uv.x * line_count);
    float x_in_column = fract(uv.x * line_count);
    
    // Random values for each column
    float rand1 = random(vec2(column, 1.0));
    float rand2 = random(vec2(column, 2.0));
    float rand3 = random(vec2(column, 3.0));
    
    // Line length varies per column
    float line_length = mix(min_length, max_length, rand1);
    
    // Offset for varied speeds
    float speed_offset = rand2 * 0.5 + 0.75;
    
    // Moving y position
    float y_pos = fract(uv.y - TIME * speed * speed_offset);
    
    // Create line at specific position
    float line_start = rand3;
    float line_end = line_start + line_length;
    
    // Check if current pixel is within line
    float line = step(line_start, y_pos) * step(y_pos, line_end);
    
    // Make line thin and sharp (centered in column)
    float center_dist = abs(x_in_column - 0.5) * 2.0;
    float thin = step(center_dist, line_width);
    
    // Fade at edges
    float fade_left = smoothstep(0.0, 0.1, uv.x);
    float fade_right = smoothstep(1.0, 0.9, uv.x);
    
    // Final color
    COLOR = line_color;
    COLOR.a *= line * thin * fade_left * fade_right;
}
"""

func _ready():
	# Set to full screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	color = Color(0.1, 0.1, 0.15)  # Dark background
	
	# Create and apply shader
	var shader = Shader.new()
	shader.code = shader_code
	
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	material = shader_material

func _process(_delta):
	if player and player.has_method("get_current_speed") and material:
		var player_speed = player.get_current_speed()
		# Convert player speed to shader speed (adjust the divisor to tune the effect)
		var shader_speed = player_speed / 200.0  # Divide by 100 to get reasonable shader values
		material.set_shader_parameter("speed", shader_speed)
