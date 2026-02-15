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
UICOMPONENT2.UITransform.OffsetPosition = vec2(0, 0)
UICOMPONENT2.UITransform.ScaleSize = vec2(1, 1)
UICOMPONENT2.UITransform.OffsetSize = vec2(0, 0)
UICOMPONENT2.UITransform.AnchorPoint = vec2(1, 1)
UICOMPONENT2.UICanvas.Color = color.fromRGBA(255, 0, 0, 255)

local Blue = EntityService.New("Canvas3")
Blue:AddComponent("UICanvas")
Blue.Ancestry.Parent = UICOMPONENT2
Blue.UITransform.ScalePosition = vec2(-0.1, 0)
Blue.UITransform.OffsetPosition = vec2.zero
Blue.UITransform.ScaleSize = vec2(0.5, 0.5)
Blue.UITransform.AnchorPoint = vec2(0, 0)
Blue.UITransform.OffsetSize = vec2(0, 0)
Blue.UICanvas.Color = color.fromRGBA(0, 0, 255, 255)

local Obj2 = EntityService.New("Canvas5")
Obj2:AddComponent("UICanvas")
Obj2.Ancestry.Parent = UICanvas
Obj2.UICanvas.Color = color.fromRGB(255, 0, 255)
Obj2.UITransform.ScalePosition = vec2(-0.1, -0.1)

local Loose = EntityService.New("Canvas4")
Loose:AddComponent("UICanvas")
Loose.Parent = WorldCam
Loose.UITransform.ScalePosition = vec2(0.5, 0.5)
Loose.UICanvas.Color = color.fromRGBA(0, 255, 0, 255)

task.wait(2)
UICanvas.UITransform.Rotation = 37
UICanvas.UITransform.ClipDescendantInstances = true
UICOMPONENT2.UITransform.ClipDescendantInstances = true
AstralEngine.Window.SetCursorIcon("crosshair")

task.wait(2)

AstralEngine.Window.SetCursorIcon()
