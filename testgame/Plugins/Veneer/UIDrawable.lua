local Component = GetService("Component")

local Drawable = {}
--[[ this module is meant to normalize certain fields across all UI components. The key is as follows::
    [1] = FunctionId (Id of callable function on UI FunctionStack)
    [2] = Reference of UITransform instance
]]

Drawable.UIComponents = {
    "UICanvas",
    "UICamera",
}

Drawable.UIRectComponents = {
    "UICanvas",
}

Drawable.Reserved = 2

function Drawable.EntityHasUIComponent(Entity)
    for _, Name in ipairs(Drawable.UIComponents) do
        local c = Component.HasComponent(Entity, Name)
        if c then
            return c
        end
    end
end

function Drawable.EntityHasUIRectComponent(Entity)
    for _, Name in ipairs(Drawable.UIRectComponents) do
        local c = Component.HasComponent(Entity, Name)
        if c then
            return c
        end
    end
end

function Drawable.Process(Object, FunctionId, Transform)
    rawset(Object, 1, FunctionId) -- encode so the render loop can access it
    rawset(Object, 2, Transform)

    rawset(Object, "Transform", Transform)
end

return Drawable
