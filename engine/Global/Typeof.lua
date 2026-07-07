local type = type

_G.kind = function(x) -- WHO owns the object
    local t = type(x)

    local mt = getmetatable(x)

    if not mt then
        return nil
    end

    if mt.__type then
        return "astrobj"
    elseif t == "userdata" and x.type then
        return "lovrobj"
    end
end

_G.typeof = function(x) -- specific type
    if x == nil then
        return "nil"
    end

    local t = type(x)
    local IsCompound = t == "userdata" or t == "table"
    local mt = IsCompound and getmetatable(x)

    if IsCompound then
        if mt and mt.__type then
            return mt.__type
        elseif x.type then
            return x:type()
        end
    end

    return t
end
