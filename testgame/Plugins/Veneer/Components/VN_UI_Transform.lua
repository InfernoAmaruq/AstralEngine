local Component = GetService("Component")
local UITransform = {}

UITransform.Name = "UITransform"
UITransform.Metadata = {}

-- bind rebuil
GetService("Entity").OnAncestryChanged:Connect(function(...)
    local i = 1
    local n = select("#", ...)
    while i <= n do
        local _, Child, _ = select(i, ...)

        local Transform = Child and Child:GetComponent("UITransform")
        if Transform then
            Transform:RebuildMatrix()
        end

        i = i + 3
    end
end)

local Pointers = {
    Matrix = 1,
    ScalePosition = 2,
    OffsetPosition = 3,
    Rotation = 4,
    ScaleSize = 5,
    OffsetSize = 6,
    AnchorPoint = 7,
    Owner = 8,
    HasDrawable = 9, -- string value telling if it has or does not have another Drawable in the same entity
}

local StorageQuat = Quat()
local CenterVec = Vec2(0.5, 0.5)

local function ResolveAncestorSize(self)
    local SelfEntity = self[Pointers.Owner]
    local SelfAncestry = Component.HasComponent(SelfEntity, "Ancestry")

    if not SelfAncestry then
        return nil
    end

    local Parent = SelfAncestry.Parent

    local ParentTransform = Parent and Parent:GetComponent("UITransform")
    local ParentUICam = Parent and Parent:GetComponent("UICamera")
    if ParentTransform then
        return ParentTransform.Matrix
    elseif ParentUICam then
        local Res = ParentUICam.Resolution
        return mat4(vec3(), vec3(Res.x, Res.y, 1), quat())
    end
end

local Methods = {
    RebuildMatrix = function(self, AncestorTransform)
        AncestorTransform = AncestorTransform or ResolveAncestorSize(self)

        if not AncestorTransform then
            AstralEngine.Log(
                "Cannot rebuild UITransform Matrix! No 'Ancestry' component found on entity! Invalidating matrix!",
                "warn",
                "VENEER"
            )
            self[Pointers.Matrix][4] = 1
            return
        end

        local Mat = self[Pointers.Matrix]
        local OldMatrix = mat4(Mat)

        local AncestorPosition = AncestorTransform:getPosition()
        local AncestorSize = AncestorTransform:getScale()
        local Orientation = AncestorTransform:getOrientation()

        -- pixel sizes
        local Size_Vec2Total = self[Pointers.ScaleSize] * AncestorSize + self[Pointers.OffsetSize]
        local Pos_Vec2Total = self[Pointers.ScalePosition] * AncestorSize
            + self[Pointers.OffsetPosition]
            + AncestorPosition

        if Pointers.AnchorPoint ~= CenterVec then
            -- now apply anchor point
            local AdditonalOffset = Size_Vec2Total * self[Pointers.AnchorPoint] -- pixel size offset

            local HalfSize = Size_Vec2Total * CenterVec                -- half-size because our renderer draws it centerd

            Pos_Vec2Total = Pos_Vec2Total - HalfSize + AdditonalOffset
        end
        -- quat
        StorageQuat:setEuler(0, 0, math.rad(self[Pointers.Rotation]))

        --Mat:set(vec3(Pos_Vec2Total.x, Pos_Vec2Total.y, 0), vec3(Size_Vec2Total.x, Size_Vec2Total.y, 0), StorageQuat)
        Mat:identity()
        Mat:translate(Pos_Vec2Total.x, Pos_Vec2Total.y, 0)
        Mat:rotate(StorageQuat)
        Mat:rotate(Orientation)
        Mat:scale(Size_Vec2Total.x, Size_Vec2Total.y, 1)
        Mat[4] = 0

        if not Mat:equals(OldMatrix) then
            -- new matrix set! propagate!
            local SelfAncestry = Component.HasComponent(self[Pointers.Owner], "Ancestry")
            for Child in SelfAncestry:IterChildren() do
                local ChildUITransform = Child:HasComponent("UITransform")
                if ChildUITransform then
                    ChildUITransform:RebuildMatrix(Mat)
                end
            end
        end
    end,
    Set = function(self, Transform) end,
}

local Mt = {
    __index = function(self, k)
        local Ptr = Pointers[k]

        if Ptr then
            if Ptr == Pointers.Matrix then
                return mat4(self[Ptr])
            elseif Ptr == Pointers.Rotation then
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

    local Size_Scale, Size_Offset = Vec2(), Vec2(100, 100)
    local Pos_Scale, Pos_Offset = Vec2(), Vec2()
    local AnchorPoint = Vec2()

    if SizeTable then
        Size_Scale:set(SizeTable.Scale or ZeroTwo)
        Size_Offset:set(SizeTable.Offset or vec2(100, 100))
    end
    if PosTable then
        Pos_Scale:set(PosTable.Scale or ZeroTwo)
        Pos_Offset:set(PosTable.Offset or ZeroTwo)
    end
    if InputTransform and InputTransform.AnchorPoint then
        AnchorPoint:set(InputTransform.AnchorPoint)
    end

    local Matrix = Mat4()

    local Data = {
        [Pointers.Matrix] = Matrix,
        [Pointers.OffsetPosition] = Pos_Offset,
        [Pointers.OffsetSize] = Size_Offset,
        [Pointers.Rotation] = Rotation,
        [Pointers.ScalePosition] = Pos_Scale,
        [Pointers.ScaleSize] = Size_Scale,
        [Pointers.AnchorPoint] = AnchorPoint,
        [Pointers.Owner] = Ent,
        [Pointers.HasDrawable] = InputTransform and InputTransform.__HasUIElement or nil,
    }

    setmetatable(Data, Mt)
    Data[Pointers.Matrix][4] = 1

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
