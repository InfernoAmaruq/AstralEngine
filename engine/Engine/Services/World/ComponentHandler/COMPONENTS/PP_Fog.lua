---@class Fog: PostProcessingEffect

local Component = GetService("Component")

local Fog = {}
Fog.Name = "FogFX"
Fog.Metadata = {}

local BufferFormat = {
    { "fogColor",     "vec4" },
    { "horizonColor", "vec4" },
    { "otherData",    "vec4" },
    layout = "std140",
}

local MT = {}

Fog.Metadata.__create = function(Input, Entity)
    if not Component.GetComponent(Entity, "Camera") then
        AstralEngine.Log("Camera component missing! FogFX will not work!", "warn", "FX")
    end

    local t = {}

    t.Active = Input.Active == nil and true or Input.Active

    local Rf, Gf, Bf, Af = (Input.FogColor or vec4(180, 180, 180, 255)):unpack()
    local Rh, Gh, Bh, Ah = (Input.HorizonColor or vec4(255, 255, 255, 0)):unpack()

    local FogColor = Vec4(Rf, Gf, Bf, Af or 1)
    local HorizonColor = Vec4(Rh, Gh, Bh, Ah or 1)

    local OtherData = Vec4(Input.Near or 10, Input.Far or 1000, Input.Smooth or 1, Input.HorizonOffset or 0)

    t.__bufferTable = {
        fogColor = FogColor:div(255),
        horizonColor = HorizonColor:div(255),
        otherData = OtherData,
    }
    t.__gpuBuffer = lovr.graphics.newBuffer(BufferFormat, t.__bufferTable)

    setmetatable(t, MT)

    return t
end

return Fog
