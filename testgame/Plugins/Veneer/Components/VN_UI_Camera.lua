local RenderService = GetService("Renderer")
local ComponentService = GetService("Component")

local UICam = {}

UICam.Name = "UICamera"

UICam.Metadata = {}

local ToRebuild = {}

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
}
local Getters = {
    Resolution = function(self)
        return vec2(self[6])
    end,
}
local Setters = {}
local Methods = {
    RebuildProjectionMatrix = function(self)
        local CurMatrix = self[5] or Mat4()

        CurMatrix:orthographic(0, self.Resolution.x, 0, self.Resolution.y, -100, 100)

        self[5] = CurMatrix
    end,
    RebuildRenderChain = function(self)
        print("rebuild")
        local Ancestry = AstralEngine.Assert(
            ComponentService.HasComponent(self.__Entity, "Ancestry"),
            "CANNOT REBUILD UI RENDER CHAIN! Ancestry COMPONENT MISSING",
            "VENEER"
        )

        self[7] = {}         -- reallocate
        local Queue = { Ancestry } -- start with own Ancestry. Cascade down, breadth wise

        while #Queue > 0 do
            local CurAnc = table.remove(Queue, 1)

            for Child in CurAnc:IterChildren() do
                print("CASCADE:", Child)
            end
        end
    end,
    Rebuild = function(self)
        self[7] = {} -- invalidate old one. I'd usually clear but re-alloc cost is amortized
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

    if DepthType == "boolean" then
        DepthTex = AstralEngine.Graphics.NewTexture(
            IOTexture:getWidth(),
            IOTexture:getHeight(),
            { format = "d32f", mipmaps = false, label = "VENEER_UI_TEXTURE_DEPTH" }
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
    Data.ResizeWithInputTexture = Input.ResizeWithInputTexture == nil and true or Input.ResizeWithInputTexture
    Data.__Entity = Entity

    RenderService.VeneerUI.BindUICamera(Data, Input.Priority)

    setmetatable(Data, MT)

    Methods.RebuildProjectionMatrix(Data)

    return Data
end

UICam.Metadata.__remove = function(self, Entity) end

return UICam
