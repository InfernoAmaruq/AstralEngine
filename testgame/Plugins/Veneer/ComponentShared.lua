local Component = GetService("Component")
local ComponentSharedRegistry = {}

ComponentSharedRegistry.ProcessComponent = function(ComponentData)
    if Component.AncestryRequired then
        table.insert(Component.AncestryRequired, ComponentData.Name)
    end
end

return ComponentSharedRegistry
