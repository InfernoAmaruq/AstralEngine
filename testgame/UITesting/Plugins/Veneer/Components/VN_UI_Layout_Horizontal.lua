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
    local TotalWidth = 0

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

            TotalWidth = TotalWidth + S.x
        end
    end

    local NChildren = #TempTable

    TotalWidth = TotalWidth + ((NChildren - 1) * Spacing.x)

    table.sort(TempTable, InverseLayoutSort)

    rawset(self, ".RebuildInProgress", true)

    local StartX
    if HAlign == LayoutEnum.Left then
        StartX = OwnPosition.x - OwnSize.x / 2
    elseif HAlign == LayoutEnum.Right then
        StartX = OwnPosition.x + OwnSize.x / 2 - TotalWidth
    else
        StartX = OwnPosition.x - TotalWidth / 2
    end

    -- wrapping math
    local Wraps = self[Index.WrapChildren] and math.ceil(math.max(1, TotalWidth / OwnSize.x)) or 1
    local CurWrap = 1
    local WrapCounter = 0
    local WrapAt = OwnSize.x

    local LargestY = -math.huge
    local WrapOffset = 0

    -- start
    local CurrentX = StartX
    for i = NChildren, 1, -1 do
        local ChildRoot = TempTable[i]
        TempTable[i] = nil
        local ChildMat = ChildRoot[1]
        local P = vec2(ChildMat:getPosition())
        local S = vec2(ChildMat:getScale())
        -- now decode euler angle we decoded previously
        local Q = quat():setEuler(0, 0, ChildMat[4])

        if Wraps > 1 then
            if S.y > LargestY then
                LargestY = S.y
            end

            WrapCounter = WrapCounter + S.x
            if WrapCounter >= WrapAt then
                WrapOffset = WrapOffset + LargestY
                LargestY = 0
                WrapCounter = 0
                CurrentX = StartX
            end
        end

        local ChildX = CurrentX + S.x / 2
        local ChildY

        if VAlign == LayoutEnum.Top then
            ChildY = -OwnSize.y / 2 + S.y / 2 + WrapOffset
        elseif VAlign == LayoutEnum.Center then
            ChildY = WrapOffset / 2
            print("MUST SHIFT HALF UP PREV LAYER, MUST PRECOMPUTE TOTAL Y")
            print("WRAPPING")
        else
            ChildY = OwnSize.y / 2 - S.y / 2 - WrapOffset
        end

        P.x = ChildX
        P.y = ChildY + OwnPosition.y

        ChildRoot:RebuildMatrix(P, S, Q, vec2())

        CurrentX = CurrentX + S.x + Spacing.x
    end

    rawset(self, ".RebuildInProgress", nil)
end

return Core.Register({
    Name = "UIHorizontalLayout",
    VTable = {
        RebuildChildren = RebuildChildren,
    },
})
