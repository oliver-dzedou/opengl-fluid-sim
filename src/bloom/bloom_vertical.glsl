#version 430

out vec4 fragColor;

layout(location = 0) uniform vec2 resolution;
layout(location = 1) uniform sampler2D texture0;
layout(location = 2) uniform sampler2D bloom_brightness;

vec2 get_uv(vec2 pos) {
    return pos / resolution;
}

vec2 get_uv_normal(vec2 pos) {
    return (pos / resolution) * 2.0 - 1.0;
}

float get_aspect() {
    return max(resolution.x, resolution.y) / min(resolution.x, resolution.y);
}

void main() {
    fragColor = vec4(1.0);
    vec2 uv = get_uv(gl_FragCoord.xy);

    vec4 sum = vec4(0.0);

    float blur_size = 1.0 / resolution.y;

    sum += texture(bloom_brightness, vec2(uv.x, uv.y - 4.0 * blur_size)) * 0.05;
    sum += texture(bloom_brightness, vec2(uv.x, uv.y - 3.0 * blur_size)) * 0.09;
    sum += texture(bloom_brightness, vec2(uv.x, uv.y - 2.0 * blur_size)) * 0.12;
    sum += texture(bloom_brightness, vec2(uv.x, uv.y - 1.0 * blur_size)) * 0.15;
    sum += texture(bloom_brightness, vec2(uv.x, uv.y + 0.0 * blur_size)) * 0.16;
    sum += texture(bloom_brightness, vec2(uv.x, uv.y + 1.0 * blur_size)) * 0.15;
    sum += texture(bloom_brightness, vec2(uv.x, uv.y + 2.0 * blur_size)) * 0.12;
    sum += texture(bloom_brightness, vec2(uv.x, uv.y + 3.0 * blur_size)) * 0.09;
    sum += texture(bloom_brightness, vec2(uv.x, uv.y + 4.0 * blur_size)) * 0.05;

    fragColor = sum;
}
