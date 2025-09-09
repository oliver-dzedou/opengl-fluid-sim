#version 430

#define ix(x, y) ((y)*width+(x))

layout(local_size_x = 16, local_size_y = 16) in;

layout(location = 0) uniform int width;
layout(location = 1) uniform int height;

layout(std430, binding = 0) buffer ssbo_b {
    vec4 data_b[];
};
layout(std430, binding = 1) buffer ssbo_pressure {
    float pressure[];
};

void main() {
    int x = int(gl_GlobalInvocationID.x);
    int y = int(gl_GlobalInvocationID.y);

    int xl = max(x - 1, 0);
    int xr = min(x + 1, width - 1);
    int yd = max(y - 1, 0);
    int yu = min(y + 1, height - 1);

    float dpdx = 0.5 * (pressure[ix(xr, y)] - pressure[ix(xl, y)]);
    float dpdy = 0.5 * (pressure[ix(x, yu)] - pressure[ix(x, yd)]);

    vec4 C = data_b[ix(x, y)];
    C.x -= dpdx;
    C.y -= dpdy;
    data_b[ix(x, y)] = C;
}
