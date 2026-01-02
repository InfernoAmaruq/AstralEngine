local Strict = {}

Strict.__NAME = "st"
Strict.__PRO = function()
    return function(x, t)
        local Nullable = t:sub(-1) == "?"

        if Nullable then
            t = t:sub(1, -2)
        end

        local Valid = type(x) == t or typeof(x) == t or math.mathtype(x) == t

        if not Valid and not (x == nil and Nullable) then
            AstralEngine.Error("Object: " .. tostring(x) .. " is not type of: " .. t, 2)
        end
        return x
    end
end

return Strict
