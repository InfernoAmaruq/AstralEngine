local Pairs = {}

local OgPairs = pairs
rpairs = pairs
Pairs.__NAME = "pairs"
Pairs.__PRO = function()
    return function(t)
        local mt = debug.getmetatable(t)
        if mt and mt.__pairs then
            return mt.__pairs(t)
        end
        return OgPairs(t)
    end
end

return Pairs
