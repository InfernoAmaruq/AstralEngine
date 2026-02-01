local BALL = RES["BALL"]

local Collider = BALL.Collider
Collider.Touched:Connect(function(Col, Contact)
    print("TOUCHED:", Col, Contact)
end)

local World = RES["WORLD"].World

local T = World:Overlap(ENUM.ColliderType.Sphere, vec3(100, 100, 100), vec3(), vec3(), nil, nil, {})

local CAM = RES["CAMERA"]

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

GetService("RunService").BindToStep("CAM_STEP", 450, function(dt)
    local F = KeyArr[W] and 1 or (KeyArr[S] and -1) or 0
    local R = KeyArr[D] and 1 or (KeyArr[A] and -1) or 0

    CAM.Transform.Position = CAM.Transform.Position + vec3(F * CamSpeed * dt, 0, R * CamSpeed * dt)
end)
