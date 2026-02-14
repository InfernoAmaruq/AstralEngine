local EntityService = GetService("Entity")

local WorldCam = RES["CAMERA"]
local CamComp = WorldCam.Camera

WorldCam:AddComponent("UICamera", { Camera = CamComp })
WorldCam:AddComponent("Ancestry")

local UICanvas = EntityService.New("Canvas")
UICanvas:AddComponent("UICanvas")
UICanvas.Ancestry.Parent = WorldCam
UICanvas.UITransform.ScalePosition = vec2(0.1, 0.1)
UICanvas.UITransform.OffsetPosition = vec2(30, 190)
print("MAT:", UICanvas.UITransform.Matrix)
UICanvas.UITransform.OffsetPosition = vec2(30, 190)
print("MAT:", UICanvas.UITransform.Matrix)
UICanvas.UITransform.OffsetPosition = vec2(30, 190)
print("MAT:", UICanvas.UITransform.Matrix)

AstralEngine.Window.SetCursorIcon("crosshair")

task.wait(2)

AstralEngine.Window.SetCursorIcon()
