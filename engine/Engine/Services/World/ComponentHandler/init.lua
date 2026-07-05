---@class Component

local SignalLib = AstralEngine.Plugins.SignalLib
local Component = {}

Component.Components = {}
Component.SetComponents = {}
Component.FastFetch = {}

local DEADMT = {
    __index = function(_,k)
        return k == "IsDead" or error("ILLEGAL ACCESS: ATTEMPT TO ACCESS DEAD COMPONENT")
    end
}

local MTCACHE = setmetatable({},{__mode = "v"})
local CBaseMT = {__type = "ComponentPrefab"}

Component.ComponentAdded = SignalLib.new(bit.bor(SignalLib.Type.RTC, SignalLib.Type.NoCtx))
Component.ComponentRemoved = SignalLib.new(bit.bor(SignalLib.Type.RTC, SignalLib.Type.NoCtx))

function Component.NewComponent(Name, Pattern, Metadata, FastFetch)
    assert(not Component.Components[Name], "Component already exists: " .. Name)
    Component.Components[Name] = setmetatable(
        { Storage = {}, Name = Name, Pattern = Pattern, Metadata = Metadata },
        CBaseMT
    )

    if FastFetch then
        for _, Obj in pairs(FastFetch) do
            Component.FastFetch[Obj] = Name
        end
    end
end

function Component.GetName(Comp)
    return getmetatable(Comp).__CName
end

-- so, it used to be solobj, then astralobj, then engineobj... its a fuckin mess dude with all the renaming, so i just make it a flag!
@execute<UNSAFE>{
    local NAME = type.EngineObj
    return "@flag:TYPE='"..NAME.."';"
}

function Component.GetComponents(e)
    if type(e) == &TYPE then
        e = e.Id
    end

    return Component.SetComponents[e] or {}
end

---@param e AnyEntity
---@param ... string names
---@return (Component|boolean)?
function Component.HasComponent(e, ...)
    local S = select("#", ...)
    local Comp = Component.SetComponents[type(e) == &TYPE and e.Id or e]
    if not Comp then return nil end
    if S == 1 then
        return Comp[(select(1, ...))]
    else
        local VAL = { ... }
        for i in pairs(Comp) do
            if table.find(VAL, i) then
                return true
            end
        end
    end
    return nil
end

local function ToString(c)
    return debug.getmetatable(c).__CName
end

---@param e AnyEntity
---@param id string Component name
---@param DATA table?
---@param ShouldSink boolean? Skip dependency resolution
---@return Component?
function Component.AddComponent(e, id, DATA, ShouldSink)
    if type(e) == &TYPE then
        e = e.Id
    end
    Component.SetComponents[e] = Component.SetComponents[e] or {}

    local D
    local t = Component.Components[id]

    AstralEngine.Assert(t,"No component "..id.." found!","COMPONENT")

    -- check if can set

    if not ShouldSink then
        -- hard dep check

        local HardDependency = t.Metadata and t.Metadata.HardDependency
        if HardDependency then
            for Name in pairs(HardDependency) do
                AstralEngine.Assert(Component.SetComponents[e][Name],"CANNOT CREATE COMPONENT "..id.." HARD DEPENDENCY CHECK FAILED ON COMPONENT: "..Name,"COMPONENT")
            end
        end

        -- exclusion check

        local Exclusion = t.Metadata and t.Metadata.HardExclusion
        if Exclusion then
            for Name in pairs(Exclusion) do
                AstralEngine.Assert(not Component.SetComponents[e][Name], "CANNOT CREATE COMPONENT "..id.." HARD EXCLUSION CHECK FAILED ON COMPONENT: "..Name,"COMPONENT")
            end
        end
    end

    -- we do not do a soft dependency check here. It is used only when constructing!

    -- set

    if t.Metadata and t.Metadata.__create then
        D = t.Metadata.__create(DATA or {}, e, ShouldSink)
    elseif DATA then
        D = {}
        for i, v in pairs(DATA) do
            if t.Pattern[i] then
                D[i] = v
            end
        end

        if t.Metadata and t.Metadata.__mt then
            setmetatable(D, t.Metadata.__mt)
        end
    end

    local MT = getmetatable(D)
    rawset(D,".CONTEXT",_G.CONTEXTGEN or 0)
    if MT then
        MT.__type = "Component"
        MT.__tostring = ToString
        MT.__CName = id
        setmetatable(D, MT)
    else
        local Cached = MTCACHE[id]
        if not Cached then
            Cached = { __type = "Component", __tostring = ToString, __CName = id }
            MTCACHE[id] = Cached
        end
        setmetatable(D,Cached)
    end

    Component.Components[id].Storage[e] = D
    Component.SetComponents[e][id] = D

    local Ent = GetService"World".GetEntityFromId(e)
    Component.ComponentAdded:Fire(Ent, id, D)
    Ent.ComponentAdded:Fire(id,D)

    rawset(D,"IsNull",false)

    return D
