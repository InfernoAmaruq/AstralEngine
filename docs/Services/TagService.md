# Tag Service
## Description
A service used to add/remove/query tags in entities. Also allows large-scale queries like getting all entities with a specific tag

```lua
local TagService = GetService("TagService")
local EntitiesWithTag = TagService.GetTagged(MyTag : string)
```

## Methods
### .HasTag(Ent:Entity|Int, Tag:string) -> boolean
Returns true if the entity has a tag
### .AddTag(Ent:Entity, Tag:string)
Add a tag to the given entity
### .RemoveTag(Ent:Entity|Int, Tag:string)
Remove a tag from the given entity
### .ClearTags(Ent:Entity|Int)
Remove all tags from the given entity. Will call `.TagRemoved` event for each tag
### .GetAllTags(Ent:Entity|Int) -> {string}
Returns a new table with all tags that the provided entity has
### .GetTagged(Tag:string) -> {Entity}
Returns a table with all entities that have the provided tag
### .GetTaggedUnsafe(Tag:string) -> {Int}
Returns the REGISTRY of Entity integer IDs with the provided tag. Does not allocate, returns registry table, not mutation safe
Majorly faster to do in hot code, however, great care is to be taken

## Events
### .TagAdded(Entity,string)
Fired when a tag is added to any entity
### .TagRemoved(Entity,string)
Fired when a tag is removed from any entity. Important to mention, while destruction of an entity removes tags, it does not fire this event. Listen for destruction instead. Tags still exist during destruction events

## Notes
All methods that take 'Entity' as the first parameter are virtualized to the Entity object, and can be called like `Entity:HasTag(Tag)`
All methods that take 'Entity' as the first parameter will error if the Entity is dead, check with `Entity.IsNull`
