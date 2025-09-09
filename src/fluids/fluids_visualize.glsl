#version 430

#define ix(x, y) ((y) * (width) + (x))

layout(location = 0) uniform int width;
layout(location = 1) uniform int height;

const vec3 deep_purple = vec3(0.0, 0.0, 0.143);

layout(std430, binding = 0) buffer ssbo_in {
    vec4 data_in[];
};

out vec4 fragColor;

void main() {
    int x = int(gl_FragCoord.x);
    int y = int(gl_FragCoord.y);
    int idx = ix(x, y);

    float density = data_in[idx].b;
    density = (density - 0.0) / (3.0 - 0.0);
    density = smoothstep(0.0, 1.0, density);
    density = pow(density, 0.8);
    vec3 col = mix(deep_purple, vec3(1.0), density);
    fragColor = vec4(col, 1.0);
}
