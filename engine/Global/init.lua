local Path = lovr.filesystem.folderFromPath(lovr.filesystem.getCurrentPath())

for _, FileName in ipairs(lovr.filesystem.getDirectoryItems(Path)) do
    if FileName:match("%init.lua$") then
        continue
    end

    local File = require(FileName)

    if type(File) == "function" then
        return
    end

    local Processed = File.__PRO and File.__PRO() or File

    _G[File.__NAME] = Processed
end
