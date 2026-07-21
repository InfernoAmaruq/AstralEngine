-- > CONST
local INSTANCING_THRESHOLD = 5
local FREE_THRESHOLD = math.floor(INSTANCING_THRESHOLD / 2) -- at what point do we free
-- Why? Because if we have a table that constantly goes between 19 and 20, we will be freeing and allocating a LOT

-- buffer alloc rules
local MAX_BYTES = 10 -- should be more than plenty
local MAX_ALLOC_SIZE = MAX_BYTES * (1024 * 1024)
local MAX_BUFFER_SIZE = --[[max memory:]]
    math.floor(MAX_ALLOC_SIZE --[[matrix size:]] / 64)

local ALLOCATION_STEP = 1.2 -- when we want to reallocate, how much more do we allocate

-- > RUNTIME

local Renderer = select(1, ...)
local Component = GetService("Component")

local mat4 = mat4

-- > LOAD SHADERS
local ShaderService = GetService "ShaderService"

--- > GRAPHICS SHADERS

local OITExtractShader = ShaderService.NewShader(Enum.ShaderType.Graphics, 'fill', "Camera/CameraComposite.glsl")

local BlurShader = ShaderService.NewShader(Enum.ShaderType.Graphics, 'fill', "Camera/BlurPass.glsl")

local FinalShader = ShaderService.NewShader(Enum.ShaderType.Graphics, 'fill', "Camera/Finalise.glsl")

--- > COMPUTE SHADERS

local Data = { Raw = true, Defines = { USE_ATOMICS = true } }
local Success, ExtractSHShader = pcall(ShaderService.NewShader, Enum.ShaderType.Compute, "PBR/GetSH.comp", Data)
if not Success then
    -- Lets try compile w/o atomics
    Data.Defines.USE_ATOMICS = nil
    ExtractSHShader = ShaderService.NewShader(Enum.ShaderType.Compute, "PBR/GetSH.comp", Data)
end
Data = nil

-- > GET PRECOMPUTED ASSETS

local SSAO_Noise_Image = lovr.data.newImage(4, 4, "rgba8")
SSAO_Noise_Image:mapPixel(function()
    local x = math.random()
    local y = math.random()
    local Unit = vec2(x, y):normalize() * 255
    return Unit.x, Unit.y
end)
local SSAO_Noise_Texture = AstralEngine.Graphics.NewTexture(SSAO_Noise_Image, { usage = { "sample" } })
SSAO_Noise_Image:release()

local BlurSampler = lovr.graphics.newSampler({ wrap = "clamp" })

-- > MAIN SHADER METHODS

local MainShader

local BFI_Transform = "mat4"
local BFI_Material = "mat4"
local BFI_Scale = "vec3"

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
local GTS_NEEDS_REALLOC = 6

local ALLOCATOR_STATE_NONE = 0
local ALLOCATOR_STATE_READY = 1
local ALLOCATOR_STATE_NEEDS_FILL = 2

local DrawTable = {
    Solid = {},
    Transparent = {},
}
Renderer.DrawTable = DrawTable

-- Shader pipelines

local ShaderRegistry = {}
local ShaderList = {}
local ShaderManifest = {}
local ShaderListTop = 0

local BASE_MANIFEST = {
    TransparentPipeline = true, SolidPipeline = true, SendDirectLightingData = true, SendIndirectLightingData = true, CanBeInstanced = true
}

local function SortFunc(a, b)
    return a.Priority < b.Priority
end

local function SortShaders()
    for i = 1, #ShaderList do
        ShaderList[i] = nil
        ShaderManifest[i] = nil
    end

    local Idx = 1
    for _, Val in pairs(ShaderRegistry) do
        ShaderList[Idx] = Val
        Idx = Idx + 1
    end

    table.sort(ShaderList, SortFunc)

    ShaderListTop = #ShaderList
    for i = 1, ShaderListTop do
        ShaderManifest[i] = ShaderList[i].Manifest
        ShaderList[i] = ShaderList[i].Shader
    end
end

function Renderer.BindShaderPipeline(Name, Shader, Config)
    local RegistryInfo = table.new(0, 4)

    Name = AstralEngine.Assert(tostring(Name), "Cannot bind an unnamed shader pipeline!", "Renderer")

    AstralEngine.Assert(ShaderRegistry[Shader] == nil,
        "Shader pipeline with shader: " .. tostring(Shader) .. " already exists!",
        "Renderer")

    local Manifest

    if Config and Config.Manifest then
        Manifest = {}

        for i, v in pairs(Config.Manifest) do
            Manifest[i] = v
        end

        for i, v in pairs(BASE_MANIFEST) do
            if Manifest[i] == nil then
                Manifest[i] = v
            end
        end
    else
        Manifest = BASE_MANIFEST
    end

    RegistryInfo.Priority = Config and Config.Priority or 101
    RegistryInfo.Manifest = Manifest
    RegistryInfo.Name = Name
    RegistryInfo.Shader = Shader

    ShaderRegistry[Shader] = RegistryInfo

    SortShaders()
