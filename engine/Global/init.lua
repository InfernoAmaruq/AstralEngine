local function ProcessDir(path, callback, recursive)
    for _, item in ipairs(lovr.filesystem.getDirectoryItems(path)) do
        local FullPath = path ~= "" and (path .. "/" .. item) or item
        local Info = lovr.filesystem.isFile(FullPath)
        if Info then
            callback(FullPath)
        else
            ProcessDir(FullPath, callback, recursive)
        end
    end
end

return function() -- Loads Global
    _G.processchildfiles = ProcessDir

    ProcessDir("Global", function(FileName)
        if not FileName:match("%.lua$") and not FileName:match("%init.lua$") then
            return
        end

        local File = require((FileName:gsub("%.lua$", "")))

        if type(File) == "function" then
            return
        end

        local Processed = File.__PRO and File.__PRO() or File

        _G[File.__NAME] = Processed
    end)
end
