shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

// ─── Texturas por zona (lecho del río) ────────────────────────────────────────────
uniform sampler2D tex_zona1 : source_color, hint_default_white;
uniform sampler2D tex_zona2 : source_color, hint_default_white;
uniform sampler2D tex_zona3 : source_color, hint_default_white;
// Zona 4 comparte textura con Zona 3

// ─── Textura de borde/orilla del río ─────────────────────────────────────────
uniform sampler2D tex_bank : source_color, hint_default_white;

// ─── Textura de la llanura superior (Suelo_Zona.glb) ────────────────────────
uniform sampler2D tex_top : source_color, hint_default_white;

// ─── Mapa de normales ─────────────────────────────────────────────────────────
uniform sampler2D normal_map : hint_normal;
uniform float normal_scale : hint_range(0.0, 4.0) = 0.0;

// ─── UV triplanar ─────────────────────────────────────────────────────────────
uniform float uv_scale : hint_range(0.01, 2.0) = 0.2;

// ─── Límites Z de las zonas (mundo) ──────────────────────────────────────────
uniform float z_blend_z1z2 : hint_range(-300.0, 0.0) = -70.0;
uniform float z_blend_z2z3 : hint_range(-300.0, 0.0) = -140.0;
uniform float z_blend_z3z4 : hint_range(-300.0, 0.0) = -210.0;
uniform float blend_half_width : hint_range(1.0, 40.0) = 12.0;

uniform float roughness : hint_range(0.0, 1.0) = 0.95;

// ─── Vertex displacement del lecho ──────────────────────────────────────────────
uniform float displacement_strength : hint_range(0.0, 1.5) = 0.45;  // metros de relieve máximo
uniform float displacement_frequency : hint_range(0.01, 1.0) = 0.10; // frecuencia espacial

// ─── Variación de altura de barranca ──────────────────────────────────────────
uniform float bank_height_strength : hint_range(0.0, 3.0) = 1.2;

// ─── Ruido de valor 2D (para vertex shader y mezcla de fragmentos) ───────────
float hash_v(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);  // smoothstep
	float a = hash_v(i);
	float b = hash_v(i + vec2(1.0, 0.0));
	float c = hash_v(i + vec2(0.0, 1.0));
	float d = hash_v(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Multi-octave fractal para relieve orgánico (4 octavas)
float fbm_bed(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int oct = 0; oct < 4; oct++) {
		v    += value_noise(p * freq) * amp;
		freq *= 2.13;  // ratio no entero → evita armonía entre octavas
		amp  *= 0.48;
	}
	return v;  // rango aprox [0, 1]
}

// ─── Vertex: desplazamiento del lecho + variación de altura de barranca ─────────────
void vertex() {
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// ── 1. Lecho: bultos y hundimientos en el fondo del canal (basado en elevación local) ──
	float bed_mask = smoothstep(-1.2, -2.2, VERTEX.y);
	float noise_val = fbm_bed(wpos.xz * displacement_frequency);
	float disp = (noise_val - 0.5) * 2.0 * displacement_strength;
	VERTEX.y += disp * bed_mask;

	// ── 2. Barranca: variación de altura a lo largo del recorrido (eje Z) ──────
	float bank_mask = smoothstep(-2.0, 0.5, VERTEX.y);
	float bank_var = sin(wpos.z * 0.018) * 0.45
	              + sin(wpos.z * 0.007 + 1.3) * 0.30
	              + (fbm_bed(vec2(wpos.z * 0.009, 0.57)) - 0.5) * 0.50;
	VERTEX.y += bank_var * bank_height_strength * bank_mask;
}

// ─── Anti-tiling suave multifrecuencia (sin costuras ni marcas de cuadrícula) ──
vec3 sample_antitile(sampler2D tex, vec2 uv) {
	vec3 col1 = texture(tex, uv).rgb;
	vec3 col2 = texture(tex, uv * 0.437 + vec2(17.3, 31.7)).rgb;
	float n = value_noise(uv * 0.65);
	return mix(col1, col2, n);
}

