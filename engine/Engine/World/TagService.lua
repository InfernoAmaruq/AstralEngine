-- A service summoned by World/init.lua for managing tags
local SignalLib = AstralEngine.Plugins.SignalLib
local World = GetService("World")

local TagService = {}

--\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//
--                PRIVATE
--\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//

-- pattern: {[TAG] = {[ENTITY] = true}}
local Registry = {}

local function SilentClearTags(EId)
    -- silent, fast method to clear all tags from an entity, used by engine on teardown since we dont reallocate or drop registry references

    for _, Reg in pairs(Registry) do
        Reg[EId] = nil
    end
end

--\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//
--                PUBLIC
--\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//

-- signals
TagService.TagAdded = SignalLib.new(SignalLib.Type.RTC)
TagService.TagRemoved = SignalLib.new(SignalLib.Type.RTC)

-- virtualized to entity
function TagService.HasTag(Entity, Tag)
    local EntRef, EntId
    if rtype("Entity") == "number" then
        EntRef = World.Alive[Entity]
        EntId = Entity
        AstralEngine.Assert(EntRef and not EntRef.IsNull, "ATTEMPT TO USE TAGS ON DEAD ENTITY: " .. EntRef, "TAGS")
    else
        AstralEngine.Assert(not Entity.IsNull, "ATTEMPT TO USE TAGS ON DEAD ENTITY: " .. Entity, "TAGS")
        EntId = Entity.Id
        EntRef = Entity
    end

    Registry[Tag] = Registry[Tag] or {}
    local TagReg = Registry[Tag]

    local Val = TagReg[EntId]

    if not Val then
        return false
    else
        return true
    end
end

function TagService.AddTag(Entity, Tag)
    local EntRef, EntId
    if rtype("Entity") == "number" then
        EntRef = World.Alive[Entity]
        EntId = Entity
        AstralEngine.Assert(EntRef and not EntRef.IsNull, "ATTEMPT TO USE TAGS ON DEAD ENTITY: " .. EntRef, "TAGS")
    else
        AstralEngine.Assert(not Entity.IsNull, "ATTEMPT TO USE TAGS ON DEAD ENTITY: " .. Entity, "TAGS")
        EntId = Entity.Id
        EntRef = Entity
    end

    Registry[Tag] = Registry[Tag] or {}
    Registry[Tag][EntId] = true

    TagService.TagAdded:Fire(EntRef, Tag)
end

function TagService.RemoveTag(Entity, Tag)
    local EntRef, EntId
    if rtype("Entity") == "number" then
        EntRef = World.Alive[Entity]
        EntId = Entity
        AstralEngine.Assert(EntRef and not EntRef.IsNull, "ATTEMPT TO USE TAGS ON DEAD ENTITY: " .. EntRef, "TAGS")
    else
        AstralEngine.Assert(not Entity.IsNull, "ATTEMPT TO USE TAGS ON DEAD ENTITY: " .. Entity, "TAGS")
        EntId = Entity.Id
        EntRef = Entity
    end

    Registry[Tag] = Registry[Tag] or {}
    Registry[Tag][EntId] = nil

    TagService.TagRemoved:Fire(EntRef, Tag)
end

function TagService.ClearTags(Entity)
    local EntRef, EntId
    if rtype("Entity") == "number" then
        EntRef = World.Alive[Entity]
        EntId = Entity
        AstralEngine.Assert(EntRef and not EntRef.IsNull, "ATTEMPT TO USE TAGS ON DEAD ENTITY: " .. EntRef, "TAGS")
    else
        AstralEngine.Assert(not Entity.IsNull, "ATTEMPT TO USE TAGS ON DEAD ENTITY: " .. Entity, "TAGS")
        EntId = Entity.Id
        EntRef = Entity
    end

    for Tag, Reg in pairs(Registry) do
        if Reg[EntId] then
            Reg[EntId] = nil
            TagService.TagRemoved:Fire(EntRef, Tag)
        end
    end
end

function TagService.GetAllTags(Entity)
    local EntRef, EntId
    if rtype("Entity") == "number" then
        EntRef = World.Alive[Entity]
        EntId = Entity
        AstralEngine.Assert(EntRef and not EntRef.IsNull, "ATTEMPT TO USE TAGS ON DEAD ENTITY: " .. EntRef, "TAGS")
    else
        AstralEngine.Assert(not Entity.IsNull, "ATTEMPT TO USE TAGS ON DEAD ENTITY: " .. Entity, "TAGS")
        EntId = Entity.Id
        EntRef = Entity
    end

    local Ret = {}
    for Name, Reg in pairs(Registry) do
        if Reg[EntId] then
            Ret[#Ret + 1] = Name
        end
    end
    return Ret
end

-- global
function TagService.GetTagged(Tag)
    local Ret = {}

    if not Registry[Tag] then
        return Ret
    end

    for EntId in pairs(Registry[Tag]) do
        Ret[#Ret + 1] = World.GetEntityFromId(EntId)
    end

    return Ret
end

function TagService.GetTaggedUnsafe(Tag)
    return Registry[Tag]
end

return TagService, SilentClearTags
