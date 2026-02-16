local Sig = AstralEngine.Plugins.SignalLib
local Component = GetService("Component")
local Renderer = GetService("Renderer")
local UIRoot = {}

UIRoot.Name = "UIRoot"
UIRoot.Metadata = {}

-- bind rebuild
GetService("Entity").OnAncestryChanged:Connect(function(...)
    local i = 1
    local n = select("#", ...)
    while i <= n do
        local _, Child, _ = select(i, ...)

        local Transform = Child and Child:GetComponent("UIRoot")
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
    ZIndex = 10,
    EffectiveZIndex = 11,
    FuncId = 12,
    ClipDescendantInstances = 13,
    __ClipDepth = 14,
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

    local ParentTransform = Parent and Parent:GetComponent("UIRoot")
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
                "Cannot rebuild UIRoot Matrix! No 'Ancestry' component found on entity! Invalidating matrix!",
                "warn",
                "VENEER"
            )
            self[Pointers.Matrix][4] = 1
            return
        end

        local Mat = self[Pointers.Matrix]
        local OldMatrix = mat4(Mat)

        local AncestorPosition = vec2(AncestorTransform:getPosition())
        local AncestorSize = vec2(AncestorTransform:getScale())

        -- pixel sizes
        local Size_Vec2Total = self[Pointers.ScaleSize] * AncestorSize + self[Pointers.OffsetSize]
        local Pos_Vec2Total = self[Pointers.ScalePosition] * AncestorSize
            + self[Pointers.OffsetPosition]
            + AncestorPosition

        -- anchor

        local AnchorOffset = Size_Vec2Total * self[Pointers.AnchorPoint]
        local HalfSize = Size_Vec2Total * CenterVec
        local CenterAdjustmentAnchor = AnchorOffset - HalfSize

        Pos_Vec2Total = Pos_Vec2Total + CenterAdjustmentAnchor

        -- quat

        local Rot = self[Pointers.Rotation]
        StorageQuat:setEuler(0, 0, math.rad(Rot))

        --Mat:set(vec3(Pos_Vec2Total.x, Pos_Vec2Total.y, 0), vec3(Size_Vec2Total.x, Size_Vec2Total.y, 0), StorageQuat)
        Mat:identity()
        Mat:translate(Pos_Vec2Total.x, Pos_Vec2Total.y, 0)
        Mat:translate(CenterAdjustmentAnchor.x, CenterAdjustmentAnchor.y, 0)
        Mat:rotate(StorageQuat)
        Mat:translate(-CenterAdjustmentAnchor.x, -CenterAdjustmentAnchor.y, 0)
        Mat:scale(Size_Vec2Total.x, Size_Vec2Total.y, 1)

        if not Mat:equals(OldMatrix) then
            -- new matrix set! propagate!
            local SelfAncestry = Component.HasComponent(self[Pointers.Owner], "Ancestry")
            for Child in SelfAncestry:IterChildren() do
                local ChildUIRoot = Child:GetComponent("UIRoot")
                if ChildUIRoot then
                    ChildUIRoot:RebuildMatrix(Mat)
                end
            end
        end
    end,
    RequestChainRebuild = function(self)
        local Ancestry = Component.HasComponent(self[Pointers.Owner], "Ancestry")

        local CameraUI = Ancestry:FindFirstAncestorWithComponent("UICamera")
        if CameraUI then
            CameraUI.UICamera:RebuildRenderChain()
        end
    end,
    ContainsPoint = function(self, V1, V2)
        local ContSelf = self:ContainsPointIndividual(V1, V2)

        if not ContSelf then
            return false
        end

        local ClippingParents = self[14]
        if ClippingParents <= 0 then
            return true
        end

        local CurClip = 0
        local Ancestry = Component.HasComponent(self[8], "Ancestry")

        if not Ancestry then
            return false
        end

        while Ancestry and CurClip < ClippingParents do
            local Parent = Ancestry.Parent
            if not Parent then
                return false
            end -- ret false cause it means ClipDepth is invalid

            local ParentTransform = Parent:GetComponent("UIRoot")
            if ParentTransform and ParentTransform[13] then
                if not ParentTransform:ContainsPointIndividual(V1, V2) then
                    return false
                end
                CurClip = CurClip + 1
            end

            Ancestry = Parent:GetComponent("Ancestry")
        end

        return true -- no clipping, gg
    end,
    ContainsPointIndividual = function(self, V1, V2)
        local x, y
        if type(V1) == "number" then
            x, y = V1, V2
        else
            x, y = V1:unpack()
        end

        local vec = vec4(x, y, 0, 1)

        local Matrix = self[1]
        if Matrix[4] == 1 then
            return false
        end
        local InvMatrix = mat4(Matrix):invert()

        local LocalPoint = InvMatrix:mul(vec)

        local Width, Height = Matrix:getScale()

        local HalfW = Width * 0.5
        local HalfH = Height * 0.5

        return math.abs(LocalPoint.x) <= 0.5 and math.abs(LocalPoint.y) <= 0.5
    end,
}

