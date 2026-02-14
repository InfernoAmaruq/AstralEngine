local EntityService = GetService("Entity")

local WorldCam = RES["CAMERA"]
local CamComp = WorldCam.Camera

WorldCam:AddComponent("UICamera", { Camera = CamComp })
WorldCam:AddComponent("Ancestry")

local UICanvas = EntityService.New("Canvas")
UICanvas:AddComponent("UICanvas")
UICanvas.UITransform.ScalePosition = vec2(0.5, 0.5)
UICanvas:AddComponent("Ancestry")
UICanvas.Ancestry.Parent = WorldCam

AstralEngine.Window.SetCursorIcon("crosshair")

task.wait(2)

AstralEngine.Window.SetCursorIcon()
