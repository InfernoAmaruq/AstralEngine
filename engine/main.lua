local CONFIG = CONF

local SIGNAL = require("Lib.Signal")

local ROOT, World, Renderer, RunService, SS

AstralEngine.Callbacks = {}

-- LOAD

function lovr.load()
    -- INITIAL DECL
    require("ResizeRepair")

    _G.ENUM = require("Lib.Enum")

    require("Engine")
    local CentralScheduler = require("Engine.Scheduler")
    require("Engine.Render")
    World = require("Engine.World")

    Renderer = GetService"Renderer"
    local Entity = GetService"Entity"

    local SERIALIZER = require("Lib.Serialize")

    local BRIDGE = require("LOVRBridge")

    ROOT = {
        SCHEDULERS = {},
        SCRIPTSYS = {},
    }

    QUIT = lovr.event.quit

    lovr.draw = Renderer.DrawScene

    CONFIG.RUNSPLASH()

    -- EXE

    ROOT.SCHEDULERS.MAIN = CentralScheduler.New(lovr.timer.getTime)

    SIGNAL.SCHEDULER = ROOT.SCHEDULERS.MAIN
    SIGNAL.CLOCK = lovr.timer.getTime

    -- DEFINING EXTRA GLOBALS

    BRIDGE.LoadGlobals({ SIGNAL = SIGNAL, ROOT = ROOT, ALLKEYS = require("ALLKEYS") })

    RunService = GetService"RunService"
    require("Engine.Physics")

    -- RUNNING ALL SCRIPTS

    CURRENT_FRAME = 0
    CURRENT_CPUTICK = 0

    World.Component.LoadComponents({GetDir = lovr.filesystem.getDirectoryItems})

    World.Component.__RunPostPass()

    SS = require("Engine.ScriptSystem")

    -- now that everything is loaded, alias
    BRIDGE.ConnectDevices()
    BRIDGE.LoadRandom()
    BRIDGE.LoadWindow()
    BRIDGE.Alias()

    Renderer.LateCall()
end

lovr.textinput = nil

local QuitSig = SIGNAL.new(SIGNAL.Type.RTC)
function lovr.quit(...)
    local ShouldAbort = false
    if AstralEngine.Callbacks.OnQuit then ShouldAbort = AstralEngine.Callbacks.OnQuit(...) end

    if ShouldAbort then return false end

    QuitSig:Fire(...)

    return true
end

lovr.mirror = nil
lovr.draw = nil

function lovr.run()
    if lovr.load then lovr.load() end
    collectgarbage("collect")
    _G.AstralEngine.__ENGINETHREAD = coroutine.running()

    -- RUNTIME DEFINITION

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
                if MainPhysWorld then
                    local Alpha = math.min(PhysicsRate > 0 and (PhysTime / PhysicsRate) or 1,1)
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

        if &Tickrate <= 0 then
            &CALL(&CV1)
        else
            while &Time >= &Tickrate do
            &Time = &Time - &Tickrate
            -- MACRO CALL
            &CALL(&CV1)
            end
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
                elseif Handlers[Name] then Handlers[Name](A,B,C,D) end
            end
            Clear()
        }
        ]===]
    }

    @execute<UNSAFE>{
        if lovr.headset then
            return 'local H_UPD = lovr.headset.submit; @macro<L>{CALL_HEADSET() = H_UPD()}
        end
        return '@macro<L>{CALL_HEADSET() = -- NO HEADSET}
    }

    @macro<L,!USEBRACK>{M_CPUTick(&DT) = 
        @ifdef<Physics.Interpolate & Physics.InterpolAtCPU>{
            PHYSICS_INTERPOLATE()
        }
        CURRENT_CPUTICK++;
        @execute<UNSAFE>{
            if lovr.headset then
                return "if lovr.headset.isActive() then XRDT = lovr.headset.update() end"
            end
        }
        ROOT.SCHEDULERS.MAIN:Update()
        RunService.__TICK(0,500,&DT)
        Drain()
    }

    local Graph = lovr.graphics
    local Head = lovr.headset

    local HGetPass = Head and Head.getPass
    local WGetPass = Graph and Graph.getWindowPass
    local Present = Graph and Graph.present
    local Submit = Graph and Graph.submit
    local SubmitHead = Head and Head.submit

    @ifdef<Extra.PinPass>{
        local REG = debug.getregistry()
        REG.__PINNED_PASS = WGetPass()
    }

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
                RETURNFIELD = RETURNFIELD.."SubmitHead()"
            end
            @ifdef<Physics.Interpolate & Physics.InterpolAtRender>{
                RETURNFIELD = [[
                    PHYSICS_INTERPOLATE()
                ]]..RETURNFIELD
            }
            return RETURNFIELD
        }
    }

    local LastTime = lovr.timer.getTime()
    LastCPUTime = LastTime

    local COUNTER = 0
    local TICK = 0

    local SLEEP = lovr.timer.sleep

    local LASTCPUT = 0

    -- MOUNT

    -- try execute core script first
    local Ok, Err = pcall(loadfile,"GAMEFILE/launch.lua")
    if Ok then
        if Err then
            task.spawn(Err)
        end
    else
        AstralEngine.Log("File 'launch.lua' encountered an error!\n > "..tostring(Err),"FATAL")
    end

    SS.Scene.LoadScene(AstralEngine._CONFIG.Filesystem.EntryScene)

    -- DEFINE LOOP FUNC

    return function()
        local TIME = lovr.timer.getTime()
        local DT = TIME - LastTime
        LastTime = TIME

        @execute<UNSAFE>{
            if lovr.headset then return "local XRDT = DT" end
        }

        TICK = TICK + DT
        COUNTER = COUNTER + 1
        if TICK > 1 then
            local osc, cpuc = os.clock(), debug.cpuclock()
            print("TPS:",COUNTER,osc,cpuc,cpuc/osc*100,cpuc-LASTCPUT)
            TICK = 0
            COUNTER = 0
            LASTCPUT = cpuc
        end

        -- EVENT
        @execute<UNSAFE>{
            return lovr.system and "GETTICK(DT,TIME,EventTime,EventTickrate,M_EventTick,nil)" or "-\-\NO SYS, NO EVENT"
        }

        -- CPU TICK
        GETTICK(@execute<UNSAFE>{return lovr.headset and "XRDT" or "DT"},TIME,CPUTime,CpuTickrate,M_CPUTick,CpuTickrate)

        -- GPU TICK
        GETTICK(@execute<UNSAFE>{return lovr.headset and "XRDT" or "DT"},TIME,RenderTime,RenderTickrate,M_GPUTick,nil)

        @ifdef<Physics.BindMainWorld>{
        -- PHYS TICK
        GETTICK(DT,TIME,PhysTime,PhysicsRate,M_PHYSTICK,TIME)
        }

        @ifdef<GC.UseAstr>{
        -- GC TICK
        GETTICK(DT,TIME,GCTime,GCRate,M_GCTick,nil)
        }

        @ifdef<Runtime.Sleep>{
            SLEEP(0)
        }
    end
end
