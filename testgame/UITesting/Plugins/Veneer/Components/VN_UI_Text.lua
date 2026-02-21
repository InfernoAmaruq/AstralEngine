local Component = GetService("Component")
local Renderer = GetService("Renderer")
local Text = {}

local DefaultFont = AstralEngine.Graphics.GetDefaultFont()
DefaultFont:setPixelDensity(1)

Text.Name = "UIText"
Text.Metadata = {
    UIDrawableObject = true,
    HardDependency = { UIRoot = true },
}

local AlignPos = ENUM.TextAlignPosition
    or ENUM({
        Left = 1,
        Right = 2,
        Center = 3,
        Top = 4,
        Bottom = 5,
    }, "TextAlignPosition")

local HAlignTranslate = {
    [AlignPos.Center] = "center",
    [AlignPos.Left] = "left",
    [AlignPos.Right] = "right",
}
local VAlignTranslate = {
    [AlignPos.Center] = "middle",
    [AlignPos.Top] = "top",
    [AlignPos.Bottom] = "bottom",
}

local Indecies = {
    R = 1,
    G = 2,
    B = 3,
    A = 4,
    ColorRaw = 5,
    Text = 6,
    FontSize = 7,
    HorizontalAlignment = 8,
    VerticalAlignment = 9,
    Font = 10,
}

local SetComponents = Component.SetComponents
Renderer.VeneerUI.AddToStack(Text.Name, function(Pass, Entity, Matrix)
    local TextInst = SetComponents[Entity].UIText
    local R, G, B, A = TextInst[1], TextInst[2], TextInst[3], TextInst[4]
    local String = TextInst[6]
    local FontSize = TextInst[7]
    local HAlign, VAlign = TextInst[8], TextInst[9]
    local Font = TextInst[10]
    Pass:setShader()
    Pass:setFont(Font)

    local sx = Matrix:getScale()

    Pass:setColor(R, G, B, A)

    if VAlign ~= "middle" or HAlign ~= "center" then
        -- gonna have to set scale based on offset here
        local OffsetX = HAlign == "left" and -0.5 or (HAlign == "right" and 0.5 or 0)
        local OffsetY = VAlign == "top" and -0.5 or (VAlign == "bottom" and 0.5 or 0)
        --Matrix = mat4(x, y, z, sx + OffsetX, sy + OffsetY, 1, a, ax, ay, az) -- new mat with offset
        Matrix = mat4(Matrix):translate(OffsetX, OffsetY, 0)
    end

    local FontHeight = Font:getHeight()

    -- goal: 32px (FontSize)
    -- density: 38.... px (Density)
    -- Height, where 1 unit = 1 meter (or pixel)

    local Scale = 1 / FontHeight
    Scale = Scale * FontSize

    local x, y, z, a, ax, ay, az = Matrix:getPose()
    local Wrapping = sx / Font:getPixelDensity()
    Pass:text(String, x, y, z, Scale, a, ax, ay, az, Wrapping, HAlign, VAlign)
end)

local DirectGetter = {
    Color = Indecies.ColorRaw,
    Text = Indecies.Text,
    Font = Indecies.Font,
    FontSize = Indecies.FontSize,
}
local DirectSetter = { Font = Indecies.Font, FontSize = Indecies.FontSize, Text = Indecies.Text }
local Getters = {
    HorizontalAlignment = function(self) end,
    VerticalAlignment = function(self) end,
}
local Setters = {
    Color = function(self, v)
        local R, G, B, A = v:unpack()
        self[Indecies.R] = R
        self[Indecies.G] = G
        self[Indecies.B] = B
        self[Indecies.A] = A
        self[Indecies.ColorRaw] = v
    end,
    HorizontalAlignment = function(self, v) end,
    VerticalAlignment = function(self, v) end,
}

local Meta = {
    __index = function(self, k)
        if DirectGetter[k] then
            return self[DirectGetter[k]]
        elseif Getters[k] then
            return Getters[k](self)
        end
    end,
    __newindex = function(self, k, v)
        if DirectSetter[k] then
            self[DirectSetter[k]] = v
            return
        elseif Setters[k] then
            return self[Setters[k]](self, v)
        end
    end,
}

local ToTransform = {
    __HasUIElement = "UIText",
}

Text.Metadata.__create = function(Input, Entity, Sink)
    local TransformComponent = Component.HasComponent(Entity, "UIRoot")
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
        Component.AddComponent(Entity, "UIRoot", InputValue)
        if UD then -- clear UD just incase
            InputValue.__HasUIElement = nil
        end
    end

    local Data = {}

    local Color = Input and Input.Color or color.fromRGBA(255, 255, 255, 255)

    local R, G, B, A = Color:unpack()

    local HAlign = Input and Input.HorizontalAlignment or AlignPos.Center
    local VAlign = Input and Input.VerticalAlignment or AlignPos.Center

    Data[Indecies.R] = R
    Data[Indecies.G] = G
    Data[Indecies.B] = B
    Data[Indecies.A] = A
    Data[Indecies.ColorRaw] = Color
    Data[Indecies.Text] = Input and Input.Text or ""
    Data[Indecies.HorizontalAlignment] = HAlignTranslate[HAlign]
    Data[Indecies.VerticalAlignment] = VAlignTranslate[VAlign]
    Data[Indecies.Font] = Input and Input.Font or DefaultFont
    Data[Indecies.FontSize] = Input and Input.FontSize or 32

    setmetatable(Data, Meta)

    return Data
end

Text.Metadata.__remove = function(_, Entity)
    local UIRoot = Component.HasComponent(Entity, "UIRoot")
    if UIRoot then
        UIRoot.__HasUIElement = nil
    end
end

return Text
