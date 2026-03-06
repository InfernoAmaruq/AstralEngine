-- STELLAR CONFIG HERE
local StellarEditor = {}
_G.StellarEditor = StellarEditor

local VERSIONSTRING = "0.0.0 - DEMO"

local Ok = pcall(require, package.GAME_PATH .. "Early/init.lua")

print(pcall(StellarEditor.Log, "Hello World!", "success"))

if not Ok then
    lovr.event.quit()
end

StellarEditor.GetVersion = function()
    return VERSIONSTRING
end

-- ASTRAL CONFIG HERE
local AstralConfig = {
    Define = {
        Sched = {
            "UseLua", -- "UseLua" | "UseAuto" | "UseNative"
        },
        GC = {},
        Render = {
            "LoadShadowmap",
            "LoadCel",
        },
        Asset = {
            "StrictLoad", -- the asset manager will not load raw binary blobs or random types unless told to
        },
        Runtime = {
            --"Sleep" -- sleep 0s after each runtime step
        },
        --[[
        --  You can define your own values with the same logic of KEY = {VALUES}, and it will be read as: @ifdef<KEY.VALUE>
        --]]
    },
    Astral = {
        Debug = true,
        Splash = false,
        Modules = {
            Headset = false,
        },
        Tick = {
            PhysicsRate = 60,
            FrameRate = 165,
            CPU = 100,
            EventRate = 100,
        },
    },
    Game = {
        Identity = "STELLAR_EDITOR_" .. VERSIONSTRING:upper(),
        SavePrecedence = true,
        Window = {
            AntiAliasing = true,
            Vsync = false,
            Fullscreen = true,
            --Width = 1700, -- or 0 for borderless fullscreen
            --Height = 900,
            --Resizable = false,
            Name = "Stellar Engine " .. VERSIONSTRING,
        },
    },
    Filesystem = {
        EntryScene = false,
    },
}

return AstralConfig
