#version 430

out vec4 fragColor;

layout(location = 0) uniform vec2 resolution;
layout(location = 1) uniform sampler2D texture0;
layout(location = 2) uniform sampler2D bloom_vertical;
layout(location = 3) uniform sampler2D raw_scene;

vec2 get_uv(vec2 pos) {
    return pos / resolution;
}

vec2 get_uv_normal(vec2 pos) {
    return (pos / resolution) * 2.0 - 1.0;
}

float get_aspect() {
    return max(resolution.x, resolution.y) / min(resolution.x, resolution.y);
}

vec4 get_bloom(vec2 uv) {
    float blur_size = 1.0 / resolution.x;
    vec4 sum = vec4(0.0);
    sum += texture(bloom_vertical, vec2(uv.x - 4.0 * blur_size, uv.y)) * 0.05;
    sum += texture(bloom_vertical, vec2(uv.x - 3.0 * blur_size, uv.y)) * 0.09;
    sum += texture(bloom_vertical, vec2(uv.x - 2.0 * blur_size, uv.y)) * 0.12;
    sum += texture(bloom_vertical, vec2(uv.x - blur_size, uv.y)) * 0.15;
    sum += texture(bloom_vertical, vec2(uv.x, uv.y)) * 0.16;
    sum += texture(bloom_vertical, vec2(uv.x + blur_size, uv.y)) * 0.15;
    sum += texture(bloom_vertical, vec2(uv.x + 2.0 * blur_size, uv.y)) * 0.12;
    sum += texture(bloom_vertical, vec2(uv.x + 3.0 * blur_size, uv.y)) * 0.09;
    sum += texture(bloom_vertical, vec2(uv.x + 4.0 * blur_size, uv.y)) * 0.05;
    return sum;
}

vec3 reinhard_tone_map(vec3 color) {
    return color / (color + vec3(1.0));
}

vec3 gamma_correction(vec3 color) {
    return pow(color, vec3(1.0 / 2.2));
}

void main() {
    vec2 uv = get_uv(gl_FragCoord.xy);
    fragColor = vec4(1.0);

    vec4 bloomed = get_bloom(uv);

    vec4 scene = bloomed + texture(raw_scene, uv);

    fragColor = scene;
}
