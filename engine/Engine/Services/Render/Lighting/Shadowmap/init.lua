local Renderer, Lighting = select(1, ...)

local Shadowmap = {}

local Manager = loadfile("Manager")(Renderer, Lighting)

Shadowmap.Add = Manager.Register
Shadowmap.Remove = Manager.Deregister

return Shadowmap
