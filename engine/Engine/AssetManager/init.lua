local l_NewBlobFile = lovr.filesystem.newBlob
local l_NewBlob = lovr.data.newBlob

local STRICT_LOAD = meta.getdefined("Asset", "StrictLoad")

local NormalizePath = lovr.filesystem.normalize

local function GetPath(Path, Stack)
    return NormalizePath(lovr.filesystem.folderFromPath(lovr.filesystem.getCurrentPath(3 + (Stack or 0))) .. Path)
end

local function FNV1A32(Str)
    local Hash = 0x811c9dc5
    for i = 1, #Str do
        Hash = (Hash ^^ string.byte(Str, i)) * 0x01000193
        Hash = Hash & 0xFFFFFFFF
    end
    return string.format("%08x", Hash)
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
    Material = 9,
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
            Cache[TypeEnum.ImageData][ImagePath], DeadCache[TypeEnum.ImageData][ImagePath] = Image, nil
            return Image
        end
    else
        return Image
    end

    if not Image then
        local ImgFromFile = NewImage(ImagePath)

        if ImgFromFile then
            -- ALLOCATE IMAGE DATA TABLE

            local Table = {
                DATA = ImgFromFile,
                CTX = _G.CONTEXT and _G.CONTEXT.Gen or 0,
            }

            Cache[TypeEnum.ImageData][FNV1A32(ImagePath)] = Table
            return Table
        end
    end
end

function AssetManager.NewImage(ImagePath)
    local CanonPath = GetPath(ImagePath)
    local Image = GetRawImageData(CanonPath)

    local ReturnValue = nil

    if Image then
        ReturnValue = NewImage(CanonPath, Image.DATA)
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
        return AstralEngine.Graphics.NewTexture(ImageData.DATA, Options)
    else
        return nil
    end
end

local MaterialKeyArray = {
    "Color",
    "Glow",
    "UVShift",
    "UVScale",
    "Metalness",
    "Roughness",
    "Clearcoat",
    "ClearcoatRoughness",
    "OcclusionStrength",
    "NormalScale",
    "AlphaCutoff",
    "Texture",
    "GlowTexture",
    "MetalnessTexture",
    "RoughnessTexture",
    "ClearcoatTexture",
    "OcclusionTexture",
    "NormalTexture",
}

local function ProcessMaterialInput(Input)
    -- tokenize
    local Str = ""

    local InputProcessed = {}

    for i, v in pairs(Input) do
        if i == "Color" or i == "Glow" then
            local r, g, b, a

            local t = rtype(v)
            if t == "table" then
                r, g, b, a = unpack(t)
            else
                r, g, b, a = v:unpack()
            end

            InputProcessed[i] = { r, g, b, a }
        elseif i == "UvShift" or i == "UvScale" then
            local x, y

            local t = rtype(v)
            if t == "table" then
                x, y = unpack(t)
            elseif t == "number" then
                x = v
                y = v
            else
                x, y = v:unpack()
            end

            InputProcessed[i] = { x, y }
        elseif i:match("[%w_]*[Tt]exture[%w_]*") then
            local ObjType = rtype(v)

            local t = ObjType == "string" and AssetManager.NewTexture(v) or (v[1] or v)

            InputProcessed[i] = t[1] or t -- NewTexture gives wrapped texture, we need unwrapped
        else
            InputProcessed[i] = v
        end
    end

    for _, Field in ipairs(MaterialKeyArray) do
        local Lower = Field:sub(1, 2):lower() .. Field:sub(3)
        local Val = InputProcessed[Field]

        InputProcessed[Field] = nil
        InputProcessed[Lower] = Val -- lovr likes camelCase, i like pascalCase

        local SubStr = "[" .. Field .. "]="
        local Type = rtype(Val)

        if Type == "number" then
            SubStr = SubStr .. tostring(Val) .. ";"
        elseif Type == "table" then
            local Len = #Val
            for i, TableValue in ipairs(Val) do -- always array, always number
                SubStr = SubStr .. tostring(TableValue) .. (i == Len and ";" or ",")
            end
        elseif Val then
            SubStr = SubStr .. debug.getaddress(Val) .. ";"
        end

        Str = Str .. SubStr
    end

    local Hashed = FNV1A32(Str)

    return Hashed, InputProcessed
end

local MatMt = {__type = "Material",__newindex = function() AstralEngine.Error("MATERIALS ARE READ-ONLY","MATERIAL",2) end}

function AssetManager.NewMaterial(Input)
    local Hash, InputProcessed = ProcessMaterialInput(Input)

    local Material = Cache[TypeEnum.Material][Hash]
    if not Material then
        Material = DeadCache[TypeEnum.Material][Hash]
        if Material then
            Cache[TypeEnum.Material][Hash], DeadCache[TypeEnum.Material][Hash] = Material, nil
            return Material
        end
    else
        return Material
    end

    local LovrMat = lovr.graphics.newMaterial(InputProcessed)

    Material = setmetatable({
        __lmat = LovrMat,
        Properties = Input
    },MatMt)

    return Material
end

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
