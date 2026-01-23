print("RESERVE:", RES, RES["FLDR"])
print("Hello world 2")

local FLDR = RES["FLDR"]
local CAMERA = RES["CAMERA"]

if not CAMERA then
    return
end

local Speed = 0.5
local BALL = RES["BALL"]
local Transform = BALL.Transform

GetService("RunService").BindToStep("Func", 300, function(dt)
    Transform.Position = Transform.Position + Vec3(Speed * dt, 0, 0)
end)

local i = 0
while task.wait(1) do
    i = i + 1
    if i == 3 then
        local SM = GetService("SceneManager")
        SM.UnloadScene(SM.GetCurrentScene())
    end
end

--[[
--NOTES:
--disconnect RS n CAS binds
--]]
