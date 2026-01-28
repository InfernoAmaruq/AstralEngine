local BALL = RES["BALL"]

local Collider = BALL.Collider
Collider.Touched:Connect(function(Col, Contact)
    print("TOUCHED:", Col, Contact)
end)

local World = RES["WORLD"].World

GetService("RunService").BindToStep("CAST", 350, function()
    local CastData = World:Shapecast(ENUM.ColliderType.Sphere, vec3(30, 30, 30), vec3(0, 0, 0), vec3(), vec3(0, 0, 100))
    print("CAST:", CastData)
end)