end

function Renderer.UnbindShaderPipeline(Name)
    for i, v in pairs(ShaderRegistry) do
        if v.Name == Name then
            ShaderRegistry[i] = nil

            if DrawTable.Solid[v.Shader] or DrawTable.Transparent[v.Shader] then
                AstralEngine.Log("Unbound shader pipeline with geometry bound to shader. Geometry will be ignored",
                    "warn", "Renderer")
            end

            SortShaders()
            return
        end
    end
end

Renderer.GetMainShader = function()
    return MainShader
end

Renderer.SetMainShader = function(Shader)
    MainShader = Shader

    Renderer.SetMainShader = nil

    Renderer.BindShaderPipeline("__PRIMARY_GEOMETRY_PIPELINE", Shader)
end

-- Geometry/Register

local function Enqueue(Table, Entity)
    if Table.Queue[Entity] then
        return
    elseif Table.Queue[Entity] == false then
        Table.Queue[Entity] = true
        return
    end

    for i = 1, Table.Top do
        if Table[i] == Entity then
            return
        end
    end

    Table.Queue[Entity] = true

    Table.Queue.ToCheck = true
    Table.State = GTS_NEEDS_UPDATE
end

local function Dequeue(Table, Entity)
    if Table.Queue[Entity] then
        Table.Queue[Entity] = nil   -- means we have yet to add this entity to the render array, meaning we can delete it here
    else
        Table.Queue[Entity] = false -- remove and we presume it already exists
    end

    Table.Queue.ToCheck = true
    Table.State = GTS_NEEDS_UPDATE
end

function DrawTable.AddToStack(Entity, IsSolid, Material, GeometryHash, DrawType, Shader)
    local SubTable = IsSolid and DrawTable.Solid or DrawTable.Transparent

    Shader = Shader or MainShader

    AstralEngine.Assert(GeometryTypeRegistry[DrawType], "No DrawType " .. DrawType .. " exists in registry", "Renderer")

    local LookUpShader = ShaderRegistry[Shader]
    if not LookUpShader then
        AstralEngine.Log(
            "Shader " ..
            tostring(Shader) .. " is missing from shader registy. Objects with this shader will not be drawn",
            "warn", "Renderer")

        local Manifest = Shader.Manifest
        if IsSolid and not Manifest.SolidPipeline then return end
        if not IsSolid and not Manifest.TransparentPipeline then return end
    end

    local ShaderTable = SubTable[Shader] or {}
    SubTable[Shader] = ShaderTable

    Material = Material or false

    local MatTable = ShaderTable[Material] or {}
    ShaderTable[Material] = MatTable

    local GeometryTable = MatTable[GeometryHash] or
        { Top = 0, Type = DrawType, Hash = GeometryHash, Queue = table.new(10, 50) }

    MatTable[GeometryHash] = GeometryTable

    Enqueue(GeometryTable, Entity)
end

function DrawTable.Invalidate(Shader, Material, GeometryHash)
    Material = Material or false

    for i = 1, 2 do
        local t1 = DrawTable[i == 1 and "Solid" or "Transparent"][Shader]

        if not t1 then
            goto continue
        end

        local t2 = t1[Material]

        if not t2 then
            goto continue
        end

        local t3 = t2[GeometryHash]

        if not t2 then
            goto continue
        end

        t3.State = GTS_NEEDS_UPDATE

        ::continue::
    end
end

function DrawTable.RemoveFromStack(Entity, IsSolid, Material, GeometryHash, Shader)
    -- here the RenderTarget component will know material, geometry hash and state
    local SubTable = IsSolid and DrawTable.Solid or DrawTable.Transparent

    Shader = Shader or MainShader

    local ShaderTable = SubTable[Shader]

    if not ShaderTable then return end

    Material = Material or false

    local MatTable = ShaderTable[Material]

    if not MatTable then return end

    local GeometryTable = MatTable[GeometryHash]

    if not GeometryTable then return end

    Dequeue(GeometryTable, Entity)
end

