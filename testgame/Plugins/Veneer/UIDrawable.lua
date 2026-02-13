local Drawable = {}
--[[ this module is meant to normalize certain fields across all UI components. The key is as follows::
    [1] = FunctionId (Id of callable function on UI FunctionStack)
    [2] = Reference of UITransform instance
]]

function Drawable.Process(Object, FunctionId, Transform)
    rawset(Object, 1, FunctionId) -- encode so the render loop can access it
    rawset(Object, 2, Transform)

    rawset(Object, "Transform", Transform)
end

return Drawable
