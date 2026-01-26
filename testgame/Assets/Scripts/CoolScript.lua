local BALL = RES["BALL"]

local Collider = BALL.Collider
Collider.Touched:Connect(function(Col, Contact)
    print("TOUCHED:", Col, Contact)
end)

local World = RES["WORLD"].World
print("Has World:", World)

print("WALL:", RES["WALL"])

local RP = GetService("Physics").RaycastParams.New()

GetService("RunService").BindToStep("CAST", 350, function()
    local CastData = World:Raycast(vec3(0, 0, 0), vec3(0, 0, -100))
end)

-- conclusion: the raycast is lightly massaging the cpu
