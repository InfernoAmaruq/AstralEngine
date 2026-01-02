-- DECLARATION
local RunSer = GetService("RunService")
local BUFFER = nil
local CAM = _G.CAM
local CAMCOMP = CAM:GetComponent("Camera")

local SOLIDCAMPASS = CAMCOMP.SolidPass

-- COMPUTE
local FORMAT = {
    { name = "VertexPosition", type = "vec3" },
    { name = "VertexColor",    type = "vec4" },
    { name = "VertexNormal",   type = "vec3" },
}
local DATA = {}

local INDECIES = {}

local function BUILDBUFFER()
    BUFFER = lovr.graphics.newMesh(FORMAT, DATA, "gpu")
    BUFFER:setIndices(INDECIES)
end

local Success, SHADER = pcall(
    lovr.graphics.newShader,
    "unlit",
    [[

    layout(constant_id = 0) const bool SET_COLOR = true;

    vec4 lovrmain()
    {
        #ifdef SET_COLOR
        return vec4(0.0f,0.0f,0.0f,0.0f);
        #endif
        return Color;
    }

]],
    {
        flags = {
            SET_COLOR = true,
        },
    }
)

if not Success then
    print(SHADER)
    return
end

local function BINDDRAW()
    CAMCOMP.DrawToScreen = false
    RunSer.BindToStep("DRAW_TERRAIN", 801, function(Pass)
        SOLIDCAMPASS:setShader(SHADER)
        SOLIDCAMPASS:draw(BUFFER, 0, -100, 0)
        SOLIDCAMPASS:setColor(0, 0.4, 1, 0.5)
        SOLIDCAMPASS:plane(500, -60, 500, 1000, 1000, math.rad(-90), 1, 0, 0)

        Pass:fill(SOLIDCAMPASS:getCanvas()[1])
    end)
end

local function SaveVector(x, y, z, r, g, b)
    table.insert(DATA, { x, y, z, r, g, b, 1, 0, 1, 0 })
end

-- GEN

local Noise = lovr.math.noise
local SEED = 0x32ff12f4

local Amplitude = 100
local ScaleX, ScaleZ = 1000, 1000
local SizeX, SizeZ = 1000, 1000

local OffsetX, OffsetZ = SEED * 0.137, SEED * 0.513

local Octaves = 8

local function OctNoise(x, y, oc)
    local n = 0
    for i = 1, oc do
        n = n + Noise(x * i, y * i) * (1 / (i + 1))
    end
    return n
end

for X = 0, SizeX - 1 do
    for Z = 0, SizeZ - 1 do
        local x = (X + OffsetX) / ScaleX
        local z = (Z + OffsetZ) / ScaleZ
        local Height = OctNoise(x, z, Octaves)

        local r = math.random()
        local g = math.random()
        local b = math.random()

        SaveVector(X, Height * Amplitude, Z, r * Height, g * Height, b * Height)
    end
end

for X = 0, SizeX - 2 do
    for Z = 0, SizeZ - 2 do
        local i = X * SizeZ + Z + 1
        table.insert(INDECIES, i)
        table.insert(INDECIES, i + SizeZ + 1)
        table.insert(INDECIES, i + SizeZ)
        table.insert(INDECIES, i)
        table.insert(INDECIES, i + 1)
        table.insert(INDECIES, i + SizeZ + 1)
    end
end

BUILDBUFFER()
BINDDRAW()
