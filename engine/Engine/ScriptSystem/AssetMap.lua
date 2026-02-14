local AssetMapLoader = {}

local PhysicsService = GetService("Physics", "PhysicsService")
local EntityService = GetService("Entity", "EntityService")
local ComponentService = GetService("Component", "ComponentService")

local TAG_OFFSET = 40
local TAG_UNSET = 0b00 << TAG_OFFSET
local TAG_FORCE = 0b01 << TAG_OFFSET
local TAG_RES = 0b10 << TAG_OFFSET

local TAG_MASK = 0b11 << TAG_OFFSET
local ID_MASK = ~TAG_MASK

local BYTE = 8
local FENVFLAGS = {
    F_PHYS_WORLD = 0b0001 << BYTE,
    F_PHYS_MAINWORLD = 0b0010 << BYTE,
    F_ENT_NOCTX = 0b0100 << BYTE,
}

local FLAG_RESOLVE = {
    [FENVFLAGS.F_PHYS_MAINWORLD] = function(Ent)
        PhysicsService.SetMainWorld(Ent)
    end,
    [FENVFLAGS.F_ENT_NOCTX] = function(Ent)
        Ent.__context = 0
    end,
}

local SinkNidx = function()
    return
end

local RES_PTR = 0
local RES_HASH = {}
local INV_RES_HASH = {}

local RTMT = {
    __index = function(self, Name)
        local RealName = "@CACHE:" .. Name
        local PTR = rawget(self, RealName)
        if not PTR then
            return nil
        end
        local EntityId, UUID = rawget(self, PTR), rawget(self, PTR + 1)
        local EntPtr = EntityService.GetEntityFromId(EntityId)
        if EntityId and UUID and EntPtr and EntPtr.UniqueId == UUID then
            return EntPtr
        end
        -- free referene when not used anymore
        self[PTR] = nil
        self[PTR + 1] = nil
        self[RealName] = nil
        return nil
    end,
}

local CURSHARED
local FENV = setmetatable({
    GID = setmetatable({}, {
        __index = function(_, n)
            return n | TAG_FORCE
        end,
        __newindex = SinkNidx,
    }),
    RES = setmetatable({}, {
        __index = function(_, s)
            if RES_HASH[s] then
                return RES_HASH[s]
            end
            RES_PTR = RES_PTR + 1
            local RET = RES_PTR | TAG_RES
            RES_HASH[s] = RET
            INV_RES_HASH[RES_PTR] = s
            return RET
        end,
        __newindex = SinkNidx,
    }),
}, {
    __index = function(_, k)
        return FENVFLAGS[k] or CURSHARED[k] or _G[k]
    end,
    __newindex = function(_, k, v)
        rawset(CURSHARED, k, v)
    end,
})

local function LoadAssetFile(Path)
    local f = loadfile(Path)
    setfenv(f, FENV)
    return f and f() or error("Failed to load asset file at path: " .. Path)
end

