local UITransformModule = {}

local ZeroTwo = Vec2(vec2.zero)

AstralEngine.Plugins.VeneerUI.UITransformModule = UITransformModule

local EmptySlot = 4 -- unused field in a transform matrix. Set 4 to 1 to invalidate

UITransformModule.Pointers = {
    Matrix = 1,
    ScalePosition = 2,
    OffsetPosition = 3,
    Rotation = 4,
    ScaleSize = 5,
    OffsetSize = 6,
}

local Pointers = UITransformModule.Pointers

local Mt = {
    __tostring = function(self)
        return "UITransform: " .. debug.getaddress(self)
    end,
    __index = function(self, k)
        local Ptr = UITransformModule.Pointers[k]

        if Ptr then
            if Ptr == UITransformModule.Pointers.Matrix then
                return mat4(self[Ptr])
            elseif Ptr == UITransformModule.Pointers.Rotation then
                return self[Ptr]
            else
                return vec2(self[Ptr])
            end
        end

        return UITransformModule[k]
    end,
}

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

    Matrix[4] = 1

    setmetatable(Data, Mt)

    return Data
end

local StorageQuat = Quat()

function UITransformModule:RebuildMatrix(ImageResolution)
    local Mat = self[Pointers.Matrix]

    local Pos_Vec2Total = self[Pointers.ScalePosition] * ImageResolution + self[Pointers.OffsetPosition]
    local Size_Vec2Total = self[Pointers.ScaleSize] * ImageResolution + self[Pointers.OffsetSize]

    StorageQuat:set(1, 0, 0, math.rad(self[Pointers.Rotation]))

    Mat:set(vec3(Pos_Vec2Total.x, Pos_Vec2Total.y, 0), vec3(Size_Vec2Total.x, Size_Vec2Total.y, 0), StorageQuat)

    Mat[4] = 0
end

function UITransformModule:IsValid()
    return self[1][4] == true
end

return UITransformModule
