local Handle = select(1, ...)
local Conf = loadfile("./config.lua")()

Handle.Config = Conf

local Name = "VeneerUI"
local Ver = "0.0.1"

return {
    Name = Name,

    Version = Ver,

    AliasMap = {
        ["./Shader/UIShader"] = "Shaders/UIMain",
        ["./Components"] = "Components",
        ["./Render"] = "RenderCalls",
    },

    OnLoad = function()
        AstralEngine.Log(Name .. " version: " .. Ver .. " ready", "info", "VENEER")
    end,
}
