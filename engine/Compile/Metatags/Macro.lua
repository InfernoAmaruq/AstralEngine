local Macro = {}

--[[SYNTAX HINT

    V - variable

    @macro<IMPORT>:V,V.MACRO1
    @macro<E=V/G/L>

]]

local MacroStorage = {}
MacroStorage.Global = {}
MacroStorage.Scoped = {}

local CURRENTMEMORY = {}

local Symbols = {}
local SymString = "!@#$%^&*_-=+:?/<>,.,[]|"
for i = 1, #SymString do
    table.insert(Symbols, "%" .. SymString:sub(i, i))
end
SymString = table.concat(Symbols)
Symbols = nil

local function CreateMacro(Body) -- add(a,b) = a+b
    Body = Body:match("^%s*(.-)%s*$")

    local M = {
        Name = nil,
        Body = nil,
        Type = nil, -- function / symbol / prefix
        Parameters = {},
    }

    -- FORM: <SYMBOL>(...<PAR>)=<STATEMENT>
    local Name, Par, Bod = Body:match("^([%a_][%w_]*)%s*%(([^)]*)%)%s*=%s*(.+)$")
    if Name then
        for P in Par:gmatch("[^,%s]+") do
            table.insert(M.Parameters, P)
        end
        M.Name, M.Body, M.Type = Name, Bod, "F"
        return M
    end

    -- FORM: <SYMBOL><PAR>=<STATEMENT>
    local P, Par2, Bod3 = Body:match("^([" .. SymString .. "]+)([%a_][%w_]*)%s*=%s*(.+)$")
    if P then
        M.Name, M.Body, M.Type = P, Bod3, "P"
        M.Parameters[1] = Par2
        return M
    end

    -- FORM: <PAR><SYMBOL><PAR>=<STATEMENT>
    local Lhs, Sym, Rhs, Bod2 = Body:match("^([%a_][%w_]*)%s*([" .. SymString .. "]+)%s*([%a_][%w_]*)%s*=%s*(.+)$")
    if Sym then
        M.Name, M.Body, M.Type = Sym, Bod2, "S"
        M.Parameters = { Lhs, Rhs }
        return M
    end

    error("Invalid macro syntax! " .. Body)
end

local function GetMacroSaveEnv(Memory, Con)
    local Context = Con:split(",")[1]
    local SaveTo
    if Context == "G" or not Context then
        SaveTo = MacroStorage.Global
    elseif Context == "L" then
        SaveTo = Memory.LIBRARY
    elseif Context and Context:sub(1, 1) == "E" then
        Context = Context:gsub("%s+", "")
        local Equal = Context:sub(1, 2) == "E="
        local Key
        if Equal then
            Key = Context:sub(3)
            if not Key or #Key == 0 then
                error("NO ENV PROVIDED TO EXPORT MACRO TO")
            end
        else
            error("INVALID SYNTAX FOR CONTEXT DEFINITION: " .. Context)
        end
        MacroStorage.Scoped[Key] = MacroStorage.Scoped[Key] or {}
        SaveTo = MacroStorage.Scoped[Key]
    else
        error("INVALID CONTEXT FOR MACRO: " .. Context)
    end

    return SaveTo
end

Macro.Tag = "macro"
Macro.Priority = 4
function Macro.PARSE(Blk, _, Id)
    local Context = Blk.Context
    local Memory = CURRENTMEMORY[Id]
    if Context == "IMPORT" then
        for _, Symbol in pairs(Blk.Body) do
            local Group, Specific = unpack(Symbol:split("."))
            local Search = MacroStorage.Scoped[Group]
            if Search then
                if Specific then
                    Memory.LIBRARY[Specific] = Search[Specific]
                else
                    for n, v in pairs(Search) do
                        Memory.LIBRARY[n] = v
                    end
                end
            end
        end
    else
        local SaveTo = GetMacroSaveEnv(Memory, Context)
        local Split = Context:split(",")

        local DropBrackets = false

        for i = 2, #Split do
            local v = Split[i]
            if v == "!USEBRACK" then
                DropBrackets = true
            end
        end
        local ParsedMacro = SaveTo and CreateMacro(Blk.Raw)
        ParsedMacro.DropBrackets = DropBrackets
        if ParsedMacro then
            print("MACRO")
            for i, v in pairs(ParsedMacro) do
                if type(v) == "table" then
                    print(i, unpack(v))
                else
                    print(i, v)
                end
            end
            SaveTo[ParsedMacro.Type .. ":" .. ParsedMacro.Name] = ParsedMacro
        end
    end
    return nil
