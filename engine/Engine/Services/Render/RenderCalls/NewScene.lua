local INSTANCING_THRESHOLD = 20

local Renderer = select(1, ...)
local Component = GetService("Component")

local mat4 = mat4

-- > LOAD SHADERS
local OITExtractRaw = GetService("ShaderService").ComposeShader(
    ENUM.ShaderType.Fragment,
    "OIT/Composite",
    { Include = { "PostProcessing/AO/SSAO", "PostProcessing/Bloom/Extract.glsl", "Fog" } }
)
local OITExtractShader = lovr.graphics.newShader("fill", OITExtractRaw)

local BlurShaderRaw = GetService("ShaderService").ComposeShader(ENUM.ShaderType.Fragment, "Camera/BlurPass")
local BlurShader = lovr.graphics.newShader("fill", BlurShaderRaw)

local FinalShaderRaw = GetService("ShaderService").ComposeShader(ENUM.ShaderType.Fragment, "Camera/Finalise")
local FinalShader = lovr.graphics.newShader("fill", FinalShaderRaw)

-- > GET PRECOMPUTED ASSETS

local SSAO_Noise_Image = lovr.data.newImage(4, 4, "rgba8")
SSAO_Noise_Image:mapPixel(function()
    local x = math.random()
    local y = math.random()
    local Unit = vec2(x, y):normalize() * 255
    return Unit.x, Unit.y
end)
local SSAO_Noise_Texture = AstralEngine.Graphics.NewRawTexture(SSAO_Noise_Image, { usage = { "sample" } })
SSAO_Noise_Image:release()

local BlurSampler = lovr.graphics.newSampler({ wrap = "clamp" })

-- > MAIN SHADER METHODS

local MainShader

-- lets cache instanced buffer formats here
local BFI_Transform, BFL_Transform
local BFI_Material, BFL_Material
local BFI_Scale, BFL_Scale

Renderer.GetMainShader = function()
    return MainShader
end

Renderer.SetMainShader = function(Shader)
    MainShader = Shader

    if not Shader:hasVariable("INSTANCE_Transform") then
        INSTANCING_THRESHOLD = math.huge -- should not instance
        return
    end

    -- now to pull formats in case they were updated!

    if BFI_Transform then
        -- override and potentially rebuild
        local New_BFI_Transform, New_BFL_Transform
        local New_BFI_Material, New_BFL_Material
        local New_BFI_Scale, New_BFL_Scale

        -- TODO
    else
        local _
        _, BFL_Transform = Shader:getBufferFormat("INSTANCE_Transform")
        _, BFL_Material = Shader:getBufferFormat("INSTANCE_Material")
        _, BFL_Scale = Shader:getBufferFormat("INSTANCE_Scale")

        BFI_Transform = "mat4"
        BFI_Material = "mat4"
        BFI_Scale = "vec3"
    end
end

-- > HANDLE RENDERING DATA
-- >> STACK
-- >>> CAMERA

local Cams = {}
local CamCount = 0
Renderer.CameraStorage = Cams

