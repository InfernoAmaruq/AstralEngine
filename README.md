# Astral Engine - IN PROGRESS
Astral Engine is an open-source extensible Lua-based game engine built from a modified fork of LOVR, the goal of which is to provide its users with mechanisms, not policies
## Philosophy
The engine is designed around easy extensibility, most engine systems (renderer, ECS, scheduler) being scripted in performance-oriented Lua
You can easily append new features that the engine will treat as native, such as, adding new component types to the ECS or new Lua compiler directives
## Language
The engine uses Aspera for scripting, a dialect of Lua 5.1 centred around metaprogramming.
Features:
- Bit operators (>>, |, &&)
- Metaprogramming via macros and compile-time execute blocks (@macro, @define, @ifdef, @execute)
- Easily extensible metaprogramming dialect. Adding a new `@directive` is just a single Lua file!
- LBMF (Lua-Based Markdown File) a JSON-like format used for data by the engine, utilising the shape of Lua tables and optional `@CODE` blocks for logic. Supports comments!
The Aspera compiler does a quick parse over files as they are loaded, checking for macro symbols or '@'. The compilers effect on boot time is minimal

A lightweight GLSL shader pipeline is also included that makes compiling shaders easier

Haxe and Teal supports are planned within the future!
## Building
You need CMake to build the engine, the command flow would be something like:
```bash
git clone https://github.com/InfernoAmaruq/AstralEngine TARGET_PATH
cd TARGET_PATH
git submodule update --init --recursive
mkdir build
cd build
cmake ..
cmake --build .

#finally, run it when its done compiling
bin/astral PATH/TO/GAME/FOLDER
```
You do not need to recompile/shift folders manually at every minor change to the lua engine code, just add an argument like `astral -eTARGET_PATH/engine` to override engine path. -h is also available for help
