local Compiler = {}

local _G = {} -- just need a dummy table for now, dont wanna give global access cause just testing

_G.meta = {}

Compiler.Meta = {}
Compiler.Dirs = {}

local SharedMemory = {}

local Lexer = require("Lexer")
--local Code = require("Code")

local SPLITSYMBOL = "<SP>"
Lexer.SetSplitSymbol(SPLITSYMBOL)

local ConfigPresets
ConfigPresets = {
    lua = {
        Language = {
            Syntax = {
                S1 = "'",
                S2 = '"',
                SML1 = "[[",
                SML2 = "]]",
                C = "--",
                CML1 = "--[[",
                CML2 = "]]",
            },
        },
    },
    glsl = {
        Language = {
            Syntax = {},
        },
    },
    lbmf = {},
}
ConfigPresets.aspr = { Language = ConfigPresets.lua.Language }
Compiler.ConfigPresets = ConfigPresets

Compiler.Lexer = Lexer

Compiler.MaxPasses = 5

local function PREPROCESS(Src, n)
    for _, v in ipairs(Recompiler.Dirs) do
        if v.PRE then
            Src = v.PRE(Src, n) or Src
        end
    end
    return Src
end

local function POSTPROCESS(Src, n)
    for _, v in ipairs(Recompiler.Dirs) do
        if v.POST then
            Src = v.POST(Src, n) or Src
        end
    end
    return Src
end

local function Verify(c)
    for _, v in ipairs(Recompiler.Dirs) do
        if v.VER then
            if v.VER(c) then
                return true
            end
        end
    end
end

local function Free(n)
    for _, v in ipairs(Recompiler.Dirs) do
        if v.FREE then
            v.FREE(n)
        end
    end
end

return Compiler
