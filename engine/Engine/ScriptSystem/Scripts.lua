local ScriptLoader = {}

function ScriptLoader.LoadScriptList(List, Folder, ...)
    for _, v in ipairs(List) do
        local LocalPath = lovr.filesystem.normalize(Folder .. v)

        local IsGlobal = lovr.filesystem.isFile(v)
        local IsLocal = lovr.filesystem.isFile(LocalPath)

        AstralEngine.Assert(
            IsGlobal or IsLocal,
            "INVALID SCRIPT PATHS AT: " .. LocalPath .. " AND " .. v,
            "SCENEMANAGER"
        )
        local UsePath = IsGlobal and v or LocalPath

        local Content = lovr.filesystem.read(UsePath)

        Content = [[
        local RES = select(1,...)
        ]] .. Content

        local Ok, Result = pcall(comp_loadstring, Content, UsePath)
        AstralEngine.Assert(Ok, "SCRIPT LOADING ERROR:\n > " .. tostring(Result), "SCENEMANAGER")
        Result(...)
    end
end

return ScriptLoader
