#version 430

#define ix(x, y) ((y)*width+(x))

layout(local_size_x = 16, local_size_y = 16) in;

layout(location = 0) uniform int width;
layout(location = 1) uniform int height;

// Input: b = ∇·u* (divergence of the intermediate velocity)
// Output: one Jacobi relaxation step for pressure p
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

    // --- Jacobi update for the pressure Poisson equation -----------------------
    // Discretization: ∇² p = b on a unit-spaced grid (h = 1)
    // 5-point Laplacian: -4 p_ij + p_{i±1,j} + p_{i,j±1} = b_ij
    // Rearranged for Jacobi relaxation:
    //     p^{k+1}_ij = (pL + pR + pD + pU - b_ij) * 1/4
    //
    // This is one iteration; multiple passes of this kernel “relax” p toward a
    // solution. The resulting pressure will be used in the projection step
    // u^{n+1} = u* − ∇p to make the velocity field divergence-free.
    float p = (pL + pR + pD + pU - div) * 0.25;
    pressure_b[ix(x, y)] = p;
}
