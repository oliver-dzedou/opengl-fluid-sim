#version 430

out vec4 fragColor;

layout(location = 0) uniform vec2 resolution;
layout(location = 1) uniform sampler2D texture0;
layout(location = 2) uniform sampler2D scene;

const float OFFSET = 0.0025;

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

    float dist = distance(uv, vec2(0.5));
    vec4 color = vec4(vec3(0.0), 1.0);
    color.r = texture(scene, uv + dist * OFFSET).r;
    color.g = texture(scene, uv).g;
    color.b = texture(scene, uv - dist * OFFSET).b;
    fragColor = color;
}
