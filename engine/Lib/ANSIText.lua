local tostring = tostring
local schar = string.char

local Colors = {
    -- attributes
    Reset = 0,
    Clear = 0,
    Bright = 1,
    Dim = 2,
    Underscore = 4,
    Blink = 5,
    Reverse = 7,
    Hidden = 8,

    -- foreground
    Black = 30,
    Red = 31,
    Green = 32,
    Yellow = 33,
    Blue = 34,
    Magenta = 35,
    Cyan = 36,
    White = 37,

    -- background
    OnBlack = 40,
    OnRed = 41,
    OnGreen = 42,
    OnYellow = 43,
    OnBlue = 44,
    OnMagenta = 45,
    OnCyan = 46,
    OnWhite = 47,
}

local AnsiMod = {}

local Base = schar(27) .. "["
for Name, Value in pairs(Colors) do
    local Val = Base .. tostring(Value) .. "m"
    AnsiMod[Name] = Val
end

return AnsiMod
