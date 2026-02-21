local AssetService = GetService("AssetMapService")
local EntityService = GetService("Entity")

-- declare camera
local CameraEnt = EntityService.New("CameraEnt")
local CamComp = CameraEnt:AddComponent("Camera", {
    FOV = 90,
    DrawToScreen = true,
})

local UICam = CameraEnt:AddComponent("UICamera", {
    Camera = CamComp,
    ProcessInputs = true,
})

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

for i = 1, 4 do
    local Object = AssetService.LoadAssetMap(Map).ROOT
    Object.Parent = LayoutContainer
    TextFrames[i] = Object
end
