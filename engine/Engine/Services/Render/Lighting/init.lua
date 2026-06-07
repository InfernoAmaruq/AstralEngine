local Renderer = select(1, ...)
local Lighting = {}

local MainShader = Renderer.GetMainShader()
local MainBufferFormat = MainShader:getBufferFormat("Lighting_Data")

local CacheTable = {}
local LightCount = 0
CacheTable.Light_LightCount = 0 -- amount of lights set
CacheTable.Light_Positions = table.alloc(256, 0)
CacheTable.Light_Colors = table.alloc(256, 0)
CacheTable.Light_Directions = table.alloc(256, 0)
CacheTable.Light_Extras = table.alloc(256, 0)
CacheTable.Light_ExtrasTwo = table.alloc(256, 0)

local LightBuffer = lovr.graphics.newBuffer(MainBufferFormat)
Lighting.LightBuffer = LightBuffer

LightBuffer:setData(CacheTable)

local LightRegistry = {} -- we use this to hold LightEntity = IdInBuffer registry

local LightType = ENUM({
    Point = 0,
    Spot = 1,
    Surface = 2,
    Directional = 3,
}, "LightType")

Lighting.AddLight = function(LightEntity, EarlyLightComponent)
    local LC = EarlyLightComponent or LightEntity.Light
    local Color = LC.Color
    local Distance = LC.Distance
    local Angle = LightEntity.Orientation
    local TargetAngle = LC.Angle or -1

    local Type = (LC.Type or LightType.Point).RawValue

    Angle = Angle and Angle:direction() or vec3(0, 0, 1)
    local ReadyAngle = vec4(Angle.x, Angle.y, Angle.z, math.cos(math.rad(TargetAngle / 2)))

    Distance = Distance * Distance

    local Pos = LightEntity.Position

    local PosVector = vec4(Pos.x, Pos.y, Pos.z, Distance)

    local Id = LightRegistry[LightEntity]

    if not Id then
        LightCount = LightCount + 1
        Id = LightCount
        LightRegistry[LightEntity] = Id
        CacheTable.Light_LightCount = LightCount
    end

    CacheTable.Light_Colors[Id] = CacheTable.Light_Colors[Id] or Vec4()
    CacheTable.Light_Colors[Id]:set(Color)

    CacheTable.Light_Positions[Id] = CacheTable.Light_Positions[Id] or Vec4()
    CacheTable.Light_Positions[Id]:set(PosVector)

    CacheTable.Light_Directions[Id] = CacheTable.Light_Directions[Id] or Vec4()
    CacheTable.Light_Directions[Id]:set(ReadyAngle)

    local ExtrasVector = vec4()
    ExtrasVector.xy = LC.SurfaceSize or vec2.zero
    ExtrasVector.z = Type
    ExtrasVector.w = 1 / (LC.Hardness or 1)

    CacheTable.Light_Extras[Id] = CacheTable.Light_Extras[Id] or Vec4()
    CacheTable.Light_Extras[Id]:set(ExtrasVector)

    LightBuffer:setData(CacheTable)
end

Lighting.RemoveLight = function(LightEntity)
    local Id = LightRegistry[LightEntity]

    local Top = LightCount
    if Top == 1 then
        CacheTable.Light_Colors[Id]:set(0)
        CacheTable.Light_Positions[Id]:set(0)
        CacheTable.Light_Directions[Id]:set(0)
        CacheTable.Light_Extras[Id]:set(0)
    elseif Top ~= Id then
        local TopEnt = table.find(LightRegistry, Top)
        LightRegistry[TopEnt] = Id

        CacheTable.Light_Colors[Id]:set(CacheTable.Light_Colors[Top])
        CacheTable.Light_Positions[Id]:set(CacheTable.Light_Positions[Top])
        CacheTable.Light_Directions[Id]:set(CacheTable.Light_Directions[Top])
        CacheTable.Light_Extras[Id]:set(CacheTable.Light_Extras[Top])
    end

    LightRegistry[LightEntity] = nil

    LightCount = LightCount - 1
    CacheTable.Light_LightCount = LightCount
    LightBuffer:setData(CacheTable)
end

return Lighting
