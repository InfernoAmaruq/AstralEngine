local Signal = {}

Signal.__index = Signal

local Scheduler

function Signal.new(NoCtx)
    Scheduler = Scheduler or GetService and GetService("Scheduler")

    local Tab = {
        _connections = {},
        _waiting = {},
        _conLen = 0,
        _waitLen = 0,
    }
    if _G.CONTEXT and not NoCtx then
        _G.CONTEXT:BindToContext("Signal", Tab)
    end

    return setmetatable(Tab, Signal)
end

function Signal:GetListenerCount()
    return self._conLen + self._waitLen
end

function Signal:Clear()
    for i = 1, self._conLen do
        self._connections[i] = nil
    end
    for i = 1, self._waitLen do
        self._waiting[i] = nil
    end
end

local DisconnectFunc = function(s)
    local self = s._self
    local Callback = s._callback
    if not self or not self._connections then
        error("Attempt to disconnect dead signal")
    end
    for i, con in ipairs(self._connections) do
        if con == Callback then
            table.remove(self._connections, i)
            if _G.CONTEXT then
                _G.CONTEXT:UnbindFromContext("SignalBind", s)
            end
            self._conLen = self._conLen - 1
            break
        end
    end
end
local ConMt = { __index = { Disconnect = DisconnectFunc }, __mode = "v" }

-- Listener

function Signal:Connect(Callback)
    table.insert(self._connections, Callback)
    self._conLen = self._conLen + 1

    local Tab = setmetatable({ _self = self, _callback = Callback }, ConMt)
    if _G.CONTEXT then
        _G.CONTEXT:BindToContext("SignalBind", Tab)
    end

    return Tab
end

function Signal:Wait()
    local r = coroutine.running()
    assert(Scheduler.CanAsync(r), "Cannot <Signal>:Wait() in a non-async block!")
    table.insert(self._waiting, r)
    self._waitLen = self._waitLen + 1
    return coroutine.yield()
end

function Signal:Once(f)
    local s = nil
    s = Signal.Connect(self, function(...)
        s:Disconnect() -- wanna disconnect first just incase the function errors
        f(...)
    end)
end

-- Messenger

function Signal:FireAndDefer()
    error("INCOMPLETE, KILL FLAME")
end

function Signal:FireAndSpawn()
    error("INCOMPLETE, KILL FLAME")
end

function Signal:FireRTC(...)
    local ConLen, WaitLen = self._conLen, self._waitLen

    if ConLen == 0 and WaitLen == 0 then
        return
    end

    local Con = self._connections
    local Wait = self._waiting

    for i = WaitLen, 1, -1 do
        Scheduler.Resume(Wait[i], ...)
        Wait[i] = nil
    end

    self._waitLen = 0

    for i = 1, ConLen do
        local s, err = pcall(Con[i], ...)
        if not s then
            AstralEngine.Error("SIGNAL ERROR: ", debug.traceback(err), "SIGNAL")
        end
    end
end

function Signal:Destroy()
    Signal.Clear(self)

    if _G.CONTEXT then
        _G.CONTEXT:UnbindFromContext("Signal", self)
    end

    setmetatable(self, nil)
end

return Signal
