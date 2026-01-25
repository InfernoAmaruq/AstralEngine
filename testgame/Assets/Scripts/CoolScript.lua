local BALL = RES["BALL"]

print(BALL)

local Collider = BALL.Collider
Collider.Touched:Connect(function(Col, Contact)
    print("TOUCHED:", Col, Contact)
end)
