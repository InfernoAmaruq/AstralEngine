local Math = {}

Math.__NAME = "math"
Math.__PRO = function()
    return math
end

local floor, ceil, abs, type = math.floor, math.ceil, math.abs, type

math.mathtype = function(x)
    if type(x) ~= "number" then
        return nil
    end
    if math.isinf(x) then
        return "Inf"
    end
    if math.abs(x - math.floor(x)) < 1e-9 then
        return "Integer"
    else
        return "Double"
    end
end

math.round = function(x, n) -- val, dp
    n = n and (10 ^ n) or 1
    if x >= 0 then
        return floor(x * n + 0.5) / n
    else
        return ceil(x * n - 0.5) / n
    end
end

math.isinf = function(x)
    return abs(x) == math.huge
end

math.clamp = function(x, a, b)
    return (x < a and a) or (x > b and b) or x
end

return Math
