# Entity Service
## Description
A service for managing entities and tracking events associated with them. Can be required via `GetService()`, read `Globals/GetService.md`
For documentation on entities read `Classes/Entity.md`

```lua
local Entity = GetService("Entity")
Entity.New("MyCoolEntity")
```

## Methods
### .New(Name:string,...:ComponentTuple\*) -> Entity
Creates a new entity and returns it

### .Destroy(Ent:Entity|number)
Destroy an entity

### .CreateAtId(Id:number,Name:string,...:ComponentTuple\*) -> Entity
Allocates an entity at this specific ID. WILL destroy the entity already there

Where `ComponentTuple` = (ComponentName:string,ComponentInput:table)

## Events
For event documentation see `Classes/Event.md`
### .OnAncestryChanged(...: (Parent: Entity, Child: Entity, Status:"add"|"remove")+) - Non-yieldable
Fired any time ancestry is changed. This event may return a large tuple, so make sure to process everything as it is sometimes batched
### .EntityAdded(Entity) - Non-yieldable
Fired when the entity is added, returns entity
### .EntityRemoving(Entity) - Non-yieldable
Fired BEFORE the entity is removed. Finish up any and all work needed
