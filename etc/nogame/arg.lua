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

    for i = 0, #arg do
        arg[i - shift], arg[i] = arg[i], nil
    end

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
