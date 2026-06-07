local Component = GetService("Component")

local DOF = {}
DOF.Name = "DepthOfFieldFX"
DOF.Metadata = {}

local FieldToId = {
    FocusRadius = x,
    FocusDistance = y,
    NearIntensity = z,
    FarIntensity = w,
}

local MT = {
    __index = function(self, k)
        local Key = FieldToId[k]
        if Key then
            return self.__gpuBuffer[Key]
        end
    end,
    __newindex = function(self, k, v)
        local Key = FieldToId[k]
        if Key then
            self.__gpuBuffer[Key] = v
        end
    end,
}

DOF.Metadata.__create = function(Input, Entity)
    if not Component.HasComponent(Entity, "Camera") then
        AstralEngine.Log("Camera component missing! DepthOfFieldFX will not work!", "warn", "FX")
    end

    local t = {}

    t.Active = Input.Active == nil and true or Input.Active

    local FocusRadius = Input.FocusRadius or 10
    local FocusDistance = Input.FocusDistance or 0
    local NearIntensity = Input.NearIntensity or 1
    local FarIntensity = Input.FarIntensity or 1
    local Fade = Input.FadeDistance or 3

    t.__gpuBuffer = Vec4(FocusRadius, FocusDistance, NearIntensity, FarIntensity)
    t.FadeDistance = Fade

    return setmetatable(t, MT)
end

return DOF
