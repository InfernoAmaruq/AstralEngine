local Folder = select(2, ...)
local ScriptsFldr = "GAMEFILE/Assets/Scripts/"
local Map = "../AssetMaps/"

return {
    Mount = {},
    AssetMaps = { Map .. "CoreMap.lua", Map .. "PhysWorld", Map .. "Folder.lua", Map .. "Objects.lua" },
    Scripts = { ScriptsFldr .. "TestScript.lua" },
}
