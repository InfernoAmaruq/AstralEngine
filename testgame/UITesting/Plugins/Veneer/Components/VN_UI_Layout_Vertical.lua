local Component = GetService("Component")
local Core = require("../LayoutCore")

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
    local TotalHeight = 0

    local Spacing = OffsetSpacing + OwnSize * ScaleSpacing

    local TempTable = {}

    local ShouldWrap = self[Index.WrapChildren]
    local Layers = {}
    local WrapCount, WrapY = 0, 0
    local CurrentHeightCount = 0
    local MaxLocalWidth = 0
    local CurChild, TopChild = 0, 0
    local ChildCount = 0

    for _, Child in Anc:IterChildren() do
        local UIRoot = Child:GetComponent("UIRoot")
        if UIRoot then
            TempTable[#TempTable + 1] = UIRoot
            ChildCount = ChildCount + 1
        end
    end

    if ChildCount == 0 then
        return
    end

    table.sort(TempTable, InverseLayoutSort)

    local i = 1
    while i < #TempTable + 1 do
        local UIRoot = TempTable[i]
        CurChild = CurChild + 1

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

        if ShouldWrap then
            local IsEq = i == ChildCount
            local OverSize = WrapY + S.y >= OwnSize.y
            if OverSize or IsEq then
                WrapCount = WrapCount + 1

                local IsBoth = IsEq and OverSize

                if (not IsEq or IsBoth) and S.y <= OwnSize.y then
                    i = i - 1
                    CurChild = CurChild - 1
                else
                    CurrentHeightCount = CurrentHeightCount + S.y
                    MaxLocalWidth = S.x > MaxLocalWidth and S.x or MaxLocalWidth
                end

                if CurrentHeightCount > TotalHeight then
                    TotalHeight = CurrentHeightCount
                end

                Layers[WrapCount] = {
                    Width = MaxLocalWidth,
                    Height = CurrentHeightCount,
                    From = TopChild + 1,
                    Count = CurChild,
                }

                TopChild = CurChild + TopChild
                TotalWidth = TotalWidth + MaxLocalWidth
                MaxLocalWidth = 0
                WrapY = 0
                CurrentHeightCount = 0
                CurChild = 0
            else
                CurrentHeightCount = CurrentHeightCount + S.y

                MaxLocalWidth = S.x > MaxLocalWidth and S.x or MaxLocalWidth

                WrapY = WrapY + S.y
            end
        else
            TotalWidth = S.x > TotalWidth and S.x or TotalWidth
            TotalHeight = TotalHeight + S.y
        end
        i = i + 1
    end

    TotalWidth = TotalWidth + (math.max(#Layers - 1, 0) * Spacing.x)

    if not ShouldWrap then
        Layers[1] = {
            Width = TotalWidth,
            Height = TotalHeight,
            From = 1,
            Count = ChildCount,
        }
    end

    rawset(self, ".RebuildInProgress", true)

    local WrapOffset = 0

    for LayerId = 1, #Layers do
        local LayerData = Layers[LayerId]
        local LayerWidth = LayerData.Width
        local LayerHeight = LayerData.Height + ((LayerData.Count - 1) * Spacing.y)

        local StartY

        if VAlign == LayoutEnum.Top then
            StartY = OwnPosition.y - OwnSize.y / 2
        elseif VAlign == LayoutEnum.Bottom then
            StartY = OwnPosition.y + OwnSize.y / 2 - LayerHeight
        else
            StartY = OwnPosition.y - LayerHeight / 2
        end

        local CurrentY = StartY
        for i = LayerData.From, LayerData.From + LayerData.Count - 1 do
            local ChildRoot = TempTable[i]
            local ChildMat = ChildRoot[1]

            local P = vec2(ChildMat:getPosition())
            local S = vec2(ChildMat:getScale())
            -- now decode euler angle we encoded previously
            local Q = quat():setEuler(0, 0, ChildMat[4])

            local ChildX
            local ChildY = CurrentY + S.y / 2

            if HAlign == LayoutEnum.Left then
                ChildX = -OwnSize.x / 2 + S.x / 2 + WrapOffset
            elseif HAlign == LayoutEnum.Right then
                ChildX = OwnSize.x / 2 - S.x / 2 - WrapOffset
            else
                ChildX = -TotalWidth / 2 + WrapOffset + LayerWidth / 2
            end

            P.x = ChildX + OwnPosition.x
            P.y = ChildY

            ChildRoot:RebuildMatrix(P, S, Q, vec2())

            CurrentY = CurrentY + S.y + Spacing.y
        end

        WrapOffset = WrapOffset + LayerData.Width + Spacing.x
    end

    rawset(self, ".RebuildInProgress", nil)
end

return Core.Register({
    Name = "UIVerticalLayout",
    VTable = {
        RebuildChildren = RebuildChildren,
    },
})
