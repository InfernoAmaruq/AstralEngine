local PluginHandler = {}
local PluginCache = {}

AstralEngine.Plugins = PluginHandler
PluginHandler.Cache = PluginCache

local LateFuncs = {}

PluginHandler.Load = function(Path)
    AstralEngine.Assert(lovr.filesystem.isDirectory(Path), "INVALID PLUGIN. PLUGIN MUST BE A DIRECTORY", "PLUGIN")

    local S, MetadataFile = pcall(loadfile, Path .. "/meta.lua")

    if not S or type(MetadataFile) == "string" or not MetadataFile then
        AstralEngine.Log(
            "ERROR LOADING PLUGIN AT: " .. Path .. " ERROR: " .. (MetadataFile or "no file meta.lua found"),
            "warn",
            "PLUGIN"
        )
        return
    end

    local Alloc = {}

    local Success, Tab = pcall(MetadataFile, Alloc)

    AstralEngine.Assert(Success, "FAILED TO LOAD PLUGIN META.LUA FILE: " .. tostring(Tab), "PLUGIN")
    AstralEngine.Assert(Tab and rtype(Tab) == "table" and Tab.Name, "INVALID DATA INSIDE META.LUA FILE", "PLUGIN")

    if PluginCache[Tab.Name] then
        return
    end

    PluginCache[Tab.Name] = {
        Version = Tab.Version or "UNKNOWN",
    }
    PluginHandler[Tab.Name] = Alloc

    if Tab.AliasMap then
        for LocalPath, Alias in pairs(Tab.AliasMap) do
            local FullPath = lovr.filesystem.normalize(Path .. "/" .. LocalPath)
            lovr.filesystem.alias(FullPath, Alias)
        end
    end

    if Tab.OnRead then
        Tab.OnRead()
    end
    if Tab.OnLoad then
        table.insert(LateFuncs, Tab.OnLoad)
    end
end

PluginHandler.Finish = function()
    PluginHandler.Finish = nil

    for _, Func in ipairs(LateFuncs) do
        Func()
    end

    LateFuncs = nil
end

return PluginHandler
