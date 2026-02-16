local EntityService = GetService("Entity")

local WorldCam = RES["CAMERA"]
local CamComp = WorldCam.Camera

WorldCam:AddComponent("UICamera", { Camera = CamComp, ProcessInputs = true })
WorldCam:AddComponent("Ancestry")

local UICanvas = EntityService.New("Canvas")
UICanvas:AddComponent("UICanvas")
UICanvas.Ancestry.Parent = WorldCam
UICanvas.UIRoot.ScalePosition = vec2(0.1, 0.1)
UICanvas.UIRoot.OffsetPosition = vec2(30, 190)
print("MAT:", UICanvas.UIRoot.Matrix)
UICanvas.UIRoot.OffsetPosition = vec2(30, 190)

local UICOMPONENT2 = EntityService.New("Canvas2")
UICOMPONENT2:AddComponent("UICanvas")
UICOMPONENT2.Ancestry.Parent = UICanvas
UICOMPONENT2.UIRoot.OffsetPosition = vec2(0, 0)
UICOMPONENT2.UIRoot.ScaleSize = vec2(1, 1)
UICOMPONENT2.UIRoot.OffsetSize = vec2(0, 0)
UICOMPONENT2.UIRoot.AnchorPoint = vec2(1, 1)
UICOMPONENT2.UICanvas.Color = color.fromRGBA(255, 0, 0, 255)

local Blue = EntityService.New("Canvas3")
Blue:AddComponent("UICanvas")
Blue.Ancestry.Parent = UICOMPONENT2
Blue.UIRoot.ScalePosition = vec2(-0.1, 0)
Blue.UIRoot.OffsetPosition = vec2.zero
Blue.UIRoot.ScaleSize = vec2(0.5, 0.5)
Blue.UIRoot.AnchorPoint = vec2(0, 0)
Blue.UIRoot.OffsetSize = vec2(0, 0)
Blue.UICanvas.Color = color.fromRGBA(0, 0, 255, 255)

local Obj2 = EntityService.New("Canvas5")
Obj2:AddComponent("UICanvas")
Obj2.Ancestry.Parent = UICanvas
Obj2.UICanvas.Color = color.fromRGB(255, 0, 255)
Obj2.UIRoot.ScalePosition = vec2(-0.1, -0.1)

local Loose = EntityService.New("Canvas4")
Loose:AddComponent("UICanvas")
Loose.Parent = WorldCam
Loose.UIRoot.ScalePosition = vec2(0.5, 0.5)
Loose.UICanvas.Color = color.fromRGBA(0, 255, 0, 255)

Obj2.UIRoot.MouseEnter:Connect(function(x, y)
    print("ENTER", x, y)
end)

Obj2.UIRoot.MouseLeave:Connect(function(x, y)
    print("LEAVE", x, y)
end)

Obj2.UIRoot.MouseButton:Connect(function(state, b, x, y)
    print("CLICK:", state, b, x, y)
end)

Obj2.UIRoot.MouseScroll:Connect(function(x, y)
    print("SCROLL", x, y)
end)

task.wait(2)
UICanvas.UIRoot.Rotation = 37
UICanvas.UIRoot.ClipDescendantInstances = true
UICOMPONENT2.UIRoot.ClipDescendantInstances = true
AstralEngine.Window.SetCursorIcon("crosshair")

task.wait(2)

AstralEngine.Window.SetCursorIcon()

local InputSer = GetService("InputService")
local Mouse = InputSer.GetMouse()

Loose.UIRoot.OffsetSize = vec2(200, 100)
Loose.UIRoot.Rotation = 23
