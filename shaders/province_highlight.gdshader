shader_type canvas_item;

uniform sampler2D id_map : filter_nearest;
uniform sampler2D data_texture : filter_nearest; 
uniform sampler2D occupation_texture : filter_nearest;
uniform sampler2D selected_multi_texture : filter_nearest;
uniform sampler2D capital_focus_owned_texture : filter_nearest;
uniform sampler2D capital_focus_valid_texture : filter_nearest;
uniform float total_provinces = 5000.0;
uniform vec4 selected_multi_color : source_color = vec4(0.95, 0.85, 0.25, 1.0);
uniform bool peace_selection_player_color_mode = false;
uniform bool peace_target_visual_mode = false;
uniform vec4 peace_target_owner_color : source_color = vec4(0.8, 0.2, 0.2, 1.0);
uniform bool low_detail_mode = false;

uniform float hovered_id = -1.0;
uniform float selected_id = -1.0;
uniform bool has_hover = false;
uniform bool has_selected = false;
uniform bool capital_focus_mode = false;

// --- NEW: Parameter to track if we are picking a target for army movement ---
uniform bool is_target_hover = false;

float _decode_province_id(vec4 mask_color) {
	return round(mask_color.r * 255.0) +
		round(mask_color.g * 255.0) * 256.0 +
		round(mask_color.b * 255.0) * 65536.0;
}

void fragment() {
	vec4 mask_color = texture(id_map, UV);
	
	if (mask_color.a < 0.1) {
		COLOR = texture(TEXTURE, UV);
	} else {
		float prov_id = _decode_province_id(mask_color);

		float data_x = (prov_id + 0.5) / total_provinces;
		vec4 mode_color = texture(data_texture, vec2(data_x, 0.5));
		vec4 occupation_flag = texture(occupation_texture, vec2(data_x, 0.5));
		vec4 multi_selected_flag = texture(selected_multi_texture, vec2(data_x, 0.5));
		vec4 focus_owned_flag = texture(capital_focus_owned_texture, vec2(data_x, 0.5));
		vec4 focus_valid_flag = texture(capital_focus_valid_texture, vec2(data_x, 0.5));

		vec4 base_color = mode_color.a < 0.1 ? texture(TEXTURE, UV) : mode_color;

		if (!low_detail_mode && occupation_flag.a > 0.5) {
			float px = UV.x / TEXTURE_PIXEL_SIZE.x;
			float py = UV.y / TEXTURE_PIXEL_SIZE.y;
			float hatch_step = 9.0;
			float hatch_width = 1.2;
			float hatch_diag = mod(px + py, hatch_step);
			float hatch = step(hatch_diag, hatch_width);
			base_color.rgb = mix(base_color.rgb, base_color.rgb * 0.72, hatch * 0.20);
		}

		if (capital_focus_mode) {
			bool is_owned_state = focus_owned_flag.a > 0.5;
			bool is_valid_target = focus_valid_flag.a > 0.5;

			if (!is_owned_state) {
				base_color.rgb = mix(base_color.rgb, vec3(0.03, 0.04, 0.06), 0.68);
			} else {
				base_color.rgb *= 0.92;
			}

			float border = 0.0;
			if (!low_detail_mode) {
				float px = TEXTURE_PIXEL_SIZE.x;
				float py = TEXTURE_PIXEL_SIZE.y;

				vec4 m_r = texture(id_map, UV + vec2(px, 0.0));
				vec4 m_l = texture(id_map, UV + vec2(-px, 0.0));
				vec4 m_u = texture(id_map, UV + vec2(0.0, py));
				vec4 m_d = texture(id_map, UV + vec2(0.0, -py));

				if (m_r.a > 0.1 && abs(_decode_province_id(m_r) - prov_id) > 0.1) border = 1.0;
				if (m_l.a > 0.1 && abs(_decode_province_id(m_l) - prov_id) > 0.1) border = 1.0;
				if (m_u.a > 0.1 && abs(_decode_province_id(m_u) - prov_id) > 0.1) border = 1.0;
				if (m_d.a > 0.1 && abs(_decode_province_id(m_d) - prov_id) > 0.1) border = 1.0;
			}

			if (is_valid_target) {
				if (peace_target_visual_mode) {
					base_color.rgb = mix(base_color.rgb, peace_target_owner_color.rgb, 0.78);
				} else {
					base_color.rgb = mix(base_color.rgb, vec3(0.98, 0.90, 0.35), 0.10);
				}
			}

			if (is_owned_state && border > 0.5) {
				vec3 border_col = vec3(0.62, 0.72, 0.80);
				if (is_valid_target) {
					border_col = vec3(1.0, 0.93, 0.45);
				}
				base_color.rgb = mix(base_color.rgb, border_col, 0.92);
			} else if (low_detail_mode && is_owned_state) {
				base_color.rgb = mix(base_color.rgb, vec3(0.72, 0.80, 0.88), 0.04);
			}
		}

		// Keep original default selection style; peace conference can use player color.
		if ((has_selected && abs(prov_id - selected_id) < 0.1) || multi_selected_flag.a > 0.5) {
			if (peace_selection_player_color_mode) {
				float tint_amount = 0.62;
				COLOR.rgb = mix(base_color.rgb, selected_multi_color.rgb, tint_amount);
			} else {
				float select_dim = 0.88;
				COLOR.rgb = base_color.rgb * select_dim;
			}
			COLOR.a = base_color.a;
		} else if (has_hover && abs(prov_id - hovered_id) < 0.1) {
			float hover_boost = is_target_hover ? 0.14 : 0.10;
			COLOR.rgb = mix(base_color.rgb, vec3(1.0), hover_boost);
			COLOR.a = base_color.a;
		} else {
			COLOR = base_color;
		}
	}
}