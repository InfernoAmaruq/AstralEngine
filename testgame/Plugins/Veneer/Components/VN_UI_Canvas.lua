local UITransform = require("../UITransform.lua")
local UIDrawable = require("../UIDrawable.lua")
local Canvas = {}

Canvas.Name = "UICanvas"
Canvas.Metadata = {}

local Meta = {}

Canvas.Metadata.__create = function(Input)
    local Data = {}

    local Transform = UITransform.New(Input)

    setmetatable(Data, Meta)

    UIDrawable.Process(Data, 1, Transform)

    return Data
end

return Canvas
