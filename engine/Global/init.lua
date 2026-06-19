local Path = lovr.filesystem.folderFromPath(lovr.filesystem.getCurrentPath())

for _, FileName in ipairs(lovr.filesystem.getDirectoryItems(Path)) do
    if
        (
            (lovr.filesystem.isFile(Path .. "/" .. FileName) and FileName:find(".lua"))
            or lovr.filesystem.isDirectory(Path .. "/" .. FileName)
        )
        and not FileName:match("%init.lua$")
    then
        print("LOAD:", Path .. "/" .. FileName)
        require(FileName)
    end
end
