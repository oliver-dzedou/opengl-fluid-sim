#version 430

#define ix(x, y) ((y)*width+(x))

layout(local_size_x = 16, local_size_y = 16) in;

// Input: data_b holds the intermediate velocity u* in .xy
// Input: pressure is the scalar field p computed by the Poisson solve
// Output: overwrite data_b.xy with u^{n+1} = u* − ∇p (projection step)
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

    // --- Pressure gradient -----------------------------------------------------
    // Central differences for ∂p/∂x and ∂p/∂y using a 4-neighborhood. This
    // uses the same (1/(2h)) factors as the divergence pass, so the pair
    // (divergence, gradient) is consistent.
    float dpdx = 0.5 * (pressure[ix(xr, y)] - pressure[ix(xl, y)]);
    float dpdy = 0.5 * (pressure[ix(x, yu)] - pressure[ix(x, yd)]);

    vec4 C = data_b[ix(x, y)];
    // --- Projection: u^{n+1} = u* − ∇p ---------------------------------------
    // Subtract the pressure gradient from the intermediate velocity to remove
    // the divergence measured earlier. In this formulation, constants like Δt/ρ
    // are absorbed in how p was solved, so the correction is a direct subtraction.vec4 C = data_b[ix(x, y)];
    C.x -= dpdx;
    C.y -= dpdy;
    data_b[ix(x, y)] = C;
}