end

local function CallstackDepth()
    local Depth = 0
    while debug.getinfo(Depth + 1, "") do
        Depth = Depth + 1
    end
    return Depth
end

local function KillComponent(e,id,Force)
    local D = CallstackDepth() - 4
    local pre = string.rep(">",D)
    if type(e) == &TYPE then
        e = e.Id
    end

    local Comp = Component.Components[id]

    if not Component.SetComponents[e] or not Comp then
        return
    end

    local CompInst = Component.SetComponents[e][id]

    if not CompInst then return end

    if not Force then
        for Name, UserComp in pairs(Component.SetComponents[e]) do
            if v ~= UserComp then

                local UCMeta = Component.Components[Name].Metadata
                if UCMeta and UCMeta.HardDependency and UCMeta.HardDependency[id] then
                    AstralEngine.Error("CANNOT REMOVE COMPONENT "..id.." BECAUSE COMPONENT "..Name.." DEPENDS ON IT!","COMPONENT",2)
                end
            end
        end
    end

    if not Force then
        local Ent = GetService"World".GetEntityFromId(e)
        Component.ComponentRemoved:Fire(Ent,id,Component.SetComponents[e][id])
        Ent.ComponentRemoving:Fire(id, Component.SetComponents[e][id])
    end

    if Comp.Metadata and Comp.Metadata.__remove then
        Comp.Metadata.__remove(CompInst, e, Force) -- weirdly, error lower occurs only when this method is called (it destroys another component), but it should not occur cause it doesnt touch CompInst
    end

    for i in pairs(CompInst) do -- ERROR HERE?
        CompInst[i] = nil
    end

    rawset(CompInst,"IsNull",true)

    setmetatable(CompInst, DEADMT)

    Component.Components[id].Storage[e] = nil
    Component.SetComponents[e][id] = nil
end

local ComponentsToKill = {}

---@param e AnyEntity
---@param id string
---@param Force boolean? force destruction, ignoring dependency checks
function Component.RemoveComponent(e, id, Force)
    ComponentsToKill[e] = ComponentsToKill[e] or {}
    ComponentsToKill[e][id] = Force or false
end

function Component.__DrainDestructionList()
    for Entity, List in pairs(ComponentsToKill) do
        for Comp, Force in pairs(List) do
            KillComponent(Entity,Comp,Force)
        end
        ComponentsToKill[Entity] = nil
    end
end

Component.GetComponentStorage = function(Name)
    return Component.Components[Name].Storage
end

---@param ... string component names
---@return Entity[]
Component.GetAllWithComponent = function(...)
    local Ret = {}

    local n = select("#",...)
    for i = 1, n do
        local Comp = select(i,...)
        local Storage = AstralEngine.Assert(Component.Components[Comp].Storage,"INVALID COMPONENT NAME AT GetAllWithComponent, NAME: "..Comp.." AT INDEX: "..i,"COMPONENT")

        for EntId in pairs(Storage) do
            local EntRef = GetService"World".GetEntityFromId(EntId)
            table.insert(Ret,EntRef)
        end
    end

    return Ret
end

function Component.__RemoveAllComponents(EntityHandle)
    local Id = EntityHandle.Id

    if not Component.SetComponents[Id] then
        -- no components, return
        return
    end

    for CId in pairs(Component.SetComponents[Id]) do
        Component.RemoveComponent(Id,CId,true)
    end
end

local FinalProcessing = {}

function Component.__RunPostPass()
    Component.__RunPostPass = nil
    for _, v in pairs(FinalProcessing) do
        v()
    end
end

function Component.LoadComponents()
    local Files = lovr.filesystem.getAliasedFiles("Components")

    for _, f in pairs(Files) do

        if f:match("%.lua$") then
            AstralEngine.Log("LOAD COMPONENT FILE: "..f,"info","COMPONENT")

            local File = loadfile(f)

            if File then
                local S, Res = pcall(File)

                if not S or not Res then AstralEngine.Log("FAILED TO LOAD COMPONENT: "..f.." - "..(Res or "COMPONENT RETURNED NIL"),"warn","COMPONENT") goto continue else File = Res end

                Component.NewComponent(File.Name, File.Pattern, File.Metadata, File.FastFetch)
                table.insert(FinalProcessing, File.FinalProcessing)
            else
                AstralEngine.Log("FAILED TO LOAD COMPONENT: "..f,"warn","COMPONENT")
            end
        end

        ::continue::
    end

    local ANSI = AstralEngine.Plugins.ANSIColor or {}

    if AstralEngine._CONFIG.Astral.Debug then
        for i in pairs(Component.Components) do
            AstralEngine.Log("LOADED COMP: "..ANSI.Magenta..ANSI.Underscore..i..ANSI.Clear,"success","COMPONENT")
        end
    end
end

return Component
