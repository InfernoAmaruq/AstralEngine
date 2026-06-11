local AudioSource = { Name = "AudioSource", Metadata = {} }

local Methods = {
    Play = function(self, SoundId, Volume, Start) end,
    AddSound = function(self, Sound, Name) end,
    RemoveSound = function(self, Name) end,
    GetSound = function(self, Name) end,
}

local Mt = {
    __newindex = function() end,
    __index = function(self, k)
        return Methods[k]
    end,
}

AudioSource.Metadata.__create = function(Data, Ent)
    local t = {}

    t.__effectRegistar = {}

    setmetatable(t, Mt)

    return t
end

return AudioSource
