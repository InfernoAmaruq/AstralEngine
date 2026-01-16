local Folder = select(2, ...)
local ScriptsFldr = "GAMEFILE/Assets/Scripts/"

return {
    Mount = {},
    AssetMaps = { "../AssetMaps/CoreMap.lua" },
    Scripts = { ScriptsFldr .. "TestScript.lua" },
}
