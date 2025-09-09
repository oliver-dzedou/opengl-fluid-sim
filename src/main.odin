package main

import "bloom"
import "chromatic_aberration"
import "fluids"
import "libs/graphics"
import "vendor:raylib"

WIDTH :: 1600
HEIGHT :: 900

IS_SIMPLE :: true

main :: proc() {
	/* ---== INITIALIZATION ---== */
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		logger := log.create_console_logger()
		context.logger = logger

		defer {
			log.destroy_console_logger(context.logger)
			if len(track.allocation_map) > 0 {
				fmt.println("\n-----== Tracking allocator: Detected memory leaks ==-----\n")
				for _, entry in track.allocation_map {
					fmt.printfln("%v leaked %v bytes", entry.location, entry.size)
				}
			} else {
				fmt.println("\n-----== Tracking allocator: No leaks detected ==-----\n")
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	raylib.InitWindow(WIDTH, HEIGHT, "GLSL Fluid Sim")
	raylib.SetTargetFPS(165)
	fluid_sim: fluids.FluidSim
	when IS_SIMPLE {
		fluid_sim = fluids.init_simple(WIDTH, HEIGHT, 0.2, 0.15, 0.25)
	} else {
		fluid_sim = fluids.init(WIDTH, HEIGHT, 0.2, 0.5, 0.03)
	}

	scene: graphics.Texture
	/* ---== END INITIALIZATION ---== */


	/* ---== MAIN LOOP ---== */
	for true {
		defer free_all(context.temp_allocator)
		frametime := raylib.GetFrameTime()

		when IS_SIMPLE {
			VELOCITY_INJECTION: f32 : 0.00008
			DENSITY_INJECTION :: 1.0
		} else {
			VELOCITY_INJECTION: f32 : 0.8
			DENSITY_INJECTION :: 0.5
		}

		mouse_pos := raylib.GetMousePosition()
		mouse_delta := raylib.GetMouseDelta()

		fluids.clear_injections(&fluid_sim)
		if (raylib.IsMouseButtonDown(raylib.MouseButton.LEFT)) {
			dx := f32(mouse_delta.x)
			dy := -f32(mouse_delta.y)

			vx := dx * VELOCITY_INJECTION
			vy := dy * VELOCITY_INJECTION
			fluids.push_injection(
				&fluid_sim,
				fluids.Injection {
					x = i32(mouse_pos.x),
					y = i32(HEIGHT - mouse_pos.y),
					velocity = [2]f32{vx, vy},
					density = DENSITY_INJECTION,
					_pad = 0,
				},
			)
		}

		when IS_SIMPLE {
			fluids.step_simple(&fluid_sim, frametime)
			fluids.draw_simple(&fluid_sim)
		} else {
			fluids.step(&fluid_sim, frametime)
			fluids.draw(&fluid_sim)
		}
		scene = fluid_sim.draw_texture
		bloomed_scene := bloom.pass(scene, graphics.Resolution{WIDTH, HEIGHT})
		aberrated_scene := chromatic_aberration.pass(
			bloomed_scene,
			graphics.Resolution{WIDTH, HEIGHT},
		)
		graphics.begin_drawing()
		graphics.texture_rect(WIDTH, HEIGHT, aberrated_scene)
		graphics.end_drawing()

		if raylib.WindowShouldClose() {
			break
		}

	}
	/* ---== END MAIN LOOP ---== */


	/* ---== DE-INITIALIZATION ---== */
	bloom.destroy()
	chromatic_aberration.destroy()
	graphics.unload_texture(&scene)
	when IS_SIMPLE {
		fluids.destroy_simple(&fluid_sim)
	} else {
		fluids.destroy(&fluid_sim)
	}
	/* ---== END DE-INITIALIZATION ---== */
}
