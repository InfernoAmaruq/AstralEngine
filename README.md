# STILL IN DEVELOPMENT! UNSTABLE AND UNRELIABLE IN CERTAIN CASES

# Astral Engine
Astral Engine is an open-source extensible Lua-based game engine built from a modified fork of LOVR, the goal of which is to provide its users with mechanisms, not policies
## Philosophy
The engine is designed around easy extensibility, most engine systems (renderer, ECS, scheduler) being written in very performant Lua
You can easily append new features that the engine will treat as native, such as, adding new component types to the ECS, Rendering steps, etc
Astral is designed to be minimal, a lot of features will be intentionally missing but easy to implement/have libraries made to add them
## Language
Currently, Astral runs on LuaJIT or Lua5.2 (must have goto statement currently), however the goal is to soon remove 'goto' reliant code to allow Lua5.1 to be used and other dialects of 5.1\n
Despite Lua version, Astral includes a Lua metaprogramming library thats entirely optional to use in game code. It is used to slightly optimise certain engine code\n
Astral also includes some GLSL QOL improvements for scripting GPU code

Haxe and Teal supports are planned within the future!
## Features
- API inspired by Roblox Studio, meant to be easy to use
- Vector library, including temporary vectors without garbage
- ECS
- A PBR renderer pipeline with instancing
- Jolt physics engine
- Input handling with contorller support
## Platforms
Runs on MacOS, Windows 10/11 and Linux. Other platforms may work but are untested
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
