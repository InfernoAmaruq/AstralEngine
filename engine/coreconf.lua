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
            "UseAstr", -- or nil for Lua GC
        },
        Render = {
            "LoadShadowmap",
            "LoadCel",
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
            GC = 3,
            GCCollect = 20,
        },
    },
    Enums = {
        StepPriority = {},
    },
    Game = {
        Identity = "Astral_Default",
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
