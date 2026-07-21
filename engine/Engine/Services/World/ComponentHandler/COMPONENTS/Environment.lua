local Component = GetService("Component")

local EmptySkybox = AstralEngine.Graphics.NewTexture(1, 1, 6)

local Environment = { Name = "Environment" }

Environment.Metadata = {}

local Indexes = {
    Skybox = 1,
    UseSkyboxHarmonics = 2,

    -- buffer data
    Ambient = 3,
    LinearY = 4,
    LinearX = 5,
    LinearZ = 6,
    QuadX2 = 7,
    QuadXY = 8,
    QuadY2 = 9,
    QuadYZ = 10,
    QuadZ2 = 11,

    Gamma = 12,
    Exposure = 13,
}

local Mt = {
    __index = function(self, k)
        if Indexes[k] then
            if Indexes[k] >= Indexes.Ambient and Indexes[k] <= Indexes.Ambient + 8 then
                return vec3(self[Indexes[k]]):mul(256)
            end
            return self[Indexes[k]]
        end
    end,
    __newindex = function(self, k, v)
        local Key = Indexes[k]

        if k == "Skybox" then
            AstralEngine.Assert(
                typeof(v) == "Texture" or v == nil,
                "Invalid input for 'Skybox' field. Expected Texture or nil, got: " .. typeof(v),
                "Environment"
            )

            if v then
                AstralEngine.Assert(v:getType() == "cube", "Skyboxes must be cube maps", "Environment")
            end

            self[1] = v or EmptySkybox
            self.__UpdateBuffers = true
        elseif k == "UseSkyboxHarmonics" then
            self[2] = not not v
            self.__UpdateBuffers = self[2]
        elseif Key >= Indexes.Ambient and Key <= Indexes.Ambient + 8 then
            v = v / 256

            self[Key]:set(v)
            self.UserHarmonics:setData(self, 1, Indexes.Ambient, 9)
        elseif Key >= Indexes.Gamma then
            self[Key] =
                AstralEngine.Assert(type(v) == "number" and v, "Not a number provided for field: " .. k, "Environment")
        end
    end,
}

local Format = { "vec3", layout = "std430" }

Environment.Metadata.__create = function(Data, Entity)
    local self = {}

    if not Component.GetComponent(Entity, "Camera") then
        AstralEngine.Log("Camera component missing! Environment will not work!", "warn", "Environment")
    end

    local Skybox = Data.Skybox or EmptySkybox

    self[1] = Skybox
    self[2] = Data.UseSkyboxHarmonics == nil and true or Data.UseSkyboxHarmonics

    for i = Indexes.Ambient, Indexes.Ambient + 8 do
        self[i] = Vec3(0, 0, 0)
    end

    self[Indexes.Gamma] = Data.Gamma or 1
    self[Indexes.Exposure] = Data.Exposure or 1

    self.__EnvHarmonics = lovr.graphics.newBuffer(Format, 9)
    self.__UpdateBuffers = Skybox ~= EmptySkybox and true or false

    self.UserHarmonics = lovr.graphics.newBuffer(Format, 9)

    return setmetatable(self, Mt)
end

return Environment
