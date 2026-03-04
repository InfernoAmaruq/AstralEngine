# Astral Type Guide
Astral extends Lua's type() and adds 2 more type checkers:
 - math.mathtype(n)
 - typeof(n)

# Types:
## type(a:any) -> string
A lightly extended Lua type() function. Returns all the basic Lua types (read Lua 5.1 documentation) alongside 2 more:
 - array
 - astrobj

For information on arrays read `Types/Array.md`
`astrobj` is an umbrella type for all Astral (and LOVR) types. `astrobj` can be either a table or userdata. This can be used to quickly and loosely check if something is an astral object (entity, component, etc). This does not extend to types like `Types/Signal.md`

Ex:
```lua
local Entity = GetService"Entity".New()
local Type = type(Entity)
print(Type) --> astrobj
```

## math.mathtype(a:any) -> string|nil
A function for checking specific types of numbers, can return "Inf"|"Integer"|"Double". May return 'nil' if input is not a number

Ex:
```lua
local IsInt = math.mathtype(21) == "Int"
print(IsInt) --> true
```

## typeof(a:any) -> string
A broader type function. Can be used to typecheck enums and objects more specifically. User types can be added for typeof() to interpret.

A new metatable field, `.__type`. Accepting any value and returning it if typeof() is called on the object.

Ex:
```lua
local Entity = GetService"Entity".New()
local Type = typeof(Entity)
print(Type) --> Entity
print(typeof(ENUM.MyEnum.MyEnumField)) --> __ENUM_MyEnum (syntax: __ENUM_<Name>)
```

## Notes
Astral provides `rtype()` for the true implementation of Lua's type() just incase it is needed
