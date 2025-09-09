# glsl-fluid-sim

Real time fluid simulation implemented on the GPU using the Navier-Stokes equation, GLSL, Raylib and Odin

## Build 

Running the project requires 

A) Installing the [Odin programming language](https://odin-lang.org)
B) Compiling [Raylib](https://github.com/raysan5/raylib) from source with OpenGL 4.3 support enabled and updating the Raylib folder in the Odin language installation

Once that's done, simply run ``odin run .`` in the src folder

To switch between simple and accurate fluid simulation, change the ``IS_SIMPLE`` constant in ``src/main.odin``
