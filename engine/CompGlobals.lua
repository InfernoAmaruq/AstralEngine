@macro<G>:A&==B = A & B ~= 0
@macro<G>:A!&==B = A & B == 0

@macro<G>:A|==B = A | B ~= 0
@macro<G>:A!|==B = A | B == 0

-- NUMBERS
local REGISTRY = _G.NTYPEREG or {}
_G.NTYPEREG = REGISTRY

debug.setmetatable(0,{
    __index = function(i,idx)
        for _, v in pairs(REGISTRY) do
            if not v.FIELDS then continue end
            local CALC = v.Tag << (v.Expo or 0)
            if (i & CALC) ~= 0 then
                return v.FIELDS[idx]
            end
        end
    end
})

return nil
