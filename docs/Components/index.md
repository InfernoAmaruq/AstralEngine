# Astral Component Guide
Astral's components are defined as data and/or logic that is attached to an entity

Components are managed by Component service, read `Services/Component.md`

# Creation:
## Component Anatomy
A component must have:
 - A name
 - a Pattern table OR Metadata table with __create method

An example of component anatomy would be:

```lua
local ComponentObject = {
    Name = "MyCoolComponent",
    Pattern = {},
    Metadata = {
        __create = function(Input)
            return {
                x = ProcessInput(Input)
            }
        end
    }
    FastFetch = { "x" }
}

ComponentService.NewComponent(
    ComponentObj.Name,
    ComponentObj.Pattern,
    ComponentObj.Metadata,
    ComponentObj.FastFetch
)
```

Meaning:
 - `Pattern` refers to default fields to set in-case of no default constructor being provided. It is not required if `Metadata.__create` is provided
 - `Metadata` stores metadata about the component. Can be used to set (and fetch) custom parameters at runtime. Has a few special fields:
 - - __create(Input:any?,Entity:Int,ShouldIgnoreSoftDependency:bool?) -> Component; ShouldIgnoreSoftDependency is to be used if the component checks if the entity has other components
 - - __remove(Component:Component,Entity:Int,Forced:bool?); Destructor function. Forced is true on Entity destruct, in which case forcefully teardown because death is guaranteed before next frame
 - - SoftDependency : {ComponentName = true}|nil - Refers to soft-dependencies. Soft-dependencies are REQUIRED to be present at scene load and will error without. Soft dependencies will NOT error on runtime component creation
 - - HardDependency : {ComponentName = true}|nil - Will ALWAYS error if dependency missing
 - - HardExclusion : {ComponentName = true}|nil - Will ALWAYS error if component listed already exists on the entity
 - - SymbolExport : {Field = SYMBOL_EXPORT_STRING} - Not used by Astral itself, exists for tooling purposes. Interpretation and syntax are entirely up to the user, but Astral uses a set syntax for its components, read Appendix
 - `FastFetch` refers to an optional table that allows direct indexing from Entity (`<Entity>.x` would be applicable to example above). If functions are to be used with this, they should be coded to handle both Entity input and Component input!

All component instances are type of `astrobj` and typeof `Component`. All components have a metatable field `__CName` referring to component name and a `__tostring` meta function. These fields are *always* set by the engine when the component is added to any entity. You cannot override `__tostring` or `_CName`

Loading components at boot time is a bit different. Read below.

## Loading
Components may be loaded either via Lua code at runtime, or loaded at boot-time. It is generally recommended to load components at boot time.
### Runtime loading:
Components may be loaded at runtime by running:
```lua
GetService("Component").NewComponent(Name : string, Pattern : table?, Metadata : table?, FastFetch : table?)
```
### Boot-time loading:
Boot-time components may be put into one of 2 paths:
 - <engine>/Engine/World/ComponentHandler/COMPONENTS/
 - <gamefile>/Assets/Components/
They will be automatically loaded at runtime. They must have a file extension of `.lua`. Sub-folders are not searched

Plugins may also load components at boot time, read `Plugins/AddingComponents.md` to see how

A pattern is meant to be followed by all Component files:
```lua
local Component = {
    Name = <string>,
    Metadata = <MetadataTable>?,
    Pattern = <PatternTable>?,
    FastFetch = <FastFetch>?
}

return Component
```
Keys are case and spelling sensitive. The returned table will be converted to a component automatically
Boot-time components also allow one extra field,
```lua
Component.FinalProcessing = function() end
```
Which is a function that will be ran for all components (if they have it) after all boot-time components finished loading. Good for resolving some dependencies that may not exist at component load time. Especially if ComponentA needs something from ComponentB which may or may not exist immediately
## Note
To create a component, the `Name` must be unique and it must have `Pattern` or `Metadata` with `__create` method
You can find a lot of example folders on how to use Components in above mentioned folders!
## Appendix
### Astral Component Symbol Export Syntax
A syntax used to export component symbols in Astral. This is highly abstract, and not at all used by the engine, instead meant to be translated and used by external tooling. This format is not hard set, one may override it with their own format if they wish
The syntax uses strings, referred to as `SYMBOL_EXPORT_STRING`, which includes 4 unique symbols, each denoting a different field. Each symbol is optional
 - ; -> separator used to break up fields
 - @ -> used to denote component name to show in tooling ("@Parent")
 - \# -> used for tooltips ("@Parent;#Parent of the Entity")
 - $ -> used to denote type ("@Parent;#Parent of the Entity;$Entity")
Our string, "@Parent;#Parent of the Entity;$Entity" means "Field `Parent` needs an input of an `Entity` and is used to represent the Parent of the Entity the field is on"
