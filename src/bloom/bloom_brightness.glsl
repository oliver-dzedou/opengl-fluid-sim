#version 430

out vec4 fragColor;

layout(location = 0) uniform vec2 resolution;
layout(location = 1) uniform sampler2D texture0;
layout(location = 2) uniform sampler2D raw_scene;

const float THRESHOLD = 0.3;
const vec3 LUMINANCE_RGB = vec3(0.2126, 0.7152, 0.0722);

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
    vec2 uv = get_uv(gl_FragCoord.xy);
    vec3 color = texture(raw_scene, uv).rgb;
    float luminance = dot(color.rgb, LUMINANCE_RGB);
    float weight = max(luminance - THRESHOLD, 0.0) / THRESHOLD;
    fragColor = vec4(color * weight, 1.0);
}
