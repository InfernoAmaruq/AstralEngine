local ShaderService = require("ShaderService")

local Renderer = {}
Renderer.CamMask = bit.bnot(0)
local PassTable = {}

-- PASS STORAGE
local CONSTOFFSET = lovr.headset and 2 or 1
-- Allocate an AO texture
Renderer.PassStorage = {
    __CORE = {},
    PassTable = PassTable,
    PreTable = {},
    PostTable = {},
}

function Renderer.PassStorage.AddPass(P, Pass, Id)
    local T = Renderer.PassStorage[P and "PostTable" or "PreTable"]

    T[Id] = T[Id] or {}
    table.insert(T[Id], Pass)

    Renderer.PassStorage.RebuildPassTable()
end

function Renderer.PassStorage.RemovePass(Pass)
    for i = 1, 2 do
        local Search = i == 1 and "PreTable" or "PostTable"
        for _, T in pairs(Renderer.PassStorage[Search]) do
            for j, P in pairs(T) do
                if P == Pass then
                    Renderer.PassStorage[Search][j] = nil
                    break
                end
            end
        end
    end

    Renderer.PassStorage.RebuildPassTable()
end

function Renderer.PassStorage.RebuildPassTable()
    for i in pairs(PassTable) do
        PassTable[i] = nil
    end

    local Keys = {}

    local Top = 0

    for id in pairs(Renderer.PassStorage.PreTable) do
        Keys[#Keys + 1] = id
    end

    table.sort(Keys)

    for _, Id in ipairs(Keys) do
        local v = Renderer.PassStorage.PreTable[Id]
        for _, Pass in ipairs(v) do
            Top = Top + 1
            PassTable[Top] = Pass[1] or Pass
        end
    end

    for i = Top + 1, Top + CONSTOFFSET do
        PassTable[i] = false -- padding
    end

    -- SUBMIT NEW ID
    AstralEngine.Graphics.__WPASS_EMPTYID = Top + 1

    Top = Top + CONSTOFFSET
    Keys = {}

    for id in pairs(Renderer.PassStorage.PostTable) do
        Keys[#Keys + 1] = id
    end
    table.sort(Keys)

    for _, Id in ipairs(Keys) do
        local v = Renderer.PassStorage.PostTable[Id]
        for _, Pass in ipairs(v) do
            Top = Top + 1
            PassTable[Top] = Pass[1] or Pass
        end
    end
end

function Renderer.GetPassTable()
    return PassTable
end

-- ASSET HANDLING

Renderer.Assets = {}
Renderer.Assets.Meshes = {}
Renderer.Assets.Textures = {}
Renderer.Assets.Shaders = {}

-- LATE INIT

Renderer.Late = {}
function Renderer.LateCall()
    for _, v in pairs(Renderer.Late) do
        v()
    end
    Renderer.Late = nil
end

-- RENDERING DATA

for _, File in ipairs(lovr.filesystem.getAliasedFiles("RenderCalls")) do
    local f = loadfile(File)(Renderer)
    if f then
        Renderer.Late[#Renderer.Late + 1] = f
    end
end

local SignalLib = require("Lib/Signal")
AstralEngine.Signals.OnMainShaderChanged = SignalLib.new(SignalLib.Type.RTC)

local Shader = ShaderService.NewShader(Enum.ShaderType.Graphics, "Camera/Camera.glsl", {
    Defines = {
        Fragment = {
            MAX_LIGHTS = 256,
        },
    },
})

Renderer.SetMainShader(Shader)

Renderer.Lighting = loadfile("Lighting")(Renderer)

GetService.AddService("Renderer", Renderer)

return Renderer
