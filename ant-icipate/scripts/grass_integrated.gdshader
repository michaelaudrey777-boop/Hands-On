shader_type canvas_item;

uniform vec2 shadow_offset = vec2(-0.025, -0.055);
uniform vec4 shadow_color : source_color = vec4(0.12, 0.08, 0.05, 0.44);
uniform vec4 ground_tint : source_color = vec4(1.0, 0.96, 0.87, 1.0);
uniform float root_darken : hint_range(0.0, 1.0) = 0.45;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.8;
uniform float wind_strength : hint_range(0.0, 20.0) = 5.0;

void vertex() {
	// Pangkal akar (UV.y = 1.0) menancap diam di tanah, pucuk daun (UV.y = 0.0) bergoyang
	float sway_factor = pow(1.0 - UV.y, 1.6);
	float wave = sin(TIME * wind_speed + (VERTEX.x + VERTEX.y) * 0.008);
	VERTEX.x += wave * wind_strength * sway_factor;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	vec2 shadow_uv = UV + shadow_offset;
	float shadow_alpha = 0.0;
	if (shadow_uv.x >= 0.0 && shadow_uv.x <= 1.0 && shadow_uv.y >= 0.0 && shadow_uv.y <= 1.0) {
		shadow_alpha = texture(TEXTURE, shadow_uv).a;
	}

	float root_mask = smoothstep(0.60, 0.90, UV.y);
	float ao = mix(1.0, 1.0 - root_darken, root_mask);
	vec3 grass_rgb = tex.rgb * ground_tint.rgb * ao;
	vec4 grass_col = vec4(grass_rgb, tex.a);

	vec4 shadow_col = vec4(shadow_color.rgb, shadow_alpha * shadow_color.a);
	COLOR = mix(shadow_col, grass_col, grass_col.a);
}