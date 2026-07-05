local SignalLib = require("Lib/Signal")

-- NOTE: This service allocates events which are later wired in LOVRBridge

local InputService = {}

local RTC = SignalLib.Type.RTC

-- load mouse
InputService.Mouse = {
    IsMouseDown = lovr.system.IsMouseDown,
    GetPosition = lovr.system.getMousePosition,

    MouseButtonDown = SignalLib.new(RTC),
    MouseButtonUp = SignalLib.new(RTC),
    MouseMoved = SignalLib.new(RTC),
    WheelMoved = SignalLib.new(RTC),

    Position = Vec2(lovr.system.getMousePosition()),
}

-- load kb
InputService.Keyboard = {
    IsKeyDown = lovr.system.isKeyDown,

    KeyPressed = SignalLib.new(RTC),
    KeyReleased = SignalLib.new(RTC),
    TextInput = SignalLib.new(RTC),
}

GetService.AddService("InputService", InputService)
