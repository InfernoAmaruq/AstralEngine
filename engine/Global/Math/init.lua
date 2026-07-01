local floor, ceil, abs = math.floor, math.ceil, math.abs

if _G.jit then
    require("bit")
    -- sets a global but doesnt return a table, which is somewhat annoying, but whatevs
else
    local file = lovr.filesystem.folderFromPath(lovr.filesystem.getCurrentPath()) .. "bit.so"
    local a = require(file)
    _G.bit = _G.bit or a
end

math.round = function(x, n) -- val, dp
    n = n or 1
    if x >= 0 then
        return floor(x * n + 0.5) / n
    else
        return ceil(x * n - 0.5) / n
    end
end

math.isinf = function(x)
    return abs(x) == math.huge
end

math.isnan = function(x)
    return not (x == x) -- nans fail == checks
end

math.clamp = function(x, a, b)
    return (x < a and a) or (x > b and b) or x
end
