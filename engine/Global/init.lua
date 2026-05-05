local Path = lovr.filesystem.folderFromPath(lovr.filesystem.getCurrentPath())

for _, FileName in ipairs(lovr.filesystem.getDirectoryItems(Path)) do
    if lovr.filesystem.isFile(Path .. "/" .. FileName) and not FileName:find(".lua") then
        continue
    end

    if FileName:match("%init.lua$") then
        continue
    end

    require(FileName)
end
