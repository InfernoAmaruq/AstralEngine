return function(ScriptService)
    _G.CONTEXT = nil

    local Context = {}

    local MT = { __index = Context }
    local WMT = { __mode = "k" }

    local ContextGen = 0

    local CAS, RS = GetService("ContextActionService", "CAS"), GetService("RunService", "RS")

    function Context.New()
        ContextGen = ContextGen + 1
        local t = {
            Alive = false,
            Gen = ContextGen,
            Tasks = setmetatable({}, WMT),  -- {task = true}
            Signals = setmetatable({}, WMT), -- {UNBINDFUNC = true}
            SignalInstances = setmetatable({}, WMT), -- {SIGNAL = true}
            RSTemp = setmetatable({}, WMT),
            RSBinds = {},                   -- {Name}
            CASBinds = {},
            Require = setmetatable({}, WMT),
            Passes = {},                 -- {PassRef}
            AllocObjects = setmetatable({}, WMT), -- {Obj = Type}
            -- cache / scene allocated assets (meshes, images, sfx, whatevs)
        }
        -- entities are tracked externally with _context field
        _G.CONTEXT = t
        return setmetatable(t, MT)
    end

    function Context:KillAll()
        local CTXGEN = self.Gen

        self.Alive = false

        -- BINDS

        for i, v in pairs(self.RSTemp) do
            RS.__UNBIND_TEMP(i, v)
        end

        for _, v in pairs(self.RSBinds) do
            RS.UnbindFromStep(v)
        end

        for _, v in pairs(self.CASBinds) do
            CAS.__RawUnbind(v)
        end

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

        -- SIGNALS
        for i in pairs(self.Signals) do
            self[i] = nil
            i:Disconnect()
        end

        for i in pairs(self.SignalInstances) do
            self[i] = nil
            i:Destroy()
        end

        -- ENTITIES
        for _, Ent in ipairs(GetService("World").Alive) do
            if not Ent.IsNull and Ent.__context == CTXGEN then
                Ent:Destroy()
            end
        end

        -- CACHE
        for Module, Name in pairs(self.Requre) do
            local Mod = package.loaded[Name]
            if Mod == Module then
                package.loaded[Name] = nil
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
        elseif Ctx == "Signal" then
            self.SignalInstances[Obj1] = true
        elseif Ctx == "SignalBind" then
            self.Signals[Obj1] = true
        elseif Ctx == "CASBinds" then
            self.CASBinds[#self.CASBinds + 1] = Obj1
        elseif Ctx == "RSBinds" then
            self.RSBinds[#self.RSBinds + 1] = Obj1
        elseif Ctx == "RSTemp" then
            self.RSTemp[Obj1] = Obj2
            -- gc does the job better for RSTemp, so we dont add an Unbind to it
        elseif Ctx == "Passes" then
            self.Passes[#self.Passes + 1] = Obj1
        elseif Ctx == "AllocObjects" then
            self.AllocObjects[Obj] = Obj2
        elseif Ctx == "Require" then
            self.Require[Obj1] = Obj2
        end
    end

    function Context:UnbindFromContext(Ctx, Obj)
        if Ctx == "SignalBind" then
            self.Signals[Obj] = nil
        elseif Ctx == "Signal" then
            self.SignalInstances[Obj] = nil
        elseif Ctx == "CASBinds" then
            local Idx = table.find(self.CASBinds, Obj)
            table.remove(self.CASBinds, Idx)
        elseif Ctx == "RSBinds" then
            local Idx = table.find(self.RSBinds, Obj)
            table.remove(self.RSBinds, Idx)
        end
    end

    return Context
end
