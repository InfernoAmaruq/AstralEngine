local SharedMem = select(1, ...)

local Execute = {}

local EXEMEM = {}
local CURRENTMEM = {}
local EXECSTACK = setmetatable({}, { __mode = "k" })

local PREFIX = [[
local CUREXEMEM, EXEMEM, SHAREDMEM = select(1,...)
]]
local EXEPRINT = function(...)
    print("[COMP_EXE]:", ...)
end

local ENVTABLE = setmetatable({
    print = EXEPRINT,
    EXE_SAFE = false,
}, { __index = _G })
local SAFEENV = {
    EXE_SAFE = true,
    print = EXEPRINT,
    pairs = pairs,
    ipairs = ipairs,
    next = next,
    table = table,
    string = string,
    select = select,
}

Execute.Priority = 7
Execute.Tag = "execute"
function Execute.PARSE(Blk, _, N)
    local Context = Blk.Context

    local SAFE = nil
    local LoadstringToUse = loadstring

    for _, v in pairs(Context:split(",")) do
        if (v == "UNSAFE" or v == "SAFE") and SAFE == nil then
            SAFE = v == "SAFE"
        end
        if v == "COMP" then
            LoadstringToUse = comp_loadstring
        end
    end

    SAFE = SAFE == nil and true or SAFE

    local ENV = SAFE and SAFEENV or ENVTABLE
    local Code = Blk.Raw
    if Code == "" then
        return ""
    else
        Code = PREFIX .. "\n" .. Code
    end
    print("EXE EMIT:", Code)
    local Body, Err = LoadstringToUse(Code, "COMPILETIME EXE " .. N)
    if Body then
        setfenv(Body, ENV)
        local SMem
        if not SAFE then
            SMem = SharedMem
        end
        return tostring(Body(CURRENTMEM[N], EXEMEM, SMem) or "")
    else
        print("[COMP_EXE]: ERROR PARSING CODE:", "\n" .. Err)
    end
    return ""
end

function Execute.PRE(SRC, Id)
    local Frame = {
        __SOURCE = SRC,
        __OUTPUTSRC = nil,
        __DEPTH = Id,
    }
    CURRENTMEM[Id] = Frame
    EXECSTACK[Frame] = true
    return nil
end

function Execute.POST(_, Id)
    local Frame = CURRENTMEM[Id]
    if not Frame then
        return
    end
    local Out = Frame.__OUTPUTSRC
    return Out
end

function Execute.FREE(Id)
    local Frame = CURRENTMEM[Id]
    CURRENTMEM[Id] = nil
    EXECSTACK[Frame] = nil
end

return Execute
