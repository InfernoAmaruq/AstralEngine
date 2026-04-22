local Module = require("LuaIK")

local Bones = {}
local List = {}

local function NewPoint(Pos, Rad)
    local t = {}

    t.r = 0
    t.g = 0
    t.b = 0

    t.Position = Pos
    t.Radius = Rad

    return t
end

local function NewBone(length)
    local t = {}

    local Point = NewPoint(Vec3(), 0.5)
    Point.b = 1

    t.Point = Point
    t.Bone = Module.newIKBone(length)

    table.insert(Bones, t)

    return t
end

local Tex = AstralEngine.Graphics.NewTexture(1000, 1000)
local Pass = AstralEngine.Graphics.NewPass(Tex)[1]

local Scale = 25

local Cont = Module.newIKController(10)

local function Draw(MainPass)
    Cont:solve()
    for _, v in ipairs(Bones) do
        local n = vec3(v.Bone:getPos())
        v.Point.Position:set(n)
    end

    Pass:reset()

    Pass:setProjection(1, mat4():orthographic(-Scale, Scale, -Scale, Scale, -10, 10))

    Pass:setColor(1, 1, 1, 1)
    Pass:plane(0, 0, 9, Scale * 2, Scale * 2, quat():setEuler(0, 0, 0))

    for _, v in pairs(List) do
        Pass:push("state")
        Pass:setColor(v.r, v.g, v.b)
        Pass:circle(v.Position, v.Radius)

        if v.LinkTo then
            Pass:setColor(0, 0, 0)
            Pass:line(v.Position, v.LinkTo.Position)
        end

        Pass:pop("state")
    end

    MainPass:reset()
    MainPass:fill(Tex[1])
end

List.Root = NewPoint(Vec3(), 1)
List.Root.g = 1

List.Target = NewPoint(Vec3(-15, -10, 0), 1)
List.Target.r = 1

GetService("Renderer").PassStorage.AddPass(false, Pass, 10000000)

GetService("RunService").BindToStep("RenderUpd", ENUM.StepPriority.RenderSubmit - 5, Draw)

-- LOGIC

local Bone1 = NewBone(7)
local Bone2 = NewBone(4)
local Bone3 = NewBone(2)
local Bone4 = NewBone(2)
local Bone5 = NewBone(2)

List.Bone1 = Bone1.Point
List.Bone2 = Bone2.Point
List.Bone3 = Bone3.Point
List.Bone4 = Bone4.Point
List.Bone5 = Bone5.Point

Cont:setTarget(List.Target.Position)
Cont:setRoot(List.Root.Position)

Bone2.Point.Position:set(-5, -5, 0)
Bone3.Point.Position:set(-10, -10, 0)

Bone5.Point.LinkTo = Bone4.Point
Bone4.Point.LinkTo = Bone3.Point
Bone3.Point.LinkTo = Bone2.Point
Bone2.Point.LinkTo = Bone1.Point
Bone1.Point.LinkTo = List.Root

Bone1.Bone:setDegreesOfFreedom("xy")

Cont:setBone(1, Bone1.Bone)
Cont:setBone(2, Bone2.Bone)
Cont:setBone(3, Bone3.Bone)
Cont:setBone(4, Bone4.Bone)
Cont:setBone(5, Bone5.Bone)

local MODE = "sine"
if MODE == "mouse" then
    AstralEngine.Window.GrabMouse(true)
end

local IS = GetService("InputService").GetMouse()
GetService("RunService").BindToStep("RenderUpd2", ENUM.StepPriority.RenderSubmit - 10, function()
    if MODE == "mouse" then
        local PosX, PosY = IS:GetPosition()

        local Vector = vec2(PosX, PosY) / vec2(AstralEngine.Window.W, AstralEngine.Window.H)

        local LerpedX = -(Scale + Vector.x * (-Scale - Scale))
        local LerpedY = -(Scale + Vector.y * (-Scale - Scale))
        List.Target.Position:set(LerpedX, LerpedY, 0)
        Cont:setTarget(List.Target.Position)
    elseif MODE == "sine" then
        local s = math.sin(os.clock())
        local s2 = math.cos(os.clock() / 2)
        List.Target.Position:set(s2 * 5 - 10, s * 10, 0)
        Cont:setTarget(List.Target.Position)
    end
end)
