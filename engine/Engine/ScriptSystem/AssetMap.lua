local AssetMapLoader = {}

local EntityService = GetService("Entity", "EntityService")

local function LoadAssetFile(Path)
    local f = loadfile(Path)
    return f and f() or error("Failed to load asset file at path: " .. Path)
end

local TAG_OFFSET = 50
local TAG_UNSET = 0b00 << TAG_OFFSET
local TAG_FORCE = 0b01 << TAG_OFFSET
local TAG_ANY = 0b10 << TAG_OFFSET

function AssetMapLoader.GetAssetMap(AssetMapFS, Folder)
    local Map = {}
    Map.LARGEST = -1
    Map.SMALLEST = math.huge

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
                for i, Val in ipairs(err) do
                    if Map[i] then
                        AstralEngine.Log(
                            "ID COLLISION: Id of "
                            .. i
                            .. "already defined in previous asset map. Error while loading: "
                            .. UsePath,
                            "Warning",
                            "SCENEMANAGER"
                        )
                    end
                    if Map.LARGEST < i then
                        Map.LARGEST = i
                    end
                    if Map.SMALLEST > i then
                        Map.SMALLEST = i
                    end
                    Map[i] = Val
                end
            end
        end
    end

    return Map
end

function AssetMapLoader.LoadAssetMap(Map)
    local Root = Map.SMALLEST
    local End = Map.LARGEST

    if Root == math.huge or End == -1 then
        AstralEngine.Log("Asset map " .. Map.PATH .. " is empty", "Warning", "SCENEMANAGER")
        return
    end

    local AssertedGap

    for i = Root, End do
        local Val = Map[i]
        if not Val then
            if not AssertedGap then
                AstralEngine.Log(
                    "Found gap in asset map! At index: " .. Val .. " at path: " .. Map.PATH,
                    "Warning",
                    "SCENEMANAGER"
                )
            end
            continue
        end

        local Ent

        if i & TAG_ANY ~= 0 or i & TAG_UNSET == 0 then
            Ent = EntityService.New(Val.Name)
        elseif i & TAG_FORCE ~= 0 then
            Ent = EntityService.CreateAtId(i, Val.Name)
        else
            AstralEngine.Log("INVALID TAG FOUND: " .. tostring(i >> TAG_OFFSET & 0b11), "Fatal", "SCENEMANAGER")
        end
    end
end

return AssetMapLoader
