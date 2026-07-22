-- IMPORTS

local Renderer = GetService("Renderer")
local Component = GetService("Component")

-- CONSTANTS

local PASS_PRIORITY_GEOM = 10000
local PASS_PRIORITY_COMMIT = 10100

local FIRST_TEXTURE = 1
local FINAL_TEXTURE

local TEX_DATA_CAMERA_TEXTURE = { samples = 1, usage = { "render", "sample" }, mipmaps = false, format = "rgba8" }

local TEX_DATA_OIT = { format = "rg16f", samples = 4, usage = { "render", "sample" }, mipmaps = false }
local TEX_DATA_DEPTH = { format = "d32f", samples = 4, usage = { "render", "sample" }, mipmaps = false, linear = true }

local TEX_DATA_MSAA = { samples = 4, usage = { "render", "sample" }, mipmaps = false, format = "rgba8" }

local TEX_DATA_AO = { format = "r16", usage = { "render", "sample" }, mipmaps = false, samples = 1 }

local CAMERA_PROJECTION = Enum({
    Perspective = 1,
    Orthographic = 2,
    Other = 3,
}, "CameraProjectionType")

-- DEFINITION

local Camera = {
    Name = "Camera",
    Metadata = {},
}

local Indexes = {
    TextureCamera = 1,

    TextureTransparent = 3,
    TextureSolid = 5,
    TextureReveal = 7,

    TextureDepth = 9,
    TextureNormal = 11,

    TextureComposite = 13,
    TextureAO = 15,
    TextureBloomExtract = 17,

    TextureBlurBloom1 = 19,
    TextureBlurBloom2 = 21,
    TextureBlurAO1 = 23,
    TextureBlurAO2 = 25,
    TextureBlurColor1 = 27,
    TextureBlurColor2 = 29,

    PassMain = 31,
    PassSolid = 32,
    PassTransparent = 33,
    PassComposite = 34,
    PassBlur1 = 35,
    PassBlur2 = 36,

    ProjectionMatrix = 37,
    FieldOfView = 38,
    Far = 39,
    Near = 40,
    Width = 41,
    Height = 42,
    ProjectionType = 43,

    BackfaceCulling = 44,
    ViewCulling = 45,
    NearestSampler = 46,

    RebuildCallback = 47,
}

local function RawViewToRay(self, Vector) end

local function RawWorldToview(self, Pos) end

local function RebuildTextures(self, w, h, d)
    d = d or AstralEngine.Window.GetWindowDensity()

    w = w * d
    h = h * d

    local NewTex = AstralEngine.Graphics.NewTexture

    for i = FIRST_TEXTURE, FINAL_TEXTURE, 2 do
        self[i]:release()
        self[i] = NewTex(w, h, self[i + 1]) -- our texture config is kept at i + 1 always
    end

    local Canvas = { samples = 1, depth = false }

    -- misc canvases
    Canvas[1] = self[1]
    self[31]:setCanvas(Canvas)

    Canvas[1], Canvas[2], Canvas[3] = self[13], self[15], self[17]
    self[34]:setCanvas(Canvas)
    Canvas[1], Canvas[2], Canvas[3] = self[19], self[21], self[23]
    self[35]:setCanvas(Canvas)
    Canvas[1], Canvas[2], Canvas[3] = self[25], self[27], self[29]
    self[36]:setCanvas(Canvas)

    -- geometry canvases
    Canvas.samples = 4
    Canvas.depth = self[9]
    Canvas[3] = nil

    Canvas[1], Canvas[2] = self[5], self[11]
    self[32]:setCanvas(Canvas)
    Canvas[1], Canvas[2] = self[3], self[7]
    self[33]:setCanvas(Canvas)

    self[41], self[42] = w, h

    if self[43] ~= CAMERA_PROJECTION.Other then
        self:ReconstructProjectionMatrix()
    end
end

local Methods = {
    Resize = function(self, w, h, d)
        if self[47] then
            self[47](self, w, h, d)
        end
    end,

    ScreenPointToRay = function(self, V1, V2) end,
    ViewpointToRay = function(self, V1, V2) end,

    WorldToViewpoint = function(self, Pos) end,
    WorldToScreenPoint = function(self, Pos) end,

    ReconstructProjectionMatrix = function(self)
        local Type = self[43]

        if Type == CAMERA_PROJECTION.Other then
            return
        end

        local CurrentMatrix = self[37]
        local Far, Near, W, H = self[39], self[40], self[41], self[42]

        if Type == CAMERA_PROJECTION.Perspective then
            local FOV = math.rad(self[38])
            local Aspect = W / H
            CurrentMatrix:perspective(FOV, Aspect, Near, Far)
        else
            local HalfRes = vec2(W, H):div(2)
            CurrentMatrix:orthographic(-HalfRes.x, HalfRes.x, -HalfRes.y, HalfRes.y, Far == 0 and 1000000 or Far, Near)
        end
    end,
}

