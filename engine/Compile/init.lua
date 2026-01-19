--[[
--  MODULE TO MANAGE PRAGMAS, MACROS AND ASTMACROS
--]]
local Recompiler = {}

_G.meta = {}

Recompiler.Meta = {}
Recompiler.Dirs = {}

local SharedMemory = {}

local Lexer = require("Lexer")
local Code = require("Code")

local SPLITSYMBOL = "<SP>"
Lexer.SetSplitSymbol(SPLITSYMBOL)
Code.SetSplitSymbol(SPLITSYMBOL)
Code.LoadMemory(SharedMemory)

Recompiler.MaxPasses = 5

-- APPEND STACK
_G.meta.LoadfileAppendStack = {}

function meta.LoadfileAppendStack.Push(s)
    table.insert(meta.LoadfileAppendStack, s)
end

function meta.LoadfileAppendStack.Pop()
    local Stack = meta.LoadfileAppendStack
    Stack[#Stack] = nil
end

function meta.LoadfileAppendStack.Clear()
    for i = #meta.LoadfileAppendStack, 1, -1 do
        meta.LoadfileAppendStack[i] = nil
    end
end

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

local COUNTER = 0

local function COMPILE_LOADSTRING(c, NAME)
    for i = 1, #meta.LoadfileAppendStack do
        local S = meta.LoadfileAppendStack[i]
        c = S .. c
        meta.LoadfileAppendStack.Pop()
        print("APPENDED:\n", s, "\nRESULT:\n", c)
    end

    local Dirs
    if Lexer.FSearch(c) or Verify(c) then
        COUNTER = COUNTER + 1
        local N = COUNTER
        c = PREPROCESS(c, N)
        local Passes = 1
        repeat
            Dirs, c = Lexer.ExtractDirectives(c)
            if #Dirs > 0 then
                c = Code.Translate(c, Dirs, N)
            end
            Passes = Passes + 1
            c = POSTPROCESS(c, N)
        until not Dirs or #Dirs == 0 or Passes > Recompiler.MaxPasses
        local n = 0
        Free(N)
        local t = c:gsub("\n", function(a)
            n = n + 1
            return "-- LINE: " .. n .. "\n"
        end)
        if NAME:find("main") then
            print("EMITTED CODE:", "\n" .. c)
        end
        COUNTER = COUNTER - 1
    end
    local f, err = loadstring(c, NAME)
    if not f then
        error("RECOMPILER ERROR: " .. err, 2)
    end
    return f
end

_G.comp_loadstring = COMPILE_LOADSTRING

Recompiler.Loadfile = function(path, fenv)
    if lovr.filesystem.isFile(path) then
        local c = lovr.filesystem.read(path, -1)
        if c then
            local DATA = COMPILE_LOADSTRING(c, path)
            return fenv and setfenv(DATA, fenv) or DATA
        end
    end
end

_G.__BOOT.REQUIRELIB_OVERRIDE("loadfile", Recompiler.Loadfile)

do -- GETTING ALL THE META FILES
    local Items = lovr.filesystem.getDirectoryItems("./Compile/Metatags/")
    for _, v in ipairs(Items) do
        if lovr.filesystem.isFile("./Compile/Metatags/" .. v) then
            local f = loadfile("./Compile/Metatags/" .. v)
            if f then
                local Data = f(SharedMemory, Code.Meta)
                Recompiler.Dirs[#Recompiler.Dirs + 1] = Data
                Code.AttachDirective(Data)
                Lexer.AttachDirective(Data)
            end
        end
    end
    table.sort(Recompiler.Dirs, function(a, b)
        local PA = a.Priority or 1
        local PB = b.Priority or 1
        return PA < PB
    end)
end

return Recompiler
