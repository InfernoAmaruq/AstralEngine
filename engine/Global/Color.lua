local Color = {}

local CLRHDR = 0x434C << 32

local function fromRGBA(r, g, b, a)
    local RGBA = (r << 24) | (g << 16) | (b << 8) | a
    return CLRHDR | RGBA
end

--FORMAT: #RRGGBBAA

local F = 0xFF

local Lookup = {
    validate = function(Clr)
        return (Clr & CLRHDR) ~= 0
    end,
    fromRGB = function(r, g, b)
        return fromRGBA(r, g, b, 255)
    end,
    fromRGBA = fromRGBA,
    toHex = function(c)
        return string.format("%08X", c)
    end,
    fromHex = function(s)
        return CLRHDR | (rtype(s) == "number" and s or tonumber(s:gsub("#", ""), 16))
    end,
    new = function(r, g, b, a)
        return fromRGBA(r * 255, g * 255, b * 255, (a or 1) * 255)
    end,
    unpack = function(C)
        return (C >> 24 & F) / 255, (C >> 16 & F) / 255, (C >> 8 & F) / 255, (C & F) / 255
    end,

    -- LITERALS
    Green = CLRHDR | 0x00ff00ff,
    Red = CLRHDR | 0xff0000ff,
    White = CLRHDR | 0xffffffff,
    Black = CLRHDR | 0,
    Blue = CLRHDR | 0x0000ffff,
    Magenta = CLRHDR | 0xff00ffff,
    Yellow = CLRHDR | 0xffff00ff,
    Cyan = CLRHDR | 0x00ffffff,
}

local ColorFields = {
    unpack = Lookup.unpack,
    toHex = Lookup.toHex,
}

debug.setmetatable(0, {
    __index = function(i, idx)
        if (i & CLRHDR) ~= 0 then
            return ColorFields[idx]
        end
    end,
})

Color.__NAME = "color"
Color.__PRO = function()
    return Lookup
end

return Color
