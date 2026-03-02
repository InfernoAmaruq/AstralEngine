local Sig = AstralEngine.Plugins.SignalLib
local Component = GetService("Component")
local Renderer = GetService("Renderer")
local Mouse = GetService("InputService").GetMouse()
local UIRoot = {}

UIRoot.Name = "UIRoot"
UIRoot.Metadata = {
    HardDependency = { Ancestry = true },
}

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

Component.ComponentAdded:Connect(function(Entity, ComponentName)
    local Root = Entity:GetComponent("UIRoot")
    local Metadata = Component.Components[ComponentName].Metadata
    if Root then
        if not Root.__HasUIElement and Metadata and Metadata.UIDrawableObject then
            Root.__HasUIElement = ComponentName
        elseif not Root.__HasLayoutElement and Metadata and Metadata.UILayoutObject then
            Root.__HasLayoutElement = ComponentName
        end
    end
end)
Component.ComponentRemoved:Connect(function(Entity, ComponentName)
    local Root = Entity:GetComponent("UIRoot")
    local Metadata = Component.Components[ComponentName].Metadata

    if Root then
        if Metadata.UIDrawableObject and Root.__HasUIElement then
            Root.__HasUIElement = nil
        elseif Metadata.UIDrawableObject and Root.__HasLayoutElement then
            Root.__HasLayoutElement = nil
        end
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
    __HasUIElement = 9, -- string value telling if it has or does not have another Drawable in the same entity
    ZIndex = 10,
    EffectiveZIndex = 11,
    FuncId = 12,
    ClipDescendantInstances = 13,
    __ClipDepth = 14,
    __HasLayoutElement = 15,
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
        local m = mat4(vec3(), vec3(Res.x, Res.y, 1), quat())
        return m
    end
end

local Methods = {
    __PostRebuild = function(self)
        local SelfAncestry = Component.HasComponent(self[Pointers.Owner], "Ancestry")
        local Mat = self[Pointers.Matrix]

        local HasListeners = self.MouseLeave:GetListenerCount() > 0 or self.MouseEnter:GetListenerCount() > 0
        if self.Hovering and HasListeners then
            local HasPoint = self:ContainsPoint(self.__LastHoverPoint)
            if not HasPoint then
                self.Hovering = false
                self.MouseLeave:Fire(self.__LastHoverPoint.x, self.__LastHoverPoint.y)
                self.__LastHoverPoint:set(-1, -1)
            end
        elseif not self.Hovering and HasListeners then
            local x, y = Mouse.GetPosition()
            if self:ContainsPoint(self.__LastHoverPoint) then
                self.Hovering = true
                self.MouseEnter:Fire(x, y)
                self.__LastHoverPoint:set(x, y)
            end
        end

        if self[Pointers.__HasLayoutElement] then
            Component.HasComponent(self[Pointers.Owner], self[Pointers.__HasLayoutElement]):RebuildChildren()
            -- we terminate here, because we want :RebuldChildren() of the layout element to take over here
        else
            -- new matrix set! propagate!
            for Child in SelfAncestry:IterChildren() do
                local ChildUIRoot = Child:GetComponent("UIRoot")
                if ChildUIRoot then
                    ChildUIRoot:RebuildMatrix(Mat)
                end
            end
        end
    end,
    __GetRebuildValues = function(self, AncestorTransform)
        AncestorTransform = AncestorTransform or ResolveAncestorSize(self)

        if not AncestorTransform then
            return nil
        end

        local AncestorPosition = vec2(AncestorTransform:getPosition())
        local AncestorSize = vec2(AncestorTransform:getScale())

        -- pixel sizes

        local Size_Vec2Total = self[Pointers.ScaleSize] * AncestorSize + self[Pointers.OffsetSize]

        local ProcessedAncestorPosition = vec2(
            math.max(0, AncestorPosition.x - AncestorSize.x / 2),
            math.max(0, AncestorPosition.y - AncestorSize.y / 2)
        )

        local Pos_Vec2Total = self[Pointers.ScalePosition] * AncestorSize
            + self[Pointers.OffsetPosition]
            + ProcessedAncestorPosition

        -- anchor

        local AnchorOffset = Size_Vec2Total * self[Pointers.AnchorPoint]
        local HalfSize = Size_Vec2Total * CenterVec
        local CenterAdjustmentAnchor = HalfSize - AnchorOffset

        local Rot = self[Pointers.Rotation]
        StorageQuat:setEuler(0, 0, math.rad(Rot))

        return Pos_Vec2Total, Size_Vec2Total, StorageQuat, CenterAdjustmentAnchor
    end,
    RebuildMatrix = function(self, A, B, C, D)
        local SelfAncestry = Component.HasComponent(self[Pointers.Owner], "Ancestry")
        if SelfAncestry then
            local Par = SelfAncestry.Parent
            local ParUIRoot = Par and Par:GetComponent("UIRoot")
            local ParLayout = ParUIRoot
                and ParUIRoot[Pointers.__HasLayoutElement]
                and (Par and Par:GetComponent(ParUIRoot[Pointers.__HasLayoutElement]))

            if ParLayout and not rawget(ParLayout, ".RebuildInProgress") then
                ParLayout:RebuildChildren()
                return
            end
        end

        local Pos_Vec2Total, Size_Vec2Total, Quat, CenterAdjustmentAnchor
        if A and A:type() == "Vec2" then
            Pos_Vec2Total, Size_Vec2Total, Quat, CenterAdjustmentAnchor = A, B, C, D
        else
            Pos_Vec2Total, Size_Vec2Total, Quat, CenterAdjustmentAnchor =
                self:__GetRebuildValues(A and A:type() == "Mat4" and A or nil)
        end

        local Mat = self[Pointers.Matrix]

        if not Pos_Vec2Total or not Size_Vec2Total or not Quat or not CenterAdjustmentAnchor then
            Mat[4] = 1
            return
        end

        Pos_Vec2Total = Pos_Vec2Total + CenterAdjustmentAnchor

        Mat:identity()
        Mat:translate(Pos_Vec2Total.x, Pos_Vec2Total.y, 0)
        Mat:translate(CenterAdjustmentAnchor.x, CenterAdjustmentAnchor.y, 0)
        Mat:rotate(Quat)
        Mat:translate(-CenterAdjustmentAnchor.x, -CenterAdjustmentAnchor.y, 0)
        Mat:scale(Size_Vec2Total.x, Size_Vec2Total.y, 1)

        -- now query point

        self:__PostRebuild()
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
                or Ptr == Pointers.__HasUIElement
                or Ptr == Pointers.__HasLayoutElement
            then
                return self[Ptr]
            else
                return vec2(self[Ptr])
            end
        end

        return Methods[k]
    end,
    __newindex = function(self, k, v)
        if Pointers[k] then
            local Val = Pointers[k]

            local ShouldRebuild = false

            if Val == Pointers.Rotation or Val == Pointers.EffectiveZIndex or Val == Pointers.__ClipDepth then
                self[Val] = v
                ShouldRebuild = Val == Pointers.Rotation
            elseif Val == Pointers.Matrix then
                self[Val]:set(v)
                return
            elseif Val == Pointers.ClipDescendantInstances then
                self[Val] = v
                self:RequestChainRebuild()
            elseif Val == Pointers.__HasLayoutElement then
                local Cur = self[Pointers.__HasLayoutElement]

                local Ancestry = AstralEngine.Assert(
                    Component.HasComponent(self[Pointers.Owner], "Ancestry"),
                    "NO ANCESTRY AVAILABLE! CANNOT REBUILD MATRIX",
                    "VENEER"
                )

                if Cur and not v then
                    self[Pointers.__HasLayoutElement] = false

                    -- default rebuild
                    for Child in Ancestry:IterChildren() do
                        local ChildRoot = Child:GetComponent("UIRoot")
                        if ChildRoot then
                            ChildRoot:RebuildMatrix(self[Pointers.Matrix])
                        end
                    end
                elseif not Cur and v then
                    self[Pointers.__HasLayoutElement] = v
                    -- dont really need to rebuild here, cause the Layout_Vertical will handle it
                else
                    AstralEngine.Error("CANNOT SET SEVERAL UI ELEMENTS ONTO ONE UI ENTITY", "VENEER", 3)
                end
            elseif k == "__HasUIElement" then
                local Cur = self[Pointers.__HasUIElement]

                if Cur and not v then
                    self[Pointers.__HasUIElement] = v
                    self:RequestChainRebuild()
                elseif not Cur and v then
                    self[Pointers.__HasUIElement] = v

                    local Translated = Renderer.VeneerUI.GetStackIdFromName(v)
                    self[Pointers.FuncId] = Translated

                    self:RequestChainRebuild()
                elseif Cur and v then
                    AstralEngine.Error("CANNOT SET SEVERAL DRAWABLE ELEMENTS ONTO ONE UI ENTITY", "VENEER", 3)
                end
            elseif Val == Pointers.ZIndex then
                self[Pointers.ZIndex] = v

                self:RequestChainRebuild()
            else
                ShouldRebuild = true
                self[Val]:set(v)
            end

            if not ShouldRebuild then
                return
            end

            Methods.RebuildMatrix(self)
        end
    end,
}

UIRoot.Metadata.__create = function(InputTransform, Ent)
    local Rotation = InputTransform and InputTransform.Rotation or 0

    local PosTable = InputTransform and InputTransform.Position
    local SizeTable = InputTransform and InputTransform.Size

    local Size_Scale, Size_Offset = Vec2(), Vec2()
    local Pos_Scale, Pos_Offset = Vec2(), Vec2()
    local AnchorPoint = Vec2()

    if SizeTable then
        Size_Scale:set(SizeTable.Scale or ZeroTwo)
        Size_Offset:set(SizeTable.Offset or ZeroTwo)
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
        [Pointers.__HasUIElement] = InputTransform and InputTransform.__HasUIElement or false,
        [Pointers.ZIndex] = InputTransform and InputTransform.ZIndex or 1,
        [Pointers.EffectiveZIndex] = -1,
        [Pointers.FuncId] = Renderer.VeneerUI.GetStackIdFromName(
            InputTransform and InputTransform.__HasUIElement or nil
        ),
        [Pointers.__HasLayoutElement] = false,
        [Pointers.ClipDescendantInstances] = InputTransform and InputTransform.ClipDescendantInstances or false,
        [Pointers.__ClipDepth] = 0,
    }

    Data.TransparentToStencil = InputTransform and InputTransform.TransparentToStencil or false

    -- set signals

    local Type = Sig.Type.NoCtx | Sig.Type.Default
    Data.MouseEnter = Sig.new(Type)
    Data.MouseLeave = Sig.new(Type)
    Data.MouseButton = Sig.new(Type)
    Data.MouseScroll = Sig.new(Type)
    Data.Hovering = false
    Data.__LastHoverPoint = Vec2(-1, -1)

    -- meta

    setmetatable(Data, Mt)
    Data[Pointers.Matrix][4] = 1

    return Data
end

UIRoot.Metadata.__remove = function(self, _, Forced)
    if self[Pointers.__HasUIElement] and not Forced then
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
