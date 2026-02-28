return {
    Define = {},
    Astral = {
        Debug = true,
        Modules = {
            Headset = false,
        },
        Tick = {},
    },
    Game = {
        Version = "0",
        Identity = "ASTRL_TEST_GAME",
        Window = {
            Width = 1000,
            Height = 1000,
        },
    },
    Filesystem = {
        EntryScene = false,
    },
}

--[[
     δ   σ
             δ
    /\   /\
δ   \/·`·\/
    «_@ @_»
 σ    \w/ σ
  δ
            δ
> FlareAmaro
]]

--[[
   _____________
   \/           \
	╔───────────╗
	│ F         │	
	│   σ    δ  │	
	│  /\   /\  │	
	│  \/·`·\/  │	
	│  «_@ @_»  │	
	│    \w/ σ  │	
	│  δ        │	
	│         A │	
	╚───────────╝
]]

-- making an archive
-- zip -r ./ASTRAL_GAME.zip ./Engine/ && cd ../../testgame && zip -r ../build/bin/ASTRAL_GAME.zip ./UITesting ./meta.lua && cd ../build/bin && cat ./astral ASTRAL_GAME.zip > GAMEEXE && chmod +x GAMEEXE
