local CONFIG = CONF

local ROOT, World, Renderer, RunService

local IsMouseGrabbed = false

function AstralEngine.Window.GrabMouse(State)
    IsMouseGrabbed = State
    if AstralEngine.Window.Focused then
        lovr.system.setMouseGrabbed(State)
    end
end

function lovr.focus(f)
    AstralEngine.Window.Focused = true
    if f and IsMouseGrabbed then
        lovr.system.setMouseGrabbed(f)
    end
end

function lovr.load()
    -- INITIAL DECL
    require("ResizeRepair")

    _G.ENUM = require("Lib.Enum")

    require("Engine")
    local CentralScheduler = require("Engine.Scheduler")
    local ScriptSys = require("Engine.ScriptSystem")
    require("Engine.Render")
    World = require("Engine.World")

    Renderer = GetService"Renderer"
    local Entity = GetService"Entity"

    local SERIALIZER = require("Lib.Serialize")

    local BRIDGE = require("LOVRBridge")

    local SIGNAL = require("Lib.Signal")

    ROOT = {
        SCHEDULERS = {},
        SCRIPTSYS = {},
    }

    local FS = {
        GetDir = lovr.filesystem.getDirectoryItems,
        IsFile = lovr.filesystem.isFile,
    }

    QUIT = lovr.event.quit

    lovr.draw = Renderer.DrawScene

    CONFIG.RUNSPLASH()

    -- EXE

    ROOT.SCHEDULERS.MAIN = CentralScheduler.New(lovr.timer.getTime)
    ROOT.SCRIPTSYS.MAIN = ScriptSys({
        Scheduler = ROOT.SCHEDULERS.MAIN,
        FileSystem = FS,
        DisableAfterSuccess = true,
    })

    SIGNAL.SCHEDULER = ROOT.SCHEDULERS.MAIN
    SIGNAL.CLOCK = lovr.timer.getTime

    -- DEFINING EXTRA GLOBALS

    BRIDGE.LoadGlobals({ SIGNAL = SIGNAL, ROOT = ROOT, ALLKEYS = require("ALLKEYS") })
    BRIDGE.ConnectDevices()

    RunService = GetService"RunService"
    require("Engine.Physics")

    GetService.AddService("Graphics", AstralEngine.Graphics)

    -- RUNNING ALL SCRIPTS

    CONFIG:APPLY()

    CURRENT_FRAME = 0
    CURRENT_CPUTICK = 0

    World.Component.LoadComponents({GetDir = lovr.filesystem.getDirectoryItems})

    World.Component.__RunPostPass()
end

function lovr.update(dt)
    ROOT.SCHEDULERS.MAIN:Update()
    RunService.__TICK(0,500,dt)
end

AstralEngine.Signals.OnWindowResize = require"Lib.Signal".new()

function lovr.resize(w,h)
    lovr.graphics.submit(lovr.graphics.getWindowPass())
    lovr.graphics.wait()
    AstralEngine.Window.W = w
    AstralEngine.Window.H = h
    AstralEngine.Window.__WindowResizedPasses(w,h)
    AstralEngine.Signals.OnWindowResize:Fire(w,h)
    GetService"Renderer".PassStorage.RebuildPassTable()
    collectgarbage("collect")
end

lovr.textinput = nil

