local Renderer = select(1, ...)
local Lighting = {}

local MainShader = Renderer.GetMainShader()
local MainBufferFormat = MainShader:getBufferFormat("Lighting_Data")

local CacheTable = table.new(256, 0)
local LightCount = 0
Lighting.LightCount = 0

local LightBuffer = lovr.graphics.newBuffer(MainBufferFormat)
Lighting.LightBuffer = LightBuffer

Lighting.LTCTexture = GetService("AssetService").NewTexture("ltc_mat.dds", { linear = true })
Lighting.LTCAmp = GetService("AssetService").NewTexture("ltc_amp.dds", { linear = true })

LightBuffer:setData(CacheTable)

local LightRegistry = {} -- we use this to hold LightEntity = IdInBuffer registry

local LightType = Enum({
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

    local Type = (LC.Type or LightType.Point).Value

    Angle = Angle and Angle:direction() or vec3(0, 0, 1)

    Distance = Distance * Distance

    local Pos = LightEntity.Position

    local Id = LightRegistry[LightEntity]

    if not Id then
        LightCount = LightCount + 1
        Id = LightCount
        LightRegistry[LightEntity] = Id
        Lighting.LightCount = LightCount
    end

    local Tab = CacheTable or table.new(20, 0)
    CacheTable[Id] = Tab

    Tab[1], Tab[2], Tab[3] = Pos:unpack()
    Tab[4] = Distance

    Tab[5], Tab[6], Tab[7] = Angle:unpack()
    Tab[8] = math.cos(math.rad(TargetAngle / 2))

    Tab[9], Tab[10], Tab[11], Tab[12] = Color:unpack()

    Tab[13], Tab[14] = (LC.SurfaceSize or vec2.zero):unpack()
    Tab[15] = Type
    Tab[16] = 1 / (LC.Hardness or 1)

    Tab[17], Tab[18], Tab[19] = LightEntity.Transform.UpVector:unpack()
    local CastShadow = LC.ShadowCasting
    Tab[20] = CastShadow and 999 or -1 -- 999 as placeholder for now

    if Lighting.Shadowmap then
        if CastShadow then
            Lighting.Shadowmap.Add(LightEntity, LC, Tab)
        else
            Lighting.Shadowmap.Remove(LightEntity, Tab)
        end
    end

    LightBuffer:setData(CacheTable, 1, 1, LightCount)
end

Lighting.UpdateLight = function(E)
    if not E.Light then
        return
    end
    Lighting.AddLight(E)
end

Lighting.RemoveLight = function(LightEntity)
    local Id = LightRegistry[LightEntity]

    local Top = LightCount
    if Top == 1 then
        CacheTable[Id] = nil
    elseif Top ~= Id then
        local TopEnt = table.find(LightRegistry, Top)
        LightRegistry[TopEnt] = Id

        CacheTable[Id] = CacheTable[Top]
        -- yes, we are NOT freeing the top table we swap. Chances are they'll be needed again eventually, so no freeing for now
        -- Light_LightCount should point us to top, so we know when to stop
    end

    LightRegistry[LightEntity] = nil

    LightCount = LightCount - 1
    Lighting.LightCount = LightCount

    LightBuffer:setData(CacheTable, 1, 1, LightCount)

    if Lighting.Shadowmap then
        Lighting.Shadowmap.Remove(LightEntity)
    end
end

if meta.getdefined("Lighting", "DoShadowmap") then
    Lighting.Shadowmap = loadfile("Shadowmap")(Renderer, Lighting)
end

return Lighting
