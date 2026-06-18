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
