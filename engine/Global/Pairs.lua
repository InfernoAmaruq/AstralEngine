local OgPairs = pairs
local OgIpairs = ipairs

local GetMt = debug.getmetatable

pairs = function(t)
    local mt = GetMt(t)
    local p = mt and mt.__pairs
    if p then
        local Type = rtype(p)

        if Type == "table" then
            return OgPairs(t)
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
        local Type = rtype(p)

        if Type == "table" then
            return OgIpairs(p)
        else
            return p(t)
        end
    else
        return OgIpairs(t)
    end
end
