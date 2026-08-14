shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_toon, specular_toon;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.001);
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0.1, 128.0, 0.1);

uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;

uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);

uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

// --------------------
// Distance Fade Parameters
// --------------------
// NOTE: "hint_enum" requires Godot 4.3 or newer. 
// If you are on Godot 4.2 or older, change the line below to:
// uniform int distance_fade_mode : hint_range(0, 2, 1) = 0;
uniform int distance_fade_mode : hint_enum("Disabled", "PixelAlpha", "PixelDither") = 0;
uniform float distance_fade_min : hint_range(0.0, 4096.0, 0.1) = 0.0;
uniform float distance_fade_max : hint_range(0.0, 4096.0, 0.1) = 10.0;

// --------------------
// Wind / waviness
// --------------------
uniform bool use_wind = true;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.1;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.0;
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.0);

// Texture-based wind mask
uniform sampler2D wind_mask : hint_default_white;
uniform float wind_mask_strength : hint_range(0.0, 1.0) = 1.0;

void vertex() {
    UV = UV * uv1_scale.xy + uv1_offset.xy;

    if (use_wind) {
        float height_factor = clamp(VERTEX.y, 0.0, 1.0);
        float wave = sin(TIME * wind_speed + VERTEX.x * 0.5);
        float mask = texture(wind_mask, UV).r * wind_mask_strength;
        vec3 sway = normalize(wind_direction) * wave * wind_strength * height_factor * mask;
        VERTEX += sway;
    }
}

void fragment() {
    vec2 base_uv = UV;

    vec4 albedo_tex = texture(texture_albedo, base_uv);
    ALBEDO = albedo.rgb * albedo_tex.rgb;

    float metallic_tex = dot(texture(texture_metallic, base_uv), metallic_texture_channel);
    METALLIC = metallic_tex * metallic;
    SPECULAR = specular;

    vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
    float roughness_tex = dot(texture(texture_roughness, base_uv), roughness_texture_channel);
    ROUGHNESS = roughness_tex * roughness;

    ALPHA *= albedo.a * albedo_tex.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;

    // --------------------
    // Distance Fade Logic
    // --------------------
    if (distance_fade_mode != 0) {
        float fade_distance = length(VERTEX);
        float fade_range = distance_fade_max - distance_fade_min;
        float fade_factor = 1.0;
        
        // Calculate the fade safely (avoids division by zero if min == max)
        if (fade_range != 0.0) {
            fade_factor = clamp((fade_distance - distance_fade_min) / fade_range, 0.0, 1.0);
        } else {
            fade_factor = fade_distance < distance_fade_min ? 0.0 : 1.0;
        }

        if (distance_fade_mode == 1) {
            // 1 = PixelAlpha Mode
            ALPHA *= fade_factor;
        } else if (distance_fade_mode == 2) {
            // 2 = PixelDither Mode
            float dither = dot(vec2(171.0, 231.0), FRAGCOORD.xy);
            dither = fract(dither / 71.0) - 0.5;
            if (fade_factor + dither < 0.001) {
                discard;
            }
        }
    }
}