local TypeOf = {}

TypeOf.__NAME = "wrapself"

TypeOf.__PRO = function()
    return function(self, method)
        return function(...)
            return method(self, ...)
        end
    end
end

return TypeOf
