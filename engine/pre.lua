-- mount engine path
local PATH = arg.game
if not PATH then
    return -1
end

local ExeFold = lovr.filesystem.getWorkingDirectory()

PATH = lovr.filesystem.normalize(lovr.filesystem.toUnix(ExeFold .. "/" .. PATH))

_G.__BOOT = {}
_G.AstralEngine = {
    Signals = {},
    [".Internal"] = {},
}

AstralEngine._MOUNT = lovr.filesystem.load(package.ENG_PATH .. "/Lib/Mount.lua")()
lovr.filesystem.extractor = lovr.filesystem.load(package.ENG_PATH .. "/Lib/Extractor.lua")()
loadfile, require, package.loadlib = unpack(lovr.filesystem.load(package.ENG_PATH .. "/Lib/Require.lua")())

if not lovr.filesystem.isFused() or not lovr.filesystem.isDirectory(package.GAME_PATH) then
    local mnt, err = lovr.filesystem.mount(PATH, package.GAME_PATH, true)
    if not mnt then
        print("FAILED TO MOUNT GAME PATH <" .. PATH .. ">:", err)
        return -1
    end
end

local Real = lovr.filesystem.getRealDirectory(package.ENG_PATH)
local AliasMap = {
    Shaders = "Shaders",
    COMPONENTS = "Components",
    RenderCalls = "RenderCalls",
}

-- mount core systems

local ShaderPath
local IsZip = Real:sub(-4) == ".zip"
if not IsZip and not lovr.filesystem.isFused() then
    AstralEngine._MOUNT(Real, "", "", true, function(Name, _, True)
        if AliasMap[Name] then
            if AliasMap[Name] == AliasMap.Shaders then
                ShaderPath = True
            end
            lovr.filesystem.alias(True, AliasMap[Name])
        elseif ShaderPath and True:find(ShaderPath) then
            local Sub = True:gsub(ShaderPath, "")
            lovr.filesystem.alias(True, AliasMap.Shaders .. Sub)
        end
    end)
else
    local function ProcessDir(path, callback, recursive)
        for _, item in ipairs(lovr.filesystem.getDirectoryItems(path)) do
            local FullPath = path ~= "" and (path .. "/" .. item) or item
            local Info = lovr.filesystem.isFile(FullPath)
            if Info then
                callback(FullPath)
            else
                callback(FullPath)
                ProcessDir(FullPath, callback, recursive)
            end
        end
    end

    ProcessDir(package.ENG_PATH, function(True)
        local Name = string.match(True, "([^/]+)$")
        if AliasMap[Name] then
            if AliasMap[Name] == AliasMap.Shaders then
                ShaderPath = True
            end
            lovr.filesystem.alias(True, AliasMap[Name])
        elseif ShaderPath and True:find(ShaderPath) then
            local Sub = True:gsub(ShaderPath, "")
            lovr.filesystem.alias(True, AliasMap.Shaders .. Sub)
        end
    end, true)
end

local AnsiColorLib = require("Lib/ANSIText")

-- make some IO fixes
AstralEngine.System = AstralEngine.System or {}

-- configure I/O file

do
    local BaseIO = io.output()
    AstralEngine[".Internal"].BaseIO = BaseIO
end

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

-- mount game folders
local GameAliasTable = {
    Components = AliasMap.COMPONENTS,
    Shaders = AliasMap.Shaders,
    Scenes = "Scenes",
}

AstralEngine._MOUNT(PATH, package.GAME_PATH, package.GAME_PATH, true, function(Name, _, VfsPath)
    if GameAliasTable[Name] then
        if Name == "Components" and VfsPath:find("Plugin") then
            return
        end
        lovr.filesystem.alias(VfsPath, GameAliasTable[Name])
    end
end)

-- parse config
local ok, ConfigFile = pcall(require, package.GAME_PATH .. "/config")

if ok then
    ConfigFile = ConfigFile or {}
else
    ConfigFile = {}
end

local ConfigTable
local CoreConfig = require("coreconf")

local function RecursiveAssign(t1, t2)
    for i, v in pairs(t2) do
        if t1[i] == nil then
            t1[i] = v
        elseif type(v) == "table" then
            RecursiveAssign(t1[i], v)
        end
    end
end

if ConfigFile then
    ConfigTable = ConfigFile
else
    ConfigTable = CoreConfig
end

RecursiveAssign(ConfigTable, CoreConfig)

if ConfigTable.Astral.Debug then
    print("DEBUG: -- MOUNTED")
    for i, v in pairs(lovr.filesystem.getMounted()) do
        print(" -", i, "", "", "R:", v)
    end
    print("MOUNTED EOF")
end

AstralEngine.Window = {}

AstralEngine._CONFIG = ConfigTable

function lovr.conf(t)
    -- set lovr config from AstralConfig
    t.graphics.vsync = AstralEngine._CONFIG.Game.Window.Vsync

    t.modules.headset = true --AstralEngine._CONFIG.Astral.Modules.Headset or false

    t.graphics.antialias = AstralEngine._CONFIG.Game.Window.AntiAliasing

    t.window = nil

    t.identity = AstralEngine._CONFIG.Game.Identity
    t.saveprecedence = AstralEngine._CONFIG.Game.SavePrecedence
end

-- set astral config, not lovr config
local CONF = {}
_G.CONF = CONF

CONF.CONFIG = {
    DEBUG = AstralEngine._CONFIG.Astral.Debug,

    PHYSRATE = AstralEngine._CONFIG.Astral.Tick.PhysicsRate,
    RENDERRATE = AstralEngine._CONFIG.Astral.Tick.FrameRate,
    CPURATE = AstralEngine._CONFIG.Astral.Tick.CPU,
    EVENTRATE = AstralEngine._CONFIG.Astral.Tick.EventRate,
    GCRATE = AstralEngine._CONFIG.Astral.Tick.GC,
    GCPAUSE = AstralEngine._CONFIG.Astral.Tick.GCPause,
    GCSTEPMUL = AstralEngine._CONFIG.Astral.Tick.GCStepMul,
}

lovr.identitySet = function()
    -- initiate the globals and compiler

    require("Global")()
    require("Compile")
    require("CompGlobals")

    for n, v in pairs(ConfigTable.Define) do
        for _, f in pairs(v) do
            meta.setdefined(n, f, not (f:sub(1, 1) == "!"))
        end
    end

    -- SETTING UP GLOBALS
    if meta.getdefined("System", "UNIX") then
        package.clibtag = ".so"
    elseif meta.getdefined("System", "WIN") then
        package.clibtag = ".dll"
    end -- if its none of those, Require sets it manually

    _G.__BOOT = nil
end

return CONF
