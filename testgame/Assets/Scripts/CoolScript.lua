print("RESERVE:", RES, RES["FLDR"])
print("Hello world 2")

local FLDR = RES["FLDR"]
local CAMERA = RES["CAMERA"]

for i in FLDR:IterChildren() do
    print("HAS CHILDREN:", i)
end

if not CAMERA then
    return
end

local Speed = 0.5
local BALL = RES["BALL"]
local Transform = BALL.Transform

local t = 0
local last
GetService("RunService").BindToStep("Func", 300, function(dt)
    Transform.Position = Transform.Position + Vec3(Speed * dt, 0, 0)
end)

local i = 0

while task.wait(3) do
    i = i + 1
    Speed = -Speed

    if i == 3 then
        AstralEngine.Window.SetSize(700, 1200)
    end
end
