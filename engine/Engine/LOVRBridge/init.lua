local LVRB = {}

-- configure our clock
debug.cpuclock = os.clock
os.clock = lovr.timer.getTime

local wrapself = function(s, f, VAL)
    if VAL ~= nil then
        return function(...)
            return f(s, VAL, ...)
        end
    else
        return function(...)
            return f(s, ...)
        end
    end
end

LVRB.VirtualiseScheduler = function(Scheduler)
    _G.task = {}
    local Global = _G.task
    Global.wait = wrapself(Scheduler,Scheduler.Wait,false)
    Global.delay = wrapself(Scheduler,Scheduler.Delay,false)
    Global.defer = wrapself(Scheduler,Scheduler.Defer,false)
    Global.spawn = wrapself(Scheduler,Scheduler.Spawn,false)
    Global.waitfor = wrapself(Scheduler,Scheduler.WaitFor)
    Global.spawnat = wrapself(Scheduler,Scheduler.SpawnAt)
    Global.escape = wrapself(Scheduler,Scheduler.Escape)

    Global.raw = {
        wait = wrapself(Scheduler,Scheduler.Wait,true),
        delay = wrapself(Scheduler,Scheduler.Delay,true),
        defer = wrapself(Scheduler,Scheduler.Defer,true),
        spawn = wrapself(Scheduler,Scheduler.Spawn,true)
    }

    LVRB.VirtualiseScheduler = nil
end

-- INPUT SYSTEM

LVRB.ConnectDevices = function()
    local InputService = GetService "InputService"

    local Mouse = InputService.Mouse
    local KB = InputService.Keyboard
    local CAS = GetService "ContextActionService"

    local AstralKeys = require("Keys")

    local KB_AstralToLOVR = AstralKeys.KB
    local Mouse_AstralToLOVR = AstralKeys.Mouse

    local KB_LOVRToAstral = {}
    local Mouse_LOVRToAstral = {}

    local CasTop = 1
    local ToCASCode = {}

    local KeyArray = {}

    for Astral, Lovr in pairs(KB_AstralToLOVR) do
        KB_LOVRToAstral[Lovr] = Astral
        KeyArray[Lovr] = false

        if not ToCASCode[Lovr] then -- handle key aliases safely
            ToCASCode[Lovr] = CasTop
            CasTop = CasTop + 1
        end
    end

    for Astral, Lovr in pairs(Mouse_AstralToLOVR) do
        Mouse_LOVRToAstral[Lovr] = Astral
        KeyArray[Lovr] = false

        if not ToCASCode[Lovr] then -- handle key aliases safely
            ToCASCode[Lovr] = CasTop
            CasTop = CasTop + 1
        end
    end

    InputService.__GetKeyArr = function()
        return KeyArray
    end

    InputService.IsDown = function(e)
        return KeyArray[e.Value]
    end

    local KBE = Enum(KB_AstralToLOVR, "KeyCode")
    local ME = Enum(Mouse_AstralToLOVR, "UserInputType")

    local function INPTOSTR(t)
        local s = [[Input: {
            KeyCode = %s,
            UserInputType = %s,
            State = %s,
            Mouse = %s
        }]]
        return s:format(tostring(t.KeyCode) or "NIL", tostring(t.UserInputType) or "NIL", tostring(t.State),
            tostring(t.Mouse) or "NIL")
    end

    local MT = {__tostring = INPTOSTR}

    local InputTable = setmetatable(
            { KeyCode = nil, UserInputType = nil, State = nil, Mouse = nil },
            MT)


    CAS.__RAWBIND = CAS.Bind

    @macro<L,!USEBRACK>{MAKEINPUTDATA(TERM,IsKB,CODE,ST,mx,my,ENUM) = 
        --MACRO BEGIN
        local DATA = InputTable

        local ID = ToCASCode[CODE]

        DATA.State = ST
        DATA.UserInputType = not IsKB and ENUM
        DATA.Mouse = not IsKB and vec2(mx, my)
        DATA.KeyCode = IsKB and ENUM

        TERM = CAS.__CALL(ID, DATA)

        --MACRO END
    }

    local OGBIND = CAS.Bind

    @macro<L>:TRANSLATE_Enum(K) = ToCASCode[K.Value];

    CAS.Bind = function(N, P, F, ...)
        if select('#', ...) > 3 then
            local t = { ... }
            for i, KEY in ipairs(t) do
                t[i] = TRANSLATE_Enum(KEY)
            end
            return OGBIND(N, P, F, unpack(t))
        else
            local K1, K2, K3 = select(1, ...)
            K1, K2, K3 = TRANSLATE_Enum(K1), TRANSLATE_Enum(K2), TRANSLATE_Enum(K3)
            return OGBIND(N, P, F, K1, K2, K3)
        end
    end

    -- MOUSE

    function lovr.wheelmoved(...)
        Mouse.WheelMoved:Fire(...)
    end

    function lovr.mousemoved(x,y,...)
        Mouse.MouseMoved:Fire(x,y,...)
    end

    function lovr.mousepressed(x, y, c)
        KeyArray[c] = true

        local ac = Mouse_LOVRToAstral[c]

        local E = ME[ac]

        local Terminated
        MAKEINPUTDATA(Terminated, false, c, true, x, y, E)
        Mouse.MouseButtonDown:Fire(E, x, y, Terminated)
    end

    function lovr.mousereleased(x, y, c)
        KeyArray[c] = false

        local ac = Mouse_LOVRToAstral[c]

        local E = ME[ac]

        local Terminated
        MAKEINPUTDATA(Terminated, false, c, false, x, y, E)
        Mouse.MouseButtonUp:Fire(E, x, y, Terminated)
    end

    function lovr.textinput(Char, Code)
        KB.TextInput:Fire(Char, Code)
    end

    -- KB

    function lovr.keypressed(k, c, r)
        if r then return end

        KeyArray[k] = true

        local ak = KB_LOVRToAstral[k]

        local E = KBE[ak]

        local Terminated
        MAKEINPUTDATA(Terminated, true, k, true,nil,nil,E)
        KB.KeyPressed:Fire(E, c, Terminated)
    end

    function lovr.keyreleased(k, c)
        KeyArray[k] = false

        local ak = KB_LOVRToAstral[k]

        local E = KBE[ak]

        local Terminated
        MAKEINPUTDATA(Terminated, true, k, false,nil,nil,E)
        KB.KeyReleased:Fire(E, c, Terminated)
    end

    LVRB.ConnectDevices = nil
