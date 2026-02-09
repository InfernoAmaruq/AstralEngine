return function(ScriptService, Ctx)
    local Signal = require("../../Lib/Signal.lua")

    local ScenesPath = "GAMEFILE/Assets/Scenes/"

    local AppendsToTry = { "", ".lbmf", ".lua", ".aspr" }

    local LoadedScenes = {}
    local CurScene

    local SceneManager = {}

    SceneManager.OnLoadEnd = Signal.new(Signal.Type.RTC)
    SceneManager.OnLoadBegin = Signal.new(Signal.Type.RTC)
    SceneManager.OnUnloadEnd = Signal.new(Signal.Type.RTC)
    SceneManager.OnUnloadBegin = Signal.new(Signal.Type.RTC)

    local AssetMapLoader = require("./AssetMap")
    local ScriptLoader = require("./Scripts")
    local AssetLoader = require("./LoadAssets")

    -- PUBLIC

    function SceneManager.GetCurrentScene()
        return CurScene
    end

    function SceneManager.LoadScene(Scene)
        if LoadedScenes[Scene] then
            AstralEngine.Log("Scene " .. Scene .. " already loaded", "Warning", "SCENEMANAGER")
        end

        SceneManager.OnLoadBegin:Fire(Scene)

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

        SceneManager.OnLoadEnd:Fire(Scene, err)

        -- all done, time to load the files

        -- make a new context first

        CurScene = Scene

        _G.SceneCache = {}

        local SceneT = {}
        SceneT.Context = Ctx.New()

        local AssetMap = err.AssetMaps and AssetMapLoader.GetAssetMap(err.AssetMaps, Folder) or nil
        SceneT.AssetMap = AssetMap

        LoadedScenes[Scene] = SceneT
        _G.SceneCache.__SceneData = SceneT

        -- aaand get to loading shit

        local Reserved = AssetMapLoader.LoadAssetMap(AssetMap)

        local _ = err.Scripts
            and ScriptLoader.LoadScriptList(
                err.Scripts,
                Folder,
                Reserved,
                err.ScriptValues and unpack(err.ScriptValues)
            )
            or nil
    end

    function SceneManager.UnloadScene(Scene)
        if not LoadedScenes[Scene] then
            AstralEngine.Log("Scene " .. Scene .. " is not loaded", "Warning", "SCENEMANAGER")
        end

        SceneManager.OnUnloadBegin:Fire(Scene, LoadedScenes[Scene].Context)

        LoadedScenes[Scene].Context:KillAll()
        LoadedScenes[Scene] = nil
        SceneManager.OnUnload:Fire(Scene)
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
