local String = {}

String.__NAME = "string"
String.__PRO = function()
    return string
end

local mt = debug.getmetatable("")
local strdef = mt.__index
mt.__index = function(str, i)
    if type(i) == "number" then
        return str:sub(i, i)
    end
    return strdef[i]
end
mt.__call = function(s, i, j)
    return string.sub(s, i, j or i)
end

function string.split(s, sep, MULTI)
    sep = sep or "%s"
    local t = {}
    local Pattern = string.format("([^%s]+)", sep)
    if #sep > 1 and not MULTI then
        local start = 1
        local SS, SE = s:find(sep, start, true)
        while SS do
            table.insert(t, s:sub(start, SS - 1))
            start = SE + 1
            SS, SE = s:find(sep, start, true)
        end
        table.insert(t, s:sub(start))
        return t
    end

    for str in s:gmatch(Pattern) do
        t[#t + 1] = str
    end
    return t
end

return String
