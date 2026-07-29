local TASK = lovr.task
local POLL = TASK.poll
local RESUME = TASK.resume

local TIME = lovr.timer.getTime
local SLEEP = lovr.timer.sleep

local Scheduler = {}

local StatusEnum = Enum({
    Running = 1,
    Completed = 2,
    Failed = 3,
    Waiting = 4,
    Ready = 5,
    Unregistered = 6,
}, "TaskStatus")

local StatusToEnum = {
    running = StatusEnum.Running,
    complete = StatusEnum.Completed,
    failed = StatusEnum.Failed,
    waiting = StatusEnum.Waiting,
    ready = StatusEnum.Ready,
}

-- Thread additions
local ThreadCtx = setmetatable({}, { __mode = "k" })
local ThreadMT = {
    __index = function(Co, K)
        if K == "Context" then
            return ThreadCtx[Co] or 0
        end
    end,
    __newindex = function(Co, K, V)
        if K == "Context" then
            ThreadCtx[Co] = V
        end
    end,
}

debug.setmetatable(coroutine.running(), ThreadMT)

-- Scheduler

local Budget = 0.001
function Scheduler.SetBudget(n)
    Budget = n
end

function Scheduler.Update()
    local a = AstralEngine.Assert
    local StartTime = TIME()

    for Task in POLL() do
        a(RESUME(Task))

        local Delta = TIME() - StartTime

        if Delta > Budget then
            return
        end
    end
end

function Scheduler.Status(t)
    local LovrStatus = TASK.getStatus(t or coroutine.running())

    return StatusToEnum[LovrStatus] or StatusEnum.Unregistered
end

-- Spawning functions

Scheduler.Spawn = TASK.start

function Scheduler.Defer(f, ...)
    return Scheduler.Spawn(function(...)
        TASK.yield()
        f(...)
    end, ...)
end

function Scheduler.Delay(f, ...)
    return Scheduler.Spawn(function(...)
        Scheduler.Wait(n)
        f(...)
    end, ...)
end

Scheduler.CallOnThread = lovr.thread.call

-- Other

Scheduler.Resume = TASK.resume

Scheduler.Yield = TASK.yield

function Scheduler.Wait(n, ...)
    if type(n) ~= "number" then
        return TASK.wait(n, ...)
    else
        SLEEP(n or 0)
        return true
    end
end

-- sync/async blocks
local AsyncBlocks = setmetatable({}, getmetatable(Escaped))

function Scheduler.CanAsync(t)
    t = t or coroutine.running()
    return (not AsyncBlocks[t]) and TASK.isYieldable(t)
end

function Scheduler.PushSyncBlock(t)
    t = t or coroutine.running()
    AsyncBlocks[t] = (AsyncBlocks[t] or 0) + 1
    TASK.setYieldable(t, false)
end

function Scheduler.PopSyncBlock(t)
    t = t or coroutine.running()
    if not AsyncBlocks[t] then
        return
    end

    AsyncBlocks[t] = AsyncBlocks[t] - 1

    if AsyncBlocks[t] <= 0 then
        AsyncBlocks[t] = nil
        TASK.setYieldable(t, true)
    end
end

Scheduler.Time = TIME

GetService.AddService("Scheduler", Scheduler)

return Scheduler
