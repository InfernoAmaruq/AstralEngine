local ExtraLib = {}

local TYPE_FUNC = typeof or type

function ExtraLib.Vardump(v, Depth, Key)
    local t = TYPE_FUNC(v)

    local LinePrefix = ""
    local Spaces = ""

    if Key then
        LinePrefix = "[" .. Key .. "] = "
    end

    if not Depth then
        Depth = 0
    else
        Depth = Depth + 1
        for _ = 1, Depth do
            Spaces = Spaces .. "  "
        end
    end

    if TYPE_FUNC(v) == "table" then
        local MTable = debug.getmetatable(v)
        if not MTable then
        else
        end
    end
end

return ExtraLib
