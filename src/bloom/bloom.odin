package bloom

import "../libs/graphics"
import "core:text/match"

@(private)
bloom_brightness :: cstring(#load("bloom_brightness.glsl"))
@(private)
bloom_horizontal :: cstring(#load("bloom_horizontal.glsl"))
@(private)
bloom_vertical :: cstring(#load("bloom_vertical.glsl"))

@(private)
bloom_brightness_loaded: graphics.Shader
@(private)
bloom_horizontal_loaded: graphics.Shader
@(private)
bloom_vertical_loaded: graphics.Shader

@(private)
bloom_brightness_texture: graphics.Texture
@(private)
bloom_horizontal_texture: graphics.Texture
@(private)
bloom_vertical_texture: graphics.Texture

// Runs a bloom pass on the provided scene and returns the bloomed scene
pass :: proc(scene: graphics.Texture, res: graphics.Resolution) -> graphics.Texture {
	if bloom_brightness_texture.id < 1 {
		bloom_brightness_texture = graphics.create_texture(res.width, res.height)
		bloom_vertical_texture = graphics.create_texture(res.width, res.height)
		bloom_horizontal_texture = graphics.create_texture(res.width, res.height)
	}
	if bloom_brightness_loaded.id < 1 {
		bloom_brightness_loaded = graphics.load_shader(bloom_brightness, "bloom_brightness")
		bloom_horizontal_loaded = graphics.load_shader(bloom_horizontal, "bloom_horizontal")
		bloom_vertical_loaded = graphics.load_shader(bloom_vertical, "bloom_vertical")
	}

	f32_res := graphics.to_f32(res)

	graphics.begin_texture(bloom_brightness_texture)
	graphics.begin_shader(bloom_brightness_loaded)
	graphics.set_shader_uniform(bloom_brightness_loaded, 0, .VEC2, &f32_res)
	graphics.set_shader_texture(bloom_brightness_loaded, 2, scene)
	graphics.rect(res.width, res.height)
	graphics.end_shader()
	graphics.end_texture()

	graphics.begin_texture(bloom_vertical_texture)
	graphics.begin_shader(bloom_vertical_loaded)
	graphics.set_shader_uniform(bloom_vertical_loaded, 0, .VEC2, &f32_res)
	graphics.set_shader_texture(bloom_vertical_loaded, 2, bloom_brightness_texture)
	graphics.rect(res.width, res.height)
	graphics.end_shader()
	graphics.end_texture()

	graphics.begin_texture(bloom_horizontal_texture)
	graphics.begin_shader(bloom_horizontal_loaded)
	graphics.set_shader_uniform(bloom_horizontal_loaded, 0, .VEC2, &f32_res)
	graphics.set_shader_texture(bloom_horizontal_loaded, 2, bloom_vertical_texture)
	graphics.set_shader_texture(bloom_horizontal_loaded, 3, scene)
	graphics.rect(res.width, res.height)
	graphics.end_shader()
	graphics.end_texture()

	return bloom_horizontal_texture
}

destroy :: proc() {
	graphics.unload_shader(&bloom_brightness_loaded)
	graphics.unload_shader(&bloom_vertical_loaded)
	graphics.unload_shader(&bloom_horizontal_loaded)
	graphics.unload_texture(&bloom_brightness_texture)
	graphics.unload_texture(&bloom_vertical_texture)
	graphics.unload_texture(&bloom_horizontal_texture)
}
