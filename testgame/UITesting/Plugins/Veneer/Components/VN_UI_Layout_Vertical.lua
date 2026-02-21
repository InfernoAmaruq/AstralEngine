local EntityService = GetService("Entity")
local Component = GetService("Component")
local Layout_Vertical = {
    Metadata = {
        HardDependency = { UIRoot = true, Ancestry = true },
    },
}
Layout_Vertical.Name = "UIVerticalLayout"

local OnMatrixUpdate = function(EntityId, NewMatrix)
    local Ancestry = Component.HasComponent(EntityId, "Ancestry")
    local Parent = Ancestry and Ancestry.Parent
    local ParentUIRoot = Parent and Parent:GetComponent("UIRoot")

    if ParentUIRoot and ParentUIRoot.__HasLayout then
        Parent:GetComponent(ParentUIRoot.__HasLayout):RebuildChildren()
    end
end

EntityService.OnAncestryChanged:Connect(function(...)
    local i = 1
    local n = select("#", ...)

    while i <= n do
        for LocalI = 0, 1 do
            local Parent = select(i + LocalI, ...)

            local UIRoot = Parent:GetComponent("UIRoot")
            if UIRoot and UIRoot.__HasLayout then
                Parent:GetComponent(UIRoot.__HasLayout):RebuildChildren()
            end
        end

        i = i + 3
    end
end)

local mt = {
    __index = function(self, k) end,
    __newindex = function(self, k, v) end,
}

Layout_Vertical.Metadata.__create = function(Input, Ent, Sink)
    local TransformComponent = Component.HasComponent(Ent, "UIRoot")
    local AncestryComponent = Component.HasComponent(Ent, "AncestryComponent")
    if not AncestryComponent and not Sink then
    end

    local PaddingScale
    local PaddingOffset

    local AlignmentVertical
    local AlignmentHorizontal

    return {}
end

Layout_Vertical.FinalProcessing = function()
    AstralEngine.Plugins.VeneerUI.MatrixChanged:Connect(OnMatrixUpdate)
    -- late bind it since we cant guarantee the event will exist on load-time
end

return Layout_Vertical