local Metatable = {
    __index = function(self, k)
        local Key = Indexes[k]

        if Key then
            if k == "ProjectionMatrix" then
                return mat4(self[Key])
            else
                return self[Key]
            end
        elseif Key == "Resolution" then
            return vec2(self[41], self[42])
        elseif Key == "Aspect" then
            return self[41] / self[42]
        elseif k == "IsPrimary" then
            return Renderer.GetPrimaryCamera() == self
        else
            return Methods[k]
        end
    end,
    __newindex = function(self, k, v)
        local Key = Indexes[k]

        print("WRITE TO:", Key, k)

        if Key then
            if k == "ProjectionMatrix" then
                self[Key]:set(v)
            elseif k == "IsPrimary" then
                Renderer.SetPrimaryCamera(v and self or nil)
            elseif Key > Indexes.ProjectionMatrix and Key <= Indexes.ProjectionType then
                rawset(self, Key, v)
                print("SET NEW CAM FIELD")
                if self[Indexes.ProjectionType] ~= CAMERA_PROJECTION.Other then
                    print("UPD MAT")
                    Methods.ReconstructProjectionMatrix(self)
                end
            else
                rawset(self, Key, v or false)
            end
        end
    end,
}

local function GetTexture(Table, W, H, Config, Key)
    local Texture = AstralEngine.Graphics.NewTexture(W, H, Config)
    Table[Key] = Texture
    Table[Key + 1] = Config

    return Texture
end

local Temp = {} -- temp table we use so we can write hash keys here and convert to index later

local EventBound = false

