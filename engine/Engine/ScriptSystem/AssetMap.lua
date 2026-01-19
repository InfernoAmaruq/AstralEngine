local AssetMapLoader = {}

local EntityService = GetService("Entity", "EntityService")

local TAG_OFFSET = 40
local TAG_UNSET = 0b00 << TAG_OFFSET
local TAG_FORCE = 0b01 << TAG_OFFSET
local TAG_RES = 0b10 << TAG_OFFSET

local TAG_MASK = 0b11 << TAG_OFFSET
local ID_MASK = ! TAG_MASK

local FENVFLAGS = {
    F_PHYS_WORLD = 0b0001
}

local SinkNidx = function() return end

local RES_PTR = 0
local RES_HASH = {}

local CURSHARED
local FENV = setmetatable({
        GID = setmetatable({}, {
            __index = function(_, n)
                return n | TAG_FORCE
            end,
            __newindex = SinkNidx
        }),
        RES = setmetatable({}, {
            __index = function(_, s)
                if RES_HASH[s] then
                    return RES_HASH[s]
                end
                RES_PTR = RES_PTR + 1
                RES_HASH[s] = RES_PTR
                return RES_PTR | TAG_RES
            end,
            __newindex = SinkNidx,
        })
    },
    {
        __index = function(_, k) return FENVFLAGS[k] or CURSHARED[k] or _G[k] end,
        __newindex = function(_, k, v)
            rawset(
                CURSHARED, k, v)
        end
    })

local function LoadAssetFile(Path)
    local f = loadfile(Path)
    setfenv(f, FENV)
    return f and f() or error("Failed to load asset file at path: " .. Path)
end

function AssetMapLoader.GetAssetMap(AssetMapFS, Folder)
    RES_PTR = 0
    RES_HASH = {}

    local IDs = {}

    local Map = {}
    Map.LARGEST = -1
    Map.SMALLEST = math.huge

    CURSHARED = {}

    for _, v in ipairs(AssetMapFS) do
        local GlobalPath = v
        local LocalPath = lovr.filesystem.normalize(Folder .. "/" .. v)

        local GlobalFile, LocalFile = lovr.filesystem.isFile(GlobalPath), lovr.filesystem.isFile(LocalPath)

        if GlobalFile or LocalFile then
            local UsePath = GlobalFile and GlobalPath or LocalPath

            Map.PATH = UsePath

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
                    local Tag = i & TAG_MASK

                    if Tag == TAG_RES then
                        -- handle reserve
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
                    Val.Ptr = RawId
                end
            end
        end
    end

    return Map
end

function AssetMapLoader.LoadAssetMap(Map)
    local Root = Map.SMALLEST
    local End = Map.LARGEST

    local RESERVED = {}

    if #Map == 0 then
        AstralEngine.Log("Asset map " .. Map.PATH .. " is empty", "Warning", "SCENEMANAGER")
        return
    end

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

        if Flags & FENVFLAGS.F_PHYS_WORLD ~= 0 then
            -- construct world
        else

        end

        if Tag & TAG_FORCE ~= 0 then
            Ent = EntityService.CreateAtId(NewId, Val.Name)
        elseif Tag & TAG_RES ~= 0 then
            if RESERVED[NewId] then
                AstralEngine.Log("RESERVED ID COLLISION, WITH ID " .. NewId .. " ON ENTITY " .. Val.Name, "error",
                    "SCENEMANAGER")
            end
            Ent = EntityService.New(Val.Name)
            RESERVED[NewId] = Ent
        elseif Tag & TAG_UNSET == 0 then
            Ent = EntityService.New(Val.Name)
        else
            AstralEngine.Log("INVALID TAG FOUND: " .. tostring(i >> TAG_OFFSET & 0b11), "Fatal", "SCENEMANAGER")
        end

        if Ent then
            print("SPAWNED:", Ent, Ent.Id, Ent.UniqueId)
        end
    end
end

return AssetMapLoader