end

LVRB.LoadWindow = function()
    local Sig = require("Lib.Signal")

    AstralEngine.Signals.OnFocusChanged = Sig.new(Sig.Type.Default)

    AstralEngine.Window.SetSize = lovr.system.setWindowSize
    AstralEngine.Window.SetFullscreen = lovr.system.setWindowFullscreen

    AstralEngine.Window.IsFocused = lovr.system.isWindowFocused
    AstralEngine.Window.IsWindowVisible = lovr.system.IsWindowVisible

    AstralEngine.Window.GetWindowDimensions = lovr.system.getWindowDimensions
    AstralEngine.Window.GetWindowWidth = lovr.system.getWindowWidth
    AstralEngine.Window.GetWindowHeight = lovr.system.getWindowHeight
    AstralEngine.Window.GetPass = lovr.graphics.getWindowPass
    AstralEngine.Window.GetWindowDensity = lovr.system.getWindowDensity

    AstralEngine.Window.IsFullscreen = lovr.system.isWindowFullscreen

    function lovr.focus(f)
        AstralEngine.Signals.OnFocusChanged:Fire(f)
    end

    AstralEngine.Signals.OnWindowResize = Sig.new(Sig.Type.RTC)

    function lovr.resize(w,h)
        AstralEngine.Window.W = w
        AstralEngine.Window.H = h
        AstralEngine.Window.__WindowResizedTextures(w,h)
        AstralEngine.Signals.OnWindowResize:Fire(w,h)
        GetService"Renderer".PassStorage.RebuildPassTable()
        collectgarbage("collect")
    end

    -- FINALLY OPEN THE WINDOW

    local W,H = AstralEngine.Config.Game.Window.Width, AstralEngine.Config.Game.Window.Height

    lovr.system.openWindow({
        width = W,
        height = H,
        fullscreen = AstralEngine.Config.Game.Window.Fullscreen,
        resizable = AstralEngine.Config.Game.Window.Resizable,
        title = AstralEngine.Config.Game.Window.Name,
        icon = AstralEngine.Config.Game.Window.Icon,
    })

    AstralEngine.Window.W = AstralEngine.Window.GetWindowWidth()
    AstralEngine.Window.H = AstralEngine.Window.GetWindowHeight()

    local SetCursorIcon = lovr.system.setCursorIcon

    Enum({
        Default = 1,
        Hand = 2,
        Crosshair = 3,
        IBeam = 4,
        HResize = 5,
        VResize = 6
    },"CursorIconType")

    AstralEngine.Window.SetCursorIcon = function(Inp)
        SetCursorIcon(Inp and Inp.Name:lower() or "default")
    end

    LVRB.LoadWindow = nil
