shader_type canvas_item;

uniform vec2 shadow_offset = vec2(16.0, 10.0);
uniform float shadow_skew : hint_range(-1.0, 1.0) = 0.26;
uniform vec4 shadow_color : source_color = vec4(0.08, 0.05, 0.03, 0.42);
uniform float shadow_softness : hint_range(0.0, 8.0) = 2.5;

varying vec2 uv_scale;
varying vec2 uv_offset;
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float max_skew_px = abs(shadow_skew) * tex_size.y;
	float pad = max(abs(shadow_offset.x) + max_skew_px, abs(shadow_offset.y)) + shadow_softness * 4.0 + 8.0;
	vec2 new_size = tex_size + vec2(pad * 2.0);
	uv_scale = new_size / tex_size;
	uv_offset = vec2(pad) / tex_size;
	VERTEX += sign(UV - vec2(0.5)) * pad;
}

float sample_alpha(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).a;
}

float get_shadow_alpha(sampler2D tex, vec2 uv, vec2 pixel_size, float softness) {
	if (softness <= 0.01) {
		return sample_alpha(tex, uv);
	}
	vec2 d = pixel_size * softness;
	float a = sample_alpha(tex, uv) * 0.24;
	a += sample_alpha(tex, uv + vec2(d.x, 0.0)) * 0.12;
	a += sample_alpha(tex, uv - vec2(d.x, 0.0)) * 0.12;
	a += sample_alpha(tex, uv + vec2(0.0, d.y)) * 0.12;
	a += sample_alpha(tex, uv - vec2(0.0, d.y)) * 0.12;
	a += sample_alpha(tex, uv + vec2(d.x, d.y)) * 0.07;
	a += sample_alpha(tex, uv + vec2(-d.x, d.y)) * 0.07;
	a += sample_alpha(tex, uv + vec2(d.x, -d.y)) * 0.07;
	a += sample_alpha(tex, uv + vec2(-d.x, -d.y)) * 0.07;
	return a;
}

void fragment() {
	vec2 base_uv = UV * uv_scale - uv_offset;

	vec4 main_tex = vec4(0.0);
	if (base_uv.x >= 0.0 && base_uv.x <= 1.0 && base_uv.y >= 0.0 && base_uv.y <= 1.0) {
		main_tex = texture(TEXTURE, base_uv) * v_modulate;
	}

	vec2 shadow_uv = base_uv - shadow_offset * TEXTURE_PIXEL_SIZE;
	shadow_uv.x -= (0.90 - shadow_uv.y) * shadow_skew;

	float s_alpha = get_shadow_alpha(TEXTURE, shadow_uv, TEXTURE_PIXEL_SIZE, shadow_softness) * shadow_color.a * v_modulate.a;
	vec4 sh = vec4(shadow_color.rgb, s_alpha);

	float out_a = main_tex.a + sh.a * (1.0 - main_tex.a);
	vec3 out_rgb = vec3(0.0);
	if (out_a > 0.0001) {
		out_rgb = (main_tex.rgb * main_tex.a + sh.rgb * sh.a * (1.0 - main_tex.a)) / out_a;
	}

	COLOR = vec4(out_rgb, out_a);
}