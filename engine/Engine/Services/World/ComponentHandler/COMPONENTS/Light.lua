local Light = {}

local LightService
local World = GetService("World", "World")

local LightEnum = ENUM.LightType

Light.Name = "Light"
Light.Metadata = {}

local KeyMap = {
    Color = 1,
    Distance = 2,
    Hardness = 3,
    Angle = 4,
    Type = 5,
    Enabled = 7,
    SurfaceSize = 8,
}

local Methods = {
    __OnTransformChanged = function(self)
        LightService.Translate(self[6])
    end,
}

local MetaTable = {
    __index = function(self, k)
        local Key = KeyMap[k]
        if Key == KeyMap.Color then
            return vec4(self[1]):mul(255)
        elseif Key == KeyMap.SurfaceSize then
            return vec2(self[8])
        end
        return Key and self[Key] or Methods[k]
    end,
    __newindex = function(self, k, v)
        local Key = KeyMap[k]
        if Key then
            if Key == KeyMap.Color then
                local R, G, B, A = (v / 255):unpack()
                self[1]:set(R, G, B, A or 1)
            elseif Key == KeyMap.SurfaceSize then
                self[8]:set(v)
            elseif Key == KeyMap.Enabled then
                self[Key] = v
                if not v then
                    LightService.RemoveLight(self[6])
                    return
                end
            else
                self[Key] = v
            end

            LightService.AddLight(self[6])
        end
    end,
}

Light.Metadata.__create = function(Input, Ent)
    local L = {}

    local EntRef = World.GetEntityFromId(Ent)
    local _ = EntRef.Transform or EntRef:AddComponent("Transform")

    LightService = LightService or GetService("Renderer").Lighting

    local Type = Input.Type or LightEnum.Point

    local r, g, b, a = (Input.Color or vec4(255, 255, 255, 255)):unpack()
    L[1] = Vec4(r, g, b, a or 255):div(255)
    L[2] = Input.Distance or 16
    L[3] = Input.Hardness or 1
    L[4] = Input.Angle or 90
    L[5] = Type
    L[6] = EntRef
    L[7] = Input.Enabled == nil and true or Input.Enabled
    L[8] = Input.SurfaceSize or Vec2()

    setmetatable(L, MetaTable)

    if L[7] then
        LightService.AddLight(EntRef, L)
    end

    return L
end

Light.Metadata.__remove = function(self)
    LightService.RemoveLight(self[6])
end

return Light
