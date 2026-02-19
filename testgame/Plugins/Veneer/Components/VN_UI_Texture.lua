local Component = GetService("Component")
local Renderer = GetService("Renderer")

local UITexture = {}

UITexture.Name = "UITexture"
UITexture.Metadata = {
    SceneLateLoad = true,
}

local FitImage = ENUM({
    Stretch = 1,
    Crop = 2,
    Fit = 3,
}, "ImageFitMode")

local Indecies = {
    R = 1,
    G = 2,
    B = 3,
    A = 4,
    ColorRaw = 5,
    Texture = 6,
    FitMode = 7,
}

local SetComponents = Component.SetComponents
Renderer.VeneerUI.AddToStack(UITexture.Name, function(Pass, Entity, Matrix)
    local Comp = SetComponents[Entity].UITexture
    local Image = Comp[6]
    if not Image then
        return
    end
    Image = Image[1] or Image

    local RectSize = vec2(Matrix:getScale())

    Pass:send("UIImageFit", Comp[7].RawValue)
    Pass:send("RectSize", RectSize)

    -- for some reason sampling is weird so we gotta do this:

    Pass:setColor(Comp[1], Comp[2], Comp[3], Comp[4])
    Pass:setMaterial(Image)
    Pass:plane(Matrix)

    Pass:send("UIImageFit", 0) -- none
end)

local ToTransform = {
    __HasUIElement = "UITexture",
}

local MT = {
    __index = function(self, k)
        if k == "Color" then
            return self[Indecies.ColorRaw]
        elseif k == "Texture" then
            return self[Indecies.Texture]
        elseif k == "FitMode" then
            return self[Indecies.FitMode]
        end
    end,
    __newindex = function(self, k, v)
        if k == "Color" then
            local R, G, B, A = v:unpack()

            self[Indecies.R] = R
            self[Indecies.G] = G
            self[Indecies.B] = B
            self[Indecies.A] = A
            self[Indecies.ColorRaw] = v
        elseif k == "Texture" then
            self[Indecies.Texture] = v
        elseif k == "FitMode" then
            self[Indecies.FitMode] = v
        end
    end,
}

UITexture.Metadata.__create = function(Input, Entity, Sink)
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

    Data[Indecies.R] = R
    Data[Indecies.G] = G
    Data[Indecies.B] = B
    Data[Indecies.A] = A
    Data[Indecies.ColorRaw] = Color
    Data[Indecies.Texture] = Input and Input.Texture
    Data[Indecies.FitMode] = Input and Input.FitMode or FitImage.Stretch

    setmetatable(Data, MT)

    return Data
end

UITexture.Metadata.__remove = function(_, Entity)
    local UIRoot = Component.HasComponent(Entity, "UIRoot")
    if UIRoot then
        UIRoot.__HasUIElement = nil
    end
end

UITexture.FinalProcessing = function()
    if Component.AncestryRequired then
        table.insert(Component.AncestryRequired, UITexture.Name)
    end
end

return UITexture
