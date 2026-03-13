local AssetService = GetService("AssetMapService")
local EntityService = GetService("Entity")

-- declare camera
local CameraEnt = EntityService.New("CameraEnt")
local CamComp = CameraEnt:AddComponent("Camera", {
    FOV = 90,
    DrawToScreen = true,
})

coroutine.yield()

local CSTRUCT = lovr.data.newCStruct(10)

local NEWCSTRUCT = lovr.data.newCStruct(1)

print(pcall(function()
    print(CSTRUCT:getSize())
    print(CSTRUCT:getName())
    print(CSTRUCT:getPointer())
    print(CSTRUCT:writeF64(1, 3231))
    print("READ", CSTRUCT:get(1))

    print("\n\n WRITE INT:")
    CSTRUCT:writeI64(2, 100, 100)
    print("READ INT:", CSTRUCT:get(2))

    print("TYPE 1:", CSTRUCT:getType(1))
    print("TYPE 2:", CSTRUCT:getType(2))
    print("TYPE 3:", CSTRUCT:getType(3))

    print("WRITE STR")
    CSTRUCT:writeString(10, "Hello World!")
    print("STR:", CSTRUCT:get(10))

    NEWCSTRUCT:writeF64(1, 1000)
    CSTRUCT:writeCStruct(5, NEWCSTRUCT)
    print("STRUCT", CSTRUCT:getType(5), CSTRUCT:get(5))

    CSTRUCT:setSize(5)
end))

for i, v in pairs(lovr.thread) do
    print(i, v)
end

print("CST:", CSTRUCT)
local BLOB = lovr.graphics.newTexture(100, 100)[1]
print(BLOB)
local CHANNEL = lovr.thread.newChannel("name")
local Thread = lovr.thread.newThread([[
    lovr = require('lovr')
    lovr.thread = require('lovr.thread')
    require('lovr.data')
    require('lovr.graphics')
    print("THREAD ALIVE")
    print("READ:",...)
    local cstruct = select(1,...)
    local channel = lovr.thread.getChannel'name'
    print("THREAD LOCATION:",debug.getinfo(1,"S").source)
    print(channel:peek())
    print(pcall(function()
        print(cstruct.get)
        print("READ:",cstruct:get(1))
        print("READ 2:",cstruct:get(5), cstruct:get(5):get(1))
    end))
    collectgarbage('collect')
]])

Thread:start(CSTRUCT, BLOB)
task.wait(1)
collectgarbage("collect")

local SHAPE1 = EntityService.New("Shape")
SHAPE1:AddComponent("Transform", { Position = vec3(1, -1, -4) })
SHAPE1:AddComponent("Shape", { Size = vec3(1, 1, 1), Color = color.Blue })

local SHAPE2 = EntityService.New("Shape")
SHAPE2:AddComponent("Transform", { Position = vec3(0, 0, -3) })
SHAPE2:AddComponent("Shape", { Size = vec3(1, 1, 1), Color = color.fromRGBA(255, 0, 0, 120) })

print("\n\nTEST TS\n\n")

local TagService = GetService("TagService")

local TAG = "TESTTAG"

TagService.TagAdded:Connect(function(...)
    print("TAG ADD", ...)
end)

TagService.TagRemoved:Connect(function(...)
    print("TAG REMOVE", ...)
end)

print(pcall(function()
    print("HASTAG:", TagService.HasTag(SHAPE1, TAG))
    TagService.AddTag(SHAPE1, TAG)
    print("HASTAG:", SHAPE1:HasTag(TAG))

    print("GET TAGGED")
    for i, v in pairs(TagService.GetAllTags(SHAPE1, TAG)) do
        print("", i, v)
    end
    print("END")
end))

print("\n\nEND TEST TS\n\n")
task.wait(3)

local IntroMod = require("BaseIntro")
--local Int = IntroMod.Load(CameraEnt)

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

local function RunIOTest()
    local ANSIColor = AstralEngine.Plugins.ANSIColor

    AstralEngine.Log("TEST1", "warn")
    AstralEngine.Error("Test2", ANSIColor.Green .. "testing" .. ANSIColor.Reset)
end

print(pcall(RunIOTest))

print("\nCHANGE IO\n")

--lovr.filesystem.write("output.txt", "")
local Path = lovr.filesystem.getSaveDirectory() .. "/output.txt"
local f = io.output(Path)
io.stdout = f

print(pcall(RunIOTest))

if not ok then
    return
end

local Sigma = CameraEnt
local Streng = ("Hello {Sigma}"):interpolate()

local LayoutContainer = EntityService.New("LayoutContainer")
LayoutContainer:AddComponent("Ancestry")
local LCRoot = LayoutContainer:AddComponent("UIRoot")
LCRoot.ScaleSize = vec2(0.5, 0.5)
LCRoot.ScalePosition = vec2(0.5, 0.5)
LCRoot.AnchorPoint = vec2(0.5, 0.5)
LayoutContainer.Parent = CameraEnt
LayoutContainer:AddComponent("UICanvas", { Color = color.fromRGB(180, 180, 180) })
local Comp = LayoutContainer:AddComponent("UIVerticalLayout")
Comp.ScalePadding = vec2(0.01, 0.01)
Comp.AlignmentVertical = ENUM.UIAlignPosition.Top

local Map = AssetService.AssetMapFromPath("./Assetmap.lua")

local TextFrames = {}

local c = {
    color.fromRGB(255, 0, 0),
    color.fromRGB(0, 255, 0),
    color.fromRGB(0, 0, 255),
    color.fromRGB(255, 0, 255),
    color.fromRGB(255, 255, 0),
}

local s = {
    0.5,
    1,
    0.3,
    1.1,
    0.9,
}

for i = 1, 5 do
    local Object = AssetService.LoadAssetMap(Map).ROOT
    Object.UICanvas.Color = c[i]
    local CurSize = Object.UIRoot.ScaleSize
    Object.UIRoot.ScaleSize = vec2(s[i], CurSize.y)
    Object.Parent = LayoutContainer
    TextFrames[i] = Object
end

TextFrames[1].UIRoot.Rotation = 45

task.wait(1.5)

Comp.WrapInstances = true

task.wait(1.5)

TextFrames[3].UIRoot.OffsetSize = TextFrames[3].UIRoot.OffsetSize + vec2(0, 50)

task.wait(1.5)

LayoutContainer.UIRoot.ScaleSize = LayoutContainer.UIRoot.ScaleSize + vec2(0, -0.2)
local t = debug.cpuclock()
LayoutContainer.UIRoot.ClipDescendantInstances = true
print(debug.cpuclock() - t)

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
