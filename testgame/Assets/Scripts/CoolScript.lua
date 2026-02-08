local BALL = RES["BALL"]

local Collider = BALL.Collider
Collider.Touched:Connect(function(Col, Contact)
    print("TOUCHED:", Col, Contact)
end)

local World = RES["WORLD"].World

local T = World:Overlap(ENUM.ColliderShape.Sphere, vec3(100, 100, 100), vec3(), vec3(), nil, nil, {})
print("OVERLAP:", T[1])

local CAM = RES["CAMERA"]

print("\n\n\n\n\nCAM TEST:")

local Comp = CAM:GetComponent("Camera")
print(Comp.W, Comp.H)
print(Comp.FOV)
print(Comp.Aspect)
print(Comp.OITTex)

print("\n\n\n\n\n")

AstralEngine.Signals.OnWindowResize:Connect(function(w, h)
    print(Comp.W, Comp.H, Comp.Aspect, w, h)
end)

local CamSpeed = 3

local InpService = GetService("InputService")

local KeyArr = InpService.__GetKeyArr()

local KeyEnum = ENUM.KeyCode
local W = KeyEnum.w.RawValue
local D = KeyEnum.d.RawValue
local A = KeyEnum.a.RawValue
local S = KeyEnum.s.RawValue
local E = KeyEnum.e.RawValue
local Q = KeyEnum.q.RawValue

BALL.Collider.Kinematic = true
BALL.Collider:MoveKinematic(vec3(0, 2, 0), nil, 5)

GetService("RunService").BindToStep("CAM_STEP", 450, function(dt)
    local F = KeyArr[W] and 1 or (KeyArr[S] and -1) or 0
    local R = KeyArr[D] and 1 or (KeyArr[A] and -1) or 0

    CAM.Transform.Position = CAM.Transform.Position + vec3(F * CamSpeed * dt, 0, R * CamSpeed * dt)
end)

local png = AstralEngine.Graphics.NewTexture("../Img/cart.png")
local NewE = GetService("Entity").New("TEXTURE")
NewE:AddComponent("Transform", { Position = Vec3(1, 0, -9.48) })
NewE:AddComponent("SpriteRenderer", { Texture = png, Color = color.fromRGBA(0, 255, 0, 255), Size = Vec2(2, 2) })

print("GET RESOLUTION")
print("RES:", CAM.Camera.Resolution)
print("BIND")

GetService("ContextActionService").Bind("SPACE1", 100, function()
    print("SPACE1")
end, ENUM.KeyCode.z)

GetService("ContextActionService").Bind("SPACE2", 50, function()
    print("SPACE2")
    return true
end, ENUM.KeyCode.z)

print(CAM.Camera:ScreenPointToRay(500, 500))
task.wait(2)
print(CAM.Camera:WorldToScreenPoint(RES["WALL"].Transform.Position))

GetService("RunService").BindToStep("CAM", 950, function(pass) end)
