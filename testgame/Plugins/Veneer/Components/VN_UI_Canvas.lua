local UITransform = require("../UITransform.lua")
local Canvas = {}

Canvas.Name = "UICanvas"
Canvas.Metadata = {}

local Meta = {}

Canvas.Metadata.__create = function(Input)
    local Data = {}

    Data.Transform = UITransform.New(Input)

    setmetatable(Data, Meta)

    return Data
end

return Canvas
