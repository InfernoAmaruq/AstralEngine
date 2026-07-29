local bit = bit

-- RunService logic

local Data = {}

Data.__BoundToStep = {}
Data.__UsedNames = {}

Data.UnbindFromStep = function(Name)
    if not Data.__UsedNames[Name] then
        return
    end

    if _G.CONTEXT then
        _G.CONTEXT:UnbindFromContext("RSBinds", Name)
    end

    Data.__BoundToStep[Data.__UsedNames[Name]][Name] = nil
end

Data.__RawUnbind = function(Name)
    if not Data.__UsedNames[Name] then
        return
    end

    Data.__BoundToStep[Data.__UsedNames[Name]][Name] = nil
end

local EnumName = "StepPriority"
local E = _G["Enum"]({
    CPUUpdate = 250,
    RenderSceneSolid = 600,
    RenderSceneTransparent = 700,
    RenderSceneComposite = 750,
    RenderPost = 800,
    RenderSubmit = 950,
    RenderMirror = 970,
    Physics = 1250,
}, EnumName, { CanAppend = true })

Data.__TEMPBIND = function(n, Priority, F)
    Priority = type(Priority) == "number" and Priority or Priority.Value
    assert(math.floor(Priority) == Priority, Priority .. " NOT AN INT")
    Data.__BoundToStep[Priority] = Data.__BoundToStep[Priority] or {}
    Data.__BoundToStep[Priority][n] = F
    if _G.CONTEXT then
        _G.CONTEXT:BindToContext("RSTemp", F, Priority)
    end
end

Data.__UNBIND_TEMP = function(F, P)
    for Idx, Func in pairs(Data.__BoundToStep[P]) do
        if F == Func then
            Data.__BoundToStep[P][Idx] = nil
        end
    end
end

Data.Flags = {
    Contextless = 1,
}

Data.BindToStep = function(Name, Priority, F, Flag)
    Flag = Flag or 0
    Priority = type(Priority) == "number" and Priority or Priority.Value
    assert(math.floor(Priority) == Priority, Priority .. " NOT AN INT")

    local Contextless = bit.band(Flag, Data.Flags.Contextless) ~= 0

    local IsUsed = Data.__UsedNames[Name]
    if IsUsed then
        error("RS bind of " .. Name .. " already in use")
    end

    Data.__BoundToStep[Priority] = Data.__BoundToStep[Priority] or {}

    if _G.CONTEXT and not Contextless then
        _G.CONTEXT:BindToContext("RSBinds", Name)
    end

    local T = Data.__BoundToStep[Priority]

    Data.__UsedNames[Name] = Priority

    T[Name] = F
end

local Native = require("RunServiceNative") -- calling the so/dll

Native.Init(Data)
Data.__TICK = Native.Tick

GetService.AddService("RunService", Data)

return Data
