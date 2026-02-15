local Component = GetService("Component")
local Canvas = {}

Canvas.Name = "UICanvas"
Canvas.Metadata = {}

local Indecies = {
    R = 1,
    G = 2,
    B = 3,
    A = 4,
    ColorRaw = 5,
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

local ToTransform = {
    __HasUIElement = "UICanvas",
}

Canvas.Metadata.__create = function(Input, Entity, Sink)
    local TransformComponent = Component.HasComponent(Entity, "UITransform")
    local AncestryComponent = Component.HasComponent(Entity, "Ancestry")

    if not AncestryComponent and not Sink then
        Component.AddComponent(Entity, "Ancestry")
    end

    if TransformComponent then
        AstralEngine.Assert(
            not TransformComponent.__HasUIElement,
            "ENTITY " .. Entity .. " ALREADY HAS A DRAWABLE UI COMPONENT! CANNOT CREATE ANOTHER COMPONENT!",
            "VENEER"
        )
        if Input and Input.Transform then
            TransformComponent:Set(Input.Transform)
        end
    elseif not Sink and not TransformComponent then
        local InputValue = Input and Input.Transform
        local UD = false
        if InputValue then
            UD = true
            InputValue.__HasUIElement = "UICanvas"
        else
            InputValue = ToTransform
        end
        Component.AddComponent(Entity, "UITransform", InputValue)
        if UD then -- clear UD just incase
            InputValue.__HasUIElement = nil
        end
    end

    local Data = {}

    local Color = Input and Input.Color or color.fromRGBA(255, 255, 255, 255)

    local R, G, B, A = Color:unpack()

    Data[Indecies.R] = R
    Data[Indecies.G] = G
    Data[Indecies.B] = B
    Data[Indecies.A] = A
    Data[Indecies.ColorRaw] = Color

    setmetatable(Data, Meta)

    return Data
end

Canvas.Metadata.__remove = function(_, e)
    local UITransform = Component.HasComponent(e, "UITransform")
    if UITransform then
        UITransform.__HasUIElement = nil
    end
end

return Canvas
