shader_type canvas_item;

uniform vec2 shadow_offset_px = vec2(10.0, 18.0);
uniform vec4 shadow_color : source_color = vec4(0.14, 0.08, 0.06, 0.50);
uniform vec4 ground_tint : source_color = vec4(1.03, 0.94, 0.88, 1.0);
uniform float base_ao_strength : hint_range(0.0, 1.0) = 0.35;

varying vec2 v_local_pos;

void vertex() {
	v_local_pos = VERTEX;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	vec2 dpos_x = dFdx(v_local_pos);
	vec2 dpos_y = dFdy(v_local_pos);
	vec2 uv_per_px_x = dFdx(UV) / (abs(dpos_x.x) > 0.0001 ? dpos_x.x : 1.0);
	vec2 uv_per_px_y = dFdy(UV) / (abs(dpos_y.y) > 0.0001 ? dpos_y.y : 1.0);

	vec2 shadow_uv = UV - (uv_per_px_x * shadow_offset_px.x + uv_per_px_y * shadow_offset_px.y);
	float shadow_alpha = 0.0;
	if (shadow_uv.x >= 0.0 && shadow_uv.x <= 1.0 && shadow_uv.y >= 0.0 && shadow_uv.y <= 1.0) {
		shadow_alpha = texture(TEXTURE, shadow_uv).a;
	}

	float upright_v = uv_per_px_y.y < 0.0 ? (1.0 - UV.y) : UV.y;
	float bottom_ao = mix(1.0, 1.0 - base_ao_strength, smoothstep(0.55, 0.95, upright_v));
	vec3 rock_rgb = tex.rgb * ground_tint.rgb * bottom_ao;
	vec4 rock_col = vec4(rock_rgb, tex.a);

	vec4 shadow_col = vec4(shadow_color.rgb, shadow_alpha * shadow_color.a);
	COLOR = mix(shadow_col, rock_col, rock_col.a);
}