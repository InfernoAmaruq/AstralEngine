local AssetService = GetService("AssetMapService")
local EntityService = GetService("Entity")

-- declare camera
local CameraEnt = EntityService.New("CameraEnt")
local CamComp = CameraEnt:AddComponent("Camera", {
    FOV = 90,
    DrawToScreen = true,
})

local IntroMod = require("BaseIntro")
print("INT:", IntroMod)
print("CACHED:", pcall(require, "BaseIntro"))
--local Int = IntroMod.Load(CameraEnt)
coroutine.yield()
-- wait a bit since this is launch.lua

--[[Int:Play()
print("WAIT")

Int.Finished:Wait()
print("DONE")]]

-- END

--[[local UICam = CameraEnt:AddComponent("UICamera", {
    Camera = CamComp,
    ProcessInputs = true,
})]]

local ok, Err = pcall(CameraEnt.AddComponent, CameraEnt, "UICamera", { Camera = CamComp, ProcessInputs = true })
print(ok, Err)

if not ok then
    return
end

local LayoutContainer = EntityService.New("LayoutContainer")
LayoutContainer:AddComponent("Ancestry")
local LCRoot = LayoutContainer:AddComponent("UIRoot")
LCRoot.ScaleSize = vec2(0.5, 0.5)
LCRoot.ScalePosition = vec2(0.5, 0.5)
LCRoot.AnchorPoint = vec2(0.5, 0.5)
LayoutContainer.Parent = CameraEnt
LayoutContainer:AddComponent("UICanvas")
LayoutContainer:AddComponent("UIVerticalLayout")

local Map = AssetService.AssetMapFromPath("./Assetmap.lua")

local TextFrames = {}

local c = {
    color.fromRGB(255, 0, 0),
    color.fromRGB(0, 255, 0),
    color.fromRGB(0, 0, 255),
    color.fromRGB(255, 0, 255),
}

for i = 1, 4 do
    local Object = AssetService.LoadAssetMap(Map).ROOT
    Object.UICanvas.Color = c[i]
    Object.Parent = LayoutContainer
    TextFrames[i] = Object
end

print(LayoutContainer.UIVerticalLayout, LayoutContainer.UIVerticalLayout:RebuildChildren())
print("////TEST2")

local C1 = EntityService.New("C1")
local C2 = EntityService.New("C2")

C1:AddComponent("Ancestry")
C2:AddComponent("Ancestry")

C1:AddComponent("UIRoot", {
    Size = {
        Offset = vec2(100, 150),
    },
    Position = {
        Offset = vec2(100, 200),
    },
})
C2:AddComponent("UIRoot", {
    Size = {
        Offset = vec2(300, 300),
    },
    Position = {
        Offset = vec2(700, 400),
    },
})

C1.Parent = CameraEnt
C2.Parent = CameraEnt

C1:AddComponent("UICanvas", { Color = color.fromRGBA(255, 255, 255, 255) })
C2:AddComponent("UICanvas")

local Loose = EntityService.New("E")
Loose:AddComponent("Ancestry")
Loose:AddComponent("UIRoot", { Size = { Scale = vec2(1, 1) } })
Loose:AddComponent("UICanvas", { Color = color.fromRGB(255, 0, 0) })

print("END")
