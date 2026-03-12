shader_type canvas_item;

uniform sampler2D province_tex;
uniform vec3 hover_color;
uniform vec3 selected_color;
uniform bool has_hover;
uniform bool has_selected;

void fragment() {
	vec4 base_color = texture(TEXTURE, UV);
	vec3 prov = texture(province_tex, UV).rgb;

	float d_sel = distance(prov, selected_color);
	float d_hov = distance(prov, hover_color);

	if (has_selected && d_sel < 0.01) {
		COLOR.rgb = mix(base_color.rgb, vec3(0.0, 1.0, 1.0), 0.5);
	} else if (has_hover && d_hov < 0.01) {
		COLOR.rgb = mix(base_color.rgb, vec3(1.0, 1.0, 0.0), 0.3);
	} else {
		COLOR = base_color;
	}
}