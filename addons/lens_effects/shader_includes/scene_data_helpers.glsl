#define MAX_VIEWS 2
// ARez: Uncomment the next line if you build the engine using double precision
//#define USE_DOUBLE_PRECISION
#include "godot/scene_data_inc.glsl"

// Set 0: Scene
layout(set = 0, binding = 0, std140) uniform SceneDataBlock {
    SceneData data;
    SceneData prev_data;
} scene;

// Color image uniform (binding = 1) should be defined separately with restrict
// writeonly/readonly params.
layout(set = 0, binding = 2) uniform sampler2D depth_sampler;
// layout(set = 0, binding = 3) uniform sampler2D normal_roughness_sampler;
layout(set = 0, binding = 4) uniform sampler2D color_sampler;

highp float length_squared(vec2 v) {
    return pow(v.x, 2.0) + pow(v.y, 2.0);
}

// Converts coord obtained from gl_GlobalInvocationID
// to normalize [0.0-1.0] for use in texture() sampling functions.
highp vec2 coord_to_uv(ivec2 p_coord) {
    return (vec2(p_coord) + 0.5) / scene.data.viewport_size;
}

highp float get_raw_depth(ivec2 p_coord) {
    return texelFetch(depth_sampler, p_coord, 0).r;
}

highp float raw_to_linear_depth(ivec2 p_coord, highp float p_raw_depth) {
    highp vec2 uv = coord_to_uv(p_coord);
    highp vec3 ndc = vec3((uv * 2.0) - 1.0, p_raw_depth);
    highp vec4 view = scene.data.inv_projection_matrix * vec4(ndc, 1.0);
    return -(view.xyz / view.w).z;
}

highp float get_linear_depth(ivec2 p_coord) {
    return raw_to_linear_depth(p_coord, get_raw_depth(p_coord));
}

highp float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}
// 2x1 hash. Used to jitter the samples.
highp float hash(vec2 p) {
    return fract(sin(dot(p, vec2(41, 289))) * 45758.5453);
}
