local CONFIG = CONF

local Signal = require("Lib/Signal")
local AnsiColorLib = require("Lib/ANSIText")

local MainScheduler, World, Renderer, RunService, SS

local CURRENT_FRAME = 0
local CURRENT_CPUTICK = 0

AstralEngine.Callbacks = {}

-- LOAD

function lovr.load()
    -- LOAD MISC

    _G.ENUM = require("Lib.Enum")
    require("Engine/Graphics")

    local Bridge = loadfile("Engine/LOVRBridge")() -- we want it to run once and be freed after. So we avoid caching
    Bridge.Alias() -- alias early for compat reasons

    -- INITIALISE SERVICES
    require("Engine")

    -- QUEUE PLUGINS
    local PluginHandler = require("Engine/PluginManager")

    -- turn useful libs to plugin
    AstralEngine.Plugins.SignalLib = Signal
    AstralEngine.Plugins.ANSIColor = AnsiColorLib

    for _, Dir in ipairs(lovr.filesystem.getDirectoryItems("/Plugins")) do
        lovr.filesystem.alias("/Plugins/" .. Dir, "Plugins")
    end
    for _, Dir in ipairs(lovr.filesystem.getDirectoryItems(package.GAME_PATH.."/Plugins")) do
        lovr.filesystem.alias(package.GAME_PATH.."/Plugins/" .. Dir, "Plugins")
    end

    for _, PluginFolder in ipairs(lovr.filesystem.getAliased("Plugins")) do
        PluginHandler.Load(PluginFolder)
    end

    -- LOADING ALL OTHER SERVICES

    local CentralScheduler = require("Engine/Services/Scheduler")
    MainScheduler = CentralScheduler.New(lovr.timer.getTime)

    Signal.Scheduler = MainScheduler
    Signal.Clock = lovr.timer.getTime

    Renderer = require("Engine/Services/Render")

    World = require("Engine/Services/World")

    RunService = require("Engine/Services/RunService")
    require("Engine/Services/InputService")
    require("Engine/Services/ContextActionService")

    require("Engine/Services/Physics")

    -- LOAD COMPONENTS AND SCRIPT SYSTEM

    require("Engine/Services/AssetManager")
    SS = require("Engine/Services/ScriptSystem")

    World.Component.LoadComponents()

    World.Component.__RunPostPass()

    -- now that everything is loaded, bridge it
    Bridge.VirtualiseScheduler(MainScheduler)

    Bridge.ConnectDevices()
    Bridge.LoadRandom()
    Bridge.LoadWindow()

    Renderer.LateCall()

    AstralEngine.Plugins.Finish()
    GetService.Disable() -- Disable GetService so it errors when you try to index a non-existant service
end

local QuitSig = Signal.new(Signal.Type.RTC)
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

    collectgarbage("setpause",CONFIG.CONFIG.GCPAUSE)
    -- stepmul affects everything so is unconditional
    collectgarbage("setstepmul",CONFIG.CONFIG.GCSTEPMUL)
    @ifdef<GC.UseAstr>{
        local GCPause = CONFIG.CONFIG.GCPAUSE
        local GCTime = -1
        local GCRate = 1/CONFIG.CONFIG.GCRATE
        collectgarbage("stop")

        local LastSize = collectgarbage"count"

        @macro<L,!USEBRACK>{M_GCTick(&_SINK)=
            if collectgarbage("count") >= LastSize * (GCPause / 100) then
                collectgarbage("step", collectgarbage("count") * 0.05)
                LastSize = collectgarbage"count"
            end
        }
    }

    local Drain = lovr.math.drain

    @macro<L>:MacAssignTickrate(&V) = function(N) &V = N > 0 and 1/N or -1 end

    AstralEngine.Tick = {
        SetCPURate = MacAssignTickrate(CpuTickrate),
        SetFrameRate = MacAssignTickrate(RenderTickrate),
        SetEventRate = MacAssignTickrate(EventTickrate),
        SetPhysRate = MacAssignTickrate(PhysicsRate),
        @ifdef<GC.UseAstr>{
        SetGCRate = MacAssignTickrate(GCRate),
        SetGCPause = function(n)
            collectgarbage("setpause",n)
            GCPause = n
        end,
        }
        @ifdef<!GC.UseAstr>{
        SetGCPause = function(n)
            collectgarbage("setpause",n)
        end,
        }
        SetGCStepMul = function(n)
            collectgarbage("setstepmul",n)
        end
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
            return 'local H_UPD = lovr.headset.submit; @macro<L>{CALL_HEADSET() = H_UPD()}'
        end
        return '@macro<L>{CALL_HEADSET() = -- NO HEADSET}'
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
        MainScheduler:Update()
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
                    if Headset or Window then
                        RunService.__TICK(501,1000,Headset or Window)
                    end
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
    local Ok, Err = pcall(loadfile,package.GAME_PATH.."/launch.lua")

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
            print("TPS:",COUNTER,osc,cpuc,cpuc/osc*100,cpuc-LASTCPUT,collectgarbage"count")
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
