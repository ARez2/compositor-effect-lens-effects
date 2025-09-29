#[compute]
#version 450
layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

// ARez: This is the lens flare shader I used: https://www.shadertoy.com/view/wlcyzj

#include "shader_includes/scene_data.glsl"
#include "shader_includes/scene_data_helpers.glsl"
#include "shader_includes/effect_data.glsl"

// Smooth but a bit more expensive
#define EXPENSIVE_OCCLUSION_TEST
#define CHEAP_FLARE

layout(rgba16f, set = 0, binding = 1) uniform image2D color_image;

float getSun(vec2 uv) {
    return length(uv) < 0.009 ? 1.0 : 0.0;
}

vec3 desaturate(vec3 color, float factor) {
    vec3 lum = vec3(0.299, 0.587, 0.114);
    vec3 gray = vec3(dot(lum, color));
    return mix(color, gray, factor);
}

// from: https://www.shadertoy.com/view/XdfXRX
void lensflares(vec2 uv, vec2 pos, out vec3 sunflare, out vec3 lensflare) {
    vec2 main = uv - pos;
    vec2 uvd = uv * (length(uv));

    float ang = atan(main.y, main.x);
    float dist = length(main);
    dist = pow(dist, 0.1);

    float f0 = 1.0 / (length(uv - pos) * 25.0 + 1.0);
    f0 = pow(f0, 2.0);

    f0 = f0 + f0 * (sin((ang + 1.0 / 18.0) * 12.0) * .1 + dist * .1 + .8);

    float f2 =
        max(1.0 / (1.0 + 32.0 * length_squared(uvd + 0.8 * pos)), .0) * 00.25;
    float f22 =
        max(1.0 / (1.0 + 32.0 * length_squared(uvd + 0.85 * pos)), .0) * 00.23;
    float f23 =
        max(1.0 / (1.0 + 32.0 * length_squared(uvd + 0.9 * pos)), .0) * 00.21;

    vec2 uvx = mix(uv, uvd, -0.5);

    float f4 = max(0.01 - pow(length(uvx + 0.4 * pos), 2.4), .0) * 6.0;
    float f42 = max(0.01 - pow(length(uvx + 0.45 * pos), 2.4), .0) * 5.0;
    float f43 = max(0.01 - pow(length(uvx + 0.5 * pos), 2.4), .0) * 3.0;

    uvx = mix(uv, uvd, -.4);

    float f5 = max(0.01 - pow(length(uvx + 0.2 * pos), 5.5), .0) * 2.0;
    float f52 = max(0.01 - pow(length(uvx + 0.4 * pos), 5.5), .0) * 2.0;
    float f53 = max(0.01 - pow(length(uvx + 0.6 * pos), 5.5), .0) * 2.0;

    uvx = mix(uv, uvd, -0.5);

    float f6 = max(0.01 - pow(length(uvx - 0.3 * pos), 1.6), .0) * 6.0;
    float f62 = max(0.01 - pow(length(uvx - 0.325 * pos), 1.6), .0) * 3.0;
    float f63 = max(0.01 - pow(length(uvx - 0.35 * pos), 1.6), .0) * 5.0;

    sunflare = vec3(f0);
    lensflare =
        vec3(f2 + f4 + f5 + f6, f22 + f42 + f52 + f62, f23 + f43 + f53 + f63);

    // seems to already be completely white
    sunflare = desaturate(sunflare, 1.0);

    // Problem: Lens flare has yellow tint
    // Solution desaturate
    //lensflare = desaturate(lensflare, 1.0);
    // Problem: Now chromatic abberation effect is gone
    // Solution: Desaturate only yellow amount
    float yellow = min(lensflare.r, lensflare.g); // amount of yellow
    lensflare.r -= yellow * 0.5;
    lensflare.g -= yellow * 0.5;
}

