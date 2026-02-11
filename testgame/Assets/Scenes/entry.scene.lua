local Folder = select(2, ...)
local ScriptsFldr = "GAMEFILE/Assets/Scripts/"
local Map = "../AssetMaps/"

return {
    Mount = {},
    AssetMaps = { Map .. "CoreMap.lua", Map .. "PhysWorld.lua", Map .. "Folder.lua", Map .. "Objects.lua" },
    Scripts = {
        ScriptsFldr .. "TestScript.lua",
        "../Scripts/CoolScript.lua",
        "../Scripts/TilemapTest.lua",
        ScriptsFldr .. "UITest.lua",
    },
    ScriptValues = {},
}
