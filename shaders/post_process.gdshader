shader_type canvas_item;

// Full-screen cinematic post stack: bloom (bright-pass gather), chromatic
// aberration, contrast/saturation grade and animated film grain. Reads the
// rendered frame via the screen texture, so it sits on a CanvasLayer above the
// world but below the HUD.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float bloom_intensity = 1.0;
uniform float bloom_threshold = 0.55;
uniform float ca_amount = 0.0016;
uniform float contrast = 1.08;
uniform float saturation = 1.14;
uniform float grain = 0.045;
uniform vec3 grade_tint = vec3(1.0, 1.0, 1.0);

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;

	// Chromatic aberration, strongest toward the edges.
	vec2 dir = uv - vec2(0.5);
	vec3 base;
	base.r = texture(screen_tex, uv + dir * ca_amount).r;
	base.g = texture(screen_tex, uv).g;
	base.b = texture(screen_tex, uv - dir * ca_amount).b;

	// Bloom: gather bright pixels in three rings and add them back.
	vec3 bloom = vec3(0.0);
	float total = 0.0;
	for (int r = 1; r <= 3; r++) {
		float rad = float(r) * 2.0;
		float w = 1.0 / float(r);
		for (int i = 0; i < 8; i++) {
			float a = float(i) / 8.0 * 6.2831853;
			vec2 off = vec2(cos(a), sin(a)) * rad * px;
			vec3 s = texture(screen_tex, uv + off).rgb;
			bloom += max(s - bloom_threshold, vec3(0.0)) * w;
			total += w;
		}
	}
	bloom /= max(total, 0.001);

	vec3 col = base + bloom * bloom_intensity;
	col = (col - 0.5) * contrast + 0.5;
	float l = luma(col);
	col = mix(vec3(l), col, saturation);
	col *= grade_tint;
	col += (hash(uv * vec2(1920.0, 1080.0) + vec2(TIME)) - 0.5) * grain;

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
