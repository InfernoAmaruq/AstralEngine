local StellarEditor = _G.StellarEditor
local ANSITag = "\27["
local ANSIColors = {
    Red = 31,
    Green = 32,
    Yellow = 33,
    Blue = 34,
    Magenta = 35,
    Cyan = 36,
    White = 37,
}

for i, v in pairs(ANSIColors) do
    ANSIColors[i] = ANSITag .. tostring(v) .. "m"
end

local Reset = ANSITag .. "0m"

StellarEditor.Log = function(Str, Tag, Tag2)
    local ColorTag = ""

    local LowerTag = Tag:lower()

    local f = print

    if LowerTag == "warn" then
        ColorTag = ANSIColors.Yellow
    elseif LowerTag == "fatal" then
        ColorTag = ANSIColors.Red
        lovr.event.quit()
    elseif LowerTag == "success" then
        ColorTag = ANSIColors.Green
    elseif LowerTag == "error" then
        f = error
        ColorTag = ANSIColors.Red
    elseif LowerTag == "info" then
        ColorTag = ANSIColors.Magenta
    end

    if Tag2 then
        f((ColorTag .. "[STELLAR %s]" .. Reset .. "[%s]: %s"):format(Tag, Tag2, Str))
    else
        f((ColorTag .. "[STELLAR %s]" .. Reset .. ": %s"):format(Tag, Str))
    end
end
