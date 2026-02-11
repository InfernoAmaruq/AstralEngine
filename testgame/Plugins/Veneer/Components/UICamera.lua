local RenderService = GetService("Renderer")

local UICam = {}

UICam.Name = "UICamera"

UICam.Metadata = {}

--[[
    Input pattern

    >IO
    .OutputTexture
    .OutputResolution?

    >Update rate (1-FrameRate(hz))

--]]

local IdxGetter = {
    Texture = 2,
    DepthTexture = 3,
}

local Getters = {}
local Setters = {}
local Methods = {
    SetRenderTarget = function(self, TargetTexture) end,
}

local MT = {
    __index = function(self, k)
        if Methods[k] then
            return Methods[k]
        end
        if Getters[k] then
            return Getters[k](self)
        end
    end,
    __newindex = function(self, k, v)
        if Setters[k] then
            Setters[k](self, v)
        end
    end,
}

UICam.Metadata.__create = function(Input, Entity)
    local Data = {}

    local IOTexture = Input.OutputTexture

    local DoDepth = Input.Depth
    local DepthType = typeof(DoDepth)

    -- alloc source tex
    if not IOTexture then
        local OutputResolution = Input.OutputResolution
            or (vec2(AstralEngine.Window.W, AstralEngine.Window.H) * AstralEngine.Window.GetWindowDensity())
        IOTexture = AstralEngin.Graphics.NewTexture(
            OutputResolution.x,
            OutputResolution.y,
            { label = "VENEER_UI_TEXTURE", Input.Mipmaps or false }
        )
    end
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
        [1] = IOTexture,
        depth = {
            texture = DepthTex,
        },
        samples = 1,
    })

    Data[1] = Pass
    Data[2] = IOTexturea
    Data[3] = DepthTex
    Data.ResizeWithInputTexture = Input.ResizeWithInputTexture == nil and true or Input.ResizeWithInputTexture

    setmetatable(Data, MT)

    return Data
end

UICam.Metadata.__remove = function(self, Entity) end

return UICam
