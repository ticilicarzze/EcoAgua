shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

// --- Uniforms de textura ---
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D opacity_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;

// --- Parámetros de apariencia ---
uniform vec4 foam_color : source_color = vec4(0.96, 0.94, 0.88, 1.0); // Blanco crema orgánico
uniform float foam_contrast : hint_range(0.5, 3.0, 0.1) = 1.6;
uniform float foam_strength : hint_range(0.0, 3.0, 0.05) = 1.5;
uniform float roughness_val : hint_range(0.0, 1.0, 0.05) = 0.6;
uniform float normal_depth : hint_range(0.0, 2.0, 0.05) = 1.0;
uniform float emission_boost : hint_range(0.0, 1.0, 0.02) = 0.08; // Leve realce para visibilidad sobre agua oscura

// --- Parámetros de animación y escala ---
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 drift_speed = vec2(0.0, 0.012); // Deriva muy lenta simulando corriente suave
uniform float edge_falloff_power : hint_range(0.5, 4.0, 0.1) = 1.5;

void fragment() {
	// Desvanecimiento radial desde el centro del Quad para eliminar cualquier borde cuadrado
	float dist_from_center = distance(UV, vec2(0.5));
	float radial_mask = smoothstep(0.5, 0.15, dist_from_center);
	radial_mask = pow(radial_mask, edge_falloff_power);

	// Coordenadas UV animadas con deriva lenta
	vec2 uv = UV * uv_scale + drift_speed * TIME;

	// Muestreo de texturas
	vec4 col = texture(albedo_texture, uv);
	float raw_opacity = texture(opacity_texture, uv).r;

	// Curva de contraste para que los racimos de burbujas sean densos y definidos (como en la foto)
	float bubble_opacity = smoothstep(0.06, 0.42, raw_opacity);
	bubble_opacity = pow(bubble_opacity, 1.0 / foam_contrast);

	// Alpha compuesto: burbujas * máscara radial suave * fuerza
	float final_alpha = bubble_opacity * radial_mask * foam_strength * foam_color.a;

	// Asignación de canales PBR: espuma cremosa brillante que resalta sobre el barro
	vec3 base_foam = foam_color.rgb * mix(vec3(0.85), vec3(1.05), col.r);
	ALBEDO = base_foam;
	ROUGHNESS = roughness_val;
	SPECULAR = 0.25;
	METALLIC = 0.0;
	NORMAL_MAP = texture(normal_texture, uv).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	EMISSION = base_foam * emission_boost;
	ALPHA = clamp(final_alpha, 0.0, 1.0);
}
