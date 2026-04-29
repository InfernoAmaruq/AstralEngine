--╔──────────────────────────────────────────────────╗
--│                 LayoutCore.lua                   │
--│ Abstract module for creating UILayout components │
--╚──────────────────────────────────────────────────╝

--\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//
--              DEPENDENCY
--\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//

local EnumData = require("EnumData")
local EntityService = GetService("Entity")
local Component = GetService("Component")

local LayoutEnum = EnumData.AlignPosition

--\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//
--    ABSTRACT COMPONENT DECLARATION
--\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//

EntityService.OnAncestryChanged:Connect(function(...)
    local i = 1
    local n = select("#", ...)

    while i <= n do
        for LocalI = 0, 1 do
            local Parent = select(i + LocalI, ...)

            local UIRoot = Parent:GetComponent("UIRoot")
            if UIRoot and UIRoot.__HasLayoutElement then
                Parent:GetComponent(UIRoot.__HasLayoutElement):RebuildChildren()
            end
        end

        i = i + 3
    end
end)

local Index = {
    Owner = 1,
    ScalePadding = 2,
    OffsetPadding = 3,
    AlignmentVertical = 4,
    AlignmentHorizontal = 5,
    WrapChildren = 6,
}

local HardDependency, HardExclusion = { UIRoot = true, Ancestry = true }, {}

local mt = {
    __index = function(self, k)
        local OnIdxFunc = rawget(self, "__ONIDX")
        if OnIdxFunc then
            local s, v = OnIdxFunc(self, k, v)
            if s then
                return v
            end
        end

        if self.__Methods[k] then
            return self.__Methods[k]
        else
            local Idx = Index[k]

            if Idx == Index.OffsetPadding or Idx == Index.ScalePadding then
                return vec2(self[Idx])
            elseif Idx then
                return self[Idx]
            end
        end
    end,
    __newindex = function(self, k, v)
        local OnIdxFunc = rawget(self, "__ONNEWIDX")
        if OnIdxFunc then
            local s = OnIdxFunc(self, k, v)
            if s then
                return
            end
        end

        local Idx = Index[k]

        if Idx == Index.ScalePadding or Idx == Index.OffsetPadding then
            self[Idx]:set(v)
            self.__Methods.RebuildChildren(self)
        elseif Idx then
            self[Idx] = v
            self.__Methods.RebuildChildren(self)
        end
    end,
}

local function New__createFunc(RegTable)
    local OnCreate = RegTable.OnCreate
    local VTable = RegTable.VTable
    return function(Input, Ent, Sink)
        local TransformComponent = Component.HasComponent(Ent, "UIRoot")
        local AncestryComponent = Component.HasComponent(Ent, "Ancestry")
        if not AncestryComponent and not Sink then
            Component.AddComponent(Ent, "Ancestry")
        end

        local ScalePadding = Vec2(Input and Input.ScalePadding or vec2())
        local OffsetPadding = Vec2(Input and Input.OffsetPadding or vec2())

        local AlignmentVertical = Input and Input.AlignmentVertical or LayoutEnum.Center
        local AlignmentHorizontal = Input and Input.AlignmentHorizontal or LayoutEnum.Center

        local Data = {
            [Index.Owner] = Ent,
            [Index.AlignmentHorizontal] = AlignmentHorizontal,
            [Index.AlignmentVertical] = AlignmentVertical,
            [Index.OffsetPadding] = OffsetPadding,
            [Index.ScalePadding] = ScalePadding,
            [Index.WrapChildren] = Input and Input.WrapChildren or false,
            __Methods = VTable,
            __ONIDX = RegTable.OnIndex,
            __ONNEWIDX = RegTable.OnNewIndex,
        }

        if OnCreate then
            Data = OnCreate(Data, Input) or Data
        end

        setmetatable(Data, mt)

        if TransformComponent and AncestryComponent then
            Data:RebuildChildren()
        end

        return Data
    end
end

local BaseVTable = {}

local LayoutCore = {}

local function OnRemove(_, e)
    local OwnRoot = Component.HasComponent(e, "UIRoot")
    if OwnRoot then
        -- mark as non-existant so it doesn't try to rebuild
        OwnRoot.__HasLayoutElement = false
    end
    local Anc = Component.HasComponent(e, "Ancestry")
    for _, Child in Anc:IterChildren() do
        local Root = Child:GetComponent("UIRoot")
        if Root then
            Root:RebuildMatrix()
        end
    end
end

-- Main register entry point for components inheriting this
LayoutCore.Register = function(InstancedData)
    local Name = InstancedData.Name

    -- we want it to block constructs for all other UI layouts
    HardExclusion[Name] = true

    local VTable = {}

    for i, v in pairs(BaseVTable) do -- clone since we override some funcs
        VTable[i] = v
    end

    for i, v in pairs(InstancedData.VTable) do
        VTable[i] = v
    end

    local ComponentTable = {
        Metadata = {
            HardDependency = HardDependency,
            UILayoutObject = true,
            HardExclusion = HardExclusion,
            __create = New__createFunc(InstancedData),
            __remove = OnRemove,
        },
        Name = Name,
    }

    return ComponentTable
end

LayoutCore.Index = Index
LayoutCore.Enum = LayoutEnum
function LayoutCore.InverseLayoutSort(a, b)
    return (a.LayoutOrder or 0) > (b.LayoutOrder or 0)
end

return LayoutCore
