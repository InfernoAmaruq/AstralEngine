local Plugin = AstralEngine.Plugins.VeneerUI
local Renderer = select(1, ...)

Renderer.VeneerUI = {}
BaseUIPriority = Plugin.Config.CameraPassBindPriority

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

Renderer.VeneerUI.FunctionStack = {}
local FuncStack = Renderer.VeneerUI.FunctionStack
Renderer.VeneerUI.GetFunctionStackTop = function()
    return #FuncStack
end

Renderer.Late[#Renderer.Late + 1] = function()
    -- bind
    GetService("RunService").BindToStep("VENEER_UI_DRAW", Plugin.Config.BaseRenderBand, function()
        local UICams = Renderer.VeneerUI.UICameras
        local Stack = FuncStack

        for i = 1, #UICams do
            local Cam = UICams[i]
            local Pass = Cam[1]
            local Objects = Cam[7]
            local ObjCount = #Objects
            if ObjCount == 0 then
                continue
            end
            Pass:reset()
            Pass:setProjection(1, Cam[5])
            Pass:setDepthTest()
            Pass:setDepthWrite()
            -- iter and draw obj

            local ClipLayer = 0 -- used for 'stencils' (i use depth for them here)

            for ObjIdx = 1, ObjCount do
                local Obj = Objects[ObjIdx]
                local Func = Stack[Obj[1]]

                -- commented out cause i unsure about this, since its meant to process objects ancestrally. Not globally
                --[[local TransformMatrix = Obj[2][1]

                if TransformMatrix[4] == 1 then
                    -- 4 points to the 'invalid' flag, where 1 == true
                    -- lazy-rebuild matrix with the correct resolution
                    Obj[2]:RebuiltMatrix(Cam[6])
                    -- 6 points to resolution
                end]]

                Func(TransformMatrix, Obj)
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
