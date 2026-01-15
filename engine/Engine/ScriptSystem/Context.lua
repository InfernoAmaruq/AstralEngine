_G.CONTEXT = nil
_G.CONTEXTGEN = 0

local Context = {}

local MT = { __index = Context }
local WMT = { __mode = "k" }

function Context.New()
    ContextGen = ContextGen + 1
    local t = {
        Alive = false,
        Gen = _G.CONTEXTGEN,
        Tasks = setmetatable({}, WMT),  -- {task = true}
        Signals = setmetatable({}, WMT), -- {UNBINDFUNC = SIGNAL}
        Binds = {},                     -- {Name}
        Passes = {},                    -- {PassRef}
        AllocObjects = setmetatable({}, WMT), -- {Obj = Type}
    }
    return setmetatable(t, MT)
end

function Context:KillAll() end

function Context:BindToContext() end

function Context:UnbindFromContext() end

return Context