vec3 anflares(vec2 uv, float threshold, float intensity, float stretch,
    float brightness) {
    threshold = 1.0 - threshold;

    vec3 hdr = vec3(getSun(uv));
    hdr = vec3(floor(threshold + pow(hdr.r, 1.0)));

    float d = intensity;
    float c = intensity * stretch;

    for (float i = c; i > -1.0; i--) {
        float texL = getSun(uv + vec2(i / d, 0.0));
        float texR = getSun(uv - vec2(i / d, 0.0));

        hdr += floor(threshold + pow(max(texL, texR), 4.0)) * (1.0 - i / c);
    }

    return hdr * brightness;
}

vec3 anflares2(vec2 uv, float intensity, float stretch, float brightness) {
    uv.x *= 1.0 / (intensity * stretch);
    uv.y *= 0.5;
    return vec3(smoothstep(0.009, 0.0, length(uv))) * brightness;
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Depth and normal-roughness buffers are available to use.

// For a simple way to get the normal-roughness, use:
// vec4 normal_roughness_color = get_normal_roughness_color(image_coord);

// And, for the linear depth value, use:
// float depth = get_linear_depth(image_coord);

// Transform matrices are also available, along with other helpful
// variables like viewport_size, time, and camera_visible_layers.
// They come from Godot's built-in SceneData uniform buffer object (UBO).
// See scene_data.glsl for the full list.

// Access SceneData variables like this:
// highp mat4 inv_proj_matrix = scene.data.inv_projection_matrix;

// (To see how the buffers and SceneData were implemented, see
// scene_data_helpers.glsl and base_compositor_effect.gd.)
// ---------------------------------------------------------------------------
void main() {
    ivec2 image_coord = ivec2(gl_GlobalInvocationID.xy);
    vec4 previous_color = imageLoad(color_image, image_coord);

    vec2 resolution = floor(scene.data.viewport_size);
    vec2 uv = image_coord / resolution - 0.5;
    vec2 sun_position = vec2(datablock.data.sun_position_x, datablock.data.sun_position_y);
    vec4 sun_color = datablock.data.sun_color;

    vec2 mouse = (sun_position / resolution) - vec2(0.5);
    mouse.x *= resolution.x / resolution.y;
    uv.x *= resolution.x / resolution.y;

    // ========== God rays ==========
    float godrays = 0.0;
    // Shadertoy used for the radial blur: https://www.shadertoy.com/view/XsKGRW
    vec2 godot_uv = vec2(image_coord) / resolution;
    vec2 sun_pos_uv = sun_position / resolution;

    // Radial blur factors.
    // Falloff, as we radiate outwards.
    float decay = datablock.data.decay;
    // Controls the sample density, which in turn, controls the sample spread.
    float density = datablock.data.density;
    // Sample weight. Decays as we radiate outwards.
    float weight = datablock.data.weight;
    int sample_count = int(datablock.data.sample_count);

    // Vector from sun_position to UV
    vec2 ray_dir = (godot_uv - sun_pos_uv) * datablock.data.dir_mult;
    vec2 ray_step = ray_dir * density / float(sample_count);

    vec2 ray_uv_pos = godot_uv;
    // Jitter the initial position a bit to blend the radial blur steps from the loop
    ray_uv_pos += ray_step * (hash(godot_uv + fract(scene.data.time)) * 2.0 - 1.0);
    float ray_sum = 0.0;
    for (int i = 0; i < int(sample_count); i++) {
        ray_uv_pos -= ray_step;
        highp float raw_depth = texture(depth_sampler, ray_uv_pos).r;
        ray_sum += float(int(ceil(raw_depth))) * weight;
        weight *= decay;
    }
    ray_sum /= float(sample_count);
    // Try to normalize the god rays a bit
    ray_sum = clamp(ray_sum / 0.05, 0.0, 1.0);

    godrays = pow(1.0 - ray_sum, 2.0);
    godrays = clamp(godrays, 0.0, 1.0);

    // ========== Flares ==========
    vec3 sunflare = vec3(0.0);
    vec3 lensflare = vec3(0.0);

    // Sets sunflare and lensflare
    lensflares(uv * 1.5, mouse * 1.5, sunflare, lensflare);

    // add a slight "always on" lens flare
    float always_on_strength = 0.04;
    lensflare = max(lensflare, sun_color.rgb * mix(0.02, always_on_strength, 1.0 - abs(datablock.data.dir_mult)));

    #ifdef CHEAP_FLARE
    vec3 anflare = pow(anflares2(uv - mouse, datablock.data.anamorphic_intensity, datablock.data.anamorphic_stretch, datablock.data.anamorphic_brightness), vec3(4.0));
    anflare += smoothstep(0.0025, 1.0, anflare) * 10.0;
    anflare *= smoothstep(0.0, 1.0, anflare);
    #else
    vec3 anflare = pow(anflares(uv - mouse, datablock.data.anamorphic_treshold, datablock.data.anamorphic_intensity, datablock.data.anamorphic_stretch, datablock.data.anamorphic_brightness), vec3(4.0));
    #endif

    // If the most middle sun pixel is occluded
    float sun_middle_occlusion = float(get_raw_depth(ivec2(sun_position)) <= 0.0);
    float occlusion = sun_middle_occlusion;

    #ifdef EXPENSIVE_OCCLUSION_TEST
    const int spread = 8;
    float sun_depth = float(get_raw_depth(ivec2(sun_position) + ivec2(spread, 0)) <= 0.0)
            + float(get_raw_depth(ivec2(sun_position) + ivec2(-spread, 0)) <= 0.0)
            + float(get_raw_depth(ivec2(sun_position) + ivec2(0, spread)) <= 0.0)
            + float(get_raw_depth(ivec2(sun_position) + ivec2(0, -spread)) <= 0.0)
            + float(get_raw_depth(ivec2(sun_position) + ivec2(spread, spread)) <= 0.0)
            + float(get_raw_depth(ivec2(sun_position) + ivec2(spread, -spread)) <= 0.0)
            + float(get_raw_depth(ivec2(sun_position) + ivec2(-spread, spread)) <= 0.0)
            + float(get_raw_depth(ivec2(sun_position) + ivec2(-spread, -spread)) <= 0.0);

    occlusion = (sun_middle_occlusion + sun_depth) / 9.0; // 1 if unoccluded, 0 if blocked
    #endif

    // When not facing the sun, still show some sun effects, but not 100%
    //     invert dir_mult, clamp it >0
    float occl_weight = max(-datablock.data.dir_mult, 0.0);
    //     if facing opposite of sun -> occlusion = 0.25
    //     If facing perp. to sun -> occlusion = occlusion
    occlusion = mix(occlusion, 0.25, occl_weight);
    if (datablock.data.dir_mult <= 0.0) {
        sun_middle_occlusion = 1.0;
        occlusion = 1.0;
    }

    // Only show the white sun circle if the middle pixel isnt occluded
    vec3 sun = vec3(getSun(uv - mouse) * sun_middle_occlusion);
    // add together the two effects of the sun disk
    sun += sunflare + anflare;
    // dont show the sun if its behind the camera
    float sun_mult = max(datablock.data.dir_mult, 0.0);
    sun *= sun_mult;
    // Put it all together and color it
    vec3 col = (sun + lensflare) * sun_color.rgb * occlusion;

    col = 1.0 - exp(-datablock.data.effect_easing * col);
    col *= datablock.data.effect_multiplier;

    // apply godray mask
    col *= godrays;

    vec4 new_color = vec4(clamp((previous_color.rgb + col), vec3(0.0), vec3(1.0)), 1.0);
    imageStore(color_image, image_coord, new_color);
    //imageStore(color_image, image_coord, vec4(lensflare, 1.0));
}
