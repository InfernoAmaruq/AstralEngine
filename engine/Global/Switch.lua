local Switch = {}

Switch.__NAME = "switch"
Switch.__PRO = function()
    return function(c)
        local SwTbl = {
            CaseVar = c,
            caseof = function(self, Code)
                local f
                if self.CaseVar then
                    f = Code[self.CaseVar] or Code.default
                else
                    f = Code.missing or Code.defaut
                end

                if f then
                    if type(f) == "function" then
                        return f(self.CaseVar, self)
                    else
                        return f
                    end
                end
            end,
        }
        return SwTbl
    end
end

return Switch
