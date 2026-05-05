-- set up our logging tools
local AnsiColorLib = require("Lib/ANSIText")

local BaseIO = io.output()
AstralEngine[".Internal"].BaseIO = BaseIO

local Tab = string.rep(" ", 6)
local ConsolePrint = print
_G.consoleprint = print
_G.print = function(...)
    ConsolePrint(...)
    if AstralEngine[".Internal"].BaseIO == io.output() then
        return
    end
    local n = select("#", ...)
    for i = 1, n do
        io.write(tostring(select(i, ...)):gsub("\27%[[0-9;]*m", "") .. Tab)
    end
    io.write("\n")
    if AstralEngine.System.PrintCallback then
        AstralEngine.System.PrintCallback(...)
    end
    if AstralEngine.System.ShouldFlush then
        io.flush()
    end
end

function AstralEngine.Log(Msg, Flag, Tag, Level)
    Flag = Flag and tostring(Flag) or error("Invalid flag provided!")
    local LowerFlag = Flag:lower()
    local IsErr = LowerFlag == "error"
    local IsFatal = LowerFlag == "fatal"
    local f = IsErr and error or print

    local Pre, Post = "", ""

    if IsErr or IsFatal then
        Pre = AnsiColorLib.Red
        Post = AnsiColorLib.Clear
    elseif LowerFlag == "warn" then
        Pre = AnsiColorLib.Yellow
        Post = AnsiColorLib.Clear
    elseif LowerFlag == "log" or LowerFlag == "info" then
        Pre = AnsiColorLib.Blue
        Post = AnsiColorLib.Clear
    elseif LowerFlag == "success" then
        Pre = AnsiColorLib.Green
        Post = AnsiColorLib.Clear
    end

    local MsgT = type(Msg)
    if MsgT == "table" then
        Msg = table.concat(Msg, " ")
    end

    if Tag then
        f(
            Pre .. ("[ASTRAL %s]" .. Post .. "[%s]: %s"):format(Flag:upper(), Tag, tostring(Msg)),
            IsErr and (Level or 2) or ""
        )
        if IsFatal then
            QUIT()
        end
    else
        f(Pre .. ("[ASTRAL %s]" .. Post .. ": %s"):format(Flag:upper(), tostring(Msg)), IsErr and (Level or 2) or "")
        if IsFatal then
            QUIT()
        end
    end
end

function AstralEngine.Assert(v, Msg, Tag, Layer)
    if v then
        return v
    end
    AstralEngine.Error(Msg, Tag, (Layer or 1) + 1)
end

function AstralEngine.Error(Msg, Tag, Layer)
    local IsNum = type(Tag) == "number"
    if IsNum then
        Layer = Tag
    end
    Layer = Layer or 1

    local Pre = AnsiColorLib.Red
    local Post = AnsiColorLib.Clear

    if IsNum then
        error((Pre .. "[ASTRAL ERROR]" .. Post .. ": %s"):format(Msg), Layer + 1)
    else
        error((Pre .. "[ASTRAL ERROR]" .. Post .. "[%s]: %s"):format(Tag, Msg), Layer + 1)
    end
end