Camera.Metadata.__create = function(Input, Entity, Sink)
    if not EventBound then
        AstralEngine.Signals.OnWindowResize:Connect(function(w, h, d)
            d = d or AstralEngine.Window.GetWindowDensity()

            for _, v in pairs(Component.Components.Camera.Storage) do
                if v[47] then
                    v[47](v, w, h, d)
                end
            end
        end)

        EventBound = true
    end

    if not Sink and not Component.GetComponent(Entity, "Transform") then
        Component.AddComponent(Entity, "Transform")
    end

    local self = table.new(47, 0)

    local W, H = (Input.Resolution or vec2(AstralEngine.Window.GetWindowDimensions())):unpack()
    local Density = AstralEngine.Window.GetWindowDensity()

    W, H = W * Density, H * Density

    -- // ALLOCATE TEXTURES
    local CameraTexture = GetTexture(self, W, H, TEX_DATA_CAMERA_TEXTURE, Indexes.TextureCamera)

    local OIT_Transparent = GetTexture(self, W, H, TEX_DATA_MSAA, Indexes.TextureTransparent)
    local OIT_Solid = GetTexture(self, W, H, TEX_DATA_MSAA, Indexes.TextureSolid)
    local OIT_Reveal = GetTexture(self, W, H, TEX_DATA_OIT, Indexes.TextureReveal)

    local DepthTexture = GetTexture(self, W, H, TEX_DATA_DEPTH, Indexes.TextureDepth)
    local NormalTexture = GetTexture(self, W, H, TEX_DATA_MSAA, Indexes.TextureNormal)

    local CompositeTexture = GetTexture(self, W, H, TEX_DATA_CAMERA_TEXTURE, Indexes.TextureComposite)

    local AOTexture = GetTexture(self, W, H, TEX_DATA_AO, Indexes.TextureAO)
    local BloomExtract = GetTexture(self, W, H, TEX_DATA_CAMERA_TEXTURE, Indexes.TextureBloomExtract)

    local Blurred_Bloom_1 = GetTexture(self, W, H, TEX_DATA_CAMERA_TEXTURE, Indexes.TextureBlurBloom1)
    local Blurred_Bloom_2 = GetTexture(self, W, H, TEX_DATA_CAMERA_TEXTURE, Indexes.TextureBlurBloom2)
    local Blurred_AO_1 = GetTexture(self, W, H, TEX_DATA_AO, Indexes.TextureBlurAO1)
    local Blurred_AO_2 = GetTexture(self, W, H, TEX_DATA_AO, Indexes.TextureBlurAO2)
    local Blurred_Color_1 = GetTexture(self, W, H, TEX_DATA_CAMERA_TEXTURE, Indexes.TextureBlurColor1)
    local Blurred_Color_2 = GetTexture(self, W, H, TEX_DATA_CAMERA_TEXTURE, Indexes.TextureBlurColor2)

    -- In the self table textures are stored as a tuple (Texture, TEX_DATA*)

    if not FINAL_TEXTURE then
        FINAL_TEXTURE = #self - 1
    end -- Last texture, ignoring its config. We can use this for rebuilds to skip indexing cost

    -- // ALLOCATE PASSES

    local CameraPass = AstralEngine.Graphics.NewPass({ CameraTexture, samples = 1, depth = false })

    local OIT_SolidPass = AstralEngine.Graphics.NewPass({ OIT_Solid, NormalTexture, depth = DepthTexture, samples = 4 })
    local OIT_TransparentPass =
        AstralEngine.Graphics.NewPass({ OIT_Transparent, OIT_Reveal, depth = DepthTexture, samples = 4 })
    OIT_TransparentPass:setClear({ { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, depth = false }) -- do not clear depth, we wanna reuse depth from solid pass

    local CompositePass =
        AstralEngine.Graphics.NewPass({ CompositeTexture, AOTexture, BloomExtract, samples = 1, depth = false })

    local BlurPassH =
        AstralEngine.Graphics.NewPass({ Blurred_Color_1, Blurred_AO_1, Blurred_Bloom_1, samples = 1, depth = false })
    local BlurPassV =
        AstralEngine.Graphics.NewPass({ Blurred_Color_2, Blurred_AO_2, Blurred_Bloom_2, samples = 1, depth = false })

    Temp.PassMain = CameraPass
    Temp.PassSolid = OIT_SolidPass
    Temp.PassTransparent = OIT_TransparentPass
    Temp.PassComposite = CompositePass
    Temp.PassBlur1 = BlurPassH
    Temp.PassBlur2 = BlurPassV

    --  // MISC VARIABLES

    Temp.ProjectionMatrix = Mat4(Input.ProjectionMatrix)
    Temp.Far = Input.Far or 0
    Temp.Near = Input.Near or 0.05
    Temp.FieldOfView = Input.FieldOfView or 70
    Temp.ProjectionType = Input.ProjectionType or CAMERA_PROJECTION.Perspective

    Temp.Width = W
    Temp.Height = H

    local IsPrimary = Input.IsPrimary

    if IsPrimary == nil then
        IsPrimary = not Renderer.GetPrimaryCamera()
    end

    Temp.BackfaceCulling = Input.BackfaceCulling == nil and true or Input.BackfaceCulling
    Temp.NearestSampler = Input.NearestSampler == nil and false or Input.NearestSampler
    Temp.ViewCulling = Input.ViewCulling == nil and false or Input.ViewCulling

    -- // SET REBUILDS

    Temp.RebuildCallback = Input.Rebuild or RebuildTextures

    -- // REGISTER WITH THE RENDERER

    Renderer.AddCamera(Entity)
    Renderer.PassStorage.AddPass(false, OIT_SolidPass, PASS_PRIORITY_GEOM, true)
    Renderer.PassStorage.AddPass(false, OIT_TransparentPass, PASS_PRIORITY_GEOM + 1, true)
    Renderer.PassStorage.AddPass(false, CompositePass, PASS_PRIORITY_GEOM + 10, true)
    Renderer.PassStorage.AddPass(false, BlurPassH, PASS_PRIORITY_GEOM + 13, true)
    Renderer.PassStorage.AddPass(false, BlurPassV, PASS_PRIORITY_GEOM + 16, true)
    Renderer.PassStorage.AddPass(false, CameraPass, PASS_PRIORITY_COMMIT, true)

    for i, v in pairs(Temp) do
        self[Indexes[i] or i] = v
        Temp[i] = nil
    end

    setmetatable(self, Metatable)

    if Input.ProjectionMatrix then
        self[Indexes.ProjectionType] = CAMERA_PROJECTION.Other
    else
        Methods.ReconstructProjectionMatrix(self)
    end

    if IsPrimary then
        Renderer.SetPrimaryCamera(self)
    end

    return self
end

Camera.Metadata.__remove = function() end

return Camera
