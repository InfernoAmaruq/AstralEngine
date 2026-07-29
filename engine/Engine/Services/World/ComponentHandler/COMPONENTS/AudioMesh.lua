if not meta.getdefined("Audio", "Active") then
    return nil
end

local AudioMesh = { Name = "AudioMesh" }

local AudioMeshType = Enum({
    Inherited = 1,
    Manual = 2,
}, "AudioMeshType")

---@class AudioMesh: Component

AudioMesh.New = function(Data, Ent)
    local t = {}

    return t
end

return AudioMesh
