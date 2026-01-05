shader_type canvas_item;

// Advanced Shockwave Shader with Ground Crack Effect
// Use on a ColorRect or Sprite2D covering the shockwave area

uniform vec4 primary_color : source_color = vec4(0.7, 0.55, 0.35, 1.0);
uniform vec4 secondary_color : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform vec4 crack_color : source_color = vec4(0.9, 0.6, 0.2, 1.0);

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float ring_count : hint_range(1.0, 5.0) = 3.0;
uniform float ring_width : hint_range(0.02, 0.15) = 0.06;
uniform float ring_spacing : hint_range(0.05, 0.3) = 0.12;

uniform float crack_density : hint_range(0.0, 1.0) = 0.5;
uniform float dust_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float energy_flare : hint_range(0.0, 2.0) = 1.0;

// Noise functions
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// Crack pattern
float crack_pattern(vec2 uv, float seed) {
    float angle = atan(uv.y, uv.x);
    float dist = length(uv);
    
    // Radial cracks
    float radial = abs(sin(angle * (8.0 + seed * 4.0) + seed * 10.0));
    radial = pow(radial, 8.0);
    
    // Add noise variation
    float crack_noise = fbm(uv * 20.0 + seed);
    radial *= smoothstep(0.3, 0.7, crack_noise);
    
    return radial;
}

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    vec2 uv = UV - center;
    float dist = length(uv) * 2.0;
    float angle = atan(uv.y, uv.x);
    
    vec4 final_color = vec4(0.0);
    
    // === EXPANDING RINGS ===
    float ring_alpha = 0.0;
    for (float i = 0.0; i < ring_count; i++) {
        float ring_progress = progress - (i * ring_spacing * 0.5);
        if (ring_progress < 0.0) continue;
        
        // Add noise to ring position
        float noise_offset = noise(vec2(angle * 2.0, i)) * 0.05;
        float ring_pos = ring_progress + noise_offset;
        
        float ring_dist = abs(dist - ring_pos);
        float ring_fade = 1.0 - (i / ring_count) * 0.4; // Outer rings are dimmer
        float ring = (1.0 - smoothstep(0.0, ring_width * ring_fade, ring_dist));
        ring *= (1.0 - ring_progress); // Fade as it expands
        
        ring_alpha = max(ring_alpha, ring * ring_fade);
    }
    
    // Ring color gradient
    vec3 ring_col = mix(secondary_color.rgb, primary_color.rgb, dist);
    ring_col *= 1.0 + energy_flare * (1.0 - progress);
    final_color.rgb += ring_col * ring_alpha;
    final_color.a = max(final_color.a, ring_alpha);
    
    // === GROUND CRACKS ===
    if (crack_density > 0.0 && dist < progress * 1.2) {
        float crack = crack_pattern(uv, 0.0);
        crack += crack_pattern(uv * 1.3, 3.14) * 0.5;
        
        // Cracks appear as the wave passes
        float crack_reveal = smoothstep(progress - 0.2, progress, dist);
        crack_reveal *= 1.0 - smoothstep(progress, progress + 0.3, dist);
        
        // Fade cracks over time
        float crack_fade = 1.0 - progress * 0.7;
        
        float crack_intensity = crack * crack_reveal * crack_fade * crack_density;
        
        vec3 crack_col = crack_color.rgb * (1.0 + fbm(uv * 10.0) * 0.5);
        final_color.rgb = mix(final_color.rgb, crack_col, crack_intensity * 0.8);
        final_color.a = max(final_color.a, crack_intensity * 0.6);
    }
    
    // === DUST PARTICLES ===
    if (dust_intensity > 0.0) {
        float dust_area = smoothstep(progress - 0.3, progress - 0.1, dist);
        dust_area *= 1.0 - smoothstep(progress - 0.1, progress + 0.2, dist);
        
        // Animated dust
        float dust = fbm(uv * 30.0 + vec2(TIME * 0.5, 0.0));
        dust = pow(dust, 2.0) * dust_area * dust_intensity;
        
        vec3 dust_col = primary_color.rgb * 0.6;
        final_color.rgb += dust_col * dust * (1.0 - progress);
        final_color.a = max(final_color.a, dust * 0.4);
    }
    
    // === CENTRAL FLASH ===
    float flash_radius = 0.15 * (1.0 - progress * 2.0);
    if (flash_radius > 0.0 && dist < flash_radius) {
        float flash = 1.0 - (dist / flash_radius);
        flash = pow(flash, 2.0);
        final_color.rgb += secondary_color.rgb * flash * 2.0;
        final_color.a = max(final_color.a, flash);
    }
    
    // === EDGE ENERGY SPARKS ===
    float spark_zone = smoothstep(progress - 0.05, progress, dist);
    spark_zone *= 1.0 - smoothstep(progress, progress + 0.05, dist);
    
    float spark_noise = hash(UV * 100.0 + TIME);
    float sparks = step(0.92, spark_noise) * spark_zone;
    final_color.rgb += secondary_color.rgb * 3.0 * sparks;
    final_color.a = max(final_color.a, sparks);
    
    // === OVERALL FADE ===
    final_color.a *= 1.0 - pow(progress, 0.5);
    
    // Discard transparent pixels
    if (final_color.a < 0.01) {
        discard;
    }
    
    COLOR = final_color;
}
