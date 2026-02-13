local UITransform = require("../UITransform.lua")
local UIDrawable = require("../UIDrawable.lua")
local Canvas = {}

Canvas.Name = "UICanvas"
Canvas.Metadata = {}

local Res = UIDrawable.Reserved

local Indecies = {
    R = Res + 1,
    G = Res + 2,
    B = Res + 3,
    A = Res + 4,
    ColorRaw = Res + 5,
}

local Meta = {
    __index = function(self, Key)
        if Key == "Color" then
            return self[Indecies.ColorRaw]
        end
    end,
    __newindex = function(self, Key, Value)
        if Key == "Color" then
            self[Indecies.ColorRaw] = Value
            local R, G, B, A = Value:unpack()

            self[Indecies.R] = R
            self[Indecies.G] = G
            self[Indecies.B] = B
            self[Indecies.A] = A
        end
    end,
}

Canvas.Metadata.__create = function(Input, Entity)
    AstralEngine.Assert(
        not UIDrawable.EntityHasUIComponent(Entity),
        "ENTITY " .. Entity .. " ALREADY HAS UI COMPONENT. CANNOT ADD ANOTHER!"
    )

    local Data = {}

    local Transform = UITransform.New(Input and Input.Transform, Data, Entity)

    local Color = Input and Input.Color or color.fromRGBA(255, 255, 255, 255)

    local R, G, B, A = Color:unpack()

    Data[Indecies.R] = R
    Data[Indecies.G] = G
    Data[Indecies.B] = B
    Data[Indecies.A] = A
    Data[Indecies.ColorRaw] = Color

    setmetatable(Data, Meta)

    UIDrawable.Process(Data, 1, Transform)

    return Data
end

return Canvas
