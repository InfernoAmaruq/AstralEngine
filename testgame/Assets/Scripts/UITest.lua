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

local UICOMPONENT2 = EntityService.New("Canvas2")
UICOMPONENT2:AddComponent("UICanvas")
UICOMPONENT2.Ancestry.Parent = UICanvas
UICOMPONENT2.UITransform.ScalePosition = vec2(0.5, 0.5)
UICOMPONENT2.UITransform.OffsetPosition = vec2(0, 0)
UICOMPONENT2.UITransform.ScaleSize = vec2(0.5, 0.5)
UICOMPONENT2.UITransform.OffsetSize = vec2(0, 0)
UICOMPONENT2.UICanvas.Color = color.fromRGBA(255, 0, 0, 255)

task.wait(2)
UICanvas.UITransform.Rotation = 37
UICOMPONENT2.UITransform.Rotation = -37

AstralEngine.Window.SetCursorIcon("crosshair")

task.wait(2)

AstralEngine.Window.SetCursorIcon()
