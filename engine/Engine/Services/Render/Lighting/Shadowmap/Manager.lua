local ShadowmapManager = {}

--[[NOTE TO MR AMARO

WE HAVE:
Allocation/Reallocation

Need: Register/Deregister queue

Not need: Invalidation checks
Need: PRE-Camera shadowmap validity/reallocation check

Need: Drawing
Need: Sampling
Need: Light structs knowing what shadowmap they are bound to

]]

local Table = table.new
local Texture = AstralEngine.Graphics.NewRawTexture
local View = AstralEngine.Graphics.NewTextureView
local Pass = AstralEngine.Graphics.NewPass

local MAX_LAYERS = 6       -- will be our step size
local ALLOC_STEP = 1.2     -- ceil'd to a multiple of MAX_LAYERS
local MAX_SHADOWMAPS = 150 -- for each type, n * 6 for point lights
local TEXTURE_SIZE = 256

if AstralEngine.Graphics.GPU.GetLimit("RenderSize").z < MAX_LAYERS then
    AstralEngine.Error(
        "Your GPU cannot do shadowmapping. Must be able to do at least 6 texture layers. Got: "
        .. AstralEngine.Graphics.GPU.GetLimit("RenderSize").z,
        "Shadowmap"
    )
end

local ShadowmapShader
local ShadowmapData = {
    Cube = {
        Parameters = {
            linear = true,
            format = "d32f",
            mipmaps = false,
            type = "cube",
            label = "shadowcube",
        },
        Waitlist = {},
        Texture = nil,
        TargetPass = nil,
        Registry = nil,
        Views = nil,
        Passes = nil,
        Valid = false,
        Count = -1,
        Allocated = -1,
    },
    ["2D"] = {
        Parameters = {
            linear = true,
            format = "d32f",
            mipmaps = false,
            type = "array",
            label = "shadowmap",
        },
        Waitlist = {},
        Texture = nil,
        TargetPass = nil,
        Registry = nil,
        Views = nil,
        Passes = nil,
        Valid = false,
        Count = -1,
        Allocated = -1,
    },
}

local TextureViewData = {
    layercount = MAX_LAYERS,
    layer = -1,
}

local PassFormat = {
    depth = nil,
    samples = 1,
}

local function Init()
    ShadowmapShader = GetService("ShaderService").NewShader(Enum.ShaderType.Graphics, "Shadowmap/Shadowmap.glsl")
end

---@param Struct table
---@param NewCount number
---@param Scale number
function ShadowmapManager.Realloc(Struct, Scale, NewCount)
    local NewSize = math.ceil(NewCount * ALLOC_STEP) * Scale

    local Passes = math.ceil(NewSize / MAX_LAYERS)

    if NewSize > MAX_SHADOWMAPS * Scale then
        AstralEngine.Error("OUT OF SHADOWMAP MEMORY!", "GPU")
    end

    if Struct.Allocated == -1 then -- invalid, need first time alloc
        if Init then
            Init()
            Init = nil
        end
        Struct.Views = Table(Passes, 0)
        Struct.Passes = Table(Passes, 0)
        Struct.Registry = Table(NewSize, 0)
        ---@TODO: allocate target pass here (if i add the shared draw table thing)
        Struct.Texture = Texture(TEXTURE_SIZE, TEXTURE_SIZE, NewSize, Struct.Parameters)
    else
        Struct.Texture:release()
        Struct.Texture = Texture(TEXTURE_SIZE, TEXTURE_SIZE, NewSize, Struct.Parameters)
    end

    -- now we have to update passes and texture views

    local ParentTexture = Struct.Texture

    for i = 1, Passes do
        if Struct.Views[i] then
            Struct.Views[i]:release()
        end

        local LayerNumber = (i - 1) * MAX_LAYERS
        local Layers = math.min(NewSize - LayerNumber, MAX_LAYERS)
        TextureViewData.layer = LayerNumber + 1
        TextureViewData.layercount = Layers

        Struct.Views[i] = View(ParentTexture, TextureViewData)

        PassFormat.depth = Struct.Views[i]

        if Struct.Passes[i] then
            Struct.Passes[i]:setCanvas(PassFormat)
        else
            Struct.Passes[i] = Pass(PassFormat)
        end
    end

    Struct.Allocated = NewSize
end

function ShadowmapManager.UpdateShadowmap(Table) -- the part where we register everything from the wait list
end

---@param Entity AnyEntity
function ShadowmapManager.Register(Entity, Light)
    local Type = Light.Type or Enum.LightType.Point
    local Registry = ShadowmapData[Type == Enum.LightType.Point and "Cube" or "2D"]

    print("REGISTER AS:", Type == Enum.LightType.Point and "Cube" or "2D", Type)
end

---@param Entity AnyEntity
function ShadowmapManager.Deregister(Entity) end

return ShadowmapManager
