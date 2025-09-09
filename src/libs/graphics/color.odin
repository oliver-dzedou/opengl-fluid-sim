package graphics

import "vendor:raylib"

// Represents color in rgba format with values ranging from 0 to 1
Color :: struct {
	r, g, b, a: f32,
}

// Turn 0->1 color into 0->255 color
to_u8 :: proc(color: Color) -> [4]u8 {
	return [4]u8{u8(color.r * 255), u8(color.g * 255), u8(color.b * 255), u8(color.a * 255)}
}

// Turn 0->1 color into Raylib (0->255) color
to_rl :: proc(color: Color) -> raylib.Color {
	return raylib.Color(to_u8(color))
}

DEEP_PURPLE :: Color{0, 0, 0.143, 1}
GHOST_WHITE :: Color{0.968, 0.968, 1, 1}
DIM_GRAY :: Color{0.384, 0.407, 0.407, 1}
TEA_GREEN :: Color{0.898 * 0.7, 0.968 * 0.7, 0.490 * 0.7, 1}
