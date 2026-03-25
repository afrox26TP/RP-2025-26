shader_type canvas_item;

uniform sampler2D id_map : filter_nearest;
uniform sampler2D data_texture : filter_nearest; 
uniform sampler2D occupation_texture : filter_nearest;
uniform float total_provinces = 5000.0;

uniform float hovered_id = -1.0;
uniform float selected_id = -1.0;
uniform bool has_hover = false;
uniform bool has_selected = false;

// --- NEW: Parameter to track if we are picking a target for army movement ---
uniform bool is_target_hover = false;

void fragment() {
	vec4 mask_color = texture(id_map, UV);
	
	if (mask_color.a < 0.1) {
		COLOR = texture(TEXTURE, UV);
	} else {
		float prov_id = round(mask_color.r * 255.0) + 
						round(mask_color.g * 255.0) * 256.0 + 
						round(mask_color.b * 255.0) * 65536.0;

		float data_x = (prov_id + 0.5) / total_provinces;
		vec4 mode_color = texture(data_texture, vec2(data_x, 0.5));
		vec4 occupation_flag = texture(occupation_texture, vec2(data_x, 0.5));

		vec4 base_color = mode_color.a < 0.1 ? texture(TEXTURE, UV) : mode_color;

		if (occupation_flag.a > 0.5) {
			float px = UV.x / TEXTURE_PIXEL_SIZE.x;
			float py = UV.y / TEXTURE_PIXEL_SIZE.y;
			float hatch_step = 9.0;
			float hatch_width = 1.2;
			float hatch_diag = mod(px + py, hatch_step);
			float hatch = step(hatch_diag, hatch_width);
			base_color.rgb = mix(base_color.rgb, base_color.rgb * 0.72, hatch * 0.20);
		}

		// --- SELECTION AND HOVER LOGIC ---
		if (has_selected && abs(prov_id - selected_id) < 0.1) {
			// Cyan for selected province
			COLOR.rgb = base_color.a < 0.1 ? vec3(0.0, 1.0, 1.0) : mix(base_color.rgb, vec3(0.0, 1.0, 1.0), 0.5);
			COLOR.a = 0.8; 
		} else if (has_hover && abs(prov_id - hovered_id) < 0.1) {
			// --- MODIFIED: Switch to green color if targeting, otherwise keep yellow ---
			vec3 hover_color = is_target_hover ? vec3(0.2, 1.0, 0.2) : vec3(1.0, 1.0, 0.0);
			COLOR.rgb = base_color.a < 0.1 ? hover_color : mix(base_color.rgb, hover_color, 0.4);
			COLOR.a = 0.6; 
		} else {
			COLOR = base_color;
		}
	}
}