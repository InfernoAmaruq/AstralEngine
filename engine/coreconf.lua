return {
    Define = {
        -- table of compile-time defined values
        Sched = {
            "UseLua", -- "UseLua" | "UseAuto" | "UseNative"
            -- UseNative - C code, UseLua - Lua code, UseAuto - based on size of list
            -- For tiny games with very few routines, UseLua may be fastest. UseNative is fastest for large lists
            -- UseAuto is fast but less predicable
        },
        GC = {
            --"UseAstr", -- or nil for Lua GC

            -- Lua GC runs whenever Lua GC runs, but AstralGC runs at frame boundaries, which should make code more deterministic

            -- if you'd like no GC, use lua gc and disable it in your launch.lua file

            --[[
            -- lua gc is generally recommended. AstralGC is there for specific circumstances
            -- with AstralGC, lua gc is not disabled, you can call collectgarbage"restart" and collectgarbage"stop" if you're doing a lot of alloc-heavy work without yielding
            --]]
        },
        Render = {
            "LoadShadowmap",
            "LoadCel",
        },
        Asset = {
            "StrictLoad", -- the asset manager will not load raw binary blobs or random types unless told to
        },
        Physics = {
            "BindMainWorld", -- should the central Runtime loop process physics? If disabled. Tick.PhysicsRate will be ignored
            "Interpolate", -- interpolate automatically or not? Requires BindMainWorld
            "InterpolAtRender", -- "InterpolAtCPU" | "InterpolAtRender". Interpolating at the Render Step or CPU step. Both CAN be used but it carries increased costs
        },
        Extra = {
            "PinPass",
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
            PhysicsRate = 50,
            FrameRate = 165,
            CPU = 240,
            EventRate = 240,

            GC = 3, -- how often to run GC

            GCPause = 110, -- GCPause will *only* apply to Lua GC or Astral soft GC
            GCStepMul = 350, -- will apply to all GC configs, lua and Astral, except for HardGC
            -- these are recommended settings. Lua's base settings are not very good for games
        },
    },
    Enums = {
        StepPriority = {},
    },
    Game = {
        Identity = "Astral_Default",
        SavePrecedence = true,
        Window = {
            AntiAliasing = false, -- windows AA options
            -- NOT renderer AA, just output
            Vsync = false,
            Fullscreen = false,
            Width = 1700, -- or 0 for borderless fullscreen
            Height = 900,
            Resizable = false,
            Name = "Astral Engine Demo 0.0.1",
        },
    },
    Filesystem = {
        EntryScene = "entry",
    },
}