// ─── Triplanar con anti-tiling suave ──────────────────────────────────────────
vec3 triplanar_antitile(sampler2D tex, vec3 world_pos, vec3 world_normal) {
	vec3 blend = abs(world_normal);
	blend = max(blend, 0.00001);
	float b = blend.x + blend.y + blend.z;
	blend /= b;
	vec3 xz = sample_antitile(tex, world_pos.xz * uv_scale);
	vec3 xy = sample_antitile(tex, world_pos.xy * uv_scale);
	vec3 zy = sample_antitile(tex, world_pos.zy * uv_scale);
	return xz * blend.y + xy * blend.z + zy * blend.x;
}

void fragment() {
	vec3 wpos  = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wnorm = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);

	// Texturas por zona con anti-tiling (lecho del río)
	vec3 c1 = triplanar_antitile(tex_zona1, wpos, wnorm);
	vec3 c2 = triplanar_antitile(tex_zona2, wpos, wnorm);
	vec3 c3 = triplanar_antitile(tex_zona3, wpos, wnorm);
	vec3 c4 = c3;

	// Textura de borde/orilla y llanura superior (Suelo_Zona)
	vec3 c_bank = triplanar_antitile(tex_bank, wpos, wnorm);
	vec3 c_top  = triplanar_antitile(tex_top, wpos, wnorm);

	// Blending por posición Z (entre zonas del lecho)
	float t12 = smoothstep(z_blend_z1z2 + blend_half_width, z_blend_z1z2 - blend_half_width, wpos.z);
	float t23 = smoothstep(z_blend_z2z3 + blend_half_width, z_blend_z2z3 - blend_half_width, wpos.z);
	float t34 = smoothstep(z_blend_z3z4 + blend_half_width, z_blend_z3z4 - blend_half_width, wpos.z);

	vec3 zone_col = mix(c1, c2, t12);
	zone_col       = mix(zone_col, c3, t23);
	zone_col       = mix(zone_col, c4, t34);

	// ─── Blending orgánico y continuo (lecho -> borde -> planicie) ───────────
	// 1. Ruido espacial en el mundo para romper líneas rectas y marcas horizontales
	float edge_noise = (value_noise(wpos.xz * 0.05) - 0.5) * 0.9;
	float effective_y = wpos.y + edge_noise;

	// 2. Inclinación del terreno (0.0 horizontal, 1.0 vertical)
	float slope = clamp(1.0 - wnorm.y, 0.0, 1.0);

	// 3. Mezcla lecho -> borde del río (bank_blend):
	// Transición vertical gradual desde -2.4m hasta +0.4m combinada con inclinación
	float bank_height_factor = smoothstep(-2.4, 0.4, effective_y);
	float bank_blend = clamp(bank_height_factor + slope * 0.5, 0.0, 1.0);

	// 4. Mezcla borde del río -> planicie superior (top_blend):
	// Transición vertical gradual desde -0.2m hasta +2.6m
	float top_height_factor = smoothstep(-0.2, 2.6, effective_y);
	// En barrancas inclinadas, mantener la textura de borde reduciendo la planicie
	float slope_suppression = smoothstep(0.40, 0.10, slope);
	float top_blend = clamp(top_height_factor * slope_suppression, 0.0, 1.0);

	// Composición final por capas
	vec3 col = mix(zone_col, c_bank, bank_blend);
	col      = mix(col, c_top, top_blend);

	ALBEDO    = col;
	ROUGHNESS = roughness;
	METALLIC  = 0.0;

	if (normal_scale > 0.001) {
		vec3 n = texture(normal_map, wpos.xz * uv_scale).rgb * 2.0 - 1.0;
		NORMAL_MAP       = n;
		NORMAL_MAP_DEPTH = normal_scale;
	}
}
