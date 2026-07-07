local function NewIndex()
    error("CANNOT WRITE TO ENUM")
end

local function EnumToString(t)
    return t.Name or "__UNDEFINED"
end

local Enums = {}

local TYPE = rtype or type
local function Sub(a, b)
    return (TYPE(a) == "table" and a.Value or a) - (TYPE(b) == "table" and b.Value or b)
end

local function Add(a, b)
    return (TYPE(a) == "table" and a.Value or a) + (TYPE(b) == "table" and b.Value or b)
end

local function Eq(a, b)
    return (TYPE(a) == "table" and a.Value or a) == (TYPE(b) == "table" and b.Value or b)
end

local Funcs = {
    GetTop = function(self)
        local n = 0
        local Val
        local Name
        for N, V in pairs(self) do
            local Idx = V.Value
            if Idx > n then
                n = Idx
                Val = V
                Name = N
            end
        end
        return n, Name, Val
    end,
}

local function ProcessMember(K, V, EnumName)
    local DATA = {
        Name = K,
        Value = V,
        EnumType = EnumName or "__UNNAMED",
    }

    local t = setmetatable({}, {
        __newindex = NewIndex,
        __index = DATA,
        __tostring = EnumToString,
        __add = Add,
        __sub = Sub,
        __eq = Eq,
        __type = "Enum." .. EnumName,
    })

    return t
end

local function NewEnum(_, t, Name, Options)
    assert(Name, "No enum name provided!")

    assert(not Enums[Name], "ENUM WITH NAME [" .. Name .. "] ALREADY CREATED")
    local Proxy = {}
    local DATA = {}

    local Opt = Options or {}

    for K, V in pairs(t) do
        DATA[K] = ProcessMember(K, V, Name)
    end

    if Name then
        Enums[Name] = Proxy
    end

    local Append
    if Opt.CanAppend then
        Append = function(k, val)
            if type(k) == "table" then -- using a table
                for i, v in pairs(k) do
                    DATA[i] = ProcessMember(i, v, Name)
                end
            else -- just a single value
                DATA[k] = ProcessMember(k, val, Name)
            end
        end
    end

    Name = Name or "__UNNAMED"
    return setmetatable(Proxy, {
        __index = function(_, k)
            if Funcs[k] then
                return Funcs[k]
            end
            if k == "__Append" and Opt.CanAppend then
                return Append
            elseif k == "__HEADER" then
                return Head
            else
                local v = DATA[k]
                if not v and Opt.Strict ~= false then
                    error("Unknown enum")
                end
                return v
            end
        end,
        __newindex = NewIndex,
        __pairs = function()
            return next, DATA, nil
        end,
        __type = "Enum.Registry." .. Name,
        __tostring = function()
            local S = "ENUM: " .. Name .. " {\n"
            for NAME, ID in pairs(DATA) do
                S = S .. "      " .. NAME .. " = " .. ID.Value .. ";\n"
            end
            return S .. "}"
        end,
    })
end

return setmetatable(Enums, { __call = NewEnum })
