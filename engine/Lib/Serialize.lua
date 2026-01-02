local Serialize = {}

local function QuoteString(s)
    return string.format("%q", s)
end

local VecTable = { Vec3 = true, Vec4 = true, Mat4 = true, Vec2 = true, Quat = true }

local function SerializeVec(T)
    local t = typeof(T)
    return t .. tostring(T)
end

Serialize.Indent = "    "
local MatchPattern = "^[%a_][%w_]*$"

local KeyIgnoreList = { Ancestry = true, __CName = true }
function Serialize.IgnoreKey(k)
    return (type(k) == "string" and k:sub(1, 2) == "__") or KeyIgnoreList[k]
end

function Serialize.GetKey(k, ...)
    if type(k) == "string" and k:match(MatchPattern) then
        return k
    else
        return "[" .. Serialize.SerializeValue(k, ...) .. "]"
    end
end

Serialize.BASICMETHOD = function(T, I, V)
    local Parts = {}

    local NI = I .. Serialize.Indent

    for i, v in pairs(T) do
        if Serialize.IgnoreKey(i) then
            continue
        end
        local Key = Serialize.GetKey(i, I, V)
        local StrVal = Serialize.SerializeValue(v, NI, V)
        if StrVal then
            table.insert(Parts, NI .. Serialize.Indent .. Key .. " = " .. StrVal)
        end
    end

    return "{\n" .. table.concat(Parts, ",\n") .. "\n" .. NI .. "}"
end

local ExactSerialisations
ExactSerialisations = setmetatable({
    Component = function(T, ...)
        local Specific = ExactSerialisations[rawget(T, "__CName")]
        if Specific then
            return Specific(T, ...)
        end
    end,
}, {
    __index = function(t, k)
        if rawget(t, k) then
            return rawget(t, k)
        end
        if VecTable[k] then
            return SerializeVec
        end
    end,
})

function Serialize.AddSerializeMethod(Name, M)
    ExactSerialisations[Name] = M
end

local TablelikeMethods = {
    ["table"] = function(T, I, V)
        local Parts = {}
        local NI = I .. Serialize.Indent

        for i, v in pairs(T) do
            if Serialize.IgnoreKey(i) then
                continue
            end

            local Key = Serialize.GetKey(i, I, V)

            local StrVal = Serialize.SerializeValue(v, NI, V)

            if StrVal then
                table.insert(Parts, I .. Key .. " = " .. StrVal)
            end
        end

        return "{\n" .. table.concat(Parts, ",\n") .. "\n" .. I .. "}"
    end,
    ["solobj"] = function(T, I, V)
        local ExactType = typeof(T)
        local Met = ExactSerialisations[ExactType]
        if Met then
            return Met(T, I, V)
        end
    end,
}

local BaseSerializationMethods = {
    number = tostring,
    integer = tostring,
    boolean = tostring,
    ["nil"] = tostring,
    ["string"] = QuoteString,
}

for i, v in pairs(TablelikeMethods) do
    BaseSerializationMethods[i] = function(T, I, V)
        if V[T] then
            print("ERROR SERIALIZING:", tostring(T))
            AstralEngine.Error("Cannot serialize table with cycles", 2)
        end
        V[T] = true
        return v(T, I, V)
    end
end

function Serialize.SerializeValue(Tbl, Indent, Visited)
    Indent = Indent or ""
    Visited = Visited or {}

    local t = type(Tbl)
    local Met = BaseSerializationMethods[t]
    if Met then
        return Met(Tbl, Indent, Visited)
    else
        AstralEngine.Error("Invalid type: " .. t)
    end
end

function Serialize.ToTable(Table, Var)
    Var = Var or "return"
    return Var .. " " .. Serialize.SerializeValue(Table)
end

function Serialize.GameToTable()
    return "return " .. Serialize.SerializeValue(GetService("World").Alive)
end

return Serialize
