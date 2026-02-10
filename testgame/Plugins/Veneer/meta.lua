local Handle = select(1, ...)
local Conf = loadfile("./config.lua")()

Handle.Config = Conf

return {
    Name = "VeneerUI",

    Version = "0.0.1",

    AliasMap = {
        ["./Shader"] = "Shaders",
        ["./Components"] = "Components",
        ["./Render"] = "RenderCalls",
    },
}