function Renderer.AddCamera(Entity)
    CamCount = CamCount + 1
    Cams[#Cams + 1] = Entity
end

function Renderer.RemoveCamera(Entity)
    local Idx
    for _, v in ipairs(Cams) do
        if v == Entity then
            Idx = v
            break
        end
    end
    if not Idx then
        return
    end
    local Last = Cams[#Cams]
    Cams[Idx] = Last
    Cams[#Cams] = nil
    CamCount = CamCount - 1
end

-- >>> DRAWS

local GeometryRegistryTop = 1
local GeometryTypeRegistry = {}

function Renderer.NewGeometryType(FunctionSingle, FunctionBulk)
    local t = GeometryRegistryTop

    GeometryTypeRegistry[t] = {
        Single = FunctionSingle,
        Bulk = FunctionBulk,
    }

    GeometryRegistryTop = GeometryRegistryTop + 1

    return t
end

-- enum for Geometry Table State

local GTS_NEEDS_UPDATE = 1
local GTS_NEEDS_ALLOC = 2
local GTS_READY = 3
local GTS_NEEDS_FREE_FULL = 4
local GTS_NEEDS_FREE_GPU = 5

local ALLOCATOR_STATE_NONE = 0
local ALLOCATOR_STATE_READY = 1
local ALLOCATOR_STATE_NEEDS_FILL = 2

local DrawTable = {
    Solid = {},
    Transparent = {},
}
Renderer.DrawTable = DrawTable

function DrawTable.AddToStack(Entity, IsSolid, Material, GeometryHash, DrawType)
    local SubTable = IsSolid and DrawTable.Solid or DrawTable.Transparent

    Material = Material or false

    local MatTable = SubTable[Material] or {}

    SubTable[Material] = MatTable

    local GeometryTable = MatTable[GeometryHash] or { Top = 0, Type = DrawType }

    MatTable[GeometryHash] = GeometryTable

    local Top = GeometryTable.Top

    for i = 1, Top do
        if GeometryTable[i] == Entity then
            AstralEngine.Warn("DOUBLE ENTRY IN GEOMETRY TABLE FOR ENTITY: " .. Entity, "Renderer")
            print("EXTRA INFO:\n    SOLID:", IsSolid, "\n    MATERIAL:", Material)
            break
        end
    end

    local T = Top + 1

    GeometryTable[T] = Entity

    GeometryTable.Top = T
    if T > INSTANCING_THRESHOLD and not GeometryTable.IsInstanced then
        GeometryTable.State = GTS_NEEDS_ALLOC
    elseif GeometryTable.IsInstanced then
        GeometryTable.State = GTS_NEEDS_UPDATE
    else
        GeometryTable.State = GTS_READY
    end
end

function DrawTable.RemoveFromStack(Entity, IsSolid, Material, GeometryHash)
    -- here the RenderTarget component will know material, geometry hash and state
    local SubTable = IsSolid and DrawTable.Solid or DrawTable.Transparent

    Material = Material or false

    local MatTable = SubTable[Material]

    AstralEngine.Assert(
        MatTable,
        "No material table exists for Entity: " .. Entity .. " - Cannot remove from render stack",
        "Renderer"
    )

    local GeometryTable = MatTable[GeometryHash]

    AstralEngine.Assert(
        GeometryTable,
        "No geometry table exists for Entity: " .. Entity .. " - Cannot remove from render stack",
        "Renderer"
    )

    local Top, Id = GeometryTable.Top, -1
    for i = 1, Top do
        if GeometryTable[i] == Entity then
            Id = i
        end
    end

    AstralEngine.Assert(Id ~= -1, "Entity not found in material-geometry pair table. Cannot remove", "Renderer")

    -- swap so we have our linear array

    if Top == 1 then
        GeometryTable[Top] = nil
        GeometryTable.State = GTS_NEEDS_FREE_FULL
        -- free when drawing. Not now since it COULD be repopulated. Happens often when changing an object from one stack to another
    else
        local TopEnt = GeometryTable[Top]
        GeometryTable[Id] = TopEnt
        GeometryTable[Top] = nil

        if Top - 1 < INSTANCING_THRESHOLD and GeometryTable.IsInstanced then
            GeometryTable.State = GTS_NEEDS_FREE_GPU
        elseif GeometryTable.IsInstanced then
            GeometryTable.State = GTS_NEEDS_UPDATE
        else
            GeometryTable.State = GTS_READY
        end
    end

    GeometryTable.Top = Top - 1
end

local function DrawTableFix(Table, Where, Key)
    -- this will be called if the table needs repairs or changes to be made
    -- nts: do not forget to check if the Type of geometry has a bulk function before allocating

    local State = Table.State

    if
        State == GTS_NEEDS_FREE_FULL
        or (State == GTS_NEEDS_FREE_GPU and (Table.IsInstanced or Table.AllocatorState ~= ALLOCATOR_STATE_NONE))
    then
        if Table.IsInstanced or Table.AllocatorState ~= ALLOCATOR_STATE_NONE then
            Table.GPU_Transform:release()
            Table.GPU_Material:release()
            Table.GPU_Scale:release()
            Table.GPU_Transform = nil
            Table.GPU_Material = nil
            Table.GPU_Scale = nil

            Table.InstTransformData = nil
            Table.Material_MatrixInstanced = nil
            Table.Material_MatrixInstanced = nil
            Table.AllocatorState = ALLOCATOR_STATE_NONE
        end

        if State == GTS_NEEDS_FREE_FULL then
            Where[Key] = nil -- remove table ref
            return false
        end

        Table.IsInstanced = false
    elseif State == GTS_NEEDS_ALLOC then
        local New = table.new
        local NewBuffer = lovr.graphics.newBuffer

        Table.InstTransformData = New(BFL_Transform, 0)
        Table.Material_MatrixInstanced = New(BFL_Material, 0)
        Table.Material_ObjectScaleInstanced = New(BFL_Scale, 0)

        Table.GPU_Transform = NewBuffer(BFI_Transform, BFL_Transform)
        Table.GPU_Material = NewBuffer(BFI_Material, BFL_Material)
        Table.GPU_Scale = NewBuffer(BFI_Scale, BFL_Scale)

        Table.State = GTS_NEEDS_UPDATE
        Table.AllocatorState = ALLOCATOR_STATE_NEEDS_FILL

        return true
        -- we can only update it NEXT frame since more performance friendly
    elseif State == GTS_NEEDS_UPDATE or Table.AllocatorState then
        local T_Transform, T_Mat, T_Scale =
            Table.InstTransformData, Table.Material_MatrixInstanced, Table.Material_ObjectScaleInstanced
        if Table.AllocatorState == ALLOCATOR_STATE_NEEDS_FILL then
            local CompReg = Component.Components
            local C_Transform, C_Material = CompReg.Transform.Storage, CompReg.Material.Storage

            local EmptyMatrix = CompReg.Material.Metadata.EmptyMatrix

            for EntId = 1, Table.Top do
                local Ent = Table[EntId]

                local Transform, Material = C_Transform[Ent], C_Material[Ent]

                -- Transform always exists if its here. If it doesn't, then we'll crash elsewhere, so fuck it

                T_Transform[EntId] = Transform[3]
                T_Scale[EntId] = Transform[5]

                if Material then
                    T_Mat[EntId] = Material[9]
                else
                    T_Mat[EntId] = EmptyMatrix
                end

                T_Mat[EntId] = EmptyMatrix
            end

            -- fetch all tables and connect them
            Table.AllocatorState = ALLOCATOR_STATE_READY
            Table.IsInstanced = true
        end

        Table.GPU_Transform:setData(T_Transform, 1)
        Table.GPU_Material:setData(T_Mat, 1)
        Table.GPU_Scale:setData(T_Scale, 1)
    end

    Table.State = GTS_READY

    return true
end

-- > DRAWING

local function GetDrawFunc(IsSolid)
    local Idx = IsSolid and "Solid" or "Transparent"
    local IsTransparent = not IsSolid

    return function()
        local Cameras = Cams
        local Stack = DrawTable[Idx]

        local ComponentRegistry = Component.Components
        local CSCamera = ComponentRegistry.Camera.Storage
        local CSTransform = ComponentRegistry.Transform.Storage

        local pairs = pairs
        local FunctionRegistry = GeometryTypeRegistry

        local Lighting = Renderer.Lighting

        for CamId = 1, CamCount do
            local EntId = Cameras[CamId]
            local Camera = CSCamera[EntId]

            local Pass = Camera[IsSolid and 22 or 21][1]

            local Projection = Camera[26]
            local TransformMatrix = CSTransform[EntId][3]
            local Culling = Camera[15] and "back"

            -- ASSIGN PASS VARIABLES

            if IsSolid then
                Camera[11][1]:reset()
                Pass:reset()
                Camera[21][1]:reset()
            end

            Pass:setViewPose(1, TransformMatrix)
            Pass:setProjection(1, Projection)
            Pass:setFaceCull(Culling)

            local Skybox = Camera[28] and Camera[28][1] or Camera[28]

            if IsTransparent then
                Pass:setDepthWrite(false)
                Pass:setDepthTest(">=")
                Pass:setBlendMode(1, "add", "premultiplied")
                Pass:setBlendMode(2, "add", "premultiplied")
            elseif Skybox then
                Pass:skybox(Skybox) -- draw skybox only on first solid pass
                -- uses a unique shader so we draw it first
            end

            -- CONFIGURE SHADER

            Pass:setShader(MainShader)
            Pass:send("Lighting_Ambience", Camera[9])
            Pass:send("Transparent", IsTransparent)

            Pass:send("Lighting_Data", Lighting.LightBuffer)
            Pass:send("Lighting_LTC", Lighting.LTCTexture)
            Pass:send("Lighting_LTC_Amp", Lighting.LTCAmp)
            Pass:send("CamTransform", TransformMatrix)

            Pass:send("PBR_SphericalHarmonics", Camera[29])
            if Skybox then
                Pass:send("PBR_EnvMap", Skybox)
            end

            for Material, GeometryList in pairs(Stack) do
                Pass:setMaterial(Material or nil)

                for DrawHash, GeometryTable in pairs(GeometryList) do
                    Pass:push("state")

                    --local ShouldDrop = (GeometryTable.State == GTS_READY) and false or DrawTableFix(GeometryTable)
                    local ShouldContinue = GeometryTable.State == GTS_READY
                        or DrawTableFix(GeometryTable, GeometryList, DrawHash)

                    if ShouldContinue then
                        local Functions = FunctionRegistry[GeometryTable.Type]
                        if GeometryTable.IsInstanced and Functions.Bulk then
                            Pass:send("IsInstanced", true)

                            Pass:send("INSTANCE_Transform", GeometryTable.GPU_Transform)
                            Pass:send("INSTANCE_Material", GeometryTable.GPU_Material)
                            Pass:send("INSTANCE_Scale", GeometryTable.GPU_Scale)

                            Functions.Bulk(Pass, GeometryTable, DrawHash)
                        else
                            Pass:send("IsInstanced", false)
                            Functions.Single(Pass, GeometryTable, DrawHash)
                        end
                    end

                    Pass:pop("state")
                end
            end
        end
    end
end

Renderer.DrawSolid = GetDrawFunc(true)

Renderer.DrawTransparent = GetDrawFunc(false)

function Renderer.Composite()
    local Cameras = Cams
    local ComponentRegistry = Component.Components
    local CSCamera, CSTransform = ComponentRegistry.Camera.Storage, ComponentRegistry.Transform.Storage

    local mat4 = mat4

    for CamId = 1, CamCount do
        local Entity = Cameras[CamId]
        local Camera = CSCamera[Entity]

        local MainPass = Camera[11][1]
        local CompositePass = Camera[37][1]
        local BlurPassH = Camera[38][1]
        local BlurPassV = Camera[39][1]

        local SolidTexture = Camera[20][1]
        local TransparentTexture = Camera[13][1]
        local RevealTexture = Camera[23][1]
        local DepthTexture = Camera[24][1]

        local Projection = Camera[26]
        local InvProjection = mat4(Projection):invert()
        local ViewMatrix = mat4(CSTransform[Entity][3]):invert()

        local Near = Camera[5]

        -- FX

        local BloomData = ComponentRegistry.BloomFX.Storage[Entity]
        local DoBloom = BloomData and BloomData.Active or false

        local DOFData = ComponentRegistry.DepthOfFieldFX.Storage[Entity]
        local DoDOF = DOFData and DOFData.Active or false

        local FogData = ComponentRegistry.FogFX.Storage[Entity]
        local DoFog = FogData and FogData.Active or false

        -- COMPOSITION
        CompositePass:reset()
        CompositePass:setShader(OITExtractShader)
        CompositePass:setFaceCull()
        CompositePass:setBlendMode("none")

        -- extract config
        CompositePass:send("OIT_TexSolid", SolidTexture)
        CompositePass:send("OIT_TexTransparent", TransparentTexture)
        CompositePass:send("OIT_TexReveal", RevealTexture)
        CompositePass:send("OIT_TexDepth", DepthTexture)
        CompositePass:send("OIT_TexNormal", Camera[30][1])

        -- fog
        CompositePass:send("Fog_DoFog", DoFog)
        if DoFog then
            CompositePass:send("Fog_CamNear", Near)
            CompositePass:send("Fog_Info", FogData.__gpuBuffer)
        end

        -- bloom
        CompositePass:send("ExtractBloom", DoBloom)
        if DoBloom then
            CompositePass:send("BrightnessThreshold", BloomData.Threshold)
        end

        -- ssao
        CompositePass:send("Proj", Projection)
        CompositePass:send("ProjInv", InvProjection)
        CompositePass:send("ViewMatrix", ViewMatrix)
        CompositePass:send("SSAO_Noise", SSAO_Noise_Texture)

        CompositePass:setDepthWrite(false)
        CompositePass:setSampler("nearest")
        CompositePass:fill()

        -- BLUR PASS

        BlurPassV:reset()
        BlurPassV:setShader(BlurShader)
        BlurPassV:setSampler(BlurSampler)

        BlurPassH:reset()
        BlurPassH:setShader(BlurShader)
        BlurPassH:setSampler(BlurSampler)

        BlurPassH:send("Horizontal", true)
        BlurPassV:send("Horizontal", false)

        BlurPassH:send("AO_Tex", Camera[34][1])
        BlurPassH:send("DoBloom", DoBloom)
        BlurPassH:send("Color_Tex", Camera[33][1])

        BlurPassH:send("CamNear", Near)
        BlurPassH:send("Depth_Tex", DepthTexture)

        BlurPassV:send("CamNear", Near)
        BlurPassV:send("Depth_Tex", DepthTexture)

        BlurPassH:send("DoDOF", DoDOF)
        BlurPassV:send("DoDOF", DoDOF)

        if DoDOF then
            local DOFBuffer = DOFData.__gpuBuffer
            local DataDist = DOFData.FadeDistance

            BlurPassH:send("DOFData", DOFBuffer)
            BlurPassH:send("DOFFadeDist", DataDist)
            BlurPassV:send("DOFData", DOFBuffer)
            BlurPassV:send("DOFFadeDist", DataDist)
        end

        if DoBloom then
            local Size, Strength = BloomData.Size, BloomData.Strength

            BlurPassH:send("Bloom_Tex", Camera[36][1])
            BlurPassH:send("BloomSize", Size)
            BlurPassH:send("BloomStrength", Strength)

            BlurPassV:send("BloomSize", Size)
            BlurPassV:send("BloomStrength", Strength)
            BlurPassV:send("Bloom_Tex", Camera[41][1])
        end

        BlurPassH:fill()

        BlurPassV:send("Horizontal", false)
        BlurPassV:send("AO_Tex", Camera[42][1])
        BlurPassV:send("Color_Tex", Camera[40][1])
        BlurPassV:send("DoBloom", DoBloom)
        BlurPassV:fill()

        -- FINALISE
        MainPass:reset()
        MainPass:setShader(FinalShader)

        MainPass:send("ColorTex", Camera[32][1])
        MainPass:send("AO", Camera[35][1])
        MainPass:send("DoBloom", DoBloom)
        MainPass:send("Bloom", Camera[31][1])

        MainPass:send("gamma", 1)
        MainPass:send("exposure", 1)

        MainPass:fill()
    end
end

Renderer.Late[#Renderer.Late + 1] = function()
    local RS = GetService("RunService")
    local Flag = bit.bor(RS.Flags.Raw, RS.Flags.Contextless)

    RS.BindToStep("_REND_SCENE_SOLID", ENUM.StepPriority.RenderSceneSolid.RawValue, Renderer.DrawSolid, Flag)
    RS.BindToStep(
        "_REND_SCENE_TRANS",
        ENUM.StepPriority.RenderSceneTransparent.RawValue,
        Renderer.DrawTransparent,
        Flag
    )
    RS.BindToStep("_REND_SCENE_COMPOSITE", ENUM.StepPriority.RenderSceneComposite.RawValue, Renderer.Composite, Flag)
end

function Renderer.__OnRenderTargetReady() end
