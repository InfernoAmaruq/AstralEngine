local EntityService = GetService("Entity")

local WorldCam = RES["CAMERA"]
local CamComp = WorldCam.Camera

WorldCam:AddComponent("UICamera", { Camera = CamComp })
