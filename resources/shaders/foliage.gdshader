shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.3;
uniform float transmission_strength : hint_range(0.0, 1.0) = 0.65; // Translucidez para el brillo del atardecer
uniform float normal_up_blend : hint_range(0.0, 1.0) = 0.75;      // Mezcla de normales hacia el cielo
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

void vertex() {
	// Mezcla sutil de la normal hacia arriba: evita caras negras pero mantiene leve volumen 3D con la luz del atardecer
	NORMAL = mix(NORMAL, vec3(0.0, 1.0, 0.0), normal_up_blend);
}

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO = albedo_tex.rgb;
	
	// Transparencia por recorte Alpha Scissor
	ALPHA = albedo_tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	
	// Luz de atardecer atravesando las hojas (brillo dorado a contraluz)
	BACKLIGHT = albedo_tex.rgb * transmission_strength;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
}
