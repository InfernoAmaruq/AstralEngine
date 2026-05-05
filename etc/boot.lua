lovr = require("lovr")

local lovr = lovr

function lovr.arg(arg)
    local options = {
        _help = { short = "-h", long = "--help", help = "Show help and exit" },
        _version = { short = "-v", long = "--version", help = "Show version and exit" },
        console = { long = "--console", help = "Attach Windows console" },
        debug = { long = "--debug", help = "Enable debugging checks and logging" },
        simulator = { long = "--simulator", help = "Force headset simulator" },
        watch = { short = "-w", long = "--watch", help = "Watch files and restart on change" },
        engine = { short = "-e", long = "--engine", help = "Path override to engine folder" },
        game = { short = "-g", long = "--game", help = "Path to game folder/archive" },
        define = { short = "-d", long = "--define", help = "Define a variable with <Name>=<Value>" },
    }

    local shift

    for i, argument in ipairs(arg) do
        if argument:match("^%-") then
            for name, option in pairs(options) do
                local ShortLen = option.short and option.short:len()
                local LongLen = option.long and option.long:len()

                local IsShort = ShortLen and argument:sub(1, ShortLen) == option.short
                local IsLong = LongLen and argument:sub(1, LongLen) == option.long

                if IsShort or IsLong then
                    local Value = argument:sub((IsShort and ShortLen or LongLen) + 1)
                    if name == "define" then
                        arg[name] = arg[name] or {}

                        local v1, v2, eq
                        v1, eq = unpack(string.split(Value, "="))
                        v1, v2 = unpack(string.split(v1, "."))

                        if v2 then
                            arg[name][v1] = arg[name][v1] or {}
                            arg[name][v1][v2] = eq
                        else
                            arg[name][v1] = eq
                        end
                    else
                        arg[name] = Value ~= "" and Value or true
                    end
                    break
                end
            end
        else
            shift = i
            break
        end
    end

    shift = shift or (#arg + 1)

    if arg.console or arg._help or arg._version then
        local ok, system = pcall(require, "lovr.system")
        if ok and system then
            system.openConsole()
        end
    end

    if arg._help then
        local message = {}

        local list = {}
        for name, option in pairs(options) do
            option.name = name
            table.insert(list, option)
        end

        table.sort(list, function(a, b)
            return a.name < b.name
        end)

        for i, option in ipairs(list) do
            if option.short and option.long then
                table.insert(message, ("  %s, %s\t\t%s"):format(option.short, option.long, option.help))
            else
                table.insert(message, ("  %s\t\t%s"):format(option.long or option.short, option.help))
            end
        end

        table.insert(message, 1, "usage: lovr [options] [<source>]\n")
        table.insert(message, 2, "options:")
        table.insert(message, "\n<source> can be a Lua file, a folder, or a zip archive")
        print(table.concat(message, "\n"))
        os.exit(0)
    end

    if arg._version then
        if select("#", lovr.getVersion()) >= 5 then
            print(("ASTRAL %d.%d.%d (%s) %s"):format(lovr.getVersion()))
        else
            print(("ASTRAL %d.%d.%d (%s)"):format(lovr.getVersion()))
        end
        os.exit(0)
    end

    return function(conf)
        if arg.debug then
            conf.graphics.debug = true
            conf.headset.debug = true
        end

        if arg.simulator then
            conf.headset.connect = false
            conf.headset.start = false
        end

        if arg.watch then
            lovr.filesystem.watch()
        end
    end
end

local conf = {
    version = "0.0.1",
    identity = "default",
    saveprecedence = true,
    modules = {
        audio = true,
        data = true,
        event = true,
        graphics = true,
        headset = true,
        math = true,
        physics = true,
        system = true,
        thread = true,
        timer = true,
    },
    audio = {
        start = true,
        spatializer = nil,
    },
    graphics = {
        debug = false,
        vsync = true,
        stencil = false,
        antialias = true,
        hdr = false,
        shadercache = true,
    },
    headset = {
        connect = true,
        start = true,
        debug = false,
        seated = false,
        mask = true,
        stencil = false,
        antialias = true,
        supersample = false,
        submitdepth = true,
        overlay = false,
        controllerskeleton = "controller",
    },
    math = {
        globals = true,
    },
    thread = {
        workers = -1,
    },
    window = {
        width = 720,
        height = 800,
        fullscreen = false,
        resizable = false,
        title = "Astral",
        icon = nil,
    },
}

local ZipTag = "ENGINE"

local function HandleZipPath(Path)
    local ZipEnd = Path:find("%.zip", 1, false)
    if not ZipEnd then
        return nil
    end

    ZipEnd = ZipEnd + 3

    local ZipPath = Path:sub(1, ZipEnd)
    local InnerPath = Path:sub(ZipEnd + 2)

    if InnerPath == "" then
        InnerPath = nil
    end

    return ZipPath, InnerPath
end

function lovr.boot()
    lovr.filesystem = require("lovr.filesystem")

    local Normalize = lovr.filesystem.normalize

    -- See if there's a ZIP archive fused to the executable, and set up the fused CLI if it exists

    local bundle, root = lovr.filesystem.getBundlePath()
    local fused = bundle and lovr.filesystem.mount(bundle, nil, true, root)

    lovr.filesystem.isFused = function()
        return fused
    end

    local cli = lovr.arg and lovr.arg(arg)

    -- Figure out source archive and main module.  CLI places source at arg[0]

    local PossiblePaths = {
        "./Engine/",
        "./ENGINE/",
        "../Engine/",
        "../ENGINE/",
        "./",
    }

    arg.game = arg.game or arg[1] or "./GAMEFILE"

    local game = arg.game
    local path = arg.engine

    local pre = "pre.lua"

    local EXE = (lovr.filesystem.getExecutablePath() or root or bundle):gsub("\\", "/")
    local EXEFOLD = EXE:gsub("[^/\\]+$", "")

    _G.package.ENG_PATH = "/"
    _G.package.GAME_PATH = "GAMEFILE/"

    local ok, Data = pcall(require, "meta")

    local IsFused = fused

    local Mounted, Failed
    if not IsFused then
        if path then
            path = "/" .. Normalize(EXEFOLD .. path)
            local Zip, Inner = HandleZipPath(path)

            Inner = Inner or ""

            if Zip then
                Mounted, Failed = lovr.filesystem.mount(Zip, ZipTag)
                if not Mounted then
                    error("Failed to mount zip file! " .. Failed)
                else
                    print("MOUNTED:", Zip, ZipTag, #lovr.filesystem.getDirectoryItems(ZipTag))
                end
                path = ZipTag
                pre = path .. "/pre.lua"

                _G.package.ENG_PATH = path
            else
                Mounted, Failed = lovr.filesystem.mount(path)
                _G.package.ENG_PATH = "Engine"
            end
        else
            for _, v in ipairs(PossiblePaths) do
                local p = "/" .. Normalize(EXEFOLD .. v)

                Mounted, Failed = lovr.filesystem.mount(p)

                if Failed then
                    print("failed to mount engine:", p, Failed)
                end

                if Mounted then
                    path = v
                    break
                end
            end
        end
    elseif not Data or (Data and not Data.Engine) then
        Mounted = IsFused

        if not lovr.filesystem.isFile("main.lua") then
            for _, v in ipairs({ "Engine", "ENGINE" }) do
                local IsDir = lovr.filesystem.isDirectory(v)
                if IsDir then
                    package.ENG_PATH = v
                    break
                end
            end
        end
    elseif Data and Data.Engine then
        Mounted = true
        package.ENG_PATH = Data.Engine
    end

    package.GAME_PATH = Data and Data.Gamefile or package.GAME_PATH

    if not Mounted then
        if path then
            error(("Failed to mount engine path at: %s (%s)"):format(path, Failed))
        else
            local NormalizedPaths = {}

            for _, v in pairs(PossiblePaths) do
                table.insert(NormalizedPaths, "/" .. Normalize(EXEFOLD .. v))
            end

            error(("Failed to mount engine path, searched:\n%s"):format(table.concat(NormalizedPaths, "\n")))
        end
    end

    if not lovr.filesystem.isFile(package.ENG_PATH .. "/main.lua") then
        error("COULD NOT FIND main.lua")
    end

    if path and path:sub(-1, -1) ~= "/" then
        path = path .. "/"
    end

    -- Mount source archive, make sure it's got the main file, and load pre.lua

    lovr.filesystem.setSource(path or lovr.filesystem.getExecutablePath())
    if path ~= bundle and not fused then
        lovr.filesystem.unmount(bundle)
    end
    if lovr.filesystem.isFile(package.ENG_PATH .. "/" .. pre) then
        ok, failure = pcall(lovr.filesystem.load(package.ENG_PATH .. "/" .. pre))
        if failure == -1 then
            error("No game path has been provided")
        end
    end
    if ok and lovr.conf then
        ok, failure = pcall(lovr.conf, conf)
    end

    lovr._setConf(conf)

    if IsFused and conf and conf.identity then
        conf.identity = "ASTR/" .. conf.identity
        -- lovr is weird, bundled files get saved to share/<identity> not share/astr/<identity>, so im forcing it to be the same here
    end

    lovr.filesystem.setIdentity(conf.identity, conf.saveprecedence)

    if lovr.identitySet then
        lovr.identitySet()
        lovr.identitySet = nil
    end
    if lovr.conf then
        lovr.conf = nil
    end

    -- CLI gets a chance to use/modify conf and handle arguments

    if ok and cli then
        ok, failure = pcall(cli, conf)
    end

    -- Boot!

    for module in pairs(conf.modules) do
        if conf.modules[module] then
            local loaded, result = pcall(require, "lovr." .. module)
            if not loaded then
                lovr.log(string.format("Could not load module %q: %s", module, result), "warn")
            else
                lovr[module] = result
            end
        end
    end

    if lovr.headset and conf.headset.connect then
        local ok, message = lovr.headset.connect()
        if not ok and conf.headset.debug then
            lovr.log(
                string.format("Could not connect to headset, falling back to simulator (%s)", message),
                "warn",
                "XR"
            )
        end
    end

    if lovr.filesystem then
        local Os = lovr.system and lovr.system.getOS() or lovr.getOS()

        if Os == "Windows" then
            -- set paths

            local GetRealDir = lovr.filesystem.getRealDirectory
            lovr.filesystem.getRealDirectory = function(Path)
                local Ret = GetRealDir(Path)
                if not Ret then
                    Ret = GetRealDir(Path, lovr.filesystem.toWindows(Path))
                end
                return Ret and Ret:gsub(Win, Unix)
            end

            local GetExe = lovr.filesystem.getExecutablePath
            lovr.filesystem.getExecutablePath = function()
                return GetExe():gsub(Win, Unix)
            end
        end
    end

    if lovr.graphics then
        lovr.graphics.initialize()
    end

    if lovr.headset and conf.headset.start then
        lovr.headset.start()
    end

    if not ok and failure then
        error(failure)
    end

    local SearchAt = package.ENG_PATH .. "/main.lua"

    require(SearchAt)

    return lovr.run()
end

function lovr.run()
    if lovr.timer then
        lovr.timer.step()
    end
    if lovr.load then
        lovr.load(arg)
    end
    return function()
        if lovr.headset then
            lovr.headset.pollEvents()
        end
        if lovr.system then
            lovr.system.pollEvents()
        end
        if lovr.event then
            for name, a, b, c, d in lovr.event.poll() do
                if name == "restart" then
                    return "restart", lovr.restart and lovr.restart()
                elseif name == "quit" and (not lovr.quit or not lovr.quit(a)) then
                    return a or 0
                elseif name ~= "quit" and lovr.handlers[name] then
                    lovr.handlers[name](a, b, c, d)
                end
            end
        end
        local dt = 0
        if lovr.timer then
            dt = lovr.timer.step()
        end
        if lovr.headset then
            dt = lovr.headset.update()
            if not lovr.headset.isActive() then
                lovr.simulate(dt)
            end
        end
        if lovr.update then
            lovr.update(dt)
        end
        if lovr.graphics then
            local window = lovr.graphics.getWindowPass()
            local headset = lovr.headset and lovr.headset.getPass()
            if headset and lovr.draw and lovr.draw(headset) then
                headset = nil
            end
            if window and lovr.mirror and lovr.mirror(window) then
                window = nil
            end
            if headset or window then
                lovr.graphics.submit(headset, window)
            end
            if lovr.headset then
                lovr.headset.submit()
            end
            lovr.graphics.present()
        elseif lovr.headset then
            lovr.headset.submit()
        end
        if lovr.math then
            lovr.math.drain()
        end
    end
end

function lovr.mirror(pass)
    if lovr.headset then
        local texture = lovr.headset.isActive() and lovr.headset.getTexture()
        if texture then
            pass:fill(texture)
        else
            return true
        end
    else
        return lovr.draw and lovr.draw(pass)
    end
end

local mouseX, mouseY, handX, handY, distance, pitch, yaw = nil, nil, 0, 0, 0.5, nil, nil

function lovr.simulate(dt)
    if not lovr.math then
        return
    end

    if not pitch or not yaw then
        pitch, yaw = quat(lovr.headset.getOrientation()):getEuler()
        mouseX, mouseY = lovr.system.getMousePosition()
    end

    local movespeed = 3
    local sprintspeed = 15
    local walkspeed = 0.5
    local turnspeed = 0.005
    local turnsmooth = 30

    local click = lovr.system.isMouseDown(1)

    lovr.system.setMouseGrabbed(click)

    local lastX, lastY = mouseX, mouseY
    mouseX, mouseY = lovr.system.getMousePosition()

    if click then
        yaw = yaw - (mouseX - lastX or mouseX) * turnspeed
        pitch = pitch - (mouseY - lastY or mouseY) * turnspeed
        pitch = math.min(pitch, math.pi / 2)
        pitch = math.max(pitch, -math.pi / 2)
    else
        handX, handY = mouseX, mouseY
    end

    local trigger = lovr.system.isMouseDown(2)
    lovr.headset.setButton("hand/left", "trigger", trigger)
    lovr.headset.setButton("hand/left/point", "trigger", trigger)

    -- Head

    local angle, ax, ay, az = lovr.headset.getOrientation()
    local target = quat(yaw, 0, 1, 0) * quat(pitch, 1, 0, 0)
    local orientation = quat(angle, ax, ay, az):slerp(target, 1 - math.exp(-turnsmooth * dt))

    local sprint = lovr.system.isKeyDown("lshift", "rshift")
    local walk = lovr.system.isKeyDown("lctrl", "rctrl")
    local forward = lovr.system.isKeyDown("w", "up")
    local backward = lovr.system.isKeyDown("s", "down")
    local left = lovr.system.isKeyDown("a", "left")
    local right = lovr.system.isKeyDown("d", "right")
    local up = lovr.system.isKeyDown("q")
    local down = lovr.system.isKeyDown("e")

    local vx = left and -1 or right and 1 or 0
    local vy = down and -1 or up and 1 or 0
    local vz = forward and -1 or backward and 1 or 0
    local speed = sprint and sprintspeed or walk and walkspeed or movespeed
    local velocity = vec3(vx, vy, vz):normalize():mul(speed * dt)
    local position = vec3(lovr.headset.getPosition("head")) + orientation * velocity
    lovr.headset.setPose("head", position, orientation)

    -- Hand

    local left, right, up, down = lovr.headset.getViewAngles(1)
    local near, far = lovr.headset.getClipDistance()
    local inverseProjection = mat4():fov(left, right, up, down, near, far):invert()

    local width, height = lovr.system.getWindowDimensions()
    local coordinate = vec3(handX / width * 2 - 1, handY / height * 2 - 1, 1)
    local direction = (orientation * (inverseProjection * coordinate)):normalize()

    distance = distance * (1 + lovr.system._getScrollDelta() * 0.05)
    distance = math.min(distance, 10)
    distance = math.max(distance, 0.05)

    local handPosition = position + direction * distance
    local handOrientation = quat(mat4():target(vec3.zero, direction, orientation * vec3.up))

    lovr.headset.setPose("hand/left", handPosition, handOrientation)
    lovr.headset.setPose("hand/left/point", handPosition, handOrientation)
end

local function formatTraceback(s)
    return s:gsub("\n[^\n]+$", ""):gsub("\t", ""):gsub("stack traceback:", "\nStack:\n")
end

function lovr.errhand(message)
    message = "Error:\n\n" .. tostring(message) .. formatTraceback(debug and debug.traceback("", 4) or "")

    print(message)

    if not lovr.graphics or not lovr.graphics.isInitialized() then
        return function()
            return 1
        end
    end

    if lovr.audio then
        lovr.audio.stop()
    end

    if not lovr.headset or lovr.headset.getPassthrough() == "opaque" then
        lovr.graphics.setBackgroundColor(0.11, 0.10, 0.14)
    else
        lovr.graphics.setBackgroundColor(0, 0, 0, 0)
    end

    if lovr.headset then
        lovr.headset.setLayers()
    end

    local font = lovr.graphics.getDefaultFont()

    return function()
        lovr.system.pollEvents()

        for name, a in lovr.event.poll() do
            if name == "quit" then
                return a or 1
            elseif name == "restart" then
                return "restart", lovr.restart and lovr.restart()
            elseif name == "keypressed" and a == "f5" then
                lovr.event.restart()
            elseif name == "filechanged" then
                lovr.event.restart()
            elseif name == "keypressed" and a == "escape" then
                lovr.event.quit()
            end
        end

        if lovr.headset and lovr.headset.isActive() then
            lovr.headset.update()
            local pass = lovr.headset.getPass()
            if pass then
                font:setPixelDensity()

                local scale = 0.35
                local font = lovr.graphics.getDefaultFont()
                local wrap = 0.7 * font:getPixelDensity()
                local lines = font:getLines(message, wrap)
                local maxWidth = 0
                for i, line in ipairs(lines) do
                    maxWidth = math.max(maxWidth, font:getWidth(line))
                end
                local width = maxWidth * scale
                local height = 0.8 + #lines * font:getHeight() * scale
                local x = -width / 2
                local y = math.min(height / 2, 10)
                local z = -10

                pass:setColor(0.95, 0.95, 0.95)
                pass:text(message, x, y, z, scale, 0, 0, 0, 0, wrap, "left", "top")

                lovr.graphics.submit(pass)
                lovr.headset.submit()
            end
        end

        if lovr.system.isWindowOpen() then
            local pass = lovr.graphics.getWindowPass()
            if pass then
                local w, h = lovr.system.getWindowDimensions()
                pass:setProjection(1, lovr.math.mat4():orthographic(w, h))
                font:setPixelDensity(1)

                local scale = 0.6
                local wrap = w * 0.8 / scale
                local lines = font:getLines(message, wrap)
                local maxWidth = 0
                for i, line in ipairs(lines) do
                    maxWidth = math.max(maxWidth, font:getWidth(line))
                end
                local width = maxWidth * scale
                local x = w / 2 - width / 2

                pass:setColor(0.95, 0.95, 0.95)
                pass:text(message, x, h / 2, 0, scale, 0, 0, 0, 0, wrap, "left", "middle")

                lovr.graphics.submit(pass)
                lovr.graphics.present()
            end
        end

        lovr.math.drain()
    end
end

function lovr.threaderror(thread, err)
    error("Thread error\n\n" .. err, 0)
end

function lovr.filechanged(path, action, oldpath)
    if not path:match("^%.") then
        lovr.event.restart()
    end
end

function lovr.log(message, level, tag)
    message = message:gsub("\n$", "")
    level = level:gsub("\n$", "")
    tag = tag and tag:gsub("\n$", "") or ""
    print(("[LOVR %s][%s]:%s"):format(level, tag, message))
end

lovr.handlers = setmetatable({}, { __index = lovr })

return coroutine.create(function()
    local function onerror(...)
        onerror = function(...)
            print("Error:\n\n" .. tostring(...) .. formatTraceback(debug and debug.traceback("", 1) or ""))
            return function()
                return 1
            end
        end

        local ok, result = pcall(lovr.errhand or onerror, ...)

        if ok then
            return result or function()
                return 1
            end
        else
            return onerror(result)
        end
    end

    local thread = select(2, xpcall(lovr.boot, onerror))

    while true do
        local ok, result, cookie = xpcall(thread, onerror)
        if not ok then
            thread = result
        elseif result then
            return result, cookie
        end
        coroutine.yield()
    end
end)
