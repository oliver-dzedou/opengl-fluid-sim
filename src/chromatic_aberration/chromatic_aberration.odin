package chromatic_aberration

import "../libs/graphics"

@(private)
chromatic_aberration := cstring(#load("chromatic_aberration.glsl"))
@(private)
chromatic_aberration_loaded: graphics.Shader
@(private)
chromatic_aberration_texture: graphics.Texture

// Runs a chromatic aberration pass on the provided scene and returns the aberrated scene
pass :: proc(scene: graphics.Texture, res: graphics.Resolution) -> graphics.Texture {
	if chromatic_aberration_texture.id < 1 {
		chromatic_aberration_texture = graphics.create_texture(res.width, res.height)
	}
	if chromatic_aberration_loaded.id < 1 {
		chromatic_aberration_loaded = graphics.load_shader(
			chromatic_aberration,
			"chromatic_aberration",
		)
	}

	f32_res := graphics.to_f32(res)

	graphics.begin_texture(chromatic_aberration_texture)
	graphics.begin_shader(chromatic_aberration_loaded)
	graphics.set_shader_uniform(chromatic_aberration_loaded, 0, .VEC2, &f32_res)
	graphics.set_shader_texture(chromatic_aberration_loaded, 2, scene)
	graphics.rect(res.width, res.height)
	graphics.end_shader()
	graphics.end_texture()
	return chromatic_aberration_texture
}

destroy :: proc() {
	graphics.unload_shader(&chromatic_aberration_loaded)
	graphics.unload_texture(&chromatic_aberration_texture)
}
