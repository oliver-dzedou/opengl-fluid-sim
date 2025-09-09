#version 430

#define ix(x, y) ((y)*width+(x))

layout(local_size_x = 16, local_size_y = 16) in;

layout(location = 0) uniform int width;
layout(location = 1) uniform int height;

layout(std430, binding = 0) readonly buffer ssbo_divergence {
    float divergence[];
};
layout(std430, binding = 1) buffer ssbo_pressure_a {
    float pressure_a[];
};
layout(std430, binding = 2) buffer ssbo_pressure_b {
    float pressure_b[];
};

void main() {
    int x = int(gl_GlobalInvocationID.x);
    int y = int(gl_GlobalInvocationID.y);

    int xl = max(x - 1, 0);
    int xr = min(x + 1, width - 1);
    int yd = max(y - 1, 0);
    int yu = min(y + 1, height - 1);

    float pL = pressure_a[ix(xl, y)];
    float pR = pressure_a[ix(xr, y)];
    float pD = pressure_a[ix(x, yd)];
    float pU = pressure_a[ix(x, yu)];
    float div = divergence[ix(x, y)];

    float p = (pL + pR + pD + pU - div) * 0.25;
    pressure_b[ix(x, y)] = p;
}
