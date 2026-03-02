local EnumData = require("../EnumData")
local EntityService = GetService("Entity")
local Component = GetService("Component")
local Layout_Vertical = {
    Metadata = {
        HardDependency = { UIRoot = true, Ancestry = true },
        UILayoutObject = true,
    },
}
Layout_Vertical.Name = "UIVerticalLayout"

local LayoutEnum = EnumData.AlignPosition

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
    PaddingScale = 1,
    PaddingOffset = 2,
    AlignmentVertical = 3,
    AlignmentHorizontal = 4,
}

local TempTable = {}

local function InverseRootSort(a, b)
    return (a.LayoutOrder or 0) > (b.LayoutOrder or 0)
end

local Methods = {
    RebuildChildren = function(self)
        local Owner = self[1]
        local OwnRoot = AstralEngine.Assert(
            Component.HasComponent(Owner, "UIRoot"),
            "NO UI ROOT FOUND IN UIVerticalLayout",
            "VENEER"
        )
        local Anc = AstralEngine.Assert(
            Component.HasComponent(Owner, "Ancestry"),
            "NO ANCESTRY FOUND IN UIVerticalLayout",
            "VENEER"
        )

        local OwnMatrix = OwnRoot.Matrix

        -- TEMP
        local VAlign, HAlign = LayoutEnum.Center, LayoutEnum.Center
        local Spacing = vec4(0, 10, 0, 10)

        local OwnSize = vec2(OwnMatrix:getScale())
        local OwnPosition = vec2(OwnMatrix:getPosition())
        local TotalHeight = 0

        for Child in Anc:IterChildren() do
            local UIRoot = Child:GetComponent("UIRoot")
            if UIRoot then
                TempTable[#TempTable + 1] = UIRoot

                local P, S, Q = UIRoot:__GetRebuildValues(OwnMatrix)

                local Mat = UIRoot[1]

                Mat:identity()
                Mat:translate(P.x, P.y, 0)
                Mat:scale(S.x, S.y, 0)
                local _, _, z = Q:getEuler()

                -- store temporary Z rotation in matrix so we can later fetch it
                -- why? because :rotate() can return a different quat, so its unreliable
                -- read readme.md
                Mat[4] = z

                TotalHeight = TotalHeight + S.y
            end
        end

        table.sort(TempTable, InverseRootSort)

        local NChildren = #TempTable

        rawset(self, ".RebuildInProgress", true)

        local StartY
        if VAlign == LayoutEnum.Top then
            StartY = OwnSize.y / 2
        elseif VAlign == LayoutEnum.Bottom then
            StartY = -OwnSize.y / 2 + TotalHeight
        else
            StartY = OwnSize.y / 2
        end

        local CurrentY = StartY
        for i = NChildren, 1, -1 do
            local ChildRoot = TempTable[i]
            TempTable[i] = nil
            local ChildMat = ChildRoot[1]
            local P = vec2(ChildMat:getPosition())
            local S = vec2(ChildMat:getScale())
            local Q = quat():setEuler(0, 0, ChildMat[4])

            local ChildY = CurrentY - S.y
            local ChildX

            if HAlign == LayoutEnum.Left then
                ChildX = -OwnSize.x / 2 + S.x / 2
            elseif HAlign == LayoutEnum.Center then
                ChildX = 0
            else
                ChildX = OwnSize.x / 2 - S.x / 2
            end

            P.x = ChildX + OwnPosition.x
            P.y = ChildY + OwnPosition.y

            ChildRoot:RebuildMatrix(P, S, Q, vec2(0, 0))

            CurrentY = CurrentY - S.y - Spacing.y
        end

        rawset(self, ".RebuildInProgress", nil)
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
    local AncestryComponent = Component.HasComponent(Ent, "Ancestry")
    if not AncestryComponent and not Sink then
        Component.AddComponent(Ent, "Ancestry")
    end

    local PaddingScale = Input and Input.PaddingScale or Vec2()
    local PaddingOffset = Input and Input.PaddingOffset or Vec2()

    local AlignmentVertical = Input and Input.AlignmentVertical or LayoutEnum.Center
    local AlignmentHorizontal = Input and Input.AlignmentHorizontal or LayoutEnum.Center

    local Data = {
        [1] = Ent,
    }

    setmetatable(Data, mt)

    return Data
end

return Layout_Vertical