local Mt = {
    __index = function(self, k)
        local Ptr = Pointers[k]

        if Ptr then
            if Ptr == Pointers.Matrix then
                return mat4(self[Ptr])
            elseif
                Ptr == Pointers.Rotation
                or Ptr == Pointers.ZIndex
                or Ptr == Pointers.EffectiveZIndex
                or Ptr == Pointers.ClipDescendantInstances
                or Ptr == Pointers.__ClipDepth
            then
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

            if Val == Pointers.Rotation or Val == Pointers.EffectiveZIndex or Val == Pointers.__ClipDepth then
                self[Val] = v
            elseif Val == Pointers.Matrix then
                self[Val]:set(v)
                return
            elseif Val == Pointers.ClipDescendantInstances then
                self[Val] = v
                self:RequestChainRebuild()
            elseif k == "__HasUIElement" then
                local Cur = self[Pointers.HasDrawable]

                if Cur and not v then
                    self[Pointers.HasDrawable] = v
                    self:RequestChainRebuild()
                elseif not Cur and v then
                    self[Pointers.HasDrawable] = v

                    local Translated = Renderer.VeneerUI.GetStackIdFromName(v)
                    if Translated then
                        self[Pointers.FuncId] = Translated
                    end

                    self:RequestChainRebuild()
                elseif Cur and v then
                    AstralEngine.Error("CANNOT SET SEVERAL DRAWABLE ELEMENTS ONTO ONE UI ENTITY", "VENEER", 3)
                end
            elseif Val == Pointers.ZIndex then
                local Diff = v - self[Pointers.ZIndex]
                self[Pointers.EffectiveZIndex] = self[Pointers.EffectiveZIndex] + Diff

                self:RequestChainRebuild()
            else
                self[Val]:set(v)
            end

            Methods.RebuildMatrix(self)
        end
    end,
}

UIRoot.Metadata.__create = function(InputTransform, Ent)
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
        [Pointers.ZIndex] = InputTransform and InputTransform.ZIndex or 1,
        [Pointers.EffectiveZIndex] = -1,
        [Pointers.FuncId] = Renderer.VeneerUI.GetStackIdFromName(
            InputTransform and InputTransform.__HasUIElement or nil
        ),
        [Pointers.ClipDescendantInstances] = InputTransform and InputTransform.ClipDescendantInstances or false,
        [Pointers.__ClipDepth] = 0,
    }

    -- set signals

    local Type = Sig.Type.NoCtx | Sig.Type.Default
    Data.MouseEnter = Sig.new(Type)
    Data.MouseLeave = Sig.new(Type)
    Data.MouseButton = Sig.new(Type)
    Data.MouseScroll = Sig.new(Type)
    Data.Hovering = false

    -- meta

    setmetatable(Data, Mt)
    Data[Pointers.Matrix][4] = 1

    return Data
end

UIRoot.Metadata.__remove = function(self, _, Forced)
    if self[Pointers.HasDrawable] and not Forced then
        AstralEngine.Error("CANNOT REMOVE UIROOT COMPONENT WHILST HAVING A DEPENDENT COMPONENT!", "VENEER", 3)
    end

    self.MouseEnter:Destroy()
    self.MouseLeave:Destroy()
    self.MouseButton:Destroy()
    self.MouseScroll:Destroy()

    for i in pairs(self) do
        self[i] = nil
    end
    setmetatable(self, nil)
end

return UIRoot
