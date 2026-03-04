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

-- define interpol

local tostring = _G.tostring

local function GsubF(VarName)
    local LocalId = 1

    local LastName, LastVal

    while (LastName and LastVal) or LocalId == 1 do
        LastName, LastVal = debug.getlocal(4, LocalId) -- 4 is callstack pos
        LocalId = LocalId + 1
        if LastName == VarName then
            return tostring(LastVal)
        end
    end

    local UpvalueId = 1

    while (LastName and LastVal) or UpvalueId == 1 do
        LastName, LastVal = debug.getupvalue(f, UpvalueId)
        UpvalueId = UpvalueId + 1
        if LastName == VarName then
            return tostring(LastVal)
        end
    end

    local Global = _G[VarName]

    if Global then
        return tostring(Global)
    else
        AstralEngine.Error(
            "No variable/upvalue/global of name: " .. VarName .. " found! Cannot interpolate string!",
            "STRING",
            4
        )
    end

    --AstralEngine.Assert(Value, "Cannot interpolate string! No local/upvalue/global of " .. VarName .. " found!")
end

function string.interpolate(s)
    local Str = s:gsub("{%s*([%w%-]+)%s*}", GsubF)

    return Str
end

return String
