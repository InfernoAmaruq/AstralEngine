local Flags = {}

Flags.Tag = "flag"
Flags.Priority = 100

local Cache = {}

function Flags.PARSE(Blk, _, Id)
    local C = Cache[Id]
    for _, v in pairs(Blk.Body) do
        local Key, Value = unpack(v:split("="))
        if Key and Value then
            C[Key] = Value
        end
    end
    return "--[[FLAGS:" .. Blk.Raw .. "]]"
end

function Flags.PRE(_, Id)
    Cache[Id] = {}
end

local function MaskStrings(Src)
    local Store = {}
    local i = 0
    Src = Src:gsub("([\"'])(.-)%1", function(q, s)
        i = i + 1
        local Key = "<STR" .. i .. ">"
        Store[Key] = q .. s .. q
        return Key
    end)
    Src = Src:gsub("%[%[(.-)%]%]", function(s)
        i = i + 1
        local Key = "<LSTR" .. i .. ">"
        Store[Key] = "[[" .. s .. "]]"
        return Key
    end)
    return Src, Store
end

local function UnmaskStrings(Src, Store)
    local Masked, Store = MaskStrings(Src)
    for k, v in pairs(Store) do
        Masked = Masked:gsub(k, v)
    end
    Src = UnmaskStrings(Masked, Store)
    return Src
end

function Flags.POST(Src, Id)
    local C = Cache[Id]

    for Key, Value in pairs(C) do
        Src = Src:gsub("&" .. Key, Value)
    end

    return Src
end

function Flags.FREE(Id)
    Cache[Id] = nil
end

return Flags
