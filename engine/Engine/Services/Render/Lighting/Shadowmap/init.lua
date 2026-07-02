local Renderer = select(1, ...)

local Shadowmap = {}

local PreallocationSize = 5
local Size = 256

local ReallocationStep = 5

local UPD_RATE = 1 / 20

function Shadowmap.SetUpdateRate(n)
    UPD_RATE = 1 / n
end

function Shadowmap.GetUpdateRate()
    return 1 / UPD_RATE
end

local ShadowmapData = {
    Cube = {
        Parameters = {
            linear = true,
            format = "d32f",
            mipmaps = false,
            type = "cube",
            label = "shadowcube",
        },
        Texture = nil,
        Pass = nil,
        Valid = false,
        Registry = {},
        Count = PreallocationSize,
        LastDrawn = -1,
    },
    ["2D"] = {
        Parameters = {
            linear = true,
            format = "d32f",
            mipmaps = false,
            type = "array",
            label = "shadowmap",
        },
        Texture = nil,
        Pass = nil,
        Valid = false,
        Registry = {},
        Count = PreallocationSize,
        LastDrawn = -1,
    },
}

local ShadowmapTexture2D =
    AstralEngine.Graphics.NewRawTexture(Size, Size, PreallocationSize, ShadowmapData["2D"].Parameters)
local ShadowmapPass2D = AstralEngine.Graphics.NewRawPass({ depth = ShadowmapTexture2D, samples = 1 })

ShadowmapData["2D"].Texture = ShadowmapTexture2D
ShadowmapData["2D"].Pass = ShadowmapPass2D

local ShadowmapTextureCube =
    AstralEngine.Graphics.NewRawTexture(Size, Size, PreallocationSize * 6, ShadowmapData.Cube.Parameters)
local ShadowmapPassCube = AstralEngine.Graphics.NewRawPass({ depth = ShadowmapTextureCube, samples = 1 })

ShadowmapData.Cube.Texture = ShadowmapTextureCube
ShadowmapData.Cube.Pass = ShadowmapPassCube

-- matrices
local PointMatrix = Mat4():perspective(math.rad(90), 1, 0.01, 0)
local DirectionalMatrix = Mat4():orthographic(100, 100, 0.1, 100000000)

local Component = GetService("Component")
local ShadowmapRegistry = {} -- On removal, we will shift the general registry down. BUT NOT THE SHADOWMAP REGISTRY

function Shadowmap.Tick()
    local t = os.clock()

    local DataCube = ShadowmapData.Cube
    local Data2D = ShadowmapData["2D"]

    local DoCube = not DataCube.Valid or (t - DataCube.LastDrawn > UPD_RATE)
    local Do2D = not Data2D.Valid or (t - Data2D.LastDrawn > UPD_RATE)

    if not DoCube and not Do2D then
        return
    end

    -- we wanna keep them synchronised so we will draw both regardless of whether or not one needs to be drawn

    local PassCube, Pass2D = DataCube.Pass, Data2D.Pass
    local TextureCube, Texture2D = DataCube.Texture, Data2D.Texture

    Pass2D:reset()
    Pass2D:setFaceCull("back")

    PassCube:reset()
    PassCube:setFaceCull("back")

    DataCube.LastDrawn = t
    Data2D.LastDrawn = t

    for _, Inst in ipairs(ShadowmapRegistry) do
    end

    for _, Geometry in ipairs({}) do
    end

    -- iterate all geometry
end

Renderer.Late[#Renderer.Late + 1] = function()
    -- bind the shadowmap draw call
    local RS = GetService("RunService")
    local Flag = bit.bor(RS.Flags.Raw, RS.Flags.Contextless)

    ENUM.StepPriority.__Append("RenderShadowmap", 550)

    --RS.BindToStep("DrawShadowmap", ENUM.StepPriority.RenderShadowmap, Shadowmap.Tick, Flag)
end

local function IsInRegistry(E)
    for Idx, v in ipairs(ShadowmapRegistry) do
        if v.Ent == E then
            return Idx
        end
    end
end

local function Realloc(Cube)
    local t = ShadowmapData[(Cube and "Cube" or "2D")]
    local OldSize = t.Count
    local NewSize = OldSize + ReallocationStep

    local OldTex = t.Texture
    OldTex:release()
    t.Texture = AstralEngine.Graphics.NewRawTexture(Size, Size, NewSize * (Cube and 6 or 1), t.Parameters)
    t.Pass:setCanvas({ depth = t.Texture, samples = 1 })
    t.Valid = false

    if Cube then
        ShadowCubeCount = NewSize
    else
        ShadowMapCount = NewSize
    end
end

local function GetFreeMapId(Cube)
    local t = ShadowmapData[Cube and "Cube" or "2D"]
    local N = t.Count
    local UsedMaps = t.Registry
    for i = 1, N do
        if not UsedMaps[i] then
            return i
        end
    end

    Realloc(Cube)
    return N
end

local function RegisterLightToMap(EntryId, Cube)
    local FreeId = GetFreeMapId(Cube)

    local Map = ShadowmapData[Cube and "Cube" or "2D"].Registry
    Map[FreeId] = EntryId

    return FreeId
end

function Shadowmap.Add(E, L)
    L = L or E.Light

    local Reg = IsInRegistry(E)
    local Entry = Reg and ShadowmapRegistry[Reg]
    local Cube = L.Type == ENUM.LightType.Point

    if not Entry then
        Entry = {
            Id = #ShadowmapRegistry + 1,
            Ent = E,
            IsCube = Cube,
            MapId = -1,
            Valid = false,
        }

        ShadowmapRegistry[#ShadowmapRegistry + 1] = Entry
    end

    if Entry.MapId == -1 or (Entry.IsCube ~= Cube) then
        Entry.MapId = RegisterLightToMap(Entry.Id, Entry.IsCube)
        Entry.IsCube = Cube
    end

    --[[
    print("REGISTER SHADOWCASTING LIGHT:")
    print("ID = ", Entry.Id)
    print("SHADOWMAP ID = ", Entry.MapId)
    print("ISCUBE = ", Entry.IsCube)
    print("ENTITY = ", E)
    ]]
end

function Shadowmap.Remove(E)
    --print("DEREGISTER")
end

return Shadowmap