local function Populate(Table, From)
    local T_Transform, T_Mat, T_Scale =
        Table.InstTransformData, Table.Material_MatrixInstanced, Table.Material_ObjectScaleInstanced
    local CompReg = Component.Components
    local C_Transform, C_Material = CompReg.Transform.Storage, CompReg.Material.Storage

    local EmptyMatrix = CompReg.Material.Metadata.EmptyMatrix

    for EntId = From, Table.Top do
        local Ent = Table[EntId]

        local Transform, Material = C_Transform[Ent], C_Material[Ent]

        -- Transform always exists if its here. If it doesnt, then we will crash elsewhere, so fuck it

        T_Transform[EntId] = Transform[3]
        T_Scale[EntId] = Transform[5]

        if Material then
            T_Mat[EntId] = Material[9]
        else
            T_Mat[EntId] = EmptyMatrix
        end
    end

    -- fetch all tables and connect them
    Table.AllocatorState = ALLOCATOR_STATE_READY
    Table.IsInstanced = true
end

local function DrawTableFix(Table, Where, Key, Shader)
    -- this will be called if the table needs repairs or changes to be made
    -- nts: do not forget to check if the Type of geometry has a bulk function before allocating

    local ShaderTable = ShaderRegistry[Shader]
    local Manifest = ShaderTable.Manifest

    local State = Table.State
    local Inst = Table.IsInstanced

    -- resolve queue first
    local Queue = Table.Queue
    if Queue.ToCheck then
        Queue.ToCheck = nil

        local T_Transform, T_Mat, T_Scale =
            Table.InstTransformData, Table.Material_MatrixInstanced, Table.Material_ObjectScaleInstanced

        -- set nil so we can iterate it correctly

        local Top = Table.Top

        local CompReg = Component.Components
        local C_Transform, C_Material = CompReg.Transform.Storage, CompReg.Material.Storage

        local EmptyMatrix = CompReg.Material.Metadata.EmptyMatrix

        local ShaderUpdated = Manifest.EntityChanged

        if ShaderUpdated then
            ShaderUpdated(Table, Queue, i, v)
        end

        for i, v in pairs(Queue) do
            if v then
                Top = Top + 1
                Table[Top] = i

                if Inst then
                    local Transform, Material = C_Transform[i], C_Material[i]

                    T_Transform[Top] = Transform[3]
                    T_Scale[Top] = Transform[5]

                    if Material then
                        T_Mat[Top] = Material[9]
                    else
                        T_Mat[Top] = EmptyMatrix
                    end
                end
            else
                for j = 1, Top do
                    if Table[j] == i then -- remove
                        local TopEnt = Table[Top]
                        Table[Top] = nil

                        Table[j] = TopEnt

                        if Inst then
                            T_Transform[Top], T_Transform[j] = nil, T_Transform[Top]
                            T_Mat[Top], T_Mat[j] = nil, T_Mat[Top]
                            T_Scale[Top], T_Scale[j] = nil, T_Scale[Top]
                        end

                        Top = Top - 1
                    end
                end
            end

            Queue[i] = nil
        end

        Table.Top = Top

        State = GTS_NEEDS_UPDATE

        if GeometryTypeRegistry[Table.Type].Bulk and Manifest.CanBeInstanced then
            if Top >= INSTANCING_THRESHOLD and not Table.IsInstanced then
                State = GTS_NEEDS_ALLOC
            elseif Top == 0 then
                State = GTS_NEEDS_FREE_FULL
            elseif Table.IsInstanced and Top > Table.AllocSize then
                State = GTS_NEEDS_REALLOC
            elseif Table.IsInstanced and Top < FREE_THRESHOLD then
                State = GTS_NEEDS_FREE_GPU
            end
        end
    end

    if
        State == GTS_NEEDS_FREE_FULL
        or (State == GTS_NEEDS_FREE_GPU and (Table.IsInstanced or Table.AllocatorState ~= ALLOCATOR_STATE_NONE))
    then
        if Table.IsInstanced or Table.AllocatorState ~= ALLOCATOR_STATE_NONE then
            if Table.GPU_Transform then
                Table.GPU_Transform:release()
                Table.GPU_Material:release()
                Table.GPU_Scale:release()
            end
            Table.GPU_Transform = nil
            Table.GPU_Material = nil
            Table.GPU_Scale = nil

            Table.InstTransformData = nil
            Table.Material_MatrixInstanced = nil
            Table.Material_MatrixInstanced = nil
            Table.AllocatorState = ALLOCATOR_STATE_NONE

            if Manifest.InstFree then Manifest.InstFree(Table) end
        end

        if State == GTS_NEEDS_FREE_FULL then
            for i in pairs(Table) do
                Table[i] = nil
            end

            Where[Key] = nil -- remove table ref
            return false
        end

        Table.IsInstanced = false
    elseif State == GTS_NEEDS_REALLOC then
        -- keep old lua tables

        Table.GPU_Material:release()
        Table.GPU_Scale:release()
        Table.GPU_Transform:release()

        local NewBuffer = lovr.graphics.newBuffer
        local Alloc = Table.Top * ALLOCATION_STEP

        if Alloc > MAX_BUFFER_SIZE then
            AstralEngine.Error(
                "OUT OF BUFFER MEMORY. MAX INST BUFFER MEMORY 10MB OR " .. MAX_BUFFER_SIZE .. " INSTANCES",
                "RENDER"
            )
        end

        Table.GPU_Transform = NewBuffer(BFI_Transform, Alloc)
        Table.GPU_Material = NewBuffer(BFI_Material, Alloc)
        Table.GPU_Scale = NewBuffer(BFI_Scale, Alloc)

        Table.AllocSize = Alloc

        Table.State = GTS_READY

        local OldSize = #Table.InstTransformData
        Populate(Table, OldSize)

        if Table.IsInstanced then
            Table.GPU_Transform:setData(Table.InstTransformData)
            Table.GPU_Material:setData(Table.Material_MatrixInstanced)
            Table.GPU_Scale:setData(Table.Material_ObjectScaleInstanced)
        end

        if Manifest.InstRealloc then Manifest.InstRealloc(Table, Alloc, OldSize) end
    elseif State == GTS_NEEDS_ALLOC then
        local New = table.new
        local NewBuffer = lovr.graphics.newBuffer

        local Alloc = Table.Top * ALLOCATION_STEP

        if Alloc > MAX_BUFFER_SIZE then
            AstralEngine.Error(
                "OUT OF BUFFER MEMORY. MAX INST BUFFER MEMORY 10MB OR " .. MAX_BUFFER_SIZE .. " INSTANCES",
                "RENDER"
            )
        end

        Table.InstTransformData = New(Alloc, 0)
        Table.Material_MatrixInstanced = New(Alloc, 0)
        Table.Material_ObjectScaleInstanced = New(Alloc, 0)

        Table.GPU_Transform = NewBuffer(BFI_Transform, Alloc)
        Table.GPU_Material = NewBuffer(BFI_Material, Alloc)
        Table.GPU_Scale = NewBuffer(BFI_Scale, Alloc)

        Table.AllocSize = Alloc

        Table.State = GTS_NEEDS_UPDATE
        Table.AllocatorState = ALLOCATOR_STATE_NEEDS_FILL

        if Manifest.InstAlloc then Manifest.InstAlloc(Table, Alloc) end

        return true
        -- we can only update it NEXT frame since more performance friendly
    elseif State == GTS_NEEDS_UPDATE or Table.AllocatorState then
        local T_Transform, T_Mat, T_Scale =
            Table.InstTransformData, Table.Material_MatrixInstanced, Table.Material_ObjectScaleInstanced
        if Table.AllocatorState == ALLOCATOR_STATE_NEEDS_FILL then
            Populate(Table, 1)
        end

        if Table.IsInstanced then
            Table.GPU_Transform:setData(T_Transform)
            Table.GPU_Material:setData(T_Mat)
            Table.GPU_Scale:setData(T_Scale)
        end

        if Manifest.InstUpdate then
            Manifest.InstUpdate(Table)
        end
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
        local CSEnv = ComponentRegistry.Environment.Storage

        local pairs = pairs
        local FunctionRegistry = GeometryTypeRegistry

        local Lighting = Renderer.Lighting

        local ShaderListTop = ShaderListTop
        local ShaderList = ShaderList
        local ShaderManifest = ShaderManifest

        for CamId = 1, CamCount do
            local EntId = Cameras[CamId]
            local Camera = CSCamera[EntId]

            local Pass = Camera[IsSolid and 22 or 21]

            local Projection = Camera[26]
            local CamTransform = CSTransform[EntId]
            local TransformMatrix = CamTransform[3]
            local Culling = Camera[15] and "back"

            -- ASSIGN PASS VARIABLES

            if IsSolid then
                Camera[11]:reset()
                Pass:reset()
                Camera[21]:reset()
            end

            Pass:setViewPose(1, TransformMatrix)
            Pass:setProjection(1, Projection)
            Pass:setFaceCull(Culling)

            local EnvComponent = CSEnv[EntId]
            local Buff1, Buff2, Skybox

            if IsTransparent then
                Pass:setDepthWrite(false)
                Pass:setDepthTest(">=")
                Pass:setBlendMode(1, "add", "premultiplied")
                Pass:setBlendMode(2, "add", "premultiplied")
            end

            if EnvComponent then
                -- draw skybox only on solid pass

                Buff1 = EnvComponent.UserHarmonics
                Buff2 = EnvComponent.__EnvHarmonics
                Skybox = EnvComponent[1]

                -- recalculate SH if we need to

                if EnvComponent.__UpdateBuffers then
                    Pass:setShader(ExtractSHShader)
                    Pass:send("envMap", Skybox)
                    Pass:send("SHBuffer", Buff2)

                    local Size = Skybox:getHeight()

                    local x, y = ExtractSHShader:getWorkgroupSize()

                    Pass:compute((Size + x - 1) / x, (Size + y - 1) / y, 6)

                    Pass:setShader()

                    EnvComponent.__UpdateBuffers = false
                end

                if IsSolid then
                    Pass:skybox(Skybox)
                end
                -- uses a unique shader so we draw it first
            end

            -- CONFIGURE SHADER

            for i = 1, ShaderListTop do
                local Shader, Manifest = ShaderList[i], ShaderManifest[i]

                Pass:push("state")

                Pass:setShader(Shader)
                Pass:send("Transparent", IsTransparent)

                if Manifest.SendDirectLightingData then
                    Pass:send("Light_LightCount", Lighting.LightCount)
                    Pass:send("Lighting_Data", Lighting.LightBuffer)
                    Pass:send("Lighting_LTC", Lighting.LTCTexture)
                    Pass:send("Lighting_LTC_Amp", Lighting.LTCAmp)
                    Pass:send("CamTransform", TransformMatrix)
                end

                if Manifest.SendIndirectLightingData and EnvComponent then
                    Pass:send("PBR_SphericalHarmonics_User", Buff1)
                    Pass:send("PBR_SphericalHarmonics", Buff2)
                    Pass:send("PBR_EnvMap", Skybox)
                end

                local CanBeInstanced = Manifest.CanBeInstanced

                if Manifest.Setter then
                    Manifest.Setter(Pass, Shader, IsSolid, Camera, CamTransform)
                end

                local Geom = Stack[Shader]
                if Geom then
                    for Material, GeometryList in pairs(Geom) do
                        Pass:setMaterial(Material or nil)

                        for DrawHash, GeometryTable in pairs(GeometryList) do
                            Pass:push("state")

                            --local ShouldDrop = (GeometryTable.State == GTS_READY) and false or DrawTableFix(GeometryTable)
                            local ShouldContinue = GeometryTable.State == GTS_READY
                                or DrawTableFix(GeometryTable, GeometryList, DrawHash, Shader)

                            if ShouldContinue then
                                local Functions = FunctionRegistry[GeometryTable.Type]
                                if CanBeInstanced and GeometryTable.IsInstanced and Functions.Bulk then
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

                Pass:pop("state")
            end
        end
    end
