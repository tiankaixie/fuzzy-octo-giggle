shader_type canvas_item;

// Adds a lit rim along a sprite's silhouette so the (otherwise flat) pixel
// character reads as a backlit form against the graded scene. Edge pixels are
// brightened toward rim_color; top edges (overhead key light) get extra punch.
// Flip-invariant, so it works with AnimatedSprite2D.flip_h.

uniform vec4 rim_color : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform float rim_strength = 0.7;
uniform float top_boost = 0.6;

void fragment() {
	// Multiply by the incoming COLOR so node modulate (archetype tint, death
	// fade) is preserved.
	vec4 col = texture(TEXTURE, UV) * COLOR;
	if (col.a < 0.5) {
		COLOR = col;
	} else {
		vec2 px = TEXTURE_PIXEL_SIZE * 1.4;
		float up = texture(TEXTURE, UV + vec2(0.0, -1.0) * px).a;
		float dn = texture(TEXTURE, UV + vec2(0.0, 1.0) * px).a;
		float lf = texture(TEXTURE, UV + vec2(-1.0, 0.0) * px).a;
		float rt = texture(TEXTURE, UV + vec2(1.0, 0.0) * px).a;
		float edge = 1.0 - step(0.5, min(min(up, dn), min(lf, rt)));
		float top = (1.0 - step(0.5, up)) * top_boost;
		float amount = clamp(edge * rim_strength + top, 0.0, 1.0);
		col.rgb = mix(col.rgb, rim_color.rgb, amount);
		COLOR = col;
	}
}
