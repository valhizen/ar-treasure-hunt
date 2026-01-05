shader_type canvas_item;

// Destruction atmosphere shader - makes scenes look ruined and abandoned

uniform float darkness : hint_range(0.0, 1.0) = 0.25;
uniform float desaturation : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.5;
uniform float vignette_size : hint_range(0.0, 1.0) = 0.3;
uniform vec4 tint_color : source_color = vec4(0.7, 0.75, 0.85, 1.0);
uniform float noise_strength : hint_range(0.0, 0.1) = 0.015;
uniform float time_scale : hint_range(0.0, 2.0) = 0.5;

// Crack overlay (optional - set texture in inspector)
uniform sampler2D crack_texture : hint_default_white;
uniform float crack_opacity : hint_range(0.0, 1.0) = 0.0;

// Dust/fog effect
uniform float fog_density : hint_range(0.0, 0.5) = 0.1;
uniform vec4 fog_color : source_color = vec4(0.6, 0.55, 0.5, 1.0);

// Simple noise function for film grain
float random(vec2 st, float seed) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233)) + seed) * 43758.5453123);
}

// Smooth noise for fog
float smooth_noise(vec2 st, float seed) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    
    float a = random(i, seed);
    float b = random(i + vec2(1.0, 0.0), seed);
    float c = random(i + vec2(0.0, 1.0), seed);
    float d = random(i + vec2(1.0, 1.0), seed);
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    
    // 1. Desaturate - makes it look abandoned
    float grey = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    color.rgb = mix(color.rgb, vec3(grey), desaturation);
    
    // 2. Apply cold tint - gives eerie feeling
    color.rgb = mix(color.rgb, color.rgb * tint_color.rgb, 0.6);
    
    // 3. Darken overall
    color.rgb *= (1.0 - darkness);
    
    // 4. Add subtle fog/dust in the air
    float fog_noise = smooth_noise(UV * 3.0 + TIME * time_scale * 0.1, 0.0);
    fog_noise += smooth_noise(UV * 6.0 - TIME * time_scale * 0.05, 100.0) * 0.5;
    fog_noise = fog_noise / 1.5;
    color.rgb = mix(color.rgb, fog_color.rgb * 0.5, fog_noise * fog_density);
    
    // 5. Vignette - dark edges for focus and mood
    vec2 center = UV - vec2(0.5);
    float dist = length(center);
    float vignette = smoothstep(vignette_size, vignette_size + 0.5, dist);
    color.rgb = mix(color.rgb, color.rgb * 0.2, vignette * vignette_strength);
    
    // 6. Film grain - subtle noise for gritty feel
    float noise = random(UV * 1000.0, TIME * 10.0) * noise_strength;
    color.rgb += noise - (noise_strength * 0.5);
    
    // 7. Optional crack overlay
    if (crack_opacity > 0.0) {
        vec4 cracks = texture(crack_texture, UV);
        color.rgb = mix(color.rgb, color.rgb * cracks.rgb, crack_opacity);
    }
    
    // 8. Slight color banding reduction
    color.rgb = clamp(color.rgb, 0.0, 1.0);
    
    COLOR = color;
}
