// Recorta la textura a un círculo (avatares del chat).
shader_type canvas_item;

void fragment() {
	vec2 d = UV - vec2(0.5);
	vec4 c = texture(TEXTURE, UV);
	c.a *= 1.0 - smoothstep(0.235, 0.25, dot(d, d));
	COLOR = c;
}
