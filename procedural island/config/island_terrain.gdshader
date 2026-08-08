shader_type spatial;

// ==========================================
// SAND SETTINGS
// ==========================================
group_uniforms Sand;
uniform vec3 sand_color : source_color = vec3(0.9, 0.7, 0.3);
uniform bool sand_ignore_color = false; // Check this to ignore the color above

uniform sampler2D sand_texture : source_color, hint_default_white;
uniform sampler2D sand_normal : hint_normal;
uniform float sand_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float sand_roughness : hint_range(0.0, 1.0) = 0.9;

uniform vec2 sand_scale = vec2(10.0, 10.0);
uniform float sand_rotation = 0.0; // In radians

// ==========================================
// DIRT SETTINGS
// ==========================================
group_uniforms Dirt;
uniform vec3 dirt_color : source_color = vec3(0.2, 0.6, 0.2);
uniform bool dirt_ignore_color = false; // Check this to ignore the color above

uniform sampler2D dirt_texture : source_color, hint_default_white;
uniform sampler2D dirt_normal : hint_normal;
uniform float dirt_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float dirt_roughness : hint_range(0.0, 1.0) = 0.85;

uniform vec2 dirt_scale = vec2(10.0, 10.0);
uniform float dirt_rotation = 0.0; // In radians

group_uniforms Terrain;
uniform float sand_level = 2.0;
uniform float blend_softness = 1.5;

// Assign a FastNoiseLite texture here to randomize the tiling
uniform sampler2D anti_tiling_noise : hint_default_white;
uniform float mix_rotation_offset = 1.1; // The angle offset for the hidden second texture layer
uniform float mix_strength : hint_range(0.0, 1.0) = 0.6; // How heavily to scramble the tiles

varying float local_y;

void vertex() {
	// Store the height of the geometry to use in the fragment shader
	local_y = VERTEX.y;
}

// Helper function to rotate UV coordinates around their center point
vec2 rotate_uv(vec2 uv, float rotation) {
	float sine = sin(rotation);
	float cosine = cos(rotation);
	uv -= 0.5; // Shift to center
	vec2 rotated_uv = vec2(
		uv.x * cosine - uv.y * sine,
		uv.x * sine + uv.y * cosine
	);
	return rotated_uv + 0.5; // Shift back
}

void fragment() {
	// --- ANTI-TILING NOISE ---
	// We read a noise map to randomly blend between two different angles of the same texture.
	// This hides the visible "grid" repetition of tiled textures.
	float noise_val = texture(anti_tiling_noise, UV * 2.0).r * mix_strength;

	// --- CALCULATE UVs ---
	// Base UVs
	vec2 s_base_uv = rotate_uv(UV * sand_scale, sand_rotation);
	vec2 d_base_uv = rotate_uv(UV * dirt_scale, dirt_rotation);

	// Mixed UVs (Rotated further and slightly shifted)
	vec2 s_mix_uv = rotate_uv(UV * sand_scale, sand_rotation + mix_rotation_offset) + vec2(0.43, 0.76);
	vec2 d_mix_uv = rotate_uv(UV * dirt_scale, dirt_rotation + mix_rotation_offset) + vec2(0.21, 0.84);

	// --- SAMPLE SAND ---
	vec3 s_tex_base = texture(sand_texture, s_base_uv).rgb;
	vec3 s_tex_mix  = texture(sand_texture, s_mix_uv).rgb;
	vec3 s_albedo_tex = mix(s_tex_base, s_tex_mix, noise_val);
	vec3 s_albedo = sand_ignore_color ? s_albedo_tex : s_albedo_tex * sand_color;

	vec3 s_norm_base = texture(sand_normal, s_base_uv).rgb;
	vec3 s_norm_mix  = texture(sand_normal, s_mix_uv).rgb;
	vec3 s_normal = mix(s_norm_base, s_norm_mix, noise_val);

	// --- SAMPLE DIRT ---
	vec3 d_tex_base = texture(dirt_texture, d_base_uv).rgb;
	vec3 d_tex_mix  = texture(dirt_texture, d_mix_uv).rgb;
	vec3 d_albedo_tex = mix(d_tex_base, d_tex_mix, noise_val);
	vec3 d_albedo = dirt_ignore_color ? d_albedo_tex : d_albedo_tex * dirt_color;

	vec3 d_norm_base = texture(dirt_normal, d_base_uv).rgb;
	vec3 d_norm_mix  = texture(dirt_normal, d_mix_uv).rgb;
	vec3 d_normal = mix(d_norm_base, d_norm_mix, noise_val);

	// --- BLENDING HEIGHT ---
	float blend = smoothstep(sand_level - blend_softness, sand_level + blend_softness, local_y);

	// --- FINAL PBR OUTPUT ---
	ALBEDO = mix(s_albedo, d_albedo, blend);
	NORMAL_MAP = mix(s_normal, d_normal, blend);
	METALLIC = mix(sand_metallic, dirt_metallic, blend);
	ROUGHNESS = mix(sand_roughness, dirt_roughness, blend);
}