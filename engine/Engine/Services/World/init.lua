local SignalLib = AstralEngine.Plugins.SignalLib
local Component = require("ComponentHandler")
local InstMeta, Methods = require("Instance")(Component)
local TagService, TagService_ClearTags = require("TagService")
local bit = bit

local Entity = {}

local PREALLOCSIZE = 50
local SHIFT = 24
local RESIZEAT = 2 / 3
local RESIZESTEP = 1.25

Entity.Alive = {}
Entity.Capacity = 0 -- points to highest id
Entity.TopPtr = 0   -- points at highest alive object

-- fires event on ancestry change in parent-child pairs
function Entity.GetEntityFromId(Id)
    local E = Entity.Alive[Id]
    if not E then
        return nil
    else
        return not E.IsNull and E or nil
    end
end

-- Parent, Child, "add"|"remove"
Entity.OnAncestryChanged = SignalLib.new(SignalLib.Type.RTC)
Entity.EntityAdded = SignalLib.new(SignalLib.Type.RTC)
Entity.EntityRemoving = SignalLib.new(SignalLib.Type.RTC)
Entity.OnTransformChanged = SignalLib.new(SignalLib.Type.RTC)

local function ALLOC(Use)
    Entity.Capacity = Entity.Capacity + 1
    local ID = Entity.Capacity
    local Gen = Use and 1 or 0

    local Flag = bit.bor(SignalLib.Type.NoCtx, SignalLib.Type.RTC)

    local t = setmetatable({
        Id = ID,
        __gen = Gen,
        UniqueId = bit.band(bit.lshift(Gen, SHIFT), ID),
        IsNull = true,
        __context = _G.CONTEXT and _G.CONTEXT.Gen or 0,
        Destroying = SignalLib.new(Flag),
        ComponentAdded = SignalLib.new(Flag),
        ComponentRemoving = SignalLib.new(Flag),
    }, InstMeta)

    Entity.Alive[Entity.Capacity] = t

    return t
end

local function ADD(Res)
    local ResizeTo = Res or (Entity.Capacity * RESIZESTEP)

    while Entity.Capacity <= ResizeTo do
        ALLOC()
    end
end

for _ = 1, PREALLOCSIZE do
    ALLOC()
end

local function Alive(Ent)
    Ent.__gen = Ent.__gen + 1
    local k = bit.band(bit.lshift(Ent.__gen, SHIFT), Ent.Id)
    Ent.UniqueId = k
end

local function GetEntity()
    local n = Entity.Capacity
    for i = 1, n do
        local Ent = Entity.Alive[i]
        if Ent.IsNull then
            Alive(Ent)
            if i >= RESIZEAT * n then
                ADD()
            end
            return Ent
        end
    end

    return ALLOC(true)
end

function Entity.New(Name, ...)
    Name = Name or "UNNAMED_ENTITY"
    assert(type(Name) == "string", "Entity name not a string!")
    local NewEntity = GetEntity()

    rawset(NewEntity, "Name", Name)
    if NewEntity.Id > Entity.TopPtr then
        Entity.TopPtr = NewEntity.Id
        -- similar thing on memory freeing to move down ptr
    end

    for i = 1, select("#", ...), 2 do
        local v, Data = select(i, ...)
        Component.AddComponent(NewEntity.Id, v, Data)
    end

    local CTX = _G.CONTEXT and _G.CONTEXT.Gen
    NewEntity.__context = CTX or NewEntity.__context

    NewEntity.IsNull = false

    Entity.EntityAdded:Fire(NewEntity)

    return NewEntity
end

local ToKill = {}

local function DestroyEntity(Ent)
    Ent = type(Ent) == "astrobj" and Ent or Entity.Alive[Ent]

    if Ent.IsNull then
        AstralEngine.Log("Attempt to destroy dead entity", "warning", "ENTITY")
        return
    end

    local Id = Ent.Id

    if Id == Entity.TopPtr then
        -- reset top ptr
        local Idx = Id - 1
        while true do
            local TempEnt = Entity.Alive[Idx]
            if not TempEnt then
                break
            end
            if not TempEnt.IsNull then
                Entity.TopPtr = TempEnt.Id
                break
            end
            Idx = Idx - 1
        end
    end

    Entity.EntityRemoving:Fire(Ent)
    Ent.Destroying:Fire()

    Ent.Destroying:Clear()
    Ent.ComponentAdded:Clear()
    Ent.ComponentRemoving:Clear()

    TagService_ClearTags(Ent.Id)

    Component.__RemoveAllComponents(Ent)
    rawset(Ent, "IsNull", true)
end

function Entity.Destroy(Ent)
    ToKill[Ent] = true
end

Methods.Destroy = Entity.Destroy

-- handle destruction
Entity.__ConnectDestructors = function()
    Entity.__ConnectDestructors = nil

    local RS = GetService("RunService")

    Enum.StepPriority.__Append({
        EntityDestruction = 496,
        ComponentDestruction = 497,
    })

    RS.BindToStep("__DESTRUCTION_FRAME_ENTITY", Enum.StepPriority.EntityDestruction, function()
        for Ent in pairs(ToKill) do
            DestroyEntity(Ent)
            ToKill[Ent] = nil
        end
    end)

    RS.BindToStep(
        "__DESTRUCTION_FRAME_COMPONENT",
        Enum.StepPriority.ComponentDestruction,
        Component.__DrainDestructionList
    )
end

-- virtualize tag functions
Methods.HasTag = TagService.HasTag
Methods.AddTag = TagService.AddTag
Methods.RemoveTag = TagService.RemoveTag
Methods.ClearTags = TagService.ClearTags
Methods.GetAllTags = TagService.GetAllTags

GetService.AddService("Component", Component)
GetService.AddService("Entity", Entity)
GetService.AddService("TagService", TagService)

return Entity
