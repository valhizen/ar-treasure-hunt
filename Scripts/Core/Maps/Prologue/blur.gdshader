shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;

void fragment() {
    vec2 pixel_size = TEXTURE_PIXEL_SIZE * blur_amount;
    vec4 color = vec4(0.0);

    // Simple box blur
    for(float x = -2.0; x <= 2.0; x += 1.0) {
        for(float y = -2.0; y <= 2.0; y += 1.0) {
            color += texture(TEXTURE, UV + vec2(x, y) * pixel_size);
        }
    }
    color /= 25.0;

    COLOR = color;
}