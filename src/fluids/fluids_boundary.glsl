#version 430
#define ix(x,y) ((y) * width + (x))
layout(local_size_x = 16, local_size_y = 16) in;

layout(location = 0) uniform int width;
layout(location = 1) uniform int height;
layout(std430, binding = 0) buffer ssboB {
    vec4 data_b[];
};

void main() {
    int x = int(gl_GlobalInvocationID.x);
    int y = int(gl_GlobalInvocationID.y);

    if (y == 0) {
        vec4 n = data_b[ix(x, 1)];
        data_b[ix(x, 0)].x = n.x;
        data_b[ix(x, 0)].y = 0.0;
    }
    if (y == height - 1) {
        vec4 n = data_b[ix(x, height - 2)];
        data_b[ix(x, height - 1)].x = n.x;
        data_b[ix(x, height - 1)].y = 0.0;
    }
    if (x == 0) {
        vec4 n = data_b[ix(1, y)];
        data_b[ix(0, y)].x = 0.0;
        data_b[ix(0, y)].y = n.y;
    }
    if (x == width - 1) {
        vec4 n = data_b[ix(width - 2, y)];
        data_b[ix(width - 1, y)].x = 0.0;
        data_b[ix(width - 1, y)].y = n.y;
    }
}
