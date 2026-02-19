local RenderService = GetService("Renderer")
local ComponentService = GetService("Component")
local Entity = GetService("Entity")

local UICam = {}

UICam.Name = "UICamera"

UICam.Metadata = {}

local TotalCameraEntities = {}

-- PROCESSING INPUT

-- FLAME: NTS: RE-QUERY ENTERS ON REBUILD!
-- INVALIDATE ON TRANSFORM CHANGE?
local IS = GetService("InputService")
local UserMouse = IS.GetMouse()

local function QueryHover(x, y)
    for _, v in ipairs(TotalCameraEntities) do
        local UICamComp = ComponentService.HasComponent(v, "UICamera")
        if UICamComp.ProcessInputs then
            for _, Object in ipairs(UICamComp[7]) do
                local UIRoot = ComponentService.HasComponent(Object, "UIRoot")
                local HasListeners = UIRoot.MouseEnter:GetListenerCount() > 0
                    or UIRoot.MouseLeave:GetListenerCount() > 0
                if UIRoot.Hovering == false and HasListeners then
                    local HasPoint = UIRoot:ContainsPoint(x, y)
                    if HasPoint then
                        UIRoot.MouseEnter:Fire(x, y)
                        UIRoot.Hovering = true
                        UIRoot.__LastHoverPoint:set(x, y)
                    end
                elseif UIRoot.Hovering and HasListeners then
                    local HasPoint = UIRoot:ContainsPoint(x, y)
                    if not HasPoint then
                        UIRoot.MouseLeave:Fire(x, y)
                        UIRoot.Hovering = false
                        UIRoot.__LastHoverPoint:set(-1, -1)
                    end
                end
            end
        end
    end
end

UserMouse.MouseMoved:Connect(QueryHover)

local function GetMouseInpFunc(Event)
    return function(b, x, y)
        for _, v in ipairs(TotalCameraEntities) do
            local UICamComp = ComponentService.HasComponent(v, "UICamera")
            if UICamComp.ProcessInputs then
                for _, Object in ipairs(UICamComp[7]) do
                    local UIRoot = ComponentService.HasComponent(Object, "UIRoot")
                    if
                        UIRoot.MouseButton:GetListenerCount() > 0 and (UIRoot.Hovering and UIRoot:ContainsPoint(x, y))
                    then
                        UIRoot.MouseButton:Fire(Event, b, x, y)
                    end
                end
            end
        end
    end
end

UserMouse.MouseButtonDown:Connect(GetMouseInpFunc(true))
UserMouse.MouseButtonUp:Connect(GetMouseInpFunc(false))
UserMouse.WheelMoved:Connect(function(dx, dy, a, b)
    for _, v in ipairs(TotalCameraEntities) do
        local UICamComp = ComponentService.HasComponent(v, "UICamera")
        if UICamComp.ProcessInputs then
            for _, Object in ipairs(UICamComp[7]) do
                local UIRoot = ComponentService.HasComponent(Object, "UIRoot")
                if
                    UIRoot.MouseScroll:GetListenerCount() > 0
                    and (UIRoot.Hovering or UIRoot:ContainsPoint(UserMouse.GetPosition()))
                then
                    UIRoot.MouseScroll:Fire(dx, dy)
                end
            end
        end
    end
end)

-- PROCESSING CAMERA

local ToRebuild = {}

local function SortMethod(a, b)
    -- we using IDs here so...
    local ObjA, ObjB = Entity.GetEntityFromId(a), Entity.GetEntityFromId(b)

    return ObjA.UIRoot.EffectiveZIndex < ObjB.UIRoot.EffectiveZIndex
end

GetService("Entity").OnAncestryChanged:Connect(function(...)
    local i = 1
    local n = select("#", ...)
    while i <= n do
        for LocalI = 0, 1 do
            local Object = select(i + LocalI, ...)
            local HasEntityWithUICamera = Object
                and Object:GetComponent("Ancestry"):FindFirstAncestorWithComponent("UICamera")
            if HasEntityWithUICamera then
                ToRebuild[HasEntityWithUICamera:GetComponent("UICamera")] = true
            end
        end

        i = i + 3
    end

    for Ent in pairs(ToRebuild) do
        ToRebuild[Ent] = nil
        Ent:RebuildRenderChain()
    end
end)

local IdxGetter = {
    Texture = 2,
    DepthTexture = 3,
    ZIndex = 8,
}
local Getters = {
    Resolution = function(self)
        return vec2(self[6])
    end,
}
local Setters = {
    ZIndex = function(self, v)
        self[8] = v
        self:RebuildRenderChain()
    end,
}
local Methods = {
    RebuildProjectionMatrix = function(self)
        local CurMatrix = self[5] or Mat4()

        CurMatrix:orthographic(0, self.Resolution.x, 0, self.Resolution.y, -100, 100)

        self[5] = CurMatrix
    end,
    RebuildRenderChain = function(self)
        AstralEngine.Assert(
            ComponentService.HasComponent(self.__Entity, "Ancestry"),
            "CANNOT REBUILD UI RENDER CHAIN! Ancestry COMPONENT MISSING",
            "VENEER"
        )

        self[7] = {}

        local SelfEnt = Entity.GetEntityFromId(self.__Entity)
        local ZIndex = self[8]
        local Stack = { SelfEnt }

        while #Stack > 0 do
            local Top = table.remove(Stack)

            local OwnTransform = Top:GetComponent("UIRoot")
            local OwnIndex = OwnTransform and OwnTransform.EffectiveZIndex
            local ParentClipDepth = OwnTransform and OwnTransform.__ClipDepth or 0

            local ToClip = false
            if OwnTransform and OwnTransform.ClipDescendantInstances then
                ToClip = true
                ParentClipDepth = ParentClipDepth + 1
                OwnTransform.__ClipDepth = ParentClipDepth
            end

            for Child in Top.Ancestry:IterChildren() do
                local UIRoot = Child:GetComponent("UIRoot")

                if UIRoot and UIRoot.__HasUIElement then
                    if ToClip or ParentClipDepth > 0 then
                        local ClipDepth = ParentClipDepth
                        UIRoot.__ClipDepth = ClipDepth
                    else
                        UIRoot.__ClipDepth = 0
                    end

                    UIRoot.EffectiveZIndex = (OwnIndex or ZIndex) + UIRoot.ZIndex
                    table.insert(self[7], Child.Id)
                    table.insert(Stack, Child)
                end
            end
        end

        table.sort(self[7], SortMethod)
        if self.ProcessInputs then
            QueryHover(UserMouse.GetPosition())
        end
    end,
}

