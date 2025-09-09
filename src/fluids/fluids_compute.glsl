#version 430

#define ix(x, y) ((y) * (width) + (x))

struct Injection {
    int x;
    int y;
    vec2 velocity;
    float density;
    float _pad;
};

layout(location = 0) uniform int width;
layout(location = 1) uniform int height;
layout(location = 2) uniform float dt;
layout(location = 3) uniform float density_invariance_strength;
layout(location = 4) uniform float viscosity;
layout(location = 5) uniform float vorticity_amount;
layout(location = 6) uniform int num_injections;

layout(local_size_x = 16, local_size_y = 16) in;

layout(std430, binding = 0) buffer ssboA {
    vec4 data_a[];
};
layout(std430, binding = 1) buffer ssboB {
    vec4 data_b[];
};
layout(std430, binding = 2) readonly buffer ssbo_injections {
    Injection data_injections[];
};

void main() {
    int x = int(gl_GlobalInvocationID.x);
    int y = int(gl_GlobalInvocationID.y);

    vec4 C = data_a[ix(x, y)];

    vec4 R = data_a[ix(min(x + 1, width - 1), y)];
    vec4 L = data_a[ix(max(x - 1, 0), y)];
    vec4 U = data_a[ix(x, min(y + 1, height - 1))];
    vec4 D = data_a[ix(x, max(y - 1, 0))];

    vec4 dx = 0.5 * (R - L);
    vec4 dy = 0.5 * (U - D);

    vec2 center_prev_vel = C.xy;
    vec2 prev_pos = vec2(float(x), float(y)) - dt * center_prev_vel; // @frametime backtrace needs to be scaled by dt

    float xf = clamp(prev_pos.x, 0.5, float(width - 1) - 0.5);
    float yf = clamp(prev_pos.y, 0.5, float(height - 1) - 0.5);

    int i = int(floor(xf));
    int j = int(floor(yf));
    float fx = xf - float(i);
    float fy = yf - float(j);

    vec4 c00 = data_a[ix(i, j)];
    vec4 c10 = data_a[ix(i + 1, j)];
    vec4 c01 = data_a[ix(i, j + 1)];
    vec4 c11 = data_a[ix(i + 1, j + 1)];

    vec4 c0 = mix(c00, c10, fx);
    vec4 c1 = mix(c01, c11, fx);
    vec4 advected = mix(c0, c1, fy);

    C.x = advected.x;
    C.y = advected.y;
    C.z = advected.z;

    vec2 lap_u = (U.xy + D.xy + R.xy + L.xy) - 4.0 * center_prev_vel;
    vec2 viscosity_force = viscosity * lap_u;

    vec2 p_uv = vec2((float(x) + 0.5) / float(width),
            (float(y) + 0.5) / float(height)
        );

    float density_source = 0.0;
    vec2 injection_force = vec2(0.0);
    for (int k = 0; k < num_injections; ++k) {
        Injection inj = data_injections[k];
        vec2 q_uv = vec2((float(inj.x) + 0.5) / float(width),
                (float(inj.y) + 0.5) / float(height));
        vec2 d = p_uv - q_uv;
        float r2 = dot(d, d);
        injection_force += -0.75 * inj.velocity * d / (r2 + 1e-4);
        float density_contrib = inj.density * exp(-r2 * 500.0);
        C.z += density_contrib * dt; // @frametime density contribution needs to be scaled by dt
    }

    vec2 total_force = viscosity_force + injection_force;
    C.xy += dt * total_force; // @frametime force contribution needs to be scaled by dt

    C.xy = max(vec2(0), abs(C.xy) - ((1e-4 / 0.15) * dt)) * sign(C.xy); // @frametime velocity decay needs to be scaled by dt

    C.z *= pow(0.998, dt / 0.15); // @frametime density decay needs to be scaled by dt

    C.w = (R.y - L.y - U.x + D.x);
    vec2 vort = vec2(abs(U.w) - abs(D.w), abs(L.w) - abs(R.w));
    vort *= vorticity_amount / length(vort + 1e-9) * C.w;
    C.xy += vort * dt; // @frametime vorticity contribution needs to be scaled by dt

    C.xy = clamp(C.xy, vec2(-10.0), vec2(10.0));
    C.z = clamp(C.z, 0.0, 3.0);
    C.w = clamp(C.w, -10.0, 10.0);
    data_b[ix(x, y)] = C;
}
