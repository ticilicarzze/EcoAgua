shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

## Optimized Water Shader for Godot 4 Compatibility Backend (VR Target)
## Supports dynamic albedo transitions, dual-panning ripples, and depth-based turbidity.

// Color & Material Uniforms
uniform vec4 albedo_color : source_color = vec4(0.1, 0.4, 0.5, 0.85);
uniform float roughness : hint_range(0.0, 1.0) = 0.08;
uniform float metallic : hint_range(0.0, 1.0) = 0.05;

// Flow Uniforms
uniform float flow_speed : hint_range(0.0, 10.0) = 1.0;
uniform vec2 flow_direction = vec2(1.0, 0.0);

// Surface Normal Ripples Uniforms
uniform sampler2D normal_map_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(0.0, 2.0) = 0.4;
uniform vec2 texture_scale = vec2(2.0, 2.0);

// Turbidity & Depth Extinction Uniforms
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float extinction_coefficient : hint_range(0.0, 50.0) = 2.0;
uniform vec4 turbidity_color : source_color = vec4(0.2, 0.18, 0.12, 1.0);

void fragment() {
	// 1. Set base material properties
	METALLIC = metallic;
	ROUGHNESS = roughness;

	// 2. Dual-panning normal maps (simulating dynamic flow)
	// Panning directions are offset to create a natural interference pattern
	vec2 panned_uv1 = UV * texture_scale + (flow_direction * flow_speed * TIME * 0.04);
	vec2 panned_uv2 = (UV * texture_scale * 1.4) + (vec2(-flow_direction.y, flow_direction.x) * flow_speed * TIME * 0.03);

	vec3 normal1 = texture(normal_map_texture, panned_uv1).rgb * 2.0 - 1.0;
	vec3 normal2 = texture(normal_map_texture, panned_uv2).rgb * 2.0 - 1.0;
	
	// Blend normal maps (linear blend for mobile VR performance)
	vec3 blended_normal = normalize(normal1 + normal2);
	NORMAL_MAP = blended_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_scale;

	// 3. Depth-based Extinction (Turbidity)
	// Sample depth buffer value at current screen coordinate
	float depth_val = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	
	// Reconstruct view-space depth (distance from camera to background object)
	vec4 upk = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_val, 1.0);
	upk.xyz /= upk.w;
	float depth_view_z = -upk.z;
	
	// View-space distance from camera to water fragment Y-level
	float fragment_view_z = -VERTEX.z;
	
	// Compute vertical depth difference of water column, clamping negative values
	float depth_diff = max(depth_view_z - fragment_view_z, 0.0);
	
	// Exponential decay (Beer-Lambert law) for light absorption/turbidity
	float extinction = exp(-depth_diff * extinction_coefficient);

	// Sample background screen color
	vec3 background_color = texture(screen_texture, SCREEN_UV).rgb;
	
	// Mix water albedo and turbidity color
	// In shallower regions, albedo_color dominates; in deeper regions, it becomes turbidity_color.
	vec3 water_color = mix(turbidity_color.rgb, albedo_color.rgb, extinction);
	
	// Final blend: mix the computed water color with the background color
	// Surface transparency blends with background based on alpha and extinction
	float blend_alpha = extinction * (1.0 - albedo_color.a);
	ALBEDO = mix(water_color, background_color, blend_alpha);
	
	// Set ALPHA to 1.0 because background blending was done manually in-shader
	// This avoids double transparency blending in Godot's forward/compatibility pass
	ALPHA = 1.0;
}
