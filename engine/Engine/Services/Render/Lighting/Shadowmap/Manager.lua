local ShadowmapManager = {}

local Table = table.new
local Texture = AstralEngine.Graphics.NewRawTexture
local Pass = AstralEngine.Graphics.NewPass

local MAX_LAYERS = AstralEngine.Graphics.GPU.GetLimit("RenderSize").z -- will be our step size
local ALLOC_STEP = 1.2                                                -- ceil'd to a multiple of MAX_LAYERS
local TEXTURE_SIZE = 256

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
        TargetPass = nil,
        Registry = nil,
        Views = nil,
        Passes = nil,
        Valid = false,
        Count = -1,
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
        TargetPass = nil,
        Registry = nil,
        Views = nil,
        Passes = nil,
        Valid = false,
        Count = -1,
    },
}

function ShadowmapManager.Realloc() end

return ShadowmapManager
