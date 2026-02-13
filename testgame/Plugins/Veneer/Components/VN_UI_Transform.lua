local UITransform = {}

UITransform.Name = "UITransform"
UITransform.Metadata = {}

local Pointers = {
    Matrix = 1,
    ScalePosition = 2,
    OffsetPosition = 3,
    Rotation = 4,
    ScaleSize = 5,
    OffsetSize = 6,
    Owner = 7,
    HasDrawable = 8, -- string value telling if it has or does not have another Drawable in the same entity
}

local Methods = {
    RebuildMatrix = function(self)
        local Ancestor

        local Mat = self[Pointers.Matrix]

        local Pos_Vec2Total = self[Pointers.ScalePosition] * ImageResolution + self[Pointers.OffsetPosition]
        local Size_Vec2Total = self[Pointers.ScaleSize] * ImageResolution + self[Pointers.OffsetSize]

        StorageQuat:set(1, 0, 0, math.rad(self[Pointers.Rotation]))

        Mat:set(vec3(Pos_Vec2Total.x, Pos_Vec2Total.y, 0), vec3(Size_Vec2Total.x, Size_Vec2Total.y, 0), StorageQuat)
    end,
    Set = function(self, Transform) end,
}

local Mt = {
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

        if k == "__HasUIElement" then
            return self[Pointers.HasDrawable]
        end

        return Methods[k]
    end,
    __newindex = function(self, k, v)
        if Pointers[k] then
            local Val = Pointers[k]

            if Val == Pointers.Rotation then
                self[Val] = v
            elseif Val == Pointers.Matrix then
                self[Val]:set(v)
                return
            else
                self[Val]:set(v)
            end

            Methods.RebuildMatrix(self)
        end
    end,
}

UITransform.Metadata.__create = function(InputTransform, Ent)
    local Rotation = InputTransform and InputTransform.Rotation or 0

    local PosTable = InputTransform and InputTransform.Position
    local SizeTable = InputTransform and InputTransform.Size

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
        [Pointers.Owner] = Ent,
        [Pointers.HasDrawable] = InputTransform and InputTransform.__HasUIElement or nil,
    }

    setmetatable(Data, Mt)
    Methods.RebuildMatrix(Data)

    return Data
end

UITransform.Metadata.__remove = function(self, _, Forced)
    if self[Pointers.HasDrawable] and not Forced then
        AstralEngine.Error("CANNOT REMOVE UITRANSFORM COMPONENT WHILST HAVING A DEPENDENT COMPONENT!", "VENEER", 3)
    end
    for i in pairs(self) do
        self[i] = nil
    end
    setmetatable(self, nil)
end

return UITransform