end

Renderer.DrawSolid = GetDrawFunc(true)

Renderer.DrawTransparent = GetDrawFunc(false)

function Renderer.Composite()
    local Cameras = Cams
    local ComponentRegistry = Component.Components
    local CSCamera, CSTransform, CSEnv = ComponentRegistry.Camera.Storage, ComponentRegistry.Transform.Storage,
        ComponentRegistry.Environment.Storage

    local mat4 = mat4

    for CamId = 1, CamCount do
        local Entity = Cameras[CamId]
        local Camera = CSCamera[Entity]

        local MainPass = Camera[11]
        local CompositePass = Camera[37]
        local BlurPassH = Camera[38]
        local BlurPassV = Camera[39]

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

        local Env = CSEnv[Entity]
        if Env then
            MainPass:send("gamma", Env[12])
            MainPass:send("exposure", Env[13])
        end

        MainPass:fill()
    end
end

Renderer.Late[#Renderer.Late + 1] = function()
    local RS = GetService("RunService")
    local Flag = bit.bor(RS.Flags.Raw, RS.Flags.Contextless)

    RS.BindToStep("_REND_SCENE_SOLID", Enum.StepPriority.RenderSceneSolid.Value, Renderer.DrawSolid, Flag)
    RS.BindToStep(
        "_REND_SCENE_TRANS",
        Enum.StepPriority.RenderSceneTransparent.Value,
        Renderer.DrawTransparent,
        Flag
    )
    RS.BindToStep("_REND_SCENE_COMPOSITE", Enum.StepPriority.RenderSceneComposite.Value, Renderer.Composite, Flag)
end

function Renderer.__OnRenderTargetReady() end