end

function Macro.PRE(_, Id)
    CURRENTMEMORY[Id] = {
        LIBRARY = {},
    }
    return nil
end

local function MaskStrings(Src)
    local Store = {}
    local i = 0
    Src = Src:gsub("([\"'])(.-)%1", function(q, s)
        i = i + 1
        local Key = "<STR" .. i .. ">"
        Store[Key] = q .. s .. q
        return Key
    end)
    Src = Src:gsub("%[%[(.-)%]%]", function(s)
        i = i + 1
        local Key = "<LSTR" .. i .. ">"
        Store[Key] = "[[" .. s .. "]]"
        return Key
    end)
    return Src, Store
end

local function UnmaskStrings(Src, Store)
    for k, v in pairs(Store) do
        Src = Src:gsub(k, v)
    end
    return Src
end

local function EscapePattern(s)
    return (s:gsub("(%W)", "%%%1"))
end

local EXPR = "[%w_%.%[%]\"'%(%)%<%>{}]+"

local function AddBrackets(c, Mac)
    if Mac.DropBrackets then
        return c
    else
        return "(" .. c .. ")"
    end
end

local function ExpandMacro(Src, Mac)
    local Body = Mac.Body

    if Mac.Type == "F" then
        local Pat = ("%s%s"):format(EscapePattern(Mac.Name), "%s*%(([^)]*)%)")

        Src = Src:gsub(Pat, function(Args)
            local ArgList = {}
            for A in Args:gmatch("[^,%s]+") do
                table.insert(ArgList, A)
            end
            local Expanded = Body
            for i, Name in ipairs(Mac.Parameters) do
                local Value = ArgList[i] or ""
                Expanded = Expanded:gsub(EscapePattern(Name), Value)
            end
            return AddBrackets(Expanded, Mac)
        end)
    elseif Mac.Type == "S" then
        local Left, Right = unpack(Mac.Parameters)
        local Sym = EscapePattern(Mac.Name)
        Src = Src:gsub("(" .. EXPR .. ")%s*" .. Sym .. "%s*(" .. EXPR .. ")", function(a, b)
            local Out = Body:gsub(Left, a):gsub(Right, b)
            return AddBrackets(Out, Mac)
        end)
    elseif Mac.Type == "P" then
        local Sym = EscapePattern(Mac.Name)
        local Param = Mac.Parameters[1]
        Src = Src:gsub(Sym .. "({[^}]*})", function(Arg)
            return AddBrackets(Body:gsub(Param, Arg), Mac)
        end)
        Src = Src:gsub(Sym .. "([%w_%.]+)", function(Arg)
            return AddBrackets(Body:gsub(Param, Arg), Mac)
        end)
    end

    return Src, true
end

function Macro.POST(Src, Id)
    local CUR = CURRENTMEMORY[Id]
    for i, v in pairs(MacroStorage.Global) do
        CUR.LIBRARY[i] = v
    end

    local LastMasked
    local Masked, Store = MaskStrings(Src)
    local Changed = true
    while Changed do
        Changed = false
        local Before = Masked
        for _, Mac in pairs(CUR.LIBRARY) do
            Masked = ExpandMacro(Masked, Mac)
        end
        if Masked ~= Before then
            Changed = true
        end
    end
    Src = UnmaskStrings(Masked, Store)

    return Src
end

function Macro.FREE(Id)
    CURRENTMEMORY[Id] = nil
end

local function Literalise(s)
    local Out = ""
    for i = 1, #s do
        Out = Out .. "%" .. s:sub(i, i)
    end
    return Out
end

function Macro.VER(Src)
    for _, v in pairs(MacroStorage.Global) do
        if Src:find(Literalise(v.Name)) then
            return true
        end
    end
end

return Macro
