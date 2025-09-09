package fluids

import "../libs/graphics"
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:log"
import "core:mem/virtual"

@(private)
DELTA_COEFFICIENT: f32 : 8
@(private)
LOCAL_COMPUTE_SIZE: int : 16
@(private)
JACOBI_ITERATIONS: int : 40
@(private)
MAX_INJECTION: int : 60

@(private)
divergence_shader :: cstring(#load("fluids_divergence.glsl"))
@(private)
compute_shader :: cstring(#load("fluids_compute.glsl"))
@(private)
compute_simple_shader :: cstring(#load("fluids_compute_simple.glsl"))
@(private)
visualize_simple_shader :: cstring(#load("fluids_visualize_simple.glsl"))
@(private)
visualize_shader :: cstring(#load("fluids_visualize.glsl"))
@(private)
jacobi_shader :: cstring(#load("fluids_jacobi.glsl"))
@(private)
gradient_shader :: cstring(#load("fluids_gradient.glsl"))
@(private)
boundary_shader :: cstring(#load("fluids_boundary.glsl"))

@(private)
// The .SIMPLE simulation type is used for the visually pleasing simulation in the main menu
// The .ACCURATE simulation type is used for actual particle movement during gameplay, but it doesn't look as good when visualized
// The .ACCURATE simulation type is A LOT more expensive
SimulationType :: enum {
	SIMPLE,
	ACCURATE,
}

// A single injection into the simulation
// _pad is required to correctly align data for the SSBO
// Should be filled to 0
Injection :: struct {
	x, y:     i32,
	velocity: [2]f32,
	density:  f32,
	_pad:     f32,
}

// Represents a fluid simulation
FluidSim :: struct {
	arena:                                                                virtual.Arena,
	alloc:                                                                runtime.Allocator,
	simulation_type:                                                      SimulationType,
	width, height, size:                                                  int,
	buffer_size:                                                          uint,
	k, v, w:                                                              f32,
	ssbo_a, ssbo_b, ssbo_divergence:                                      uint,
	ssbo_injections, ssbo_pressure_a, ssbo_pressure_b:                    uint,
	data_a, data_b, data_read:                                            [dynamic][4]f32,
	data_divergence, data_pressure_a, data_pressure_b:                    [dynamic]f32,
	compute_shader_loaded, divergence_shader_loaded:                      graphics.Shader,
	jacobi_shader_loaded, gradient_shader_loaded, boundary_shader_loaded: graphics.Shader,
	visualize_simple_shader_loaded, visualize_shader_loaded:              graphics.Shader,
	injections:                                                           [dynamic]Injection,
	draw_texture:                                                         graphics.Texture,
	destroyed:                                                            bool,
}

// Destroys a simulation and it's reserved memory
// Works both on .SIMPLE and .ACCURATE
destroy_simple :: proc(fluid_sim: ^FluidSim) {
	if fluid_sim.destroyed {
		return
	}
	assert(
		fluid_sim.simulation_type == .SIMPLE,
		"Cannot use [destroy_simple] with a simulation type that is not simple, use [destroy] instead",
	)
	virtual.arena_destroy(&fluid_sim.arena)
	graphics.unload_ssbo(&fluid_sim.ssbo_a)
	graphics.unload_ssbo(&fluid_sim.ssbo_b)
	graphics.unload_ssbo(&fluid_sim.ssbo_injections)
	graphics.unload_compute_shader(&fluid_sim.compute_shader_loaded)
	graphics.unload_shader(&fluid_sim.visualize_simple_shader_loaded)
	graphics.unload_texture(&fluid_sim.draw_texture)
	fluid_sim.destroyed = true
}

destroy :: proc(fluid_sim: ^FluidSim) {
	if fluid_sim.destroyed {
		return
	}
	assert(
		fluid_sim.simulation_type == .ACCURATE,
		"Cannot use [destroy] with a simulation type that is simple, use [destroy_simple] instead",
	)
	virtual.arena_destroy(&fluid_sim.arena)
	graphics.unload_ssbo(&fluid_sim.ssbo_a)
	graphics.unload_ssbo(&fluid_sim.ssbo_b)
	graphics.unload_ssbo(&fluid_sim.ssbo_injections)
	graphics.unload_ssbo(&fluid_sim.ssbo_divergence)
	graphics.unload_ssbo(&fluid_sim.ssbo_pressure_a)
	graphics.unload_ssbo(&fluid_sim.ssbo_pressure_b)

	graphics.unload_compute_shader(&fluid_sim.compute_shader_loaded)
	graphics.unload_compute_shader(&fluid_sim.jacobi_shader_loaded)
	graphics.unload_compute_shader(&fluid_sim.gradient_shader_loaded)
	graphics.unload_compute_shader(&fluid_sim.divergence_shader_loaded)
	graphics.unload_compute_shader(&fluid_sim.gradient_shader_loaded)
	graphics.unload_shader(&fluid_sim.visualize_shader_loaded)
	graphics.unload_texture(&fluid_sim.draw_texture)
	fluid_sim.destroyed = true
}

// Initializes a .SIMPLE simulation
// Should be cleaned up with [destroy]
init_simple :: proc(#any_int width, height: int, k, v, w: f32) -> FluidSim {
	fluid_sim := FluidSim{}

	assert(
		width % LOCAL_COMPUTE_SIZE == 0,
		fmt.tprintf("width modulo LOCAL_COMPUTE_SIZE(%d) must be 0", LOCAL_COMPUTE_SIZE),
	)

	// Calculate sizes
	size := width * height
	buffer_size: uint = uint(size_of(f32) * 4 * size)
	injections_size: uint = uint(size_of(Injection) * MAX_INJECTION)

	// Memory management
	arena_reservation := (buffer_size * 3) + injections_size // 176mb 
	// We can safely initialize a static arena, as the length of the arrays
	// is never going to change
	err := virtual.arena_init_static(&fluid_sim.arena, arena_reservation)
	if err != nil {
		log.panicf("error allocating memory :: [%v]", err)
	}
	fluid_sim.alloc = virtual.arena_allocator(&fluid_sim.arena)
	// Create backing arrays for SSBOs
	data_a := make([dynamic][4]f32, size, size, fluid_sim.alloc)
	data_b := make([dynamic][4]f32, size, size, fluid_sim.alloc)
	data_read := make([dynamic][4]f32, size, size, fluid_sim.alloc) // @hack 
	injections := make([dynamic]Injection, MAX_INJECTION, MAX_INJECTION, fluid_sim.alloc)

	// Create SSBOs
	ssbo_a := graphics.create_ssbo(buffer_size, &data_a[0], .DYNAMIC_COPY)
	ssbo_b := graphics.create_ssbo(buffer_size, &data_b[0], .DYNAMIC_COPY)
	ssbo_injections := graphics.create_ssbo(
		injections_size,
		&injections[0],
		.DYNAMIC_DRAW,
		"fluids_injections",
	)

	// Load shaders into memory
	compute_shader_loaded := graphics.load_compute_shader(
		compute_simple_shader,
		"fluids_compute_simple",
	)
	visualize_simple_shader_loaded := graphics.load_shader(
		visualize_simple_shader,
		"fluids_visualize_simple",
	)

	draw_texture := graphics.create_texture(width, height)

	fluid_sim.simulation_type = .SIMPLE
	fluid_sim.width = width
	fluid_sim.height = height
	fluid_sim.size = size
	fluid_sim.buffer_size = buffer_size
	fluid_sim.k = k
	fluid_sim.v = v
	fluid_sim.w = w
	fluid_sim.ssbo_a = ssbo_a
	fluid_sim.ssbo_b = ssbo_b
	fluid_sim.data_read = data_read
	fluid_sim.ssbo_injections = ssbo_injections
	fluid_sim.data_a = data_a
	fluid_sim.data_b = data_b
	fluid_sim.compute_shader_loaded = compute_shader_loaded
	fluid_sim.visualize_simple_shader_loaded = visualize_simple_shader_loaded
	fluid_sim.injections = injections
	fluid_sim.draw_texture = draw_texture
	fluid_sim.destroyed = false

	clear(&fluid_sim.injections)
	return fluid_sim
}

// Initializes an .ACCURATE simulation
// Should be cleaned up with [destroy]
init :: proc(#any_int width, height: int, k, v, w: f32) -> FluidSim {
	fluid_sim := FluidSim{}

	assert(
		width % LOCAL_COMPUTE_SIZE == 0,
		fmt.tprintf("width modulo LOCAL_COMPUTE_SIZE(%v) must be 0", LOCAL_COMPUTE_SIZE),
	)

	// Calculate needed sizes
	size := width * height
	buffer_size: uint = uint(size_of(f32) * 4 * size)
	injections_size: uint = uint(size_of(Injection) * MAX_INJECTION)
	divergence_size: uint = uint(size_of(f32) * size)
	pressure_size: uint = uint(size_of(f32) * size)

	// Memory management
	arena_reservation :=
		(buffer_size * 3) + injections_size + divergence_size + (pressure_size * 2) // 221 MB 
	// We can safely initialize a static arena, as the length of the arrays
	// is never going to change
	err := virtual.arena_init_static(&fluid_sim.arena, arena_reservation)
	if err != nil {
		log.panicf("error allocating memory :: [%v]", err)
	}
	fluid_sim.alloc = virtual.arena_allocator(&fluid_sim.arena)

	// Create backing data arrays for SSBOs
	data_a := make([dynamic][4]f32, size, size, fluid_sim.alloc)
	data_b := make([dynamic][4]f32, size, size, fluid_sim.alloc)
	data_read := make([dynamic][4]f32, size, size, fluid_sim.alloc)
	injections := make([dynamic]Injection, MAX_INJECTION, MAX_INJECTION, fluid_sim.alloc)
	data_divergence := make([dynamic]f32, size, size, fluid_sim.alloc)
	data_pressure_a := make([dynamic]f32, size, size, fluid_sim.alloc)
	data_pressure_b := make([dynamic]f32, size, size, fluid_sim.alloc)

	// Create SSBOs
	ssbo_a := graphics.create_ssbo(buffer_size, &data_a[0], .DYNAMIC_COPY)
	ssbo_b := graphics.create_ssbo(buffer_size, &data_b[0], .DYNAMIC_COPY)
	ssbo_injections := graphics.create_ssbo(
		injections_size,
		&injections[0],
		.DYNAMIC_DRAW,
		"fluids_injections",
	)
	ssbo_divergence := graphics.create_ssbo(
		divergence_size,
		&data_divergence[0],
		.DYNAMIC_COPY,
		"fluids_divergence",
	)
	ssbo_pressure_a := graphics.create_ssbo(pressure_size, &data_pressure_a[0], .DYNAMIC_COPY)
	ssbo_pressure_b := graphics.create_ssbo(pressure_size, &data_pressure_b[0], .DYNAMIC_COPY)

	// Load shaders into memory
	compute_shader_loaded := graphics.load_compute_shader(compute_shader, "fluids_compute")
	visualize_shader_loaded := graphics.load_shader(visualize_shader, "fluids_visualize")
	divergence_shader_loaded := graphics.load_compute_shader(
		divergence_shader,
		"fluids_divergence",
	)
	jacobi_shader_loaded := graphics.load_compute_shader(jacobi_shader, "jacobi_shader")
	gradient_shader_loaded := graphics.load_compute_shader(gradient_shader, "fluids_gradient")
	boundary_shader_loaded := graphics.load_compute_shader(boundary_shader, "fluids_boundary")

	draw_texture := graphics.create_texture(width, height)

	fluid_sim.simulation_type = .ACCURATE
	fluid_sim.width = width
	fluid_sim.height = height
	fluid_sim.size = size
	fluid_sim.buffer_size = buffer_size
	fluid_sim.k = k
	fluid_sim.v = v
	fluid_sim.w = w
	fluid_sim.ssbo_a = ssbo_a
	fluid_sim.ssbo_b = ssbo_b
	fluid_sim.data_read = data_read
	fluid_sim.ssbo_divergence = ssbo_divergence
	fluid_sim.ssbo_injections = ssbo_injections
	fluid_sim.data_a = data_a
	fluid_sim.data_b = data_b
	fluid_sim.data_pressure_a = data_pressure_a
	fluid_sim.data_pressure_b = data_pressure_b
	fluid_sim.ssbo_pressure_a = ssbo_pressure_a
	fluid_sim.ssbo_pressure_b = ssbo_pressure_b
	fluid_sim.data_divergence = data_divergence
	fluid_sim.compute_shader_loaded = compute_shader_loaded
	fluid_sim.divergence_shader_loaded = divergence_shader_loaded
	fluid_sim.visualize_shader_loaded = visualize_shader_loaded
	fluid_sim.jacobi_shader_loaded = jacobi_shader_loaded
	fluid_sim.gradient_shader_loaded = gradient_shader_loaded
	fluid_sim.boundary_shader_loaded = boundary_shader_loaded
	fluid_sim.injections = injections
	fluid_sim.draw_texture = draw_texture
	fluid_sim.destroyed = false

	clear(&fluid_sim.injections)
	return fluid_sim
}

// Runs a single step of a .SIMPLE simulation
step_simple :: proc(fluid_sim: ^FluidSim, dt: f32) {
	assert(
		fluid_sim.simulation_type == .SIMPLE,
		"Cannot use [step_simple] with a simulation type that is not simple, use [step] instead",
	)

	// Speed the simulation up by a factor of 8
	delta: f32 = dt * DELTA_COEFFICIENT

	// Calculate how many workgroups do we need to dispatch
	// Local compute size is defined by the shader; see [fluids_compute.glsl]


	workgroups_x := fluid_sim.width / LOCAL_COMPUTE_SIZE
	workgroups_y := fluid_sim.height / LOCAL_COMPUTE_SIZE

	// Insert injections into the simulation
	num_injections := len(fluid_sim.injections)
	graphics.begin_compute_shader(fluid_sim.compute_shader_loaded)
	if num_injections > 0 {
		graphics.update_ssbo(
			fluid_sim.ssbo_injections,
			&fluid_sim.injections[0],
			uint(num_injections * size_of(Injection)),
		)
	}

	// Advection step
	graphics.bind_ssbo(fluid_sim.ssbo_a, 0)
	graphics.bind_ssbo(fluid_sim.ssbo_b, 1)
	graphics.bind_ssbo(fluid_sim.ssbo_injections, 2)
	graphics.set_compute_shader_uniform(0, &fluid_sim.width, .INT)
	graphics.set_compute_shader_uniform(1, &fluid_sim.height, .INT)
	graphics.set_compute_shader_uniform(2, &delta, .FLOAT)
	graphics.set_compute_shader_uniform(3, &fluid_sim.k, .FLOAT)
	graphics.set_compute_shader_uniform(4, &fluid_sim.v, .FLOAT)
	graphics.set_compute_shader_uniform(5, &fluid_sim.w, .FLOAT)
	graphics.set_compute_shader_uniform(6, &num_injections, .INT)
	graphics.dispatch_compute_shader(workgroups_x, workgroups_y)
	graphics.end_compute_shader()

	// Ping pong buffers
	fluid_sim.ssbo_a, fluid_sim.ssbo_b = fluid_sim.ssbo_b, fluid_sim.ssbo_a
}

// Runs a single step of a .ACCURATE simulation
step :: proc(fluid_sim: ^FluidSim, dt: f32) {
	assert(
		fluid_sim.simulation_type == .ACCURATE,
		"Cannot use [step] with a simulation type that is simple, use [step_simple] instead",
	)

	// Speed the simulation up by a factor of 8
	delta: f32 = dt * DELTA_COEFFICIENT

	// Calculate how many workgroups do we need to dispatch
	// Local compute size is defined by the shader; see [fluids_compute.glsl]
	workgroups_x := fluid_sim.width / LOCAL_COMPUTE_SIZE
	workgroups_y := fluid_sim.height / LOCAL_COMPUTE_SIZE

	// Insert injections into the simulation
	num_injections := len(fluid_sim.injections)
	graphics.begin_compute_shader(fluid_sim.compute_shader_loaded)
	if num_injections > 0 {
		graphics.update_ssbo(
			fluid_sim.ssbo_injections,
			&fluid_sim.injections[0],
			uint(num_injections * size_of(Injection)),
		)
	}

	// Advection step
	graphics.bind_ssbo(fluid_sim.ssbo_a, 0)
	graphics.bind_ssbo(fluid_sim.ssbo_b, 1)
	graphics.bind_ssbo(fluid_sim.ssbo_injections, 2)
	graphics.set_compute_shader_uniform(0, &fluid_sim.width, .INT)
	graphics.set_compute_shader_uniform(1, &fluid_sim.height, .INT)
	graphics.set_compute_shader_uniform(2, &delta, .FLOAT)
	graphics.set_compute_shader_uniform(3, &fluid_sim.k, .FLOAT)
	graphics.set_compute_shader_uniform(4, &fluid_sim.v, .FLOAT)
	graphics.set_compute_shader_uniform(5, &fluid_sim.w, .FLOAT)
	graphics.set_compute_shader_uniform(6, &num_injections, .INT)
	graphics.dispatch_compute_shader(workgroups_x, workgroups_y)
	graphics.end_compute_shader()

	// Divergence step
	graphics.begin_compute_shader(fluid_sim.divergence_shader_loaded)
	graphics.bind_ssbo(fluid_sim.ssbo_b, 0)
	graphics.bind_ssbo(fluid_sim.ssbo_divergence, 1)
	graphics.set_compute_shader_uniform(0, &fluid_sim.width, .INT)
	graphics.set_compute_shader_uniform(1, &fluid_sim.height, .INT)
	graphics.dispatch_compute_shader(workgroups_x, workgroups_y)
	graphics.end_compute_shader()

	// Jacobi iteration method
	// iterations can be increased to make the simulation more accurate
	// At the cost of compute power
	// 40-60 yields very accurate results, but is on the higher end of pressure on the GPU
	for _ in 0 ..< JACOBI_ITERATIONS {
		graphics.begin_compute_shader(fluid_sim.jacobi_shader_loaded)
		graphics.bind_ssbo(fluid_sim.ssbo_divergence, 0)
		graphics.bind_ssbo(fluid_sim.ssbo_pressure_a, 1)
		graphics.bind_ssbo(fluid_sim.ssbo_pressure_b, 2)
		graphics.set_compute_shader_uniform(0, &fluid_sim.width, .INT)
		graphics.set_compute_shader_uniform(1, &fluid_sim.height, .INT)
		graphics.dispatch_compute_shader(workgroups_x, workgroups_y)
		graphics.end_compute_shader()
		fluid_sim.ssbo_pressure_a, fluid_sim.ssbo_pressure_b =
			fluid_sim.ssbo_pressure_b, fluid_sim.ssbo_pressure_a
	}

	// Gradient step
	graphics.begin_compute_shader(fluid_sim.gradient_shader_loaded)
	graphics.bind_ssbo(fluid_sim.ssbo_b, 0)
	graphics.bind_ssbo(fluid_sim.ssbo_pressure_a, 1)
	graphics.set_compute_shader_uniform(0, &fluid_sim.width, .INT)
	graphics.set_compute_shader_uniform(1, &fluid_sim.height, .INT)
	graphics.dispatch_compute_shader(workgroups_x, workgroups_y)
	graphics.end_compute_shader()

	// Enforce boundaries
	graphics.begin_compute_shader(fluid_sim.boundary_shader_loaded)
	graphics.bind_ssbo(fluid_sim.ssbo_b, 0)
	graphics.set_compute_shader_uniform(0, &fluid_sim.width, .INT)
	graphics.set_compute_shader_uniform(1, &fluid_sim.height, .INT)
	graphics.dispatch_compute_shader(workgroups_x, workgroups_y)
	graphics.end_compute_shader()

	// Ping pong buffers
	fluid_sim.ssbo_a, fluid_sim.ssbo_b = fluid_sim.ssbo_b, fluid_sim.ssbo_a
}

// Draws the given simulation
// The drawn texture is available on fluid_sim.draw_texture
draw_simple :: proc(fluid_sim: ^FluidSim) {
	assert(
		fluid_sim.simulation_type == .SIMPLE,
		"Cannot use [draw_simple] with a simulation type that is not simple, use [draw] instead",
	)

	graphics.begin_texture(fluid_sim.draw_texture)
	graphics.begin_shader(fluid_sim.visualize_simple_shader_loaded)
	graphics.bind_ssbo(fluid_sim.ssbo_a, 0)
	graphics.set_shader_uniform(
		fluid_sim.visualize_simple_shader_loaded,
		0,
		.INT,
		&fluid_sim.width,
	)
	graphics.set_shader_uniform(
		fluid_sim.visualize_simple_shader_loaded,
		1,
		.INT,
		&fluid_sim.height,
	)
	graphics.rect(fluid_sim.width, fluid_sim.height)
	graphics.end_shader()
	graphics.end_texture()
}

// Draws the given simulation
// The drawn texture is available on fluid_sim.draw_texture
draw :: proc(fluid_sim: ^FluidSim) {
	assert(
		fluid_sim.simulation_type == .ACCURATE,
		"Cannot use [draw] with a simulation type that is simple, use [draw_simple] instead",
	)
	graphics.begin_texture(fluid_sim.draw_texture)
	graphics.begin_shader(fluid_sim.visualize_shader_loaded)
	graphics.bind_ssbo(fluid_sim.ssbo_a, 0)
	graphics.set_shader_uniform(fluid_sim.visualize_shader_loaded, 0, .INT, &fluid_sim.width)
	graphics.set_shader_uniform(fluid_sim.visualize_shader_loaded, 1, .INT, &fluid_sim.height)
	graphics.rect(fluid_sim.width, fluid_sim.height)
	graphics.end_shader()
	graphics.end_texture()
}

// Reads velocity, density and vorticity data into a CPU buffer
// The data can be accessed on fluid_sim.data_read
// Is VERY SLOW, should be removed eventually once prototyping is done and processing moves to the GPU
// Works on both .SIMPLE and .ACCURATE simulations
// @hack 
read :: proc(fluid_sim: ^FluidSim) {
	graphics.read_ssbo(fluid_sim.ssbo_a, &fluid_sim.data_read[0], fluid_sim.buffer_size)
}

// Pushes injections into the simulation
push_injection :: proc(fluid_sim: ^FluidSim, injection: Injection) {
	assert(
		len(fluid_sim.injections) < MAX_INJECTION,
		fmt.tprintf(
			"Cannot push more than %d injections into the fluid simulation",
			MAX_INJECTION,
		),
	)
	if len(fluid_sim.injections) < MAX_INJECTION {
		_, err := append(&fluid_sim.injections, injection)
		assert(err == nil, fmt.tprintf("Could not allocate memory :: %v", err))
	}
}

// Clears the injections array
// Normally should be called every step, unless you want
// The exact same set of injections every frame
clear_injections :: proc(fluid_sim: ^FluidSim) {
	clear(&fluid_sim.injections)
}
