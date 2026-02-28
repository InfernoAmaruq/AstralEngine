local FS = lovr.filesystem

local ExtToTry = { "", ".laf" }

local LAFReader = {}

LAFReader.Mounted = {}

function LAFReader.LoadArchive(Path, EntryPoint, Depth)
    local Folder = FS.folderFromPath(Path)
    local FileName = Path:gsub(Folder, "")
    local OSPath = FS.getRealDirectory(Path) or Path

    local RelativePath = FS.folderFromPath(FS.getCurrentPath(Depth or 2))
    local Normalized = FS.normalize(RelativePath .. "/" .. Path)

    local PathsToTry = {
        Path,
        Path .. "/" .. FileName,
        OSPath .. "/" .. FileName,
        Normalized,
        Normalized .. "/" .. FileName,
    }

    for _, P in ipairs(PathsToTry) do
        for _, Ext in ipairs(ExtToTry) do
            local IsFile = FS.isFile(P .. Ext)
            if IsFile then
                local LAFPath = P .. Ext

                local Extracted = FS.extractor.Extract(LAFPath)

                local s, err = FS.mount(Extracted, LAFPath)
                if not s and err ~= "Already mounted" then
                    AstralEngine.Error("Failed to read LAF archive! " .. err, "LAF")
                end

                local EPTag = EntryPoint or "init.lua"
                local EP = LAFPath .. "/" .. EPTag

                AstralEngine.Assert(FS.isFile(EP), "Failed to load LAF archive! No file " .. EPTag .. " found!", "LAF")

                return loadfile(EP)
            end
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
