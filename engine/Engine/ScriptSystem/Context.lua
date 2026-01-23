return function(ScriptService)
    _G.CONTEXT = nil

    local Context = {}

    local MT = { __index = Context }
    local WMT = { __mode = "k" }

    local ContextGen = 0

    function Context.New()
        ContextGen = ContextGen + 1
        local t = {
            Alive = false,
            Gen = ContextGen,
            Tasks = setmetatable({}, WMT), -- {task = true}
            Signals = setmetatable({}, WMT), -- {UNBINDFUNC = SIGNAL}
            Binds = {},                  -- {Name}
            Passes = {},                 -- {PassRef}
            AllocObjects = setmetatable({}, WMT), -- {Obj = Type}
            -- cache / scene allocated assets (meshes, images, sfx, whatevs)
        }
        _G.CONTEXT = t
        return setmetatable(t, MT)
    end

    function Context:KillAll()
        local CTXGEN = self.Gen

        self.Alive = false

        -- TASKS
        local SELFCO = coroutine.running()
        local KILL = nil
        for i, _ in pairs(self.Tasks) do
            local Ctx = i.Context
            if Ctx == CTXGEN then
                task.escape(i)
                if i == SELFCO then
                    KILL = true
                end
                self.Tasks[i] = nil
            end
        end

        -- ENTITIES
        for _, Ent in ipairs(GetService("World").Alive) do
            if not Ent.IsNull and Ent.__context == CTXGEN then
                print("KILL:", Ent)
                Ent:Destroy()
            end
        end

        -- close caller
        if KILL then
            -- error bc corutine.close doesnt exist here
            error("__KILL COROUTINE__")
        end
    end

    function Context:BindToContext(Ctx, Obj1, Obj2)
        if Ctx == "Tasks" then
            Obj1.Context = self.Gen
            self.Tasks[Obj1] = true
        elseif Ctx == "Signals" then
            self.Signals[Obj1] = Obj2
        elseif Ctx == "Binds" then
            self.Binds[#self.Binds + 1] = Obj1
        elseif Ctx == "Passes" then
            self.Passes[#self.Passes + 1] = Obj1
        elseif Ctx == "AllocObjects" then
            self.AllocObjects[Obj] = Obj2
        end
    end

    function Context:UnbindFromContext(Ctx, Obj) end

    return Context
end
