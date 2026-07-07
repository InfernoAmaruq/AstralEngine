local DeviceQuery = {}

local GPUData = { Device = {}, Features = {}, Limits = {} }

for i, v in pairs(lovr.graphics.getDevice()) do
    GPUData.Device[i:sub(1, 1):upper() .. i:sub(2)] = v
end

for i, v in pairs(lovr.graphics.getFeatures()) do
    GPUData.Features[i:sub(1, 1):upper() .. i:sub(2)] = v
end

for i, v in pairs(lovr.graphics.getLimits()) do
    if type(v) == "table" then
        v = Vec3(unpack(v))
    end
    GPUData.Limits[i:sub(1, 1):upper() .. i:sub(2)] = v
end

DeviceQuery.GetDeviceProperty = function(Key)
    local Property = GPUData.Device[Key]

    if Property == nil then
        AstralEngine.Error("Invalid property key provided: " .. Key, "GPU")
    end

    return Property
end
DeviceQuery.GetFeature = function(Key)
    local Feature = GPUData.Features[Key]

    if Feature == nil then
        AstralEngine.Error("Invalid feature key provided: " .. Key, "GPU")
    end

    return Feature
end
DeviceQuery.GetLimit = function(Key)
    local Limit = GPUData.Limits[Key]

    if Limit == nil then
        AstralEngine.Error("Invalid limit key provided: " .. Key, "GPU")
    end

    if kind(Limit) == "lovrobj" then
        Limit = vec3(Limit)
    end

    return Limit
end

return DeviceQuery
