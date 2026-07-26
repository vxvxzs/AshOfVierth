shader_type canvas_item;

// Used only during the return cinematic, when the character recedes into
// a deliberately soft painted background.
uniform float blur_radius : hint_range(0.0, 2.0) = 0.0;

void fragment() {
	vec2 offset = TEXTURE_PIXEL_SIZE * blur_radius;
	vec4 color = texture(TEXTURE, UV) * 0.4;
	color += texture(TEXTURE, UV + vec2(offset.x, 0.0)) * 0.15;
	color += texture(TEXTURE, UV - vec2(offset.x, 0.0)) * 0.15;
	color += texture(TEXTURE, UV + vec2(0.0, offset.y)) * 0.15;
	color += texture(TEXTURE, UV - vec2(0.0, offset.y)) * 0.15;
	COLOR = color;
}
