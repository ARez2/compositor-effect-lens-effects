struct EffectData {
    vec4 sun_color;
    highp float sun_position_x;
    highp float sun_position_y;
    highp float dir_mult; // 1 if looking towards the sun, -1 else
    highp float anamorphic_treshold;
    highp float anamorphic_intensity;
    highp float anamorphic_stretch;
    highp float anamorphic_brightness;
    highp float effect_multiplier;
    highp float effect_easing;

    // God ray uniforms
    highp float decay;
    highp float density;
    highp float weight;
    highp float sample_count;
};

layout(set = 1, binding = 0, std140) uniform EffectDataBlock {
    EffectData data;
} datablock;
