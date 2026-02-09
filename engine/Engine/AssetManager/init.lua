local l_NewBlobFile = lovr.filesystem.newBlob
local l_NewBlob = lovr.data.newBlob

local STRICT_LOAD = meta.getdefined("Asset", "StrictLoad")

local NormalizePath = lovr.filesystem.normalize

local function GetPath(Path, Stack)
    local Cur = lovr.filesystem.getCurrentPath(4 + (Stack or 0))
    return NormalizePath(lovr.filesystem.folderFromPath(lovr.filesystem.getCurrentPath(4 + (Stack or 0))) .. Path)
end

local AssetManager = {}

local TypeEnum = ENUM({
    ImageData = 1,
    Font = 2,
    Mesh = 3,
    ModelData = 4,
    Shader = 5,
    Sound = 6,
    Source = 7,
    RawBlob = 8,
}, "AssetType")

-- All offspin values are mutable and allocated individually
-- So, NewImage gives you a NEW image, it is on YOU to cache it later if need be

local WT = { __mode = "v" }

local Cache = {}
local DeadCache = {}
local RegToPath = setmetatable({}, { __mode = "k" })
for _, v in pairs(TypeEnum) do
    Cache[v] = {}
    DeadCache[v] = setmetatable({}, WT)
end

local function SearchCache(CacheObj, Obj, FilterBy)
    for Type, SubCache in pairs(CacheObj) do
        for Hash, Object in pairs(SubCache) do
            if Obj == (FilterBy and Hash or Object) then
                return true, (FilterBy and Object or Hash), Type
            end
        end
    end
    return false, nil, nil
end

local function GetObjPath(self)
    return RegToPath[self]
end

-- CONSTRUCTORS
-- cpu

function AssetManager.NewBlob(Path, Type, Name)
    local InputType = typeof(Path)

    if InputType == "string" then
        -- if string, it means its hashable
        local ConstPath = GetPath(Path)
        local Success, Res = pcall(GetBlob, ConstPath, Type) -- pcall because Type hint may be missing. We don't want an error here
        Blob = Success and Res or l_NewBlobFile(ConstPath)

        if not Success and Type and Blob then
            -- if Success it true, GetBlob() already cached it
            Cache[Type][ConstPath] = Blob
        end
        return Blob
    else
        -- otherwise, its not a string and is smth else
        Blob = l_NewBlob(Path, Name)
        -- in LOVR, this'll be pre-allocating a blob of n size or cloning a blob, so we do NOT cache
        return Blob
    end
end

-- img

local function NewImage(Path, ...)
    local Image = lovr.data.newImage(select("#", ...) > 0 and ... or Path)

    RegToPath[Image] = Path

    local MT = getmetatable(Image)
    if MT.__AstralTagged then
        return Image
    end

    MT.__index.getPath = GetObjPath
    MT.__AstralTagged = true

    return Image
end

local function GetRawImageData(ImagePath)
    local Image = Cache[TypeEnum.ImageData][ImagePath]

    if not Image then
        Image = DeadCache[TypeEnum.ImageData][ImagePath]
        if Image then
            Cache[TypeEnum.ImageData][ImagePath], DeadCache[TypeEnum.ImageData] = Image, nil
            return Image
        end
    else
        return Image
    end

    if not Image then
        local ImgFromFile = NewImage(ImagePath)

        if ImgFromFile then
            -- ALLOCATE IMAGE DATA TABLE
            Cache[TypeEnum.ImageData][ImagePath] = ImgFromFile
            return ImgFromFile
        end
    end
end

function AssetManager.NewImage(ImagePath)
    local CanonPath = GetPath(ImagePath)
    local Image = GetRawImageData(CanonPath)

    local ReturnValue = nil

    if Image then
        ReturnValue = NewImage(CanonPath, Image)
    end

    return ReturnValue
end

function AssetManager.NewSound() end

function AssetManager.NewModelData() end

-- gpu

function AssetManager.NewTexture(Path, Options)
    local CanonPath = GetPath(Path)
    local ImageData = GetRawImageData(CanonPath)

    if ImageData then
        return AstralEngine.Graphics.NewTexture(ImageData, Options)
    else
        return nil
    end
end

function AssetManager.NewMaterial() end

function AssetManager.NewMesh() end

function AssetManager.NewShader() end

function AssetManager.NewFont() end

function AssetManager.NewModel() end

-- misc
function AssetManager.LoadAsset() end

function AssetManager.KillCachedAsset() end

-- GETTERS

function AssetManager.GetDefaultFont() end

-- UTIL
function AssetManager.Alias() end

GetService.AddService("AssetService", AssetManager)

return AssetManager
