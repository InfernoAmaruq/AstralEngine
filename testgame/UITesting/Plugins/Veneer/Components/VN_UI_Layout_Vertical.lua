local Component = GetService("Component")
local Core = require("../LayoutCore")

local TempTable = {}

local InverseLayoutSort = Core.InverseLayoutSort

local Index = Core.Index
local LayoutEnum = Core.Enum

local function RebuildChildren(self)
    local Owner = self[1]
    local OwnRoot =
        AstralEngine.Assert(Component.HasComponent(Owner, "UIRoot"), "NO UI ROOT FOUND IN UIVerticalLayout", "VENEER")
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

    for _, Child in Anc:IterChildren() do
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

        ChildRoot:RebuildMatrix(P, S, Q, vec2())

        CurrentY = CurrentY + S.y + Spacing.y
    end

    rawset(self, ".RebuildInProgress", nil)
end

return Core.Register({
    Name = "UIVerticalLayout",
    VTable = {
        RebuildChildren = RebuildChildren,
    },
})
