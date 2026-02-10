local RenderService = GetService("Renderer")

local UICam = {}

UICam.Name = "UICamera"

UICam.Metadata = {}

--[[
    Input pattern

    >IO
    .OutputTexture
    .OutputResolution?
    .OutputDPI?

    >Update rate (1-FrameRate(hz))

--]]

UICam.Metadata.__create = function(Input, Entity)
    local Data = {}

    local IOTexture = Input.OutputTexture
    if not IOTexture then
        local OutputResolution = Input.OutputResolution or vec2(AstralEngine.Window.W, AstralEngine.Window.H)
        IOTexture = AstralEngin.Graphics.NewTexture(
            OutputResolution.x,
            OutputResolution.y,
            { label = "VENEER_UI_TEXTURE", Input.Mipmaps or false }
        )
    end

    return Data
end

UICam.Metadata.__remove = function(self, Entity) end

return UICam
