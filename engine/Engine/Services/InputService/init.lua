local SignalLib = require("Lib/Signal")

-- NOTE: This service allocates events which are later wired in LOVRBridge

local InputService = {}

-- load mouse
local Pos = lovr.system.getMousePosition

InputService.Mouse = {
    IsMouseDown = lovr.system.isMouseDown,
    GetPosition = Pos,

    GrabMouse = lovr.system.setMouseGrabbed,
    IsMouseGrabbed = lovr.system.isMouseGrabbed,

    MouseButtonDown = SignalLib.new(true),
    MouseButtonUp = SignalLib.new(true),
    MouseMoved = SignalLib.new(true),
    WheelMoved = SignalLib.new(true),
}

setmetatable(InputService.Mouse, {
    __index = function(_, k)
        if k == "Position" then
            return vec2(Pos())
        end
    end,
})

-- load kb
InputService.Keyboard = {
    KeyPressed = SignalLib.new(true),
    KeyReleased = SignalLib.new(true),
    TextInput = SignalLib.new(true),
}

if lovr.system.controllerPresent then
    InputService.Controller = require("Controller.lua")
end

-- we define IS.IsDown in LOVRBridge

GetService.AddService("InputService", InputService)