end

LVRB.LoadRandom = function()
    math.randomseed = lovr.math.setRandomSeed
    math.random = lovr.math.random
    math.noise = lovr.math.noise
    math.getrandomseed = lovr.math.getRandomSeed
    math.randomnormal = lovr.math.randomNormal

    -- seeding
    local t = lovr.timer.getTime()
    local os = lovr.system.getOS()
    local pid = lovr.system.getCoreCount()
    local addr = debug.getaddress({})

    local SEED = bit.bxor(math.floor(t * 1e9),
     (#os * 0x9e3779b9),
     bit.lshift(pid, 16),
     tonumber(addr, 16))
    math.randomseed(SEED, bit.bxor(SEED, tonumber(debug.getaddress({}),16)))

    math.newrandom = function(...)
        local RanGen = lovr.math.newRandomGenerator(...)
        local Mt = getmetatable(RanGen)

        if Mt.WRAPPED then return RanGen end

        local OgIdx = Mt.__index
        Mt.__index = function(_,k)
            local r = k:sub(1,1)
            if r == r:upper() then
                k = r:lower()..k:sub(2)
            end
            return OgIdx[k]
        end

        return RanGen
    end

    LVRB.LoadRandom = nil
end

LVRB.Alias = function()
    -- this is for aliasing LOVR functions, should be done last when there is no more mutation

    -- FILESYSTEM
    AstralEngine.Filesystem = {}
    for i,v in pairs(lovr.filesystem) do
        local Key = i:sub(1,1):upper()..i:sub(2)
        AstralEngine.Filesystem[Key] = v
    end

    -- SYSTEM
    -- requires a bit more care so
    AstralEngine.System = AstralEngine.System or {}
    AstralEngine.System.GetCoreCount = lovr.system.getCoreCount
    AstralEngine.System.GetOS = lovr.system.getOS
    AstralEngine.System.OpenConsole = lovr.system.openConsole
    AstralEngine.System.SetClipboardText = lovr.system.setClipboardText
    AstralEngine.System.GetClipboardText = lovr.system.getClipboardText
    AstralEngine.System.RequestPermission = lovr.system.requestPermission
    AstralEngine.System.GetGPUInfo = lovr.graphics.getDevice
    AstralEngine.System.GetGPUFeatures = lovr.graphics.getFeatures
    AstralEngine.System.GetGPULimits = lovr.graphics.getLimits
    AstralEngine.System.IsTextureSupported = lovr.graphics.isFormatSupported

    AstralEngine.System.Quit = lovr.event.quit
    AstralEngine.System.Restart = lovr.event.quit

    AstralEngine.Graphics.SetBackgroundColor = lovr.graphics.setBackgroundColor
    AstralEngine.Graphics.GetBackgroundColor = lovr.graphics.getBackgroundColor
    AstralEngine.Graphics.EnableTiming = lovr.graphics.setTimingEnabled
    AstralEngine.Graphics.IsTimingEnabled = lovr.graphics.isTimingEnabled
    AstralEngine.Graphics.GetDefaultFont = lovr.graphics.getDefaultFont

    AstralEngine.GetHostVersion = lovr.getVersion

    LVRB.Alias = nil
end

return LVRB
