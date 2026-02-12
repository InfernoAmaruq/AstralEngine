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

    local Font = lovr.graphics.newFont("GAMEFILE/Plugins/Veneer/RobotoMono.ttf")

    GetService("RunService").BindToStep("VENEER_UI_DRAW", Plugin.Config.BaseRenderBand, function(WorldPass)
        for i = 1, #UICams do
            local Cam = UICams[i]
            local Pass = Cam[1]
            local Objects = Cam[7]
            local ObjCount = #Objects
            if ObjCount == 0 then
                --continue
            end
            Pass:reset()
            Pass:setProjection(1, Cam[5])
            Pass:setDepthTest()
            Pass:setDepthWrite()
            -- iter and draw obj

            for ObjIdx = 1, ObjCount do
                local Obj = Objects[ObjIdx]
            end

            -- to cam
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
