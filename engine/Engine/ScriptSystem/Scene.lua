return function(ScriptService, Ctx)
    local ScenesPath = "GAMEFILE/Assets/Scenes/"

    local AppendsToTry = { "", ".lbmf", ".lua", ".aspr" }

    local LoadedScenes = {}
    local CurScene

    local SceneManager = {}

    -- PRIVATE

    local function LoadAssetFile(Path)
        local f = loadfile(Path)
        return f()
    end

    local function GetAssetMap(AssetMapFS, Folder)
        local Map = {}

        for _, v in ipairs(AssetMapFS) do
            local GlobalPath = v
            local LocalPath = lovr.filesystem.normalize(Folder .. "/" .. v)

            local GlobalFile, LocalFile = lovr.filesystem.isFile(GlobalPath), lovr.filesystem.isFile(LocalPath)

            if GlobalFile or LocalFile then
                local UsePath = GlobalFile and GlobalPath or LocalPath

                local s, err = pcall(LoadAssetFile, UsePath)
                if not s then
                    AstralEngine.Log(
                        "Failed to load asset map at " .. UsePath .. "\n > with error: " .. err,
                        "fatal",
                        "SCENEMANAGER"
                    )
                else
                    for i, v in ipairs(err) do
                    end
                end
            end
        end

        return Map
    end

    -- PUBLIC

    function SceneManager.GetCurrentScene()
        return CurScene
    end

    function SceneManager.LoadScene(Scene)
        if LoadedScenes[Scene] then
            AstralEngine.Log("Scene " .. Scene .. " already loaded", "Warning", "SCENEMANAGER")
        end

        local SceneFile
        local HasScene = Scene:find("%.scene")
        for _, v in pairs(AppendsToTry) do
            local PATH = ScenesPath .. Scene .. (HasScene and "" or ".scene") .. v
            local IsFile = lovr.filesystem.isFile(PATH)
            if IsFile then
                SceneFile = PATH
                break
            end
        end

        if not SceneFile then
            AstralEngine.Log("Scene " .. Scene .. " does not exist!", "fatal", "SCENEMANAGER")
        end

        AstralEngine.Log("Loading scene: " .. Scene .. " at path: " .. SceneFile, "info", "SCENEMANAGER")

        local s, err = pcall(loadfile, SceneFile)
        if not s then
            AstralEngine.Log(
                { "Failed to parse scene file:", Scene, "at path:", SceneFile, "\n > with error:", err },
                "fatal",
                "SCENEMANAGER"
            )
        end

        local Folder = lovr.filesystem.folderFromPath(SceneFile)
        s, err = pcall(err, SceneFile, Folder)

        if not s then
            AstralEngine.Log({ "Failed to load scene file:", Scene, "at path:", SceneFile, "\n > with error:", err })
        end

        -- lua loading passed!! now we do whatevs we gotta do

        local AssetMap = err.AssetMaps and GetAssetMap(err.AssetMaps, Folder)

        LoadedScenes[Scene] = Ctx.New()
    end

    function SceneManager.UnloadScene(Scene)
        if not LoadedScenes[Scene] then
            AstralEngine.Log("Scene " .. Scene .. " is not loaded", "Warning", "SCENEMANAGER")
        end

        LoadedScenes[Scene]:KillAll()
        LoadedScenes[Scene] = nil
    end

    function SceneManager.ReloadScene(Scene)
        if LoadedScenes[Scene] then
            SceneManager.UnloadScene(Scene)
        end
        SceneManager.LoadScene(Scene)
    end

    GetService.AddService("SceneManager", SceneManager)
    return SceneManager
end