function AssetMapLoader.GetAssetMap(AssetMapFS, Folder)
    RES_PTR = 0
    RES_HASH = {}
    INV_RES_HASH = {}

    local IDs = {}

    local Map = {}
    Map.LARGEST = -1
    Map.SMALLEST = math.huge
    Map.PATH = Folder

    local RESERVE = {}

    CURSHARED = {}

    for _, v in ipairs(AssetMapFS) do
        local GlobalPath = v
        local LocalPath = lovr.filesystem.normalize(Folder .. "/" .. v)

        local GlobalFile, LocalFile = lovr.filesystem.isFile(GlobalPath), lovr.filesystem.isFile(LocalPath)

        if GlobalFile or LocalFile then
            local UsePath = GlobalFile and GlobalPath or LocalPath

            local s, err = pcall(LoadAssetFile, UsePath)
            if not s then
                AstralEngine.Log(
                    "Failed to load asset map at " .. UsePath .. "\n > with error: " .. err,
                    "fatal",
                    "SCENEMANAGER"
                )
            else
                for i, Val in pairs(err) do
                    local RawId = i
                    i = i & ID_MASK
                    local Tag = RawId & TAG_MASK

                    if Tag == TAG_RES then
                        AstralEngine.Assert(not RESERVE[i], "Slot " .. i .. " already reserved!", 1)
                        RESERVE[i] = true
                    elseif Tag == TAG_FORCE and IDs[i] then
                        AstralEngine.Log(
                            "ID COLLISION: Id of "
                            .. i
                            .. " already defined in previous asset map. Error while loading: "
                            .. UsePath,
                            "Warning",
                            "SCENEMANAGER"
                        )
                    else
                        IDs[i] = true
                    end

                    Map[#Map + 1] = Val
                    Val.Idx = i
                    Val.Ptr = RawId
                    Val.Map = UsePath
                end
            end
        end
    end

    return Map
end

local function ResolveParent(Child, Parent)
    local ChildAnc = Child:GetComponent("Ancestry") or Child:AddComponent("Ancestry")
    local _ = Parent:GetComponent("Ancestry") or Parent:AddComponent("Ancestry")
    ChildAnc:SetParent(Parent)
end

function AssetMapLoader.LoadAssetMap(Map)
    local RESERVED = {}

    if #Map == 0 then
        AstralEngine.Log("Asset map " .. Map.PATH .. " is empty", "Warning", "SCENEMANAGER")
        return
    end

    local ENTITIES = {}

    -- SPAWNING ASSETS

    local LateCache = {}

    for i = 1, #Map do
        local Val = Map[i]
        if not Val then
            AstralEngine.Log(
                "Found gap in asset map! At index: " .. i .. " at path: " .. Map.PATH,
                "Warning",
                "SCENEMANAGER"
            )
            continue
        end

        local Ent
        local Tag = Val.Ptr & TAG_MASK
        local NewId = Val.Ptr & ID_MASK

        local Flags = Val.Flags and Val.Flags or 0

        -- summon the entity
        if Flags & FENVFLAGS.F_PHYS_WORLD ~= 0 then
            local WorldData = Val.WorldData or nil
            local Phys = GetService("Physics")
            Ent = Phys.NewWorld(WorldData, Tag & TAG_FORCE ~= 0 and NewId or nil)
            if Tag & TAG_RES ~= 0 and not (Tag & TAG_FORCE ~= 0) then
                if RESERVED[NewId] then
                    AstralEngine.Log(
                        "RESERVED ID COLLISION, WITH ID " .. NewId .. " ON ENTITY " .. Val.Name,
                        "error",
                        "SCENEMANAGER"
                    )
                end
                RESERVED[NewId] = Ent
            end
        else
            if Tag & TAG_FORCE ~= 0 then
                Ent = EntityService.CreateAtId(NewId, Val.Name)
            elseif Tag & TAG_RES ~= 0 then
                if RESERVED[NewId] then
                    AstralEngine.Log(
                        "RESERVED ID COLLISION, WITH ID " .. NewId .. " ON ENTITY " .. Val.Name,
                        "error",
                        "SCENEMANAGER"
                    )
                end
                Ent = EntityService.New(Val.Name)
                RESERVED[NewId] = Ent
            elseif Tag & TAG_UNSET == 0 then
                Ent = EntityService.New(Val.Name)
            else
                AstralEngine.Log("INVALID TAG FOUND: " .. tostring(i >> TAG_OFFSET & 0b11), "Fatal", "SCENEMANAGER")
            end
        end

        ENTITIES[Val.Map] = ENTITIES[Val.Map] or {}

        ENTITIES[Val.Map][Val.Idx] = {
            ENT = AstralEngine.Assert(Ent, ("Entity creation failed for entity: " .. Val.Name), "SCENEMANAGER"),
            VAL = Val,
        }

        -- RESOLVE FLAGS
        local FLAG_I = 0
        while FLAG_I < 53 do -- double int precision is up to 53 bits
            local FlagVal = Flags & (1 << FLAG_I)

            if FLAG_RESOLVE[FlagVal] then
                FLAG_RESOLVE[FlagVal](Ent)
            end

            FLAG_I = FLAG_I + 1
        end

        -- ASSIGNING FIELDS

        if not Val.Components then
            continue
        end
        -- we have late init components, like 'Colliders', which MUST have a transform present at build time (not optional, like with Camera transform)
        for Name, Data in pairs(Val.Components) do
            local COMPONENT_DATA = ComponentService.Components[Name]
            if COMPONENT_DATA and COMPONENT_DATA.Metadata and COMPONENT_DATA.Metadata.SceneLateLoad then
                LateCache[Name] = Data
                continue
            end

            Ent:AddComponent(Name, Data, true)
        end

        for Name, Data in pairs(LateCache) do
            LateCache[Name] = nil
            Ent:AddComponent(Name, Data, true)
        end
    end

    -- RESOLVE ANCESTRY

    for _, EntList in pairs(ENTITIES) do
        for _, Obj in pairs(EntList) do
            local Core = Obj.VAL
            local ResolveTo = Core.Parent
            if not ResolveTo then
                continue
            end
            local Ent = Obj.ENT
            local Tag, Val = ResolveTo & TAG_MASK, ResolveTo & ID_MASK

            if Tag == TAG_RES then
                local EntityTarget =
                    AstralEngine.Assert(RESERVED[Val], "INVALID RESERVE FIELD FOUND: " .. Val, "SCENEMANAGER")
                ResolveParent(Ent, EntityTarget)
            elseif Tag == TAG_FORCE then
                local EntityTarget = AstralEngine.Assert(
                    EntityService.GetEntityFromId(Val),
                    "INVALID RESERVE FIELD FOUND: " .. Val,
                    "SCENEMANAGER"
                )
                ResolveParent(Ent, EntityTarget)
            else
                ResolveParent(
                    Ent,
                    AstralEngine.Assert(
                        EntList[ResolveTo],
                        "NON-EXISTENT ID FOR PARENT RESOLUTION: " .. Val,
                        "SCENEMANAGER"
                    ).ENT
                )
            end
        end
    end

    -- final part: resolve res table to pass it to scripts

    local RT = {}
    setmetatable(RT, RTMT)

    local Ptr = 1

    for Id, Ent in pairs(RESERVED) do
        local Str = INV_RES_HASH[Id]
        RT["@CACHE:" .. Str] = Ptr
        RT[Ptr] = Ent.Id
        RT[Ptr + 1] = Ent.UniqueId
        Ptr = Ptr + 2
    end

    return RT
end

return AssetMapLoader
