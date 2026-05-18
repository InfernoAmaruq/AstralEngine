local Renderer = select(1, ...)
local Lighting = {}

local MainShader = Renderer.GetMainShader()
local MainBufferFormat = MainShader:getBufferFormat("Lighting_Data")

local CacheTable = {}
local LightCount = 0
CacheTable.Light_LightCount = 0 -- amount of lights set
CacheTable.Light_Positions = {}
CacheTable.Light_Colors = {}

local LightBuffer = lovr.graphics.newBuffer(MainBufferFormat)
Lighting.LightBuffer = LightBuffer

LightBuffer:setData(CacheTable)

local LightRegistry = {} -- we use this to hold LightEntity = IdInBuffer registry

Lighting.AddLight = function(LightEntity)
    local Color = LightEntity.Light.Color
    local Distance = LightEntity.Light.Distance

    Distance = Distance * Distance

    local Pos = LightEntity.Position

    local PosVector = vec4(Pos.x, Pos.y, Pos.z, Distance)

    local Id = LightRegistry[LightEntity]

    if not Id then
        LightCount = LightCount + 1
        Id = LightCount
        CacheTable.Light_LightCount = LightCount
    end

    CacheTable.Light_Colors[Id] = CacheTable.Light_Colors[Id] or Vec4()
    CacheTable.Light_Colors[Id]:set(Color)
    CacheTable.Light_Positions[Id] = CacheTable.Light_Positions[Id] or Vec4()
    CacheTable.Light_Positions[Id]:set(PosVector)

    LightBuffer:setData(CacheTable)
end

Lighting.RemoveLight = function(LightEntity)
    --
end

Lighting.AddLight({
    Light = {
        Color = vec4(1, 0, 0, 0.5),
        Distance = 40,
    },
    Position = vec3(10, 8, 10),
})

return Lighting
