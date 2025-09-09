# glsl-fluid-sim

Real time fluid simulation implemented on the GPU using the Navier-Stokes equation, GLSL, Raylib and Odin

## Build 

Running the project requires 

A) Installing the [Odin programming language](https://odin-lang.org) </br>
B) Compiling [Raylib](https://github.com/raysan5/raylib) from source with OpenGL 4.3 support enabled and updating the Raylib folder in the Odin language installation

Once that's done, simply run ``odin run .`` in the src folder

To switch between simple and accurate fluid simulation, change the ``IS_SIMPLE`` constant in ``src/main.odin``

## Demo

#### Simple

https://github.com/user-attachments/assets/ecbe8662-51b3-4466-a492-d1a6405cdc54

#### Accurate

https://github.com/user-attachments/assets/ceae5932-31b4-4feb-87f3-2abb308a146e


