# Entity (type)
## Description
An entity is a pure data object within Astral with a lifetime and, optionally, components. For constructing entities see `Services/Entity.md`
For components, read `Services/Component.md` and `Types/Component.md`

## Methods
### :AddComponent(s:string,InputData:any?) -> Component
Create a new component of type `s` with InputData as parameter
Be mindful components may have dependencies!

### :GetComponent(s:string) -> Component?
Returns component type of `s` if found

### :GetComponentProperty(s:string,p:string|number) -> any?
Returns the field `p` of component `s` if `s` exists

### :GetComponents() -> {Component\*}
Returns a table of components

### :RemoveComponent(s:string)
Destroys component `s`

### :Destroy()
Destroys the entity
## Fields
Note: these fields should ***NOT*** be written to by usercode

### .Id : Int
Returns entity Id, which is an Integer pointing to its position

### .__gen : Int
The generation field, representing how many times the entity has been re-used

### .__context : Int
The generation of the Context that this component is bound to. Read `Types/Context.md`

### .UniqueId : Int
A unique identifier using a bitshift from `__gen` and `Id`. Guaranteed to be unique every time

### .IsNull : bool
`IsNull` is true if the entity is dead currently. It is a good idea to check if the entity is alive before performing operations, if the entity is dead you will get an error when attempting to perform work on it

## Signals
Important -- All Entity specific events fire BEFORE global entity events such as `EntityService.EntityAdded()`. Work may be performed on the entity prior to the event reaching usercode.

### .Destroying() - Non-yieldable
Fired BEFORE the entity is killed. You may still perform work on it during the event callback.
### .ComponentAdded(ComponentName:string, Component:Component) - Non-yieldable
Fired AFTER a component is added

### .ComponentRemoving(ComponentName:string, Component:Component) - Non-yieldable
Fired BEFORE the component is removed

## Notes
Entity IDs are not permanent and may be recycled. If you want a stable ID, do not use `Entity.Id`, use `Entity.UniqueId`

Entities have unqiue indexing and newindexing rules, you can index `Entity.<ComponentName>` as a shorthand for `GetComponent()`. Some components, like `Components/Ancestry.md` may expose fast fetch fields, such as `Parent`, where they can be indexed directly without indexing the component, `Entity.Parent`. It is advised to use sparingly because:
 - Collisions are possible
 - The more there are, the slower the hash lookup will be
Fast fetch fields also apply to __newindex, so `Entity.Parent = Entity2` is valid

Most functions that accept `Entity` will also accept `Int` referring to the entity's `.Id` field
Engine may prefer the `Id` reference in most cases. Using integer references to entities fast, it is an array index to get the entity

Astral pre-allocates entities with the following math:
```lua
local PREALLOC_SIZE = 50
local RESIZE_AT = 2 / 3
local RESIZE_STEP = 1.25
```
Astral demands Entity arrays be tightly packed, because of that, creating an entity at index 100000 means preallocating 99999 entities, even if they are unused
