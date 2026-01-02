@macro<G>:A&==B = A & B ~= 0
@macro<G>:A!&==B = A & B == 0

@macro<G>:A|==B = A | B ~= 0
@macro<G>:A!|==B = A | B == 0

-- ADDING BOOLS
@macro<L>:BtI(v) = (type(v) == "number" and v) or (v and 1 or 0);

debug.setmetatable(true,{
    __add = function(a,b)
        return BtI(a) + BtI(b)
    end,
    __mul = function(a,b)
        return BtI(a) * BtI(b)
    end,
    __sub = function(a,b)
        return BtI(a) - BtI(b)
    end
})

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

-- ARRAYS
@macro<G,!USEBRACK>:[]x = table.array(x)

return nil
