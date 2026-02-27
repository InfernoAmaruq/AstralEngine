local FS = lovr.filesystem

local ExtToTry = { "", ".laf" }

local LAFReader = {}

LAFReader.Mounted = {}

function LAFReader.LoadArchive(Path, Depth)
    Path = FS.getRealDirectory(Path) or Path

    local Mounted, Err = FS.mount(Path, Path, true, nil) -- append so re-requires take priority ig

    local RelativePath = FS.folderFromPath(FS.getCurrentPath(Depth or 2))
    local Normalized = FS.normalize(RelativePath .. "/" .. Path)

    local PathsToTry = {
        Path,
        Normalized,
    }

    for _, P in ipairs(PathsToTry) do
        for _, Ext in ipairs(ExtToTry) do
            local IsFile = FS.isFile(P .. Ext)
        end
    end

    return nil
end

return {
    __NAME = "LAF",
    __PRO = function()
        return LAFReader
    end,
}
