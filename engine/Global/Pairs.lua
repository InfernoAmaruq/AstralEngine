local OgPairs = pairs
local OgIpairs = ipairs

local GetMt = debug.getmetatable

pairs = function(t)
    local mt = GetMt(t)
    local p = mt and mt.__pairs
    if p then
        local t = type(p)

        if t == "table" then
            return OgPairs(p)
        else
            return p(t)
        end
    else
        return OgPairs(t)
    end
end

ipairs = function(t)
    local mt = GetMt(t)
    local p = mt and mt.__ipairs
    if p then
        local t = type(p)

        if t == "table" then
            return OgPairs(p)
        else
            return p(t)
        end
    else
        return OgPairs(t)
    end
end

return {
    __NAME = "pairs",
    __PRO = function()
        return pairs
    end,
}
