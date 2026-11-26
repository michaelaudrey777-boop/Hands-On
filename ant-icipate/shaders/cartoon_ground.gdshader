shader_type canvas_item;

// Makes the photo texture look more flat and cartoony

uniform float blur : hint_range(0.0, 12.0) = 4.0;            // spread of the blur in texture pixels. Kills noise.
uniform float contrast : hint_range(0.0, 1.0) = 0.55;        // low = flatter and calmer
uniform float saturation : hint_range(0.0, 2.0) = 0.9;
uniform float brightness : hint_range(0.5, 1.5) = 1.05;
uniform float posterize_steps : hint_range(2.0, 24.0) = 8.0; // fewer steps = more cartoon
uniform vec4 flat_tint : source_color = vec4(0.95, 0.82, 0.70, 1.0); // colors fade toward this

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur;
	vec3 sum = vec3(0.0);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			sum += texture(TEXTURE, UV + vec2(float(x), float(y)) * px).rgb;
		}
	}
	vec3 c = sum / 9.0;

	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(g), c, saturation);
	c = mix(flat_tint.rgb, c, contrast);
	c *= brightness;
	c = floor(c * posterize_steps + 0.5) / posterize_steps;

	COLOR = vec4(c, COLOR.a);
}