local Component = GetService("Component")
local Core = require("../LayoutCore")

local FillDirectionEnum = ENUM({
    Horizontal = 1,
    Vertical = 2,
}, "UIFillDirection")

local InverseLayoutSort = Core.InverseLayoutSort

local Index = Core.Index
local LayoutEnum = Core.Enum

local Top = 0
for _, v in pairs(Index) do
    if v > Top then
        Top = v
    end
end

local CellSizeOffsetIdx = Top + 1
local CellSizeScaleIdx = Top + 2
local FillDirectionIdx = Top + 3

local function RebuildChildren(self)
    local Children = {}

    local Owner = self[1]
    local OwnRoot =
        AstralEngine.Assert(Component.HasComponent(Owner, "UIRoot"), "NO UI ROOT FOUND IN UIVerticalLayout", "VENEER")
    local Anc = AstralEngine.Assert(
        Component.HasComponent(Owner, "Ancestry"),
        "NO ANCESTRY FOUND IN UIVerticalLayout",
        "VENEER"
    )

    local OwnMatrix = OwnRoot.Matrix

    -- TEMP
    local VAlign, HAlign = self[Index.AlignmentVertical], self[Index.AlignmentHorizontal]
    local OffsetSpacing, ScaleSpacing = self[Index.OffsetPadding], self[Index.ScalePadding]

    local OwnSize = vec2(OwnMatrix:getScale())
    local OwnPosition = vec2(OwnMatrix:getPosition())

    local Spacing = OffsetSpacing + OwnSize * ScaleSpacing
    local CellSize = self[CellSizeOffsetIdx] + OwnSize * self[CellSizeScaleIdx]

    local FillHorizontal = self[FillDirectionIdx] == FillDirectionEnum.Horizontal

    local MaxX = math.floor((OwnSize.x + Spacing.x) / (CellSize.x + Spacing.x))
    local MaxY = math.floor((OwnSize.y + Spacing.y) / (CellSize.y + Spacing.y))

    for _, Child in Anc:IterChildren() do
        local UIRoot = Child:GetComponent("UIRoot")
        if UIRoot then
            Children[#Children + 1] = UIRoot
        end
    end

    table.sort(Children, InverseLayoutSort)

    local Total = #Children
    local Layers = math.ceil(Total / (FillHorizontal and MaxX or MaxY))

    local Max = FillHorizontal and MaxX or MaxY

    local MainAxis = FillHorizontal and "x" or "y"
    local AuxAxis = FillHorizontal and "y" or "x"

    rawset(self, ".RebuildInProgress", true)

    local CorePos = vec2(OwnPosition)

    local MaxSize = vec2()
    local MaxMainAxis = math.min(Total, Max)

    MaxSize[MainAxis] = MaxMainAxis * CellSize[MainAxis] + (math.max(0, MaxMainAxis - 1) * Spacing[MainAxis])
    MaxSize[AuxAxis] = Layers * CellSize[AuxAxis] + (math.max(0, Layers - 1) * Spacing[AuxAxis])

    local Full = math.max(0, Layers - 1) * Max
    local Remainder = Total - Full

    if HAlign == LayoutEnum.Right then
        CorePos.x = OwnPosition.x + OwnSize.x / 2 - MaxSize.x + CellSize.x / 2
    elseif HAlign == LayoutEnum.Left then
        CorePos.x = OwnPosition.x - OwnSize.x / 2 + CellSize.x / 2
    else
        CorePos.x = OwnPosition.x - MaxSize.x / 2 + CellSize.x / 2
    end

    if VAlign == LayoutEnum.Top then
        CorePos.y = OwnPosition.y - OwnSize.y / 2 + CellSize.y / 2
    elseif VAlign == LayoutEnum.Bottom then
        CorePos.y = OwnPosition.y + OwnSize.y / 2 - MaxSize.y + CellSize.y / 2
    else
        CorePos.y = OwnPosition.y - MaxSize.y / 2 + CellSize.y / 2
    end

    local LocalizedAlignment
    if FillHorizontal then
        LocalizedAlignment = HAlign.RawValue
    else
        if VAlign == LayoutEnum.Center then
            LocalizedAlignment = 3
        else
            LocalizedAlignment = VAlign.RawValue - 3
        end
    end

    local BasePos = vec2(CorePos)
    for i = 1, Total do
        local Root = Children[i]

        local Rot = Root.Rotation

        local P, S, Q = BasePos, CellSize, quat():setEuler(0, 0, math.rad(Rot))

        if i == Full + 1 then
            local MaxSizeOnAxis = Remainder * CellSize[MainAxis] + math.max(0, Remainder - 1) * Spacing[MainAxis]

            if LocalizedAlignment == 1 then -- left
                BasePos[MainAxis] = CorePos[MainAxis]
            elseif LocalizedAlignment == 2 then -- right
                BasePos[MainAxis] = CorePos[MainAxis] + MaxSize[MainAxis] - MaxSizeOnAxis
            else                       -- center
                BasePos[MainAxis] = OwnPosition[MainAxis] - MaxSizeOnAxis / 2 + CellSize[MainAxis] / 2
            end
        end

        Root:RebuildMatrix(P, S, Q, vec2.zero)

        local Mod = i % MaxX
        if Mod == 0 then
            -- Shift layer down
            BasePos[MainAxis] = i ~= Full and CorePos[MainAxis] or BasePos[MainAxis]
            BasePos[AuxAxis] = BasePos[AuxAxis] + CellSize[AuxAxis] + Spacing[AuxAxis]
        else
            BasePos[MainAxis] = BasePos[MainAxis] + CellSize[MainAxis] + Spacing[MainAxis]
        end
    end

    rawset(self, ".RebuildInProgress", false)
end

return Core.Register({
    Name = "UIGridLayout",
    OnCreate = function(self, Input)
        self[CellSizeOffsetIdx] = Input and Input.OffsetCellSize and Vec2(Input.OffsetCellSize) or Vec2()
        self[CellSizeScaleIdx] = Input and Input.ScaleCellSize and Vec2(Input.ScaleCellSize) or Vec2()
        self[FillDirectionIdx] = Input and Input.FillDirection or FillDirectionEnum.Horizontal
    end,
    OnIndex = function(self, k)
        if k == "WrapChildren" then
            return false, nil
        elseif k == "OffsetCellSize" then
            return true, vec2(self[CellSizeOffsetIdx])
        elseif k == "ScaleCellSize" then
            return true, vec2(self[CellSizeScaleIdx])
        elseif k == "FillDirection" then
            return true, self[FillDirectionIdx]
        end
        return false, nil
    end,
    OnNewIndex = function(self, k, v)
        if k == "WrapChildren" then
            return false
        elseif k == "OffsetCellSize" then
            self[CellSizeOffsetIdx]:set(v)
            self.__Methods.RebuildChildren(self)
            return true
        elseif k == "ScaleCellSize" then
            self[CellSizeScaleIdx]:set(v)
            self.__Methods.RebuildChildren(self)
            return true
        elseif k == "FillDirection" then
            self[FillDirectionIdx] = v
            self.__Methods.RebuildChildren(self)
            return true
        end
        return false
    end,
    VTable = {
        RebuildChildren = RebuildChildren,
    },
})
