local AudioSource = { Name = "AudioSource", Metadata = {} }

AudioSource.Metadata.__create = function(Data, Ent)
    local t = {}

    t.__effectRegistar = {}

    return t
end

return AudioSource
