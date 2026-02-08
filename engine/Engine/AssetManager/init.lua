local l_NewBlobFile = lovr.filesystem.newBlob
local l_NewBlob = lovr.data.newBlob

local NormalizePath = lovr.filesystem.normalize

local function GetPath(Path, Stack)
    return NormalizePath(lovr.system.folderFromPath(lovr.filesystem.getCurrentPath(4 + (Stack or 0))))
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

local Cache = {}
for _, v in pairs(TypeEnum) do
    Cache[v] = {}
end

-- CONSTRUCTORS
-- cpu
function AssetManager.StringBlob(String, Name)
    local Blob = l_NewBlob(String, Name)
end

function AssetManager.NewBlob(Path, Type, Name)
    local Blob
    if rtype(Path) == "string" then
        Blob = l_NewBlobFile(NormalizePath(Path))
    else
        Blob = l_NewBlob(Path, Name)
    end
end

function AssetManager.NewImage() end

function AssetManager.NewSound() end

function AssetManager.NewModelData() end

-- gpu

function AssetManager.NewTexture() end

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

GetService.AddService("AssetManager", AssetManager)

return AssetManager
