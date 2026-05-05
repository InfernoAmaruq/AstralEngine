_G.typeof = function(x)
    if x == nil then
        return "nil"
    end

    local t = type(x)
    local IsCompound = t == "astrobj" or t == "table"
    local mt = IsCompound and getmetatable(x)

    if IsCompound then
        if mt and mt.__type then
            return mt.__type
        elseif x.type and type(x.type) == "function" then
            return x:type()
        elseif x.__ISENUM then
            return x.__ISENUM
        end
    end

    return t
end
