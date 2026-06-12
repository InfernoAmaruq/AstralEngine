if not meta.getdefined("Audio", "Active") then
    return nil
end

local AudioMesh = { Name = "AudioMesh", Metadata = {} }

local AudioMeshType = ENUM({
    Inherited = 1,
    Manual = 2,
}, "AudioMeshType")

AudioMesh.Metadata.__create = function(Data, Ent)
    local t = {}

    return t
end

return AudioMesh
