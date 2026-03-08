# GetService(Name:string)
## Description
Returns singletons that reference different service API, read `Services/`

```lua
local Service = GetService("ServiceName")
```

A list of available services:
- World - lower level entity manager. Mainly stores pointers to component and information about Entity allocation. Rarely used in games
- Entity - used to create entities
- Physics - used to create new World entities
- Renderer - manages render passes
- Component - used to load new components into memory and assign components to entities (or Entity:AddComponent())
- Scheduler - rarely used, can be used to allocate a new task scheduler, which is the same scheduler as the engine uses. Important note, this has to be called *manually*
- RunService - used to bind to runtime to have functions run each step. Can be used to create things that will run every update and to create new rendering steps
- TagService - used to add tags to entities
- SceneManager - loads and unloads scenes
- AssetManager - manages assets to avoid re-allocation, I/O and decoding of assets
- InputService - used to manage low-level inputs using events. Has generic events for when any key was pressed/released. Mainly used to track mouse movements and inputs
- ShaderService - used to create and compile new shaders using Astral's shader pipeline.\*1
- AssetMapService - part of SceneManager but can be called by the user. Used to load AssetMap files
- ContextActionService - nore sophisticated input manager. Allowing user to bind a function to happen at specific keystroke(s)

## Example
```lua
local EntityService = GetService("Entity")
local MyEntity = EntityService.New("CoolEntityName") -- may or may not be outdated at any time, double check actual service reference!
```

## Custom Servicex
One can add their own services to be callable by GetService() via:
```lua
GetService.AddService(Name:string,Obj:table|function) -> nil
```
## Notes
Internally, the engine uses GetService() to resolve dependency issues, consult Engine manual to see how it works

\*1 - Later on, it will be advised to use AssetManager to create shaders once shader API for AssetManager is done. As AssetManager will cache shaders
