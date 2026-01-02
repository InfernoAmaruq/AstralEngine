local Signal = {}
Signal.__index = Signal
Signal.SCHEDULER = nil
Signal.CLOCK = os.clock

function Signal.new(yield, timeout)
    local Tab = { _connections = {}, _waiting = {}, _yielding = yield or false, _timeout = timeout or 1 }
    return setmetatable(Tab, Signal)
end

function Signal:Connect(Callback)
    table.insert(self._connections, Callback)

    return {
        Disconnect = function()
            if not self or not self._connections then
                return
            end
            for i, con in ipairs(self._connections) do
                if con == Callback then
                    table.remove(self._connections, i)
                    break
                end
            end
        end,
    }
end

function Signal:Fire(...)
    local CON = self._connections
    local WAIT = self._waiting

    if #CON == 0 and #WAIT == 0 then
        return
    end
    for i = #WAIT, 1, -1 do
        coroutine.resume(WAIT[i], ...)
        WAIT[i] = nil
    end
    if self._yielding then
        local Threads = {}

        for _, cb in ipairs(self._connections) do
            local Thread = self.SCHEDULER:Spawn(cb, ...)
            table.insert(Threads, Thread)
        end

        local ST = self.CLOCK() -- os.clock is bad here
        while self.CLOCK() - ST < self._timeout do
            local Done = true

            for _, thread in ipairs(Threads) do
                if coroutine.status(thread) ~= "dead" then
                    Done = false
                    break
                end
            end

            if Done then
                break
            end

            coroutine.yield()
        end
    else
        for _, cb in ipairs(self._connections) do
            local Ok, Error = self.SCHEDULER:Spawn(cb, ...)
            if not Ok then
                print("SIGNAL ERR:" .. Error)
            end
        end
    end
end

function Signal:Wait()
    table.insert(self._waiting, coroutine.running())
    task.escape()
    return coroutine.yield()
end

function Signal:Destroy()
    for i in pairs(self._connections) do
        self._connections[i] = nil
    end
    for i in pairs(self) do
        self[i] = nil
    end
    setmetatable(self, nil)
end

return Signal
