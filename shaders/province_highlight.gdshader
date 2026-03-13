shader_type canvas_item;

// --- NOVÉ UNIFORMY PRO DYNAMICKOU MAPU ---
uniform sampler2D id_map;          // Sem hodíš tu novou ProvinceMask.png z Pythonu
uniform sampler2D data_texture;    // Tento "proužek" budeme posílat z GDScriptu
uniform float total_provinces = 5000.0; // Uprav podle počtu provincií v tvém txt

// --- TVOJE LOGIKA, ALE PŘEVEDENÁ NA ID ---
uniform float hovered_id = -1.0;
uniform float selected_id = -1.0;
uniform bool has_hover = false;
uniform bool has_selected = false;

void fragment() {
	// 1. Přečteme pixel z masky s IDčky
	vec4 mask_color = texture(id_map, UV);

	// Pokud je maska průhledná (moře, okraje), necháme původní texturu Spritu
	if (mask_color.a < 0.1) {
		COLOR = texture(TEXTURE, UV);
	} else {
		// 2. Dekódování ID z RGB (r + g*256 + b*65536)
		float prov_id = round(mask_color.r * 255.0) + 
						round(mask_color.g * 255.0) * 256.0 + 
						round(mask_color.b * 255.0) * 65536.0;

		// 3. Spočítáme X souřadnici pro data texturu (přidáme 0.5 pro střed pixelu)
		float data_x = (prov_id + 0.5) / total_provinces;

		// 4. Přečteme barvu pro danou provincii (politika, GDP, populace z GDScriptu)
		vec4 mode_color = texture(data_texture, vec2(data_x, 0.5));

		// 5. Tvoje původní logika pro highlight a select!
		// Používáme abs(), abychom se vyhnuli float nepřesnostem při porovnávání ID
		if (has_selected && abs(prov_id - selected_id) < 0.1) {
			COLOR.rgb = mix(mode_color.rgb, vec3(0.0, 1.0, 1.0), 0.5); // Tvoje azurová
			COLOR.a = mode_color.a;
		} else if (has_hover && abs(prov_id - hovered_id) < 0.1) {
			COLOR.rgb = mix(mode_color.rgb, vec3(1.0, 1.0, 0.0), 0.3); // Tvoje žlutá
			COLOR.a = mode_color.a;
		} else {
			// Normální barva provincie podle aktuálního módu
			COLOR = mode_color;
		}
	}
}