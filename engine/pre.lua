-- mount engine path
local PATH = arg.game
if not PATH then
    return -1
end

local ExeFold = lovr.filesystem.getExecutableFolder()

PATH = lovr.filesystem.normalize(lovr.filesystem.toUnix(ExeFold .. PATH), true)

print(PATH)

_G.__BOOT = {}
_G.AstralEngine = {
    Signals = {},
}
AstralEngine._MOUNT = require("Lib.Mount")
loadfile, require = unpack(require("Lib.Require"))

local mnt, err = lovr.filesystem.mount(PATH, "GAMEFILE", true)
if not mnt then
    print("FAILED TO MOUNT GAME PATH <" .. PATH .. ">:", err)
    return -1
end

local Real = lovr.filesystem.getRealDirectory("/") .. "/"
AstralEngine.EnginePath = Real
AstralEngine.GamePath = PATH
local Eq = {
    Shaders = "GAMEFILE/Assets/Shaders",
    COMPONENTS = "GAMEFILE/Assets/Components",
}
-- mount core systems
AstralEngine._MOUNT(Real, "", "", true, function(Name)
    return Eq[Name]
end)

-- initiate the globals and compiler

require("Global")()
require("Compile")
require("CompGlobals")

function AstralEngine.Log(Msg, Flag, Tag, Level)
    Flag = Flag and tostring(Flag) or error("Invalid flag provided!")
    local IsErr = Flag:lower() == "error" or Flag:lower() == "fatal"
    local IsFatal = Flag:lower() == "fatal"
    local f = IsErr and error or print
    if Tag then
        f(("[ASTRAL %s][%s]: %s"):format(Flag:upper(), Tag, tostring(Msg)), IsErr and (Level or 2) or "")
        if IsFatal then
            lovr.quit()
        end
    else
        f(("[ASTRAL %s]: %s"):format(Flag:upper(), tostring(Msg)), IsErr and (Level or 2) or "")
        if IsFatal then
            lovr.quit()
        end
    end
end

function AstralEngine.Error(Msg, Tag, Layer)
    local IsNum = type(Tag) == "number"
    if IsNum then
        Layer = Tag
    end
    Layer = Layer or 1
    if IsNum then
        error(("[ASTRAL FATAL ERROR]: %s"):format(Msg), Layer + 1)
    else
        error(("[ASTRAL FATAL ERROR][%s]: %s"):format(Tag, Msg), Layer + 1)
    end
end

-- mount game folders
local ResolveTable = {
    Components = Eq.COMPONENTS,
    Shaders = Eq.Shaders,
    Globals = "/Global",
    Scenes = "GAMEFILE/Assets/Scenes",
}
AstralEngine._MOUNT(PATH, "GAMEFILE", "GAMEFILE", true, function(Name)
    return ResolveTable[Name]
end)

-- parse config
local ok, ConfigFile = pcall(require, "config")

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
    AstralEngine.DebugPrint = function(msg, lvl)
        local Info = debug.getinfo(lvl or 2, "l")
        local Info2 = debug.getinfo(lvl or 2, "S")

        print("DBGPRNT: ", msg, "\n- Line: " .. Info.currentline, "Script: " .. Info2.source)
    end
    print("DEBUG: -- MOUNTED")
    for i, v in pairs(lovr.filesystem.getMounted()) do
        print(" -", i, "", "", "R:", v)
    end
    print("MOUNTED EOF")
else
    AstralEngine.DebugPrint = function() end
end

for n, v in pairs(ConfigTable.Define) do
    for _, f in pairs(v) do
        meta.setdefined(n, f, not (f:sub(1, 1) == "!"))
    end
end

AstralEngine.Window = {}

AstralEngine._CONFIG = ConfigTable

function lovr.conf(t)
    -- set lovr config from AstralConfig
    t.graphics.vsync = AstralEngine._CONFIG.Game.Window.Vsync

    t.modules.headset = AstralEngine._CONFIG.Astral.Modules.Headset or false

    t.window = nil
end

-- set astral config, not lovr config
local CONF = {}
_G.CONF = CONF

local APPLYTABLE = {
    DEBUG = function(STATE)
        if not STATE then
            return
        end
        GetService("InputService").GetKeyboard().KeyPressed:Connect(function(k)
            if k == "escape" then
                QUIT()
            end
        end)
    end,
}

function CONF:APPLY()
    if self == CONF then
        self = CONF.CONFIG
    end
    for KEY, STATE in pairs(self) do
        if APPLYTABLE[KEY] then
            APPLYTABLE[KEY](STATE)
        end
    end
end

CONF.CONFIG = {
    DEBUG = AstralEngine._CONFIG.Astral.Debug,
    SPLASH = AstralEngine._CONFIG.Astral.Splash,

    PHYSRATE = AstralEngine._CONFIG.Astral.Tick.PhysicsRate,
    RENDERRATE = AstralEngine._CONFIG.Astral.Tick.FrameRate,
    CPURATE = AstralEngine._CONFIG.Astral.Tick.CPU,
    EVENTRATE = AstralEngine._CONFIG.Astral.Tick.EventRate,
    GCRATE = AstralEngine._CONFIG.Astral.Tick.GC,
    GCCollect = AstralEngine._CONFIG.Astral.Tick.GCCollect,
}

function CONF.RUNSPLASH()
    if not CONF.CONFIG.SPLASH then
        return
    end

    local SPLASH = loadfile("splash")()

    local CURUPD = lovr.update
    local CURDRW = lovr.draw

    SPLASH.FINISH = function()
        lovr.update = CURUPD
        lovr.draw = CURDRW
    end

    lovr.update = SPLASH.UPDATE
    lovr.draw = SPLASH.DRAW
end

-- SETTING UP GLOBALS
if meta.getdefined("System", "UNIX") then
    package.clibtag = ".so"
elseif meta.getdefined("System", "WIN") then
    package.clibtag = ".dll"
end -- if its none of those, Require sets it manually

_G.__BOOT = nil

return CONF
