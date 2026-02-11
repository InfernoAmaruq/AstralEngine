local Plugin = AstralEngine.Plugins.VeneerUI
local Renderer = select(1, ...)

Renderer.VeneerUI = {}

local BaseUIPriority = Plugin.Config.CameraPassBindPriority

Renderer.VeneerUI.UICameras = {}
Renderer.VeneerUI.BindUICamera = function(Camera, Priority)
    table.insert(Renderer.VeneerUI.UICameras, Camera)

    local Pass = Camera[1]
    if Pass then
        Renderer.PassStorage.AddPass(false, Pass, Priority or (BaseUIPriority + #Renderer.VeneerUI.UICameras), true)
    end
end
Renderer.VeneerUI.UnbindUICamera = function(Camera)
    local Idx = table.find(Renderer.VeneerUI.UICameras, Camera)
    if Idx then
        table.remove(Renderer.VeneerUI.UICameras, Idx)
    end
end

Renderer.Late[#Renderer.Late + 1] = function()
    -- bind

    local UICams = Renderer.VeneerUI.UICameras

    GetService("RunService").BindToStep("VENEER_UI_DRAW", Plugin.Config.BaseRenderBand, function(WorldPass)
        for i = 1, #UICams do
            local Cam = UICams[i]
            local Pass = Cam[1]
            Pass:reset()
            Pass:setProjection(1, Cam[5])
            Pass:setDepthTest()
            Pass:setColor(0.2, 0.2, 0.2, 1)
            Pass:plane(100, 500, 0, 200, 1000)
            Pass:setColor(0, 1, 0, 1)
            Pass:setFont(lovr.graphics.getDefaultFont())
            Pass:text("UI TEST", 100, 40, 0, 50)
            if Cam[4] then
                local CamPass = Cam[4][11][1]
                CamPass:push("state")
                CamPass:setBlendMode("alpha", "alphamultiply")
                CamPass:fill(Cam[2][1])
                CamPass:pop("state")
            end
        end
    end)
end
