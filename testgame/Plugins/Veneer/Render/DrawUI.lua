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
local Registry = {}

function Renderer.VeneerUI.AddToStack(ComponentName, Function)
    local Id = #FuncStack + 1
    FuncStack[Id] = Function
    Registry[ComponentName] = Id
end

function Renderer.VeneerUI.GetStackIdFromName(ComponentName)
    return Registry[ComponentName]
end

Renderer.Late[#Renderer.Late + 1] = function()
    -- bind

    print("COMPILE UI SHADER")

    local ShaderService = GetService("ShaderService")
    local V, F = ShaderService.ComposeShader(ENUM.ShaderType.Graphics, "UIMain", {
        Include = {},
    })

    print("COMPILED!", V, F)
    local MainUIShader = lovr.graphics.newShader(V, F)

    local ComponentManager = GetService("Component")

    local StencilActs = { "keep", "keep", "increment" }

    GetService("RunService").BindToStep("VENEER_UI_DRAW", Plugin.Config.BaseRenderBand, function()
        local UICams = Renderer.VeneerUI.UICameras
        local Stack = FuncStack

        local Comp = ComponentManager
        local SetComp = Comp.SetComponents
        local SActs = StencilActs

        for i = 1, #UICams do
            local Cam = UICams[i]
            local Pass = Cam[1]
            local Objects = Cam[7]
            local ObjCount = #Objects
            if ObjCount == 0 then
                continue
            end
            Pass:reset()
            Pass:setShader(MainUIShader)
            Pass:setProjection(1, Cam[5])
            Pass:setDepthTest()
            Pass:setDepthWrite()

            -- iter and draw obj

            local ClipLayer = 0 -- used for 'stencils' (i use depth for them here)

            local HighestTest = 0

            for ObjIdx = 1, ObjCount do
                local Obj = Objects[ObjIdx]
                local Transform = SetComp[Obj]["UITransform"]
                local Matrix = Transform[1]

                local ShouldClipChildren = Transform[13]
                local ClipDepth = Transform[14]

                local Invalid = Matrix[4]
                if Invalid == 1 then
                    AstralEngine.Error("INVALID MATRIX FOUND IN UI OBJECT!", "VeneerUI", 1)
                end

                local FuncCall = FuncStack[Transform[12]]

                if ShouldClipChildren then
                    if HighestTest > ClipDepth then
                        -- noting cause I WILL forget! We flush the stencil buffer on exit, since we cant just replace since we using increment
                        Pass:setColorWrite()
                        Pass:setStencilWrite("zero")
                        Pass:fill()
                        Pass:setStencilWrite()
                        Pass:setColorWrite(true, true, true, true)
                    end
                    HighestTest = ClipDepth

                    Pass:setStencilWrite(SActs, ClipDepth)

                    if ClipDepth > 1 then
                        Pass:setStencilTest("gequal", ClipDepth - 1)
                    end
                elseif ClipDepth > 0 then
                    Pass:setStencilTest(">=", ClipDepth)
                end

                Pass:push("state")
                FuncCall(Pass, Obj, Matrix)
                Pass:pop("state")
                Pass:setStencilWrite()
                Pass:setStencilTest()
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
