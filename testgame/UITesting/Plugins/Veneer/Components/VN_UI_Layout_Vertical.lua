local EnumData = require("../EnumData")
local EntityService = GetService("Entity")
local Component = GetService("Component")

-- declarations

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
    ScalePadding = 2,
    OffsetPadding = 3,
    AlignmentVertical = 4,
    AlignmentHorizontal = 5,
    WrapInstances = 6,
}

local TempTable = {}

local function InverseLayoutSort(a, b)
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
        local OwnRotationRad = math.rad(OwnRoot.Rotation)

        -- TEMP
        local VAlign, HAlign = self[Index.AlignmentVertical], self[Index.AlignmentHorizontal]
        local OffsetSpacing, ScaleSpacing = self[Index.OffsetPadding], self[Index.ScalePadding]

        local OwnSize = vec2(OwnMatrix:getScale())
        local OwnPosition = vec2(OwnMatrix:getPosition())
        local TotalHeight = 0

        local Spacing = OffsetSpacing + OwnSize * ScaleSpacing

        for Child in Anc:IterChildren() do
            local UIRoot = Child:GetComponent("UIRoot")
            if UIRoot then
                TempTable[#TempTable + 1] = UIRoot

                local P, S, Q = UIRoot:__GetRebuildValues(OwnMatrix)

                local Mat = UIRoot[1] -- matrix slot

                Mat:identity()
                Mat:translate(P.x, P.y, 0)
                Mat:scale(S.x, S.y, 0)
                local _, _, z = Q:getEuler()

                -- store temporary Z rotation in matrix so we can later fetch it
                -- why? because :rotate() can return a different quat, so its unreliable
                -- read readme.md
                Mat[4] = z -- rad

                Mat[12] = OwnRotationRad
                -- set parent rotation so we can inherit it

                TotalHeight = TotalHeight + S.y
            end
        end

        local NChildren = #TempTable

        TotalHeight = TotalHeight + ((NChildren - 1) * Spacing.y)

        table.sort(TempTable, InverseLayoutSort)

        rawset(self, ".RebuildInProgress", true)

        local StartY
        if VAlign == LayoutEnum.Top then
            StartY = OwnPosition.y - OwnSize.y / 2
        elseif VAlign == LayoutEnum.Bottom then
            StartY = OwnPosition.y + OwnSize.y / 2 - TotalHeight
        else
            StartY = OwnPosition.y - TotalHeight / 2
        end

        local CurrentY = StartY
        for i = NChildren, 1, -1 do
            local ChildRoot = TempTable[i]
            TempTable[i] = nil
            local ChildMat = ChildRoot[1]
            local P = vec2(ChildMat:getPosition())
            local S = vec2(ChildMat:getScale())
            -- now decode euler angle we decoded previously
            local Q = quat():setEuler(0, 0, ChildMat[4])

            local ChildY = CurrentY + S.y / 2
            local ChildX

            if HAlign == LayoutEnum.Left then
                ChildX = -OwnSize.x / 2 + S.x / 2
            elseif HAlign == LayoutEnum.Center then
                ChildX = 0
            else
                ChildX = OwnSize.x / 2 - S.x / 2
            end

            P.x = ChildX + OwnPosition.x
            P.y = ChildY

            ChildRoot:RebuildMatrix(P, S, Q, quat(), vec2())

            CurrentY = CurrentY + S.y + Spacing.y
        end

        rawset(self, ".RebuildInProgress", nil)
    end,
}

local mt = {
    __index = function(self, k)
        if Methods[k] then
            return Methods[k]
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
        local Idx = Index[k]
        if Idx == Index.ScalePadding or Idx == Index.OffsetPadding then
            self[Idx]:set(v)
            Methods.RebuildChildren(self)
        else
            self[Idx] = v
            Methods.RebuildChildren(self)
        end
    end,
}

Layout_Vertical.Metadata.__create = function(Input, Ent, Sink)
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
        [1] = Ent,
        [Index.AlignmentHorizontal] = AlignmentHorizontal,
        [Index.AlignmentVertical] = AlignmentVertical,
        [Index.OffsetPadding] = OffsetPadding,
        [Index.ScalePadding] = ScalePadding,
        [Index.WrapInstances] = Input and Input.WrapInstances or false,
    }

    setmetatable(Data, mt)

    if TransformComponent and AncestryComponent then
        Data:RebuildChildren()
    end

    return Data
end

return Layout_Vertical
