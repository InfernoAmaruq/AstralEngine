local ComponentSharedRegistry = require("../ComponentShared")

local Component = GetService("Component")
local Layout_Vertical = { Metadata = { SceneLateLoad = true } }
Layout_Vertical.Name = "UIVerticalLayout"

Layout_Vertical.Metadata.__create = function(Input, Ent, Sink)
    local TransformComponent = Component.HasComponent(Ent, "UIRoot")
    local AncestryComponent = Component.HasComponent(Ent, "AncestryComponent")
    if not AncestryComponent and not Sink then
    end
end

Layout_Vertical.FinalProcessing = function()
    ComponentSharedRegistry.ProcessComponent(Layout_Vertical)
end

return Layout_Vertical
