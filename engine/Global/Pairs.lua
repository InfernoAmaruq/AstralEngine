local OgPairs = pairs
local OgIpairs = ipairs

local GetMt = debug.getmetatable

pairs = function(t)
    local mt = GetMt(t)
    if mt and mt.__pairs then
        return mt.__pairs(t)
    else
        return OgPairs(t)
    end
end

ipairs = function(t)
    local mt = GetMt(t)
    if mt and mt.__ipairs then
        return mt.__ipairs(t)
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
