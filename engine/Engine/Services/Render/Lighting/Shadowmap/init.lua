local Renderer = select(1, ...)

local Shadowmap = {}

local Manager = require("Manager")

Shadowmap.Add = Manager.Register
Shadowmap.Remove = Manager.Deregister

return Shadowmap
