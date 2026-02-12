local UITransformModule = {}

local ZeroTwo = vec2.zero

AstralEngine.Plugins.VeneerUI.UITransformModule = UITransformModule

UITransformModule.__index = UITransformModule

UITransformModule.Pointers = {
    Matrix = 1,
    ScalePosition = 2,
    OffsetPosition = 3,
    Rotation = 4,
    ScaleSize = 5,
    OffsetSize = 6,
}
local Pointers = UITransformModule.Pointers

UITransformModule.__tostring = function(self)
    return "UITransform: " .. debug.getaddress(self)
end

UITransformModule.__type = "UITransform"

function UITransformModule.New(InputTransform)
    local Rotation = InputTransform and InputTransform.Rotation or 0

    local PosTable = InputTransform.Position
    local SizeTable = InputTransform.Size

    local Size_Scale, Size_Offset = Vec2(), Vec2()
    local Pos_Scale, Pos_Offset = Vec2(), Vec2()

    if SizeTable then
        Size_Scale:set(SizeTable.Scale or ZeroTwo)
        Size_Offset:set(SizeTable.Offset or ZeroTwo)
    end
    if PosTable then
        Pos_Scale:set(PosTable.Scale or ZeroTwo)
        Pos_Offset:set(PosTable.Offset or ZeroTwo)
    end

    local Matrix = Mat4()

    local Data = {
        [Pointers.Matrix] = Matrix,
        [Pointers.OffsetPosition] = Pos_Offset,
        [Pointers.OffsetSize] = Size_Offset,
        [Pointers.Rotation] = Rotation,
        [Pointers.ScalePosition] = Pos_Scale,
        [Pointers.ScaleSize] = Size_Scale,
    }

    setmetatable(Data, UITransformModule)

    return Data
end

local StorageQuat = Quat()

function UITransformModule:RebuildMatrix(ImageResolution)
    local Mat = self[Pointers.Matrix]

    local Pos_Vec2Total = self[Pointers.ScalePosition] * ImageResolution + self[Pointers.OffsetPosition]
    local Size_Vec2Total = self[Pointers.ScaleSize] * ImageResolution + self[Pointers.OffsetSize]

    StorageQuat:set(1, 0, 0, math.rad(self[Pointers.Rotation]))

    Mat:set(vec3(Pos_Vec2Total.x, Pos_Vec2Total.y, 0), vec3(Size_Vec2Total.x, Size_Vec2Total.y, 0), StorageQuat)
end

return UITransformModule
