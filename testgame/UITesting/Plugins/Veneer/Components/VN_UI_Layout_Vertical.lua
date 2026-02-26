local EnumData = require("../EnumData")
local EntityService = GetService("Entity")
local Component = GetService("Component")
local Layout_Vertical = {
    Metadata = {
        HardDependency = { UIRoot = true, Ancestry = true },
    },
}
Layout_Vertical.Name = "UIVerticalLayout"

local LayoutEnum = EnumData.AlignPosition

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

local Index = {
    PaddingScale = 1,
    PaddingOffset = 2,
    AlignmentVertical = 3,
    AlignmentHorizontal = 4,
}

local Methods = {
    RebuildChildren = function()
        --
    end,
}

local mt = {
    __index = function(self, k)
        if Methods[k] then
            return Methods[k]
        end
    end,
    __newindex = function(self, k, v) end,
}

Layout_Vertical.Metadata.__create = function(Input, Ent, Sink)
    local TransformComponent = Component.HasComponent(Ent, "UIRoot")
    local AncestryComponent = Component.HasComponent(Ent, "AncestryComponent")
    if not AncestryComponent and not Sink then
    end

    local PaddingScale = Input and Input.PaddingScale or Vec2()
    local PaddingOffset = Input and Input.PaddingOffset or Vec2()

    local AlignmentVertical = Input and Input.AlignmentVertical or LayoutEnum.Center
    local AlignmentHorizontal = Input and Input.AlignmentHorizontal or LayoutEnum.Center

    local Data = {}

    setmetatable(Data, mt)

    return Data
end

Layout_Vertical.FinalProcessing = function()
    AstralEngine.Plugins.VeneerUI.MatrixChanged:Connect(OnMatrixUpdate)
    -- late bind it since we cant guarantee the event will exist on load-time
end

return Layout_Vertical