local MT = {
    __index = function(self, k)
        if Methods[k] then
            return Methods[k]
        end
        if Getters[k] then
            return Getters[k](self)
        end
        if IdxGetter[k] then
            return self[IdxGetter[k]]
        end
    end,
    __newindex = function(self, k, v)
        if Setters[k] then
            Setters[k](self, v)
        end
    end,
}

UICam.Metadata.__create = function(Input, Entity, Skip)
    local Data = {}

    if not Skip and not ComponentService.HasComponent(Entity, "Ancestry") then
        ComponentService.AddComponent(Entity, "Ancestry")
    end

    local IOTexture = Input.OutputTexture

    local DoDepth = Input.Depth
    local DepthType = typeof(DoDepth)

    if DepthType == "nil" then
        DoDepth = true
        DepthType = "boolean"
    end

    local CamPtr

    if Input.Camera then
        -- construct from camera
        CamPtr = Input.Camera
        local TypeOf = typeof(CamPtr)

        if TypeOf == "Entity" then
            CamPtr = AstralEngine.Assert(
                CamPtr:GetComponent("Camera"),
                "PROVIDED ENTITY WITHOUT `Camera` COMPONENT",
                "VENEER"
            )
        elseif TypeOf == "Component" and tostring(CamPtr) == "Camera" then
            CamPtr = CamPtr
        else
            AstralEngine.Error("INVALID `Camera` PARAMETER PASSED!", "VENEER", 3)
        end

        -- we got camera, alloc texture

        local TrueResolution = CamPtr.TrueResolution

        IOTexture = AstralEngine.Graphics.NewTexture(
            TrueResolution.x,
            TrueResolution.y,
            { label = "VENEER_UI_TEXTURE", mipmaps = Input.Mipmaps or false }
        )
    else -- construct tex
        -- alloc source tex
        if not IOTexture then
            local OutputResolution = Input.OutputResolution
                or (vec2(AstralEngine.Window.W, AstralEngine.Window.H) * AstralEngine.Window.GetWindowDensity())
            IOTexture = AstralEngine.Graphics.NewTexture(
                OutputResolution.x,
                OutputResolution.y,
                { label = "VENEER_UI_TEXTURE", mipmaps = Input.Mipmaps or false }
            )
        end
    end -- finish construct

    -- alloc depth
    local DepthTex

    if DepthType == "boolean" and DepthType then
        DepthTex = AstralEngine.Graphics.NewTexture(
            IOTexture:getWidth(),
            IOTexture:getHeight(),
            { format = "d32fs8", mipmaps = false, label = "VENEER_UI_TEXTURE_DEPTH" }
        ) -- use safe tex so the UI is fine with resizes
    elseif DepthType == "Texture" then
        DepthTex = DoDepth
        AstralEngine.Assert(DepthTex:getFormat():find("d"), "INVALID TEXTURE FORMAT PASSED TO UI TEXTURE", "VENEER")
        AstralEngine.Assert(
            vec3(DepthTex:getDimensions()) == vec3(IOTexture:getDimensions()),
            "INVALID DEPTH TEXTURE SIZE PASSED TO UI TEXTURE",
            "VENEER"
        )
    end

    local Pass = AstralEngine.Graphics.NewRawPass({
        (IOTexture[1] or IOTexture),
        depth = DepthTex and {
            texture = (DepthTex[1] or DepthTex),
        } or false,
        samples = 1,
    })

    Pass:setClear({ 0, 0, 0, 0 })

    local ResVec = Vec2(IOTexture:getWidth(), IOTexture:getHeight())

    Data[1] = Pass
    Data[2] = IOTexture
    Data[3] = DepthTex
    Data[4] = CamPtr or false
    Data[5] = Mat4() -- proj matrix
    Data[6] = ResVec
    Data[7] = {}  -- UIChain
    Data[8] = Input.ZIndex or 0
    Data.ResizeWithInputTexture = Input.ResizeWithInputTexture == nil and true or Input.ResizeWithInputTexture
    Data.__Entity = Entity
    Data.ProcessInputs = Input.ProcessInputs

    RenderService.VeneerUI.BindUICamera(Data, Input.Priority)

    setmetatable(Data, MT)

    Methods.RebuildProjectionMatrix(Data)

    table.insert(TotalCameraEntities, Entity)

    return Data
end

UICam.Metadata.__remove = function(self, Ent)
    RenderService.VeneerUI.UnbindUICamera(self)
    table.remove(TotalCameraEntities, table.find(TotalCameraEntities, Ent))
end

UICam.FinalProcessing = function()
    if ComponentService.AncestryRequired then
        table.insert(ComponentService.AncestryRequired, UICam.Name)
    end
end

return UICam
