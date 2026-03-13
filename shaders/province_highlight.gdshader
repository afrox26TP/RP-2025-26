shader_type canvas_item;

uniform sampler2D id_map : filter_nearest;
uniform sampler2D data_texture : filter_nearest; 
uniform float total_provinces = 5000.0;

uniform float hovered_id = -1.0;
uniform float selected_id = -1.0;
uniform bool has_hover = false;
uniform bool has_selected = false;

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

		vec4 base_color = mode_color.a < 0.1 ? texture(TEXTURE, UV) : mode_color;

		// --- OPRAVENÝ HOVER A SELECT ---
		if (has_selected && abs(prov_id - selected_id) < 0.1) {
			// Pokud je podklad průhledný, použijeme rovnou čistou azurovou. Jinak mícháme.
			COLOR.rgb = base_color.a < 0.1 ? vec3(0.0, 1.0, 1.0) : mix(base_color.rgb, vec3(0.0, 1.0, 1.0), 0.5);
			COLOR.a = 0.8; // Vynucená viditelnost, aby se moře ukázalo!
		} else if (has_hover && abs(prov_id - hovered_id) < 0.1) {
			// Pokud je podklad průhledný, použijeme rovnou čistou žlutou. Jinak mícháme.
			COLOR.rgb = base_color.a < 0.1 ? vec3(1.0, 1.0, 0.0) : mix(base_color.rgb, vec3(1.0, 1.0, 0.0), 0.4);
			COLOR.a = 0.6; // Vynucená viditelnost pro hover!
		} else {
			COLOR = base_color;
		}
	}
}