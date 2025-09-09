#version 430

#define ix(x, y) ((y)*width+(x))

layout(local_size_x = 16, local_size_y = 16) in;

layout(location = 0) uniform int width;
layout(location = 1) uniform int height;

layout(std430, binding = 0) readonly buffer ssbo_b {
    vec4 data_b[];
};
layout(std430, binding = 1) buffer ssbo_divergence {
    float divergence[];
};

void main() {
    int x = int(gl_GlobalInvocationID.x);
    int y = int(gl_GlobalInvocationID.y);

    // --- Divergence of the intermediate velocity u* ----------------------------
    // This pass builds b = ∇·u*, i.e., the amount of local "volume change" the
    // projection must remove. On a collocated grid we use central differences
    // (second-order in the interior) and assume unit grid spacing (h=1), hence
    // the 0.5 = 1/(2h) factors below.

    // Indices are clamped at domain edges. That turns the centered stencil into
    // a biased, effectively half-width derivative near walls, which is only
    // first-order and tends to *underestimate* divergence at the boundary.
    // but it's simple to implement and good enough.
    int xl = max(x - 1, 0);
    int xr = min(x + 1, width - 1);
    int yd = max(y - 1, 0);
    int yu = min(y + 1, height - 1);

    float du_dx = (data_b[ix(xr, y)].x - data_b[ix(xl, y)].x) * (0.5);
    float dv_dy = (data_b[ix(x, yu)].y - data_b[ix(x, yd)].y) * (0.5);

    // Store ∇·u*.
    divergence[ix(x, y)] = du_dx + dv_dy;
}
