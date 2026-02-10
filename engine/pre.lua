-- mount engine path
local PATH = arg.game
if not PATH then
    return -1
end

local ExeFold = lovr.filesystem.getExecutableFolder()

PATH = lovr.filesystem.normalize(lovr.filesystem.toUnix(ExeFold .. PATH), true)

_G.__BOOT = {}
_G.AstralEngine = {
    Signals = {},
}
AstralEngine._MOUNT = lovr.filesystem.load(package.ENG_PATH .. "/Lib/Mount.lua")()
loadfile, require = unpack(lovr.filesystem.load(package.ENG_PATH .. "/Lib/Require.lua")())

if not arg.SHARED then
    local mnt, err = lovr.filesystem.mount(PATH, "GAMEFILE", true)
    if not mnt then
        print("FAILED TO MOUNT GAME PATH <" .. PATH .. ">:", err)
        return -1
    end
else
    print("GAME ALREADY MOUNTED!")
end

local Real = lovr.filesystem.getRealDirectory(package.ENG_PATH) .. "/"
local AliasMap = {
    Shaders = "Shaders",
    COMPONENTS = "Components",
    RenderCalls = "RenderCalls",
}

-- mount core systems

local ShaderPath

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

-- initiate the globals and compiler

require("Global")()
require("Compile")
require("CompGlobals")

function AstralEngine.Log(Msg, Flag, Tag, Level)
    Flag = Flag and tostring(Flag) or error("Invalid flag provided!")
    local IsErr = Flag:lower() == "error"
    local IsFatal = Flag:lower() == "fatal"
    local f = IsErr and error or print

    local MsgT = type(Msg)
    if MsgT == "table" then
        Msg = table.concat(Msg, " ")
    end

    if Tag then
        f(("[ASTRAL %s][%s]: %s"):format(Flag:upper(), Tag, tostring(Msg)), IsErr and (Level or 2) or "")
        if IsFatal then
            QUIT()
        end
    else
        f(("[ASTRAL %s]: %s"):format(Flag:upper(), tostring(Msg)), IsErr and (Level or 2) or "")
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
    if IsNum then
        error(("[ASTRAL FATAL ERROR]: %s"):format(Msg), Layer + 1)
    else
        error(("[ASTRAL FATAL ERROR][%s]: %s"):format(Tag, Msg), Layer + 1)
    end
end

-- mount game folders
local GameAliasTable = {
    Components = AliasMap.COMPONENTS,
    Shaders = AliasMap.Shaders,
    Scenes = "Scenes",
}

AstralEngine._MOUNT(PATH, "GAMEFILE", "GAMEFILE", true, function(Name, _, VfsPath)
    if GameAliasTable[Name] then
        lovr.filesystem.alias(VfsPath, GameAliasTable[Name])
    end
end)

-- time to mount the plugins

local PluginHandler = require("./PluginHandler")

for _, Dir in ipairs(lovr.filesystem.getDirectoryItems("/Plugins")) do
    lovr.filesystem.alias("/Plugins/" .. Dir, "Plugins")
end
for _, Dir in ipairs(lovr.filesystem.getDirectoryItems("GAMEFILE/Plugins")) do
    lovr.filesystem.alias("GAMEFILE/Plugins/" .. Dir, "Plugins")
end

for _, PluginFolder in ipairs(lovr.filesystem.getAliased("Plugins")) do
    PluginHandler.Load(PluginFolder)
end

-- parse config
local ok, ConfigFile = pcall(require, "GAMEFILE/config")

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

    t.modules.headset = true --AstralEngine._CONFIG.Astral.Modules.Headset or false

    t.graphics.antialias = AstralEngine._CONFIG.Game.Window.AntiAliasing

    t.window = nil
end

-- set astral config, not lovr config
local CONF = {}
_G.CONF = CONF

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
