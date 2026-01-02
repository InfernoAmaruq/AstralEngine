local TypeOf = {}

TypeOf.__NAME = "typeof"

local NTYPEREGISTRY = _G.NTYPEREG or {}
_G.NTYPEREG = NTYPEREGISTRY

TypeOf.__PRO = function()
    return function(x)
        if x == nil then
            return "nil"
        end

        local t = type(x)
        local IsCompound = t == "solobj" or t == "table"
        local mt = IsCompound and getmetatable(x)

        if IsCompound then
            if mt and mt.__type then
                return mt.__type, x.__ISINST
            elseif x.type and type(x.type) == "function" then
                return x:type()
            elseif x.__ISENUM then
                return x.__ISENUM
            end
        elseif t == "number" then
            for i, v in pairs(NTYPEREGISTRY) do
                local CALC = v.Tag << (v.Expo or 0)
                if (x & CALC) ~= 0 then
                    return i
                end
            end
        end

        return t
    end
end

return TypeOf
