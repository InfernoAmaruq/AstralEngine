local EntityService = GetService("Entity")

local WorldCam = RES["CAMERA"]
local CamComp = WorldCam.Camera

WorldCam:AddComponent("UICamera", { Camera = CamComp })

print("TEST")
AstralEngine.Window.SetCursorIcon("crosshair")

task.wait(2)

AstralEngine.Window.SetCursorIcon()
