local fs = select(1, ...)

local function normalize(path, full)
    local parts = {}

    for part in path:gmatch("[^/]+") do
        if part == ".." then
            table.remove(parts)
        elseif part ~= "." then
            table.insert(parts, part)
        end
    end

    if full then
        return "/" .. table.concat(parts, "/")
    end
    return table.concat(parts, "/")
end

-- PATH ALIASING

local cache = {}

fs.__aliasCache = cache
fs.alias = function(path, alias)
    alias = alias:gsub("^/+", ""):gsub("/+$", ""):gsub("//+", "/")
    cache[alias] = cache[alias] or {}

    table.insert(cache[alias], path)
end

fs.getAliasedFiles = function(alias)
    alias = alias:gsub("^/+", ""):gsub("/+$", ""):gsub("//+", "/")

    local filePaths = {}

    if not cache[alias] then
        return filePaths
    end

    local queue = {}
    local check = {}

    for _, path in ipairs(cache[alias]) do
        if check[path] then
            continue
        end
        check[path] = true
        if fs.isDirectory(path) then
            table.insert(queue, path)
        elseif fs.isFile(path) then
            table.insert(filePaths, path)
        end
    end

    while #queue > 0 do
        local curDir = table.remove(queue, 1)

        for _, item in ipairs(fs.getDirectoryItems(curDir)) do
            local path = curDir .. "/" .. item
            if check[path] then
                continue
            end
            check[path] = true

            if fs.isDirectory(path) then
                table.insert(queue, path)
            elseif fs.isFile(path) then
                table.insert(filePaths, path)
            end
        end
    end

    return filePaths
end

fs.getAliased = function(alias)
    alias = alias:gsub("^/+", ""):gsub("/+$", ""):gsub("//+", "/")

    return cache[alias] or {}
end

-- fs conversions
local fsType = package.config:sub(1, 1)
fsType = fsType == "\\" and "Win" or "Unix"
fs.filesystemType = fsType

fs.normalize = normalize

local patWin, patUnix = "\\", "%/"

fs.toWindows = function(path)
    return path:gsub(patUnix, patWin)
end

fs.toUnix = function(path)
    return path:gsub(patWin, patUnix)
end

-- pathing
fs.getCurrentPath = function(level)
    level = level or 1

    local info = debug.getinfo(level + 1, "S")
    local curPath = info and (info.source:sub(1, 1) == "@" and info.source:sub(2) or info.source)
    return curPath
end

fs.getExtension = function(path)
    local lastDot = path:match(".*()%.")
    if not lastDot then
        return nil
    end

    local afterDot = path:sub(lastDot + 1)
    if afterDot:find("/") then
        return nil
    end

    return path:sub(lastDot)
end

local fldrPattern = "[^/\\]+$"

fs.getExecutableFolder = function()
    return fs.getExecutablePath():gsub(fldrPattern, "")
end

fs.folderFromPath = function(p)
    return p:gsub(fldrPattern, "")
end

return fs
