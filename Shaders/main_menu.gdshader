shader_type canvas_item;

uniform sampler2D normal;
uniform sampler2D destroyed;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

uniform float shake_power = 0.03;
uniform float shake_speed = 5.0;
uniform float shake_block_size = 30.5;
uniform float shake_color_rate : hint_range(0.0, 1.0) = 0.01;

float random(float seed) {
    return fract(543.2543 * sin(dot(vec2(seed, seed), vec2(3525.46, -54.3415))));
}

void fragment() {
    float enable_shift = progress;
    
    float time_quantized = floor(TIME * shake_speed);
    
    float y_block = trunc(UV.y * shake_block_size) / shake_block_size;
    float shake_factor = (random(y_block + time_quantized) - 0.5) * shake_power * enable_shift;
    
    vec2 fixed_uv = UV;
    fixed_uv.x += shake_factor;

    vec2 r_uv = fixed_uv + vec2(shake_color_rate * enable_shift, 0.0);
    vec2 b_uv = fixed_uv + vec2(-shake_color_rate * enable_shift, 0.0);
    
    float norm_r = texture(normal, r_uv).r;
    float norm_g = texture(normal, fixed_uv).g;
    float norm_b = texture(normal, b_uv).b;
    float norm_a = texture(normal, fixed_uv).a;
    vec4 color_normal_glitched = vec4(norm_r, norm_g, norm_b, norm_a);
    
    float dest_r = texture(destroyed, r_uv).r;
    float dest_g = texture(destroyed, fixed_uv).g;
    float dest_b = texture(destroyed, b_uv).b;
    float dest_a = texture(destroyed, fixed_uv).a;
    vec4 color_destroyed_glitched = vec4(dest_r, dest_g, dest_b, dest_a);

    float mix_noise = random(UV.y * 10.0 + time_quantized); 
    float mix_threshold = step(0.5, progress + (mix_noise * 0.2)); 
    
    COLOR = mix(color_normal_glitched, color_destroyed_glitched, clamp(mix_threshold, 0.0, 1.0));
}