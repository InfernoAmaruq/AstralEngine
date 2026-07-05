local Def = require("Def")

local Exclude = {
    astral_main = false,
}

local SkipModifiers = {
    uniform = true,
    unmangled = true,
    struct = true,
    [Def.SYMBOLS.FLAG] = true,
}

local Compare = {}

for _, v in pairs(Def.SYMBOLS.DECLARATOR) do
    Compare[v] = true
end

local function Mangle(Text, Prefix)
    local Out, Pos, Depth = {}, 1, 0
    local IdMap = {}
    local TotalJumps = 0

    while Pos <= #Text do
        local Ch = Text:sub(Pos, Pos)

        if Ch == "{" then
            Depth = Depth + 1
            TotalJumps = TotalJumps + 1
        elseif Ch == "}" then
            Depth = Depth - 1
        end

        local Start, End, Type, Name = Text:find("(%w+)%s+(%w+)%s*[%[(;=]", Pos)
        local Window = Text:sub(math.max(1, Pos - 20), Pos)

        for i in pairs(SkipModifiers) do
            local S, E = Window:find(i)
            if S and E then
                if i == "struct" then
                    local FindStart = Text:find("{", Pos + S)
                    local FindEnd = Text:find("}", FindStart)

                    Pos = Pos + FindEnd
                elseif i == "unmangled" then
                    local Ms, Me = Text:sub(0, Start - 1):find("%w+%s*$")
                    local s = Text:sub(0, Ms - 1)
                    Text = s .. Text:sub(Me)
                else
                    Pos = Pos + E
                end
            end
        end

        if Type and Compare[Type] and Name and not Exclude[Name] and Start == Pos then
            local CHECKER = Depth .. "-" .. TotalJumps .. "@" .. Name
            if not IdMap[CHECKER] then
                IdMap[CHECKER] = Prefix .. "_" .. Name
            end
            Pos = End
        end

        Pos = Pos + 1
    end

    local Pattern = "([%.%w_]?)%f[%w_](%w+)%f[^%w_]"
    Text = Text:gsub(Pattern, function(Prev, Word)
        for k, v in pairs(IdMap) do
            if Prev == "." then
                return Prev .. Word
            end
            local _, _, Name = k:find("@(.+)$")
            if Word == Name then
                return (Prev or "") .. v
            end
        end
        return (Prev or "") .. Word
    end)

    return Text
end

return Mangle
