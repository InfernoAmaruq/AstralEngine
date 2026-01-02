local OgType = type
rtype = OgType

local Type = {}

local function get(t, k)
    return t[k]
end

Type.__NAME = "type"
Type.__PRO = function()
    local function f(_, x)
        local OgT = OgType(x)
        if OgT ~= "table" and OgT ~= "userdata" then
            return OgT
        end
        local mt = getmetatable(x)
        local GetFunc = OgT == "table" and rawget or get
        if mt and mt.__array then
            return "array"
        elseif
            (mt and mt.__type)
            or (GetFunc(x, "type") and OgType(GetFunc(x, "type")) == "function" and OgT == "userdata")
            or GetFunc(x, "__ISENUM")
        then
            return "astrobj"
        end
        return OgT
    end

    return setmetatable({
        -- EXTRA
        EngineObj = "astrobj",
        Integer = "Integer",
        Double = "Double",
        Inf = "Inf",

        -- CORE
        Number = "number",
        Nil = "nil",
        Boolean = "boolean",
        Userdata = "userdata",
        String = "string",
        Function = "function",
        Table = "table",
        Thread = "thread",
    }, { __call = f })
end

return Type
