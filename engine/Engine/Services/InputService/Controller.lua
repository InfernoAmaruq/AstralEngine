local MAX_CONTROLLERS = AstralEngine.Config.Input.MaxControllers or 4 -- ignroes all other ones

if MAX_CONTROLLERS <= 0 then
    return
end

local SignalLib = require("Lib/Signal")
local Controller = {}

local Type = bit.bor(SignalLib.Type.RTC, SignalLib.Type.NoCtx)

Controller.MAX_CONTROLLERS = MAX_CONTROLLERS

Controller.ControllerAdded = SignalLib.new(Type)
Controller.ControllerRemoved = SignalLib.new(Type)

Controller.IsPresent = lovr.system.controllerPresent
Controller.GetName = lovr.system.controllerGetName
Controller.UpdateMappings = lovr.system.controllerUpdateMappings

local sys = lovr.system

Enum({
    Left = "axisleft",
    Right = "axisright",
    LeftTrigger = "triggerleft",
    RightTrigger = "triggerright",
}, "ControllerAxis")

local bit = bit
local KeyMask = tonumber("00001111", 2)
local IdMask = tonumber("11110000", 2)

local EnumToId = {
    A = 1,
    B = 2,
    X = 3,
    Y = 4,

    Up = 5,
    Right = 6,
    Down = 7,
    Left = 8,

    LeftBumper = 9,
    RightBumper = 10,

    LeftThumb = 11,
    RightThumb = 12,

    Back = 13,
    Start = 14,
    Guide = 15,
}

local AstralToLovr = {
    A = "a",
    B = "b",
    X = "x",
    Y = "y",

    Up = "up",
    Right = "right",
    Down = "down",
    Left = "left",

    LeftBumper = "leftbumper",
    RightBumper = "rightbumper",

    LeftThumb = "leftthumb",
    RightThumb = "rightthumb",

    Back = "back",
    Start = "start",
    Guide = "guide",
}

local LovrToAstral = {}

for i, v in pairs(AstralToLovr) do
    LovrToAstral[v] = i
end

for i, v in pairs(EnumToId) do
    EnumToId[i] = bit.bor(v, bit.lshift(1, 9))
end
Enum(EnumToId, "Controller", EnumConfig)

local ControllerRegistry = {}

local Meta = {}
Meta.__index = Meta

local AstralEngine = AstralEngine

Meta.GetAxis = function(self, axis)
    return sys.controllerGetAxis(self.DeviceId, axis.Value)
end

Meta.WasButtonPressed = function(self, button)
    button = AstralEngine.Assert(button and AstralToLovr[button.Name], "Invalid button provided", "Controller")
    return sys.controllerWasButtonPressed(self.DeviceId, button)
end

Meta.WasButtonReleased = function(self, button)
    button = AstralEngine.Assert(button and AstralToLovr[button.Name], "Invalid button provided", "Controller")
    return sys.controllerWasButtonReleased(self.DeviceId, button)
end

Meta.IsButtonDown = function(self, button)
    button = AstralEngine.Assert(button and AstralToLovr[button.Name], "Invalid button provided", "Controller")
    return sys.controllerIsButtonDown(self.DeviceId, button)
end

local function AllocateController(DeviceId)
    local Ctrl = {
        DeviceId = DeviceId,
        Name = Controller.GetName(DeviceId),
        Active = nil,
    }

    setmetatable(Ctrl, Meta)

    return Ctrl
end

Controller.GetController = function(DeviceId)
    local Exists = Controller.IsPresent(DeviceId)

    if Exists then
        ControllerRegistry[DeviceId] = ControllerRegistry[DeviceId] or AllocateController(DeviceId)
        ControllerRegistry[DeviceId].Active = true
        return ControllerRegistry[DeviceId]
    elseif ControllerRegistry[DeviceId] then
        ControllerRegistry[DeviceId].Active = false
    end
end

Controller.GetAllControllers = function()
    local t = {}

    for i = 1, MAX_CONTROLLERS do
        t[i] = Controller.GetController(i)
    end

    return t
end

Controller.__Finalise = function()
    Controller.__Finalise = nil

    function lovr.controllerchanged(Id, State)
        if Id > MAX_CONTROLLERS then
            return
        end

        if ControllerRegistry[Id] then
            ControllerRegistry[Id].Active = State
        end

        if State then
            Controller.ControllerAdded:Fire(Id)
        else
            Controller.ControllerRemoved:Fire(Id)
        end
    end

    return LovrToAstral
end

return Controller
