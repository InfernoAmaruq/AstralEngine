local function NewIndex()
    error("CANNOT WRITE TO ENUM")
end

local function EnumToString(t)
    return t.Name or "__UNDEFINED"
end

local ENUMS = {}

local function EncodeEnum(Header, Value)
    return (Header << 16) | (Value & 0xffff)
end

local TYPE = rtype or type
local function Sub(a, b)
    return (TYPE(a) == "table" and a.RawValue or a) - (TYPE(b) == "table" and b.RawValue or b)
end

local function Add(a, b)
    return (TYPE(a) == "table" and a.RawValue or a) + (TYPE(b) == "table" and b.RawValue or b)
end

local Funcs = {
    GetTop = function(self)
        local n = 0
        local Val
        local Name
        for N, V in pairs(self) do
            local Idx = V.RawValue
            if Idx > n then
                n = Idx
                Val = V
                Name = N
            end
        end
        return n, Name, Val
    end,
}

local function ProcessMember(K, V, EnumName, Header)
    local DATA = {
        Name = K,
        Value = EncodeEnum(Header, V),
        RawValue = V,
        EnumType = EnumName or "__UNNAMED",
        __ISENUM = "__ENUM_" .. EnumName,
    }

    local t = setmetatable({}, {
        __newindex = NewIndex,
        __metatable = false,
        __index = DATA,
        __tostring = EnumToString,
        __add = Add,
        __sub = Sub,
    })

    return t
end

local Byte = string.byte

local function MakeHeader(Name)
    Name = Name:gsub("[^A-Za-z]", "")
    local H1 = Byte(Name:sub(1, 1))
    local H2 = Byte(Name:sub(2, 2))
    local H3 = Byte(Name:sub(3, 3))
    return (H1 << 16) | (H2 << 8) | H3
end

local function NewEnum(_, t, Name, Options, Header)
    assert(Name, "No enum name provided!")
    local Head = MakeHeader(Header or Name)

    assert(not ENUMS[Name], "ENUM WITH NAME [" .. Name .. "] ALREADY CREATED")
    local Proxy = {}
    Proxy.__HEADER = Header
    local DATA = {}

    local Opt = Options or {}

    for K, V in pairs(t) do
        DATA[K] = ProcessMember(K, V, Name, Head)
    end

    if Name then
        ENUMS[Name] = Proxy
    end

    local Append
    if Opt.CanAppend then
        Append = function(k, val)
            if type(k) == "table" then -- using a table
                for i, v in rpairs(k) do
                    DATA[i] = ProcessMember(i, v, Name, Head)
                end
            else -- just a single value
                DATA[k] = ProcessMember(k, val, Name, Head)
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
        __metatable = false,
        __pairs = function()
            return next, DATA, nil
        end,
        __tostring = function()
            local S = "ENUM: " .. Name .. " {\n"
            for NAME, ID in pairs(DATA) do
                S = S .. "      " .. NAME .. " = " .. ID.RawValue .. ";\n"
            end
            return S .. "}"
        end,
    })
end

ENUMS.__GETPROCESSOR = function(NAME, GetField)
    return function(ENUM)
        if type(ENUM) == "table" and ENUM.__ISENUM and ENUM.__ISENUM:find(NAME) then
            return ENUM[GetField]
        end
    end
end

ENUMS.GetValue = function(V)
    return V & 0xffff
end

ENUMS.GetHeader = function(V, ToString)
    local Head = (V >> 16) & 0xffffff
    local H1 = (Head >> 16) & 0xff
    local H2 = (Head >> 8) & 0xff
    local H3 = Head & 0xff

    return ToString and string.char(H1, H2, H3) or Head
end

ENUMS.Splice = EncodeEnum

return setmetatable(ENUMS, { __call = NewEnum })
