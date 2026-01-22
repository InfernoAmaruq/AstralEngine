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
        print("KILL ALL")
        self.Alive = false
        local SELFCO = coroutine.running()
        for i, _ in pairs(self.Tasks) do
            task.escape(i)
            -- tf i write
            self.Tasks[i] = nil
            if i == SELFCO then
            end
            coroutine.close(i)
            print("Kill task:", i)
        end
        print(GetService("World"), GetService("World").Alive)
        for _, Ent in ipairs(GetService("World").Alive) do
            print("ENTITIES:", Ent)
        end
    end

    function Context:BindToContext(Ctx, Obj1, Obj2)
        if Ctx == "Tasks" then
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
