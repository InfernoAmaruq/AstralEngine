print"GD RUN"
if AstralEngine.SplashPlaying then
    AstralEngine.Signals.SplashEnded:Wait()
end

local RunService = GetService("RunService")
local InputService = GetService("InputService")

local Entity = GetService("Entity")

local Camera = Entity.New("Camera")
Camera:AddComponent("Camera", { FOV = math.rad(90), DrawToScreen = true, NearestSampler = true })
local Transform = Camera:GetComponent("Transform")

_G.CAM = Camera

local CACHE = InputService.__GetKeyArr()
local MoveSpeed = 10

AstralEngine.Window.GrabMouse(true)

local E = ENUM.KeyCode
local WK = E.w.RawValue
local SK = E.s.RawValue
local AK = E.a.RawValue
local DK = E.d.RawValue
local QK = E.q.RawValue
local EK = E.e.RawValue
local SHK = E.lshift.RawValue

local Mouse = InputService.GetMouse()

local RotationStep = math.rad(0.5)

local Pitch, Yaw = 0, 0
local LastPitch, LastYaw = Pitch, Yaw

Mouse.WheelMoved:Connect(function(_, b)
    MoveSpeed += b
end)

Mouse.MouseMoved:Connect(function(_, _, dx, dy)
    LastPitch = Pitch
    LastYaw = Yaw

    Pitch = Pitch - dx * RotationStep
    Yaw = Yaw - dy * RotationStep
end)

RunService.BindToStep("CamMove", ENUM.StepPriority.CPUUpdate - 50, function(dt)
    local x = (CACHE[DK] and 1 or 0) - (CACHE[AK] and 1 or 0)
    local z = (CACHE[WK] and 1 or 0) - (CACHE[SK] and 1 or 0)
    local y = (CACHE[EK] and 1 or 0) - (CACHE[QK] and 1 or 0)

    local Boost = (CACHE[SHK] and 5 or 1)

    if LastPitch ~= Pitch or LastYaw ~= Yaw then
        Transform.Rotation = vec3(Pitch, Yaw, 0)
    end
    if x ~= 0 or y ~= 0 or z ~= 0 then
        local Ori = Transform.Orientation
        local Forward, Right, Up = Ori * vec3.forward, Ori * vec3.right, Ori * vec3.up
        local mv = (Forward * z + Right * x + Up * y):normalize():mul(MoveSpeed * Boost * dt)
        Transform.Position = Transform.Position + mv
    end
end)

GetService("ContextActionService").Bind("TEST",100,function(x)
end,ENUM.KeyCode.z,ENUM.KeyCode.x,ENUM.KeyCode.c)

@ifdef<!TEST_TERRAIN>{
    local Block = Entity.New("Block")
    Block:AddComponent("Transform", { Position = Vec3(0, -10, 0) })
    Block:AddComponent("Shape", { Color = color.Red, Size = Vec3(50, 5, 50) })

    local Sphere = Entity.New("Sphere")
    Sphere:AddComponent("Transform", { Position = Vec3(3, 0, -10) })
    Sphere:AddComponent("Shape", { Shape = ENUM.ShapeType.Sphere, Color = color.Blue, Size = Vec3(5, 5, 5) })

    local Torus = Entity.New("Torus")
    Torus:AddComponent("Transform", { Position = Vec3(-6, 2, -14), Rotation = Vec3(math.rad(45), math.rad(45), 0) })
    Torus:AddComponent(
        "Shape",
        { Shape = ENUM.ShapeType.Cylinder, Color = (color.Red | color.Green), Size = Vec3(2, 8, 8) }
    )

    local Wall = Entity.New("Wall")
    Wall:AddComponent("Transform", { Position = Vec3(-10, 30, -20), Rotation = Vec3(math.rad(20), math.rad(5), 0) })
    Wall:AddComponent("Shape", { Color = 0xff00ffff, Size = Vec3(20, 20, 1) })
local TEST_TERRAIN = false
}

local Skybox = Entity.New("Skybox")
Skybox:AddComponent("Skybox", { Texture = AstralEngine.Graphics.NewTexture("Skybox.jpg") })

local PHYSTEST = true
local GRAPHTEST = true

local CAS = GetService("ContextActionService")

if TEST_TERRAIN then
    require("GAME2")
end

if PHYSTEST and not TEST_TERRAIN then
    local Phys = GetService("Physics")
    local World = Phys.NewWorld()

    Phys.SetMainWorld(World)

    local Collider = Block:AddComponent("Collider", { ColliderType = ENUM.ColliderType.Box })
    Collider.Static = true

    local SP = Sphere:AddComponent("Collider", { ColliderType = ENUM.ColliderType.Sphere })

    Camera:AddComponent("Collider", { ColliderType = ENUM.ColliderType.Sphere, Size = Vec3(2, 2, 2) })
    Camera.Anchored = true

    Wall:AddComponent("Collider", { ColliderType = ENUM.ColliderType.Box })

    CAS.Bind("SPACE_PRESS", 100, function(a)
        if not a.State then
            return
        end
    end, ENUM.KeyCode.r)
    CAS.Bind("SPACE_PRESS2", 200, function(a)
        if not a.State then
            return
        end
    end, ENUM.KeyCode.r)
end
if GRAPHTEST then
 --   task.wait(1)
    Torus:GetComponent"Shape".Color = color.fromRGBA(0, 255, 0, 253)
    Sphere:GetComponent"Shape".Color = color.fromRGBA(0, 0, 255, 100)
end

local LBMFFILE = require("LBMFTEST")
local function RECURSE(t)
    for i,v in pairs(t) do
        if type(v) == "table" then
            print("RECURSE:")
            RECURSE(v)
        else
            print(i,v)
        end
    end
end
RECURSE(LBMFFILE)

local S,COMPILE2 = pcall(require,"CompileNEW/init.lua")
local Lexer = COMPILE2.Lexer
Lexer.SetLanguage(COMPILE2.ConfigPresets.lua.Language)
Lexer.SetCallback(function(a)
    return -1
end)
local s,t,str = pcall(Lexer.ExtractDirectives,[[
--VOID
@CODE;
print("Hi")
]])

print("OUT:\n",str)
print("DIR:")
for i,v in pairs(t) do
    print(">",i,v.Type)
end

-- TESTING ANCESTRY

print("\n>FOLDER TEST SUCCESS:",pcall(function()
    local FOLDER = Entity.New("FOLDER")
    FOLDER:AddComponent("Ancestry")
    print("CONTAINER:",FOLDER)

    local Obj1 = Entity.New("OBJECT1")
    local Obj2 = Entity.New("OBJECT2")
    Obj1:AddComponent("Ancestry")
    Obj2:AddComponent("Ancestry")

    Obj1.Parent = FOLDER.__id
end))
QUIT()
