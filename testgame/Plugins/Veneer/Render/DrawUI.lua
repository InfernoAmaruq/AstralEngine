local Plugin = AstralEngine.Plugins.VeneerUI
local Renderer = select(1, ...)

Renderer.VeneerUI = {}

Renderer.VeneerUI.UICameras = {}

Renderer.Late[#Renderer.Late + 1] = function()
    print(AstralEngine.Plugins, AstralEngine.Plugins.VeneerUI, AstralEngine.Plugins.VeneerUI.Config.BaseRenderBand)
    -- bind
    GetService("RunService").BindToStep("VENEER_UI_DRAW", Plugin.Config.BaseRenderBand, function(Pass) end)
end
