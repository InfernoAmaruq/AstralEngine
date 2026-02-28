-- ZIP/DLL extractor!!
local Extractor = {}

local Base = "CACHE/EXTRACTION"

local function GetCacheFldr(Type, CanonPath)
    local p = Base .. "/" .. Type .. "/" .. CanonPath
    lovr.filesystem.createDirectory(p)
    return p
end

local Cache = {}

function Extractor.Extract(Path) -- assumes canon virtual path
    if Cache[Path] then
        return Cache[Path]
    end

    local GetOSPath = lovr.filesystem.getRealDirectory(Path)
    local Type = lovr.filesystem.getExtension(Path)

    Type = Type and Type:sub(2):upper() or "UNKNOWN"

    if not GetOSPath then
        -- path either is already valid or doesnt exist
        -- either way, no longer the extractors problem!
        return Path
    end

    local Folder = lovr.filesystem.folderFromPath(Path)
    local File = Path:gsub(Folder, "")

    local TargetPath = GetOSPath .. "/" .. Path

    if not lovr.filesystem.isFile(Path) then
        return
    end

    local TempBlob = lovr.filesystem.newBlob(Path)

    if not TempBlob then
        return
    end

    local Where = GetCacheFldr(Type, Folder)
    local FileName = Path:gsub(Folder, "")
    local CachePath = Where .. "/" .. FileName
    lovr.filesystem.write(CachePath, TempBlob)

    CachePath = lovr.filesystem.getSaveDirectory() .. "/" .. CachePath

    Cache[Path] = CachePath

    return CachePath
end

return Extractor
