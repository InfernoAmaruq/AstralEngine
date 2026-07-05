local ScriptSystem = {}

-- KEEP THIS NEAR THE END, LATE INIT
local Ctx = require("Context")(ScriptSystem)
local Scene = require("Scene")(ScriptSystem, Ctx)

ScriptSystem.Context = Ctx
ScriptSystem.Scene = Scene

return ScriptSystem
