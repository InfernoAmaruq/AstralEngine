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
    local WrapCount, WrapX = 0, 0
    local CurrentWidthCount = 0
    local MaxLocalHeight = 0
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
            local OverSize = WrapX + S.x >= OwnSize.x
            if OverSize or IsEq then
                WrapCount = WrapCount + 1

                local IsBoth = IsEq and OverSize

                if (not IsEq or IsBoth) and S.x <= OwnSize.x then
                    i = i - 1
                    CurChild = CurChild - 1
                else
                    CurrentWidthCount = CurrentWidthCount + S.x
                    MaxLocalHeight = S.y > MaxLocalHeight and S.y or MaxLocalHeight
                end

                if CurrentWidthCount > TotalWidth then
                    TotalWidth = CurrentWidthCount
                end

                Layers[WrapCount] = {
                    Width = CurrentWidthCount,
                    Height = MaxLocalHeight,
                    From = TopChild + 1,
                    Count = CurChild,
                }

                TopChild = CurChild + TopChild
                TotalHeight = TotalHeight + MaxLocalHeight
                MaxLocalHeight = 0
                WrapX = 0
                CurrentWidthCount = 0
                CurChild = 0
            else
                CurrentWidthCount = CurrentWidthCount + S.x

                MaxLocalHeight = S.y > MaxLocalHeight and S.y or MaxLocalHeight

                WrapX = WrapX + S.x
            end
        else
            TotalWidth = TotalWidth + S.x
            TotalHeight = S.y > TotalHeight and S.y or TotalHeight
        end
        i = i + 1
    end

    TotalHeight = TotalHeight + (math.max((#Layers - 1), 0) * Spacing.y)

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
        local LayerWidth = LayerData.Width + ((LayerData.Count - 1) * Spacing.x)
        local LayerHeight = LayerData.Height

        local StartX

        if HAlign == LayoutEnum.Left then
            StartX = OwnPosition.x - OwnSize.x / 2
        elseif HAlign == LayoutEnum.Right then
            StartX = OwnPosition.x + OwnSize.x / 2 - LayerWidth
        else
            StartX = OwnPosition.x - LayerWidth / 2
        end

        local CurrentX = StartX
        for i = LayerData.From, LayerData.From + LayerData.Count - 1 do
            local ChildRoot = TempTable[i]
            local ChildMat = ChildRoot[1]

            local P = vec2(ChildMat:getPosition())
            local S = vec2(ChildMat:getScale())
            -- now decode euler angle we encoded previously
            local Q = quat():setEuler(0, 0, ChildMat[4])

            local ChildX = CurrentX + S.x / 2
            local ChildY

            if VAlign == LayoutEnum.Top then
                ChildY = -OwnSize.y / 2 + S.y / 2 + WrapOffset
            elseif VAlign == LayoutEnum.Center then
                ChildY = -TotalHeight / 2 + WrapOffset + LayerHeight / 2
            else
                ChildY = OwnSize.y / 2 - S.y / 2 - WrapOffset
            end

            P.x = ChildX
            P.y = ChildY + OwnPosition.y

            ChildRoot:RebuildMatrix(P, S, Q, vec2())

            CurrentX = CurrentX + S.x + Spacing.x
        end

        WrapOffset = WrapOffset + LayerData.Height + Spacing.y
    end

    rawset(self, ".RebuildInProgress", nil)
end

return Core.Register({
    Name = "UIHorizontalLayout",
    VTable = {
        RebuildChildren = RebuildChildren,
    },
})