function lovr.run()
    if lovr.load then lovr.load() end

    local W,H = AstralEngine._CONFIG.Game.Window.Width, AstralEngine._CONFIG.Game.Window.Height

    AstralEngine.Window.W = W
    AstralEngine.Window.H = H
    lovr.system.openWindow({
        width = W,
        height = H,
        fullscreen = AstralEngine._CONFIG.Game.Window.Fullscreen,
        Vsync = AstralEngine._CONFIG.Game.Window.Vsync,
        title = AstralEngine._CONFIG.Game.Window.Name,
        icon = AstralEngine._CONFIG.Game.Window.Icon,
    })

    -- GET GAME SCRIPTS
    local f = coroutine.create(function()
        require("GAMEDUMMY")
    end)
    local s,e = pcall(coroutine.resume,f)
    if not s then print(debug.traceback(f)) error(e) end
    -- GAME SCRIPTS OVER

    local Frames = 0
    local t = 0

    local CPUTime = 0
    local CpuTickrate = 1/CONFIG.CONFIG.CPURATE
    local LastCPUTime

    local RenderTime = 0
    local RenderTickrate = 1/CONFIG.CONFIG.RENDERRATE

    local EventTime = 0
    local EventTickrate = 1/CONFIG.CONFIG.EVENTRATE

    local PhysTime = 0
    local PhysicsRate = 1/CONFIG.CONFIG.PHYSRATE

    @ifdef<Physics.BindMainWorld>
    {
        local Phys = GetService"Physics"
        local MainPhysWorld, MainPhysWorldID = Phys.GetMainWorld()
        local UpdTrans = Phys.UpdateTransforms
        local SyncState = Phys.LuaToJolt
        local LastPhysTime = -1

        @macro<L,!USEBRACK>{M_PHYSTICK(&TIMER) =
            if MainPhysWorld then
                SyncState(MainPhysWorldID)
                MainPhysWorld:update(PhysicsRate)
                UpdTrans(MainPhysWorldID)
                LastPhysTime = &TIMER
            end
        }

        Phys.__OnWorldReset = function(W,WId)
            -- if ifdef fails, this just doesnt get attached so it doesnt fire
            -- Usercode can attach to this instead
            MainPhysWorld = W
            MainPhysWorldID = WId
        end

        @ifdef<Physics.Interpolate>{
            @macro<L,!USEBRACK>{PHYSICS_INTERPOLATE() = 
                -- get alpha, world and whatnot, interpolate
                local Alpha = TIME - LastPhysTime
                if Alpha >= 0 and Alpha <= 1 and MainPhysWorld then
                    MainPhysWorld:interpolate(Alpha)
                    UpdTrans(MainPhysWorldID)
                end
            }
        }
    }

    @ifdef<GC.UseAstr>{
        local GCTime = 0
        local GCRate = 1/CONFIG.CONFIG.GCRATE
        local GCReap = CONFIG.CONFIG.GCCollect
        collectgarbage("stop")
        @macro<L,!USEBRACK>:M_GCTick(&_SINK) = collectgarbage("step",GCReap)
    }

    local Drain = lovr.math.drain

    @macro<L>:MacAssignTickrate(&V) = function(N) &V = N > 0 and 1/N or -1 end

    AstralEngine.Tick = {
        SetCPURate = MacAssignTickrate(CpuTickrate),
        SetFrameRate = MacAssignTickrate(RenderTickrate),
        SetEventRate = MacAssignTickrate(EventTickrate),
        SetPhysRate = MacAssignTickrate(PhysicsRate),
        @ifdef<GC.UseAstr>{
        SetGCCollect = function(n)
            GCReap = n
        end,
        SetGCRate = MacAssignTickrate(GCRate),
        }
    }

    @macro<L,!USEBRACK>{GETTICK(&DT,&CT,&Time,&Tickrate,&CALL,&CV1)=
        &Time = &Time + &DT

        if &Time >= &Tickrate or &Tickrate <= 0 then
            &Time = &Time - &Tickrate
            -- MACRO CALL
            &CALL(&CV1)
        end
    }

    @macro<L,!USEBRACK>{GETCPUTICK(&DT,&CT,&Time,&Tickrate,&LastTime,&CALL) =
        &Time = &Time + &DT

        --&CALL
        if &Time >= &Tickrate or &Tickrate <= 0 then
            &Time = &Time - &Tickrate
            local CPUDT = &CT - &LastTime
            &LastTime = &CT
            -- CALLING THE INTERNAL MACRO
            &CALL(CPUDT)
        end
    }

    @execute<UNSAFE>{
        return lovr.system and [===[
        local PollEve = lovr.system.pollEvents
        local Poll = lovr.event.poll
        local Handlers = lovr.handlers
        local Clear = lovr.event.clear

        @macro<L,!USEBRACK>{M_EventTick(&_SINK) = 
            PollEve()
            for Name, A, B, C, D in Poll() do
                if Name == 'restart' then return name, lovr.restart and lovr.restart()
                elseif Name == 'quit' and (not lovr.quit or lovr.quit(A)) then return A or 0
                elseif Handlers[Name] then if Name == "resize" then lovr.graphics.wait() lovr.graphics.submit(lovr.graphics.getWindowPass()) lovr.graphics.wait() end Handlers[Name](A,B,C,D) end
            end
            Clear()
        }
        ]===]
    }

    @macro<L,!USEBRACK>{M_CPUTick(&DT) = 
        @ifdef<Physics.Interpolate & Physics.InterpolAtCPU>{
            PHYSICS_INTERPOLATE()
        }
        CURRENT_CPUTICK++
        Drain()
        lovr.update(&DT)
    }

    local Graph = lovr.graphics
    local Head = lovr.headset
    local Mirror = lovr.mirror

    local HGetPass = Head and Head.getPass
    local WGetPass = Graph and Graph.getWindowPass
    local Present = Graph and Graph.present
    local Submit = Graph and Graph.submit

    local PassTable = Renderer.PassStorage.PassTable

    @macro<L,!USEBRACK>{M_GPUTick(&_SINK) = 
        @execute<UNSAFE,COMP>{
            local RETURNFIELD = "CURRENT_FRAME++;\n"
            local HASHEADSET = lovr.headset
            if lovr.graphics then
                local CONCAT
                if HASHEADSET and lovr.draw then
                    RETURNFIELD = RETURNFIELD..[[
                        local Headset = HGetPass()
                        if Headset and (not lovr.draw or lovr.draw(Headset)) then Headset = nil end]]
                    CONCAT = "local Idx = #PassTable+1\nPassTable[Idx] = Headset\nPassTable[Idx+1] = Window\nSubmit(PassTable)\nPassTable[Idx] = nil\nPassTable[Idx+1] = nil\n"
                else
                    CONCAT = "local Idx = #PassTable+1\nPassTable[Idx] = Window\nSubmit(PassTable)\nPassTable[Idx] = nil\n"
                end
                RETURNFIELD = RETURNFIELD..[[
                    local Window = WGetPass()
                    RunService.__TICK(501,1000,Headset or Window)
                   ]]..CONCAT.."Present()"

            end
            if HASHEADSET then
                RETURNFIELD = RETURNFIELD.."lovr.headset.submit()"
            end

            @ifdef<Physics.Interpolate & Physics.InterpolAtRender>{
                RETURNFIELD = [[
                    PHYSICS_INTERPOLATE()
                ]]..RETURNFIELD
            }

            return RETURNFIELD
        }
    }

    @execute<UNSAFE>{
        local HASHEAD = not not lovr.headset
        local RV = "local Wrap = function(...) return lovr.draw and lovr.draw(...) end \n local RS = GetService'RunService'\n"
        local v = HASHEAD and "Mirror" or "Wrap"
        if HASHEAD then
            RV = RV..[[
            RS.BindToStep("_CORE_RENDER_HEADSET",749,Wrap)
            ]]
        end
        RV = RV..[[
            RS.BindToStep("_CORE_RENDER",750,]]..v..")"
        return RV
    }

    local LastTime = lovr.timer.getTime()
    LastCPUTime = LastTime

    local COUNTER = 0
    local TICK = 0
    return function()
        local TIME = lovr.timer.getTime()
        local DT = TIME - LastTime
        LastTime = TIME

        TICK = TICK + DT
        COUNTER = COUNTER + 1
        if TICK > 1 then
            print("TPS:",COUNTER)
            TICK = 0
            COUNTER = 0
        end

        -- EVENT
        @execute<UNSAFE>{
            return lovr.system and "GETTICK(DT,TIME,EventTime,EventTickrate,M_EventTick,nil)" or "-\-\NO SYS, NO EVENT"
        }

        -- CPU TICK
        GETCPUTICK(DT,TIME,CPUTime,CpuTickrate,LastCPUTime,M_CPUTick)

        -- GPU TICK
        GETTICK(DT,TIME,RenderTime,RenderTickrate,M_GPUTick,nil)

        @ifdef<Physics.BindMainWorld>{
        -- PHYS TICK
        GETTICK(DT,TIME,PhysTime,PhysicsRate,M_PHYSTICK,TIME)
        }

        @ifdef<GC.UseAstr>{
        -- GC TICK
        GETTICK(DT,TIME,GCTime,GCRate,M_GCTick,nil)
        }
    end
end
