shader_type canvas_item;

// Draws a solid outline around the opaque part of a sprite by sampling
// neighbouring texels' alpha. Width is in texture pixels; the camp
// scales it per-sprite so the on-screen thickness stays consistent.

uniform vec4 outline_color : source_color = vec4(1.0, 0.85, 0.35, 1.0);
uniform float outline_width : hint_range(0.0, 32.0) = 6.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 px = outline_width / vec2(textureSize(TEXTURE, 0));

	float neighbour = 0.0;
	neighbour = max(neighbour, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	neighbour = max(neighbour, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	neighbour = max(neighbour, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	neighbour = max(neighbour, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	neighbour = max(neighbour, texture(TEXTURE, UV + px).a);
	neighbour = max(neighbour, texture(TEXTURE, UV - px).a);
	neighbour = max(neighbour, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
	neighbour = max(neighbour, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);

	float edge = neighbour * (1.0 - col.a);
	COLOR = mix(col, outline_color, edge);
}
