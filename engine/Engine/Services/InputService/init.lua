local SignalLib = require("Lib/Signal")

-- NOTE: This service allocates events which are later wired in LOVRBridge

local InputService = {}

local RTC = SignalLib.Type.RTC

-- load mouse
local Pos = lovr.system.getMousePosition

InputService.Mouse = {
    IsMouseDown = lovr.system.isMouseDown,
    GetPosition = Pos,

    GrabMouse = lovr.system.setMouseGrabbed,
    IsMouseGrabbed = lovr.system.isMouseGrabbed,

    MouseButtonDown = SignalLib.new(RTC),
    MouseButtonUp = SignalLib.new(RTC),
    MouseMoved = SignalLib.new(RTC),
    WheelMoved = SignalLib.new(RTC),
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
    KeyPressed = SignalLib.new(RTC),
    KeyReleased = SignalLib.new(RTC),
    TextInput = SignalLib.new(RTC),
}

-- we define IS.IsDown in LOVRBridge

GetService.AddService("InputService", InputService)
