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

local ParamProcess = {
    SCHEDULER = function(SCHEDULER)
        local DATA = {}

        DATA.wait = wrapself(SCHEDULER, SCHEDULER.Wait, false)
        DATA.delay = wrapself(SCHEDULER, SCHEDULER.Delay, false)
        DATA.defer = wrapself(SCHEDULER, SCHEDULER.Defer, false)
        DATA.spawn = wrapself(SCHEDULER, SCHEDULER.Spawn, false)
        DATA.waitfor = wrapself(SCHEDULER, SCHEDULER.WaitFor)
        DATA.spawnat = wrapself(SCHEDULER, SCHEDULER.SpawnAt)
        DATA.escape = wrapself(SCHEDULER, SCHEDULER.Escape, false)

        return "task", DATA
    end,
    TICK = function(T)
        local OldPath = package.cpath
        local BASE = ";./Engine/SERVICES/RunService/RunServiceNative"
        package.cpath = package.cpath .. BASE .. ".so" .. BASE .. ".dll"
        local DATA = require("Engine.SERVICES.RunService")(T)
        package.cpath = OldPath
        return "RunService", DATA
    end,
    INPUT = function(T)
        local ogpath = package.path
        package.path = package.path .. ";./Engine/SERVICES/InputService/?.sol"
        local d = require("Engine.SERVICES.InputService")(T)
        package.path = ogpath
        return "InputService", d
    end,
    CONTEXTACT = function(T)
        local OldPath = package.cpath
        local BASE = ";./Engine/SERVICES/ContextActionService/CASNATIVE"
        package.cpath = package.cpath .. BASE .. ".so" .. BASE .. ".dll"
        local D = require("Engine.SERVICES.ContextActionService")(T)
        package.cpath = OldPath
        return "ContextActionService", D
    end,
}

return function(PARAMETERS)
    for NAME, DATA in pairs(PARAMETERS) do
        local Process = ParamProcess[NAME]

        if Process then
            local N, RET = Process(DATA)
            if N[1] == N[1]:lower() then
                _G[N] = RET
            else
                GetService.AddService(N, RET)
            end
        end
    end
end
