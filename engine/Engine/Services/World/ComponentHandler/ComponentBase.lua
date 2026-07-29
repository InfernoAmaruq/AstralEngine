local BaseVTable = {}
local Signal = AstralEngine.Plugins.SignalLib

local SignalRegistry = {}
setmetatable(SignalRegistry, { __mode = "kv" })

BaseVTable.Index = function(Cmp, k)
    if k == "PropertyChanged" then
        SignalRegistry[Cmp] = SignalRegistry[Cmp] or Signal.new(true)
        return SignalRegistry[Cmp]
    end
end

BaseVTable.Release = function(Cmp)
    SignalRegistry[Cmp] = nil
end

BaseVTable.PropertyChanged = function(Cmp, ...)
    local Event = SignalRegistry[Cmp]
    if Event then
        return Event:FireRTC(...)
    end
end

return BaseVTable
